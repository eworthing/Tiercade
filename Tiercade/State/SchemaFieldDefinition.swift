import Foundation

struct SchemaFieldDefinition: Identifiable, Codable, Hashable, Sendable {
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
    }
}
