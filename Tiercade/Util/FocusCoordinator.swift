internal enum FocusRegion: Hashable {
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
    internal var isOverlay: Bool {
        switch self {
        case .grid, .toolbar, .actionBar:
            return false
        default:
            return true
        }
    }
}
