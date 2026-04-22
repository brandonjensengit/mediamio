//
//  ServerDiscoveryService.swift
//  MediaMio
//
//  Discovers Jellyfin servers on the local network via mDNS / Bonjour.
//  Browses `_jellyfin-server._tcp.` (modern) and `_jellyfin._tcp.` (legacy),
//  resolves each service endpoint to a real host:port using `NWConnection`,
//  and publishes the resulting list so the server-entry screen can offer
//  one-tap connect without the user typing a URL.
//
//  Constraint: never performs HTTP. It only emits candidate `http://host:port`
//  strings — the existing `AuthenticationService.testServerConnection` is the
//  single source of truth for whether a candidate is a real Jellyfin server.
//

import Combine
import Foundation
import Network

@MainActor
final class ServerDiscoveryService: ObservableObject {

    struct DiscoveredServer: Identifiable, Hashable {
        let name: String
        let host: String
        let port: Int

        var id: String { "\(host):\(port)" }

        var url: String {
            // Wrap IPv6 literals in brackets so they're URL-legal.
            let hostComponent = host.contains(":") ? "[\(host)]" : host
            return "http://\(hostComponent):\(port)"
        }
    }

    @Published private(set) var servers: [DiscoveredServer] = []
    @Published private(set) var isBrowsing: Bool = false

    private var browsers: [NWBrowser] = []
    private var resolvers: [String: NWConnection] = [:]
    private var pendingNames: [String: String] = [:]

    private static let serviceTypes = [
        "_jellyfin-server._tcp.",
        "_jellyfin._tcp."
    ]

    // MARK: - Lifecycle

    func start() {
        guard !isBrowsing else { return }
        isBrowsing = true

        for type in Self.serviceTypes {
            let params = NWParameters()
            params.includePeerToPeer = false

            let browser = NWBrowser(for: .bonjour(type: type, domain: nil), using: params)

            browser.browseResultsChangedHandler = { [weak self] results, _ in
                Task { @MainActor [weak self] in
                    self?.handle(results: results)
                }
            }

            browser.stateUpdateHandler = { state in
                if case .failed(let err) = state {
                    print("⚠️ NWBrowser(\(type)) failed: \(err)")
                }
            }

            browser.start(queue: .main)
            browsers.append(browser)
        }
    }

    func stop() {
        browsers.forEach { $0.cancel() }
        browsers.removeAll()
        resolvers.values.forEach { $0.cancel() }
        resolvers.removeAll()
        pendingNames.removeAll()
        isBrowsing = false
    }

    // MARK: - Browse → Resolve

    private func handle(results: Set<NWBrowser.Result>) {
        for result in results {
            guard case let .service(name: serviceName, type: _, domain: _, interface: _) = result.endpoint else {
                continue
            }
            let key = String(describing: result.endpoint)
            if resolvers[key] != nil { continue }

            let conn = NWConnection(to: result.endpoint, using: .tcp)
            resolvers[key] = conn
            pendingNames[key] = serviceName

            conn.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready, .waiting:
                    // Once the path is populated — either because the TCP handshake
                    // completed (`.ready`) or a connection attempt is in-flight
                    // (`.waiting`) — DNS-SD resolution has finished and
                    // `currentPath.remoteEndpoint` carries the real host:port.
                    Task { @MainActor [weak self] in
                        self?.harvest(from: conn, key: key)
                    }
                case .failed, .cancelled:
                    Task { @MainActor [weak self] in
                        self?.drop(key: key)
                    }
                default:
                    break
                }
            }
            conn.start(queue: .main)
        }
    }

    private func harvest(from conn: NWConnection, key: String) {
        defer {
            conn.cancel()
            drop(key: key)
        }

        guard case let .hostPort(host: host, port: port) = conn.currentPath?.remoteEndpoint else {
            return
        }

        let hostStr: String
        switch host {
        case .name(let name, _):
            hostStr = name
        case .ipv4(let addr):
            hostStr = "\(addr)"
        case .ipv6(let addr):
            hostStr = "\(addr)"
        @unknown default:
            return
        }

        let server = DiscoveredServer(
            name: pendingNames[key] ?? hostStr,
            host: hostStr,
            port: Int(port.rawValue)
        )

        if !servers.contains(where: { $0.id == server.id }) {
            servers.append(server)
        }
    }

    private func drop(key: String) {
        resolvers.removeValue(forKey: key)
        pendingNames.removeValue(forKey: key)
    }
}
