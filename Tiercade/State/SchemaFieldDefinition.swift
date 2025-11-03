import Foundation

internal struct SchemaFieldDefinition: Identifiable, Codable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var fieldType: FieldType
    var required: Bool
    var allowMultiple: Bool
    var options: [String]

    enum FieldType: String, Codable, CaseIterable, Sendable {
        case text
        case textarea
        case number
        case date
        case singleSelect
        case multiSelect
        case boolean

        var displayName: String {
            switch self {
            case .text: return "Text"
            case .textarea: return "Text Area"
            case .number: return "Number"
            case .date: return "Date"
            case .singleSelect: return "Single Select"
            case .multiSelect: return "Multi-Select"
            case .boolean: return "Yes/No"
            }
        }

        var icon: String {
            switch self {
            case .text: return "textformat"
            case .textarea: return "text.alignleft"
            case .number: return "number"
            case .date: return "calendar"
            case .singleSelect: return "list.bullet"
            case .multiSelect: return "checklist"
            case .boolean: return "checkmark.square"
            }
        }

        var guidance: String {
            switch self {
            case .text: return "Developer or publisher name"
            case .textarea: return "Long-form notes"
            case .number: return "Metacritic rating (0–100)"
            case .date: return "Release date"
            case .singleSelect: return "Platform family"
            case .multiSelect: return "Gameplay tags"
            case .boolean: return "Cross-play enabled?"
            }
        }

        var suggestion: String {
            switch self {
            case .text: return "Genre, Developer, Publisher"
            case .textarea: return "Notes, Synopsis, Strategy"
            case .number: return "Rating, Score, Year"
            case .date: return "Release Date, Launch"
            case .singleSelect: return "Platform, Status, Category"
            case .multiSelect: return "Tags, Genres, Features"
            case .boolean: return "Completed, Owned, Favorite"
            }
        }

        var exampleValue: String {
            switch self {
            case .text: return "Arcadia Studios"
            case .textarea: return "Boss fight strategy overview"
            case .number: return "87"
            case .date: return "Oct 22, 2024"
            case .singleSelect: return "Console"
            case .multiSelect: return "Co-op, Ranked"
            case .boolean: return "Yes"
            }
        }
    }
}
