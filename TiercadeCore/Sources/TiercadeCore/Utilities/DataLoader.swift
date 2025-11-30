import Foundation

// MARK: - DataVersion

public enum DataVersion: Int, Sendable { case v1 = 1 }

// MARK: - DataLoader

public struct DataLoader: Sendable {
    public init() {}

    public func decodeItems(from data: Data) throws -> [String: Item] {
        let decoder = JSONDecoder()
        return try decoder.decode([String: Item].self, from: data)
    }

    public func decodeGroups(from data: Data) throws -> [String: [String]] {
        let decoder = JSONDecoder()
        return try decoder.decode([String: [String]].self, from: data)
    }

    public func validate(groups: [String: [String]], items: [String: Item]) -> Bool {
        for (_, ids) in groups {
            for id in ids where items[id] == nil {
                return false
            }
        }
        return !items.isEmpty
    }
}
