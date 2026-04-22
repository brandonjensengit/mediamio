//
//  SavedServersStoreTests.swift
//  MediaMioTests
//
//  Contract tests for the persistence layer behind the multi-user server
//  picker. Uses a freshly created in-memory `UserDefaults` suite per test
//  so state can't leak between cases or into the shared standard suite.
//  The Keychain side of the store is not exercised here — hitting the real
//  `Security.framework` from unit tests is flaky in CI and the token
//  round-trip is covered implicitly via integration.
//

import Testing
import Foundation
@testable import MediaMio

@MainActor
struct SavedServersStoreTests {

    private func freshDefaults() -> UserDefaults {
        let name = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func testUser(id: String, name: String) -> User {
        User(
            id: id, name: name, serverId: "",
            hasPassword: true, hasConfiguredPassword: true
        )
    }

    @Test
    func remembersNewServerAndUser() {
        let store = SavedServersStore(defaults: freshDefaults())
        store.remember(
            serverURL: "http://jelly.lan:8096",
            serverName: "Lan Jelly",
            user: testUser(id: "u1", name: "alice"),
            accessToken: "t1"
        )

        #expect(store.servers.count == 1)
        #expect(store.servers[0].name == "Lan Jelly")
        #expect(store.servers[0].users.count == 1)
        #expect(store.servers[0].users[0].name == "alice")
    }

    @Test
    func remembersSecondUserOnSameServer() {
        let store = SavedServersStore(defaults: freshDefaults())
        store.remember(
            serverURL: "http://jelly.lan:8096",
            serverName: "Lan Jelly",
            user: testUser(id: "u1", name: "alice"),
            accessToken: "t1"
        )
        store.remember(
            serverURL: "http://jelly.lan:8096",
            serverName: "Lan Jelly",
            user: testUser(id: "u2", name: "bob"),
            accessToken: "t2"
        )

        #expect(store.servers.count == 1)
        #expect(store.servers[0].users.count == 2)
        #expect(store.servers[0].users.map(\.name).sorted() == ["alice", "bob"])
    }

    @Test
    func remembersTwoSeparateServers() {
        let store = SavedServersStore(defaults: freshDefaults())
        store.remember(
            serverURL: "http://jelly.lan:8096",
            serverName: "Lan",
            user: testUser(id: "u1", name: "alice"),
            accessToken: "t1"
        )
        store.remember(
            serverURL: "https://remote.example.com",
            serverName: "Remote",
            user: testUser(id: "u1", name: "alice"),
            accessToken: "t2"
        )

        #expect(store.servers.count == 2)
    }

    @Test
    func forgettingLastUserRemovesServer() {
        let store = SavedServersStore(defaults: freshDefaults())
        store.remember(
            serverURL: "http://jelly.lan:8096",
            serverName: "Lan",
            user: testUser(id: "u1", name: "alice"),
            accessToken: "t1"
        )

        store.forget(serverURL: "http://jelly.lan:8096", userId: "u1")
        #expect(store.servers.isEmpty)
    }

    @Test
    func forgettingOneOfTwoUsersKeepsServer() {
        let store = SavedServersStore(defaults: freshDefaults())
        store.remember(
            serverURL: "http://jelly.lan:8096",
            serverName: "Lan",
            user: testUser(id: "u1", name: "alice"),
            accessToken: "t1"
        )
        store.remember(
            serverURL: "http://jelly.lan:8096",
            serverName: "Lan",
            user: testUser(id: "u2", name: "bob"),
            accessToken: "t2"
        )

        store.forget(serverURL: "http://jelly.lan:8096", userId: "u1")
        #expect(store.servers.count == 1)
        #expect(store.servers[0].users.count == 1)
        #expect(store.servers[0].users[0].name == "bob")
    }

    @Test
    func persistsAcrossStoreInstances() {
        let defaults = freshDefaults()
        let first = SavedServersStore(defaults: defaults)
        first.remember(
            serverURL: "http://jelly.lan:8096",
            serverName: "Lan",
            user: testUser(id: "u1", name: "alice"),
            accessToken: "t1"
        )

        // A second instance pointed at the same UserDefaults suite should
        // observe the data the first one wrote — this is the contract the
        // app relies on when it relaunches and the picker needs to populate.
        let second = SavedServersStore(defaults: defaults)
        #expect(second.servers.count == 1)
        #expect(second.servers[0].users[0].name == "alice")
    }

    @Test
    func sortedReturnsMostRecentFirst() async throws {
        let store = SavedServersStore(defaults: freshDefaults())
        store.remember(
            serverURL: "http://a.lan",
            serverName: "A",
            user: testUser(id: "u1", name: "alice"),
            accessToken: "t1"
        )
        // Ensure the second remember lands with a strictly later timestamp.
        try await Task.sleep(nanoseconds: 5_000_000)
        store.remember(
            serverURL: "http://b.lan",
            serverName: "B",
            user: testUser(id: "u1", name: "alice"),
            accessToken: "t1"
        )

        #expect(store.sorted.map(\.name) == ["B", "A"])
    }
}
