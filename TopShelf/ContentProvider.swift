//
//  ContentProvider.swift
//  TopShelfExtension
//
//  Shows Continue Watching / Recently Added on the tvOS home screen.
//  Self-contained: reads credentials from the shared keychain group and
//  talks to Jellyfin directly (app code isn't linked into the extension).
//

import TVServices

class ContentProvider: TVTopShelfContentProvider {

    override func loadTopShelfContent() async -> TVTopShelfContent? {
        guard let credentials = SharedCredentials.load() else { return nil }

        async let resume = fetchItems(
            path: "/Users/\(credentials.userId)/Items/Resume",
            query: "Limit=8&MediaTypes=Video",
            credentials: credentials
        )
        async let latest = fetchItems(
            path: "/Users/\(credentials.userId)/Items/Latest",
            query: "Limit=8",
            credentials: credentials
        )

        var sections: [TVTopShelfItemCollection<TVTopShelfSectionedItem>] = []
        if let items = await resume, !items.isEmpty {
            let section = TVTopShelfItemCollection(items: items.map { topShelfItem(for: $0, credentials: credentials) })
            section.title = "Continue Watching"
            sections.append(section)
        }
        if let items = await latest, !items.isEmpty {
            let section = TVTopShelfItemCollection(items: items.map { topShelfItem(for: $0, credentials: credentials) })
            section.title = "Recently Added"
            sections.append(section)
        }

        return sections.isEmpty ? nil : TVTopShelfSectionedContent(sections: sections)
    }

    private func topShelfItem(for item: ShelfItem, credentials: SharedCredentials) -> TVTopShelfSectionedItem {
        let shelfItem = TVTopShelfSectionedItem(identifier: item.id)
        shelfItem.title = item.name
        shelfItem.imageShape = .poster
        shelfItem.setImageURL(
            URL(string: "\(credentials.serverURL)/Items/\(item.id)/Images/Primary?maxWidth=600&quality=90&api_key=\(credentials.accessToken)"),
            for: .screenScale1x
        )
        if let url = URL(string: "gloxx://item/\(item.id)") {
            shelfItem.displayAction = TVTopShelfAction(url: url)
            shelfItem.playAction = TVTopShelfAction(url: url)
        }
        return shelfItem
    }

    private func fetchItems(path: String, query: String, credentials: SharedCredentials) async -> [ShelfItem]? {
        guard let url = URL(string: "\(credentials.serverURL)\(path)?\(query)") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue(credentials.accessToken, forHTTPHeaderField: "X-Emby-Token")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }

        // /Latest returns a bare array; /Resume returns {"Items": [...]}
        if let wrapped = try? JSONDecoder().decode(ShelfItemsResponse.self, from: data) {
            return wrapped.items
        }
        return try? JSONDecoder().decode([ShelfItem].self, from: data)
    }
}

// MARK: - Minimal models

private struct ShelfItemsResponse: Decodable {
    let items: [ShelfItem]
    enum CodingKeys: String, CodingKey { case items = "Items" }
}

struct ShelfItem: Decodable {
    let id: String
    let name: String
    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
    }
}

// MARK: - Shared keychain credentials

struct SharedCredentials {
    let serverURL: String
    let accessToken: String
    let userId: String

    static func load() -> SharedCredentials? {
        guard
            let serverURL = read("serverURL"),
            let accessToken = read("accessToken"),
            let userId = read("userId")
        else { return nil }
        return SharedCredentials(serverURL: serverURL, accessToken: accessToken, userId: userId)
    }

    private static func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.mediamio.tvos",
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
