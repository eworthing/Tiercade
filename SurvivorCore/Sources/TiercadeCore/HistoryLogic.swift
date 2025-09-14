import Foundation

public enum HistoryLogic {
    public static func initHistory<T: Sendable>(_ initial: T, limit: Int = 50) -> History<T> {
        History(stack: [initial], index: 0, limit: max(1, limit))
    }

    public static func saveSnapshot<T: Sendable>(_ history: History<T>, snapshot: T) -> History<T> {
        var before = Array(history.stack.prefix(history.index + 1))
        before.append(snapshot)
        let overflow = max(0, before.count - history.limit)
        let newStack = overflow > 0 ? Array(before.suffix(history.limit)) : before
        return History(stack: newStack, index: newStack.count - 1, limit: history.limit)
    }

    public static func canUndo<T>(_ h: History<T>) -> Bool { h.index > 0 }
    public static func canRedo<T>(_ h: History<T>) -> Bool { h.index < h.stack.count - 1 }

    public static func undo<T>(_ h: History<T>) -> History<T> { canUndo(h) ? History(stack: h.stack, index: h.index - 1, limit: h.limit) : h }
    public static func redo<T>(_ h: History<T>) -> History<T> { canRedo(h) ? History(stack: h.stack, index: h.index + 1, limit: h.limit) : h }

    public static func current<T>(_ h: History<T>) -> T { h.stack[h.index] }
}
