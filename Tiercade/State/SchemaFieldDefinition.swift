import Foundation

struct SchemaFieldDefinition: Identifiable, Codable, Hashable, Sendable {
    enum FieldType: String, Codable, CaseIterable, Sendable {
        case text
        case textarea
        case number
        case date
        case singleSelect
        case multiSelect
        case boolean

        // MARK: Internal

        var displayName: String {
            switch self {
            case .text: "Text"
            case .textarea: "Text Area"
            case .number: "Number"
            case .date: "Date"
            case .singleSelect: "Single Select"
            case .multiSelect: "Multi-Select"
            case .boolean: "Yes/No"
            }
        }

        var icon: String {
            switch self {
            case .text: "textformat"
            case .textarea: "text.alignleft"
            case .number: "number"
            case .date: "calendar"
            case .singleSelect: "list.bullet"
            case .multiSelect: "checklist"
            case .boolean: "checkmark.square"
            }
        }

        var guidance: String {
            switch self {
            case .text: "Developer or publisher name"
            case .textarea: "Long-form notes"
            case .number: "Metacritic rating (0–100)"
            case .date: "Release date"
            case .singleSelect: "Platform family"
            case .multiSelect: "Gameplay tags"
            case .boolean: "Cross-play enabled?"
            }
        }

        var suggestion: String {
            switch self {
            case .text: "Genre, Developer, Publisher"
            case .textarea: "Notes, Synopsis, Strategy"
            case .number: "Rating, Score, Year"
            case .date: "Release Date, Launch"
            case .singleSelect: "Platform, Status, Category"
            case .multiSelect: "Tags, Genres, Features"
            case .boolean: "Completed, Owned, Favorite"
            }
        }

        var exampleValue: String {
            switch self {
            case .text: "Arcadia Studios"
            case .textarea: "Boss fight strategy overview"
            case .number: "87"
            case .date: "Oct 22, 2024"
            case .singleSelect: "Console"
            case .multiSelect: "Co-op, Ranked"
            case .boolean: "Yes"
            }
        }
    }

    var id = UUID()
    var name: String
    var fieldType: FieldType
    var required: Bool
    var allowMultiple: Bool
    var options: [String]

}
