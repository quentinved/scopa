/// How much the interface does for the player. It never changes the rules, only the help.
public enum AssistLevel: String, CaseIterable, Codable, Sendable, Hashable {
    /// Everything the beginner gets, and a coach on top of it: every card in hand weighed
    /// before it is played, and every move the other side makes told back with what it did.
    case coached
    /// Outlines what can be taken, fills in the only possible take, names it, and warns before a wrong one.
    case beginner
    /// No outlines, no filling in, no warning. A wrong take is played and refused by the rules.
    case normal

    public static let `default` = AssistLevel.normal

    public var title: String {
        switch self {
        case .coached: "Coached"
        case .beginner: "Beginner"
        case .normal: "Normal"
        }
    }

    public var detail: String {
        switch self {
        case .coached: "Talks you through your three cards, and through what the bot just did"
        case .beginner: "Outlines what you can take and fills in the obvious ones"
        case .normal: "You work out the take yourself, with no warning before a wrong one"
        }
    }

    /// Below normal the table shows which cards a take could use.
    public var highlightsCaptures: Bool { self != .normal }
    /// And has the single possible take filled in.
    public var fillsSingleCapture: Bool { self != .normal }
    /// And stops a take the rules would refuse before it is sent.
    public var checksBeforeSending: Bool { self != .normal }
    /// Only the coached level says anything about *why* a card is the one to play, and
    /// what the last move did. Everything else here is the interface being helpful; this
    /// is the game being explained, which is worth turning off once it has been learnt.
    public var explains: Bool { self == .coached }
}
