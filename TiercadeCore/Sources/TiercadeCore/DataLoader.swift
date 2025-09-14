import Foundation

public enum DataVersion: Int, Sendable { case v1 = 1 }

public struct DataLoader: Sendable {
    public init() {}

    public func decodeContestants(from data: Data) throws -> [String: Contestant] {
        let decoder = JSONDecoder()
        return try decoder.decode([String: Contestant].self, from: data)
    }

    public func decodeGroups(from data: Data) throws -> [String: [String]] {
        let decoder = JSONDecoder()
        return try decoder.decode([String: [String]].self, from: data)
    }

    public func validate(groups: [String: [String]], contestants: [String: Contestant]) -> Bool {
        for (_, ids) in groups {
            for id in ids where contestants[id] == nil { return false }
        }
        return !contestants.isEmpty
    }
}
