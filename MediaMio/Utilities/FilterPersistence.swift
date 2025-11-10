//
//  FilterPersistence.swift
//  MediaMio
//
//  Utility for persisting library filters per library
//

import Foundation

class FilterPersistence {
    private static let defaults = UserDefaults.standard
    private static let keyPrefix = "library_filters_"

    /// Save filters for a specific library
    static func save(_ filters: LibraryFilters, for libraryId: String) {
        let key = keyPrefix + libraryId

        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(filters)
            defaults.set(data, forKey: key)
            print("💾 Saved filters for library: \(libraryId)")
        } catch {
            print("❌ Failed to save filters for library \(libraryId): \(error)")
        }
    }

    /// Load filters for a specific library
    static func load(for libraryId: String) -> LibraryFilters? {
        let key = keyPrefix + libraryId

        guard let data = defaults.data(forKey: key) else {
            print("📂 No saved filters found for library: \(libraryId)")
            return nil
        }

        do {
            let decoder = JSONDecoder()
            let filters = try decoder.decode(LibraryFilters.self, from: data)
            print("📂 Loaded filters for library: \(libraryId) - \(filters.activeCount) active")
            return filters
        } catch {
            print("❌ Failed to load filters for library \(libraryId): \(error)")
            return nil
        }
    }

    /// Clear filters for a specific library
    static func clear(for libraryId: String) {
        let key = keyPrefix + libraryId
        defaults.removeObject(forKey: key)
        print("🗑️ Cleared filters for library: \(libraryId)")
    }

    /// Clear all saved filters
    static func clearAll() {
        let allKeys = defaults.dictionaryRepresentation().keys
        let filterKeys = allKeys.filter { $0.hasPrefix(keyPrefix) }

        for key in filterKeys {
            defaults.removeObject(forKey: key)
        }

        print("🗑️ Cleared all saved filters (\(filterKeys.count) libraries)")
    }
}
