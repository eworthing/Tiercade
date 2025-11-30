// MARK: - FocusRegion

enum FocusRegion: Hashable {
    case grid
    case toolbar
    case actionBar
    case detail
    case analytics
    case headToHead
    case quickRank
    case quickMove
    case itemMenu
    case themePicker
    case tierBrowser
}

extension FocusRegion {
    var isOverlay: Bool {
        switch self {
        case .actionBar,
             .grid,
             .toolbar:
            false
        default:
            true
        }
    }
}
