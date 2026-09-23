/// What a review makes of one move. The praise and the lessons are named in Scopa's own
/// terms, because "blunder" tells a card player nothing and "missed scopa" tells them everything.
public enum Verdict: String, Hashable, Codable, Sendable, CaseIterable {
    // Praise: the best move there was, and what made it worth noticing.
    /// Swept the table.
    case scopa
    /// Took the seven of coins.
    case settebello
    /// The best move, by the bot's reckoning.
    case best
    /// There was only one legal move, so there is nothing to judge.
    case forced
    /// Within a card or two of the best, which is close enough not to matter.
    case fine

    // Lessons, worst first.
    /// A sweep was there and something else was played.
    case missedScopa
    /// The seven of coins was laid on the table for anybody to take.
    case settebelloGiven
    /// The seven of coins could have been taken and was left.
    case settebelloMissed
    /// A card was laid while another card in hand could have taken.
    case missedTake
    /// A take was made, and a bigger pile was there for the taking.
    case weakTake
    /// A take was made, of a pile no smaller than the best one but worth less: the coins,
    /// the sevens, or the seven of coins itself were in the other one.
    case tookTheWrongCards
    /// Nothing could be taken, and the card laid opened the table to the next player.
    case exposedTable
    /// Nothing could be taken, the table was left no more open than it had to be, and the
    /// card put down was the wrong one to give up: a coin, or a card the primiera wanted.
    case gaveAwayAGoodCard

    public var isPraise: Bool {
        switch self {
        case .scopa, .settebello, .best: true
        default: false
        }
    }

    public var isLesson: Bool {
        switch self {
        case .missedScopa, .settebelloGiven, .settebelloMissed, .missedTake, .weakTake,
             .tookTheWrongCards, .exposedTable, .gaveAwayAGoodCard: true
        default: false
        }
    }
}

/// One move, judged. `view` is what the seat could see when it played, so the judgement
/// only ever uses what the player knew.
public struct MoveReview: Hashable, Sendable, Identifiable {
    /// Position in the game, counting every seat's moves from zero.
    public let id: Int
    /// Which deal of the deck, counting from one.
    public let round: Int
    public let seat: Int
    public let view: PlayerView
    public let move: Move
    /// The move the bot would have made. Equal to `move` when the move was the best.
    public let best: Move
    /// How far short of the best this move fell, in the bot's units. Zero for the best.
    public let gap: Int
    public let verdict: Verdict

    public var sweeps: Bool { view.isScopa(taking: move.captures) }
}

/// Every move of a game, judged from the seat that made it.
public struct GameReview: Hashable, Sendable {
    public let moves: [MoveReview]

    /// One seat's game, summed up.
    public struct Summary: Hashable, Sendable {
        /// How close, on average, the seat's moves came to the bot's, from 0 to 100.
        /// Forced moves are left out: a move nobody chose says nothing about the player.
        /// Near misses cost a little, so a game with no lessons in it still reads under 100.
        public let accuracy: Int
        public let counts: [Verdict: Int]
        /// The moves worth going back to: every lesson, biggest first.
        public let lessons: [MoveReview]
        /// The moves worth a nod: sweeps and the seven, in the order they came.
        public let highlights: [MoveReview]

        public var praiseCount: Int { counts.filter { $0.key.isPraise }.values.reduce(0, +) }
        public var lessonCount: Int { counts.filter { $0.key.isLesson }.values.reduce(0, +) }
    }

    public func moves(forSeat seat: Int) -> [MoveReview] {
        moves.filter { $0.seat == seat }
    }

    /// One seat's game summed up, or one round of it when `round` is given.
    ///
    /// Which one is asked for matters. A whole game averages a mistake across fifty-odd
    /// judged moves and the number stops moving: over twelve games, a seat playing at random
    /// scored 90% and one playing the first legal move scored 99%. A single round spreads
    /// the same play back out, 59% to 99% for the random seat, so a panel headed "Round 3"
    /// should ask for round 3.
    public func summary(forSeat seat: Int, round: Int? = nil) -> Summary {
        let mine = round.map { round in moves(forSeat: seat).filter { $0.round == round } }
            ?? moves(forSeat: seat)
        let judged = mine.filter { $0.verdict != .forced }
        let accuracy: Int
        if judged.isEmpty {
            accuracy = 100
        } else {
            let total = judged.reduce(0.0) { $0 + max(0, 1 - Double($1.gap) / Reviewer.accuracyScale) }
            accuracy = Int((total / Double(judged.count) * 100).rounded())
        }
        var counts: [Verdict: Int] = [:]
        for move in mine { counts[move.verdict, default: 0] += 1 }
        return Summary(
            accuracy: accuracy,
            counts: counts,
            lessons: mine.filter { $0.verdict.isLesson }.sorted { $0.gap > $1.gap },
            highlights: mine.filter { $0.verdict == .scopa || $0.verdict == .settebello }
        )
    }
}

/// Reads a record back and judges every move against what the bot would have done from
/// the same chair. It sees only what that seat saw, so it never blames a player for a card
/// they could not have known about.
public enum Reviewer {
    /// A gap this small is the difference between two cards of the same suit, not a mistake.
    static let fineGap = 12
    /// A missed scopa costs at least this much, and counts as an accuracy of zero for the move.
    static let accuracyScale = Double(Bot.Weight.scopa)

    /// A lesson the search reckons cost less than this much of a point is not a lesson. It
    /// is half of one of the four points on offer, which is about where the difference between
    /// two moves stops being something anybody could reasonably have been expected to see.
    static let forgiven = 0.5

    public static func review(_ record: GameRecord) -> GameReview {
        let bot = Bot()
        let steps = record.replay().steps
        let reviews = steps.enumerated().map { index, step -> MoveReview in
            let view = step.state.view(forSeat: step.move.seat)
            return judge(step.move, in: view, ordinal: index, round: step.state.roundNumber, bot: bot)
        }
        return GameReview(moves: reviews.map { second(look: $0, signature: record.signature) })
    }

    /// Every telling-off, put to the hard bot before it is shown to anybody.
    ///
    /// The verdicts above come from the normal bot's one-move weighing, which a search that
    /// plays the round out beats three games in four. So a move it calls a mistake is priced
    /// again by the search, and a move that costs next to nothing in points keeps its place.
    /// Only lessons get a second look, which keeps it cheap.
    ///
    /// Seeded from the game itself, so the same game reviewed twice reads the same way. The
    /// accuracy goes to the daily ladder, where a number that wobbles is no use.
    private static func second(look review: MoveReview, signature: UInt64) -> MoveReview {
        guard review.verdict.isLesson else { return review }
        var rng = SeededGenerator(seed: signature &+ UInt64(review.id))
        guard let opinions = Search.opinions(for: review.view, using: &rng),
              let best = opinions.map(\.value).max(),
              let played = opinions.first(where: {
                  $0.move.card == review.move.card && Set($0.move.captures) == Set(review.move.captures)
              })?.value,
              best - played < forgiven
        else { return review }
        // Not the best move, not a mistake either, which is what `fine` is for. The gap is
        // priced from the search's own answer rather than pinned to the top of the band: a
        // move level with the best costs nothing. Pinned at `fineGap`, a game with nothing
        // to teach still came out at 97%.
        let priced = Int(((best - played) / forgiven * Double(fineGap)).rounded())
        return MoveReview(id: review.id, round: review.round, seat: review.seat, view: review.view,
                          move: review.move, best: review.move,
                          gap: min(fineGap, max(0, priced)), verdict: .fine)
    }

    static func judge(_ move: Move, in view: PlayerView, ordinal: Int, round: Int, bot: Bot) -> MoveReview {
        let options = bot.evaluate(view)
        // The same take in a different order is the same move. Compared as a list it was
        // not, so a player who tapped the ace before the eight was marked down for a move
        // the bot itself would have made.
        let chosen = options.first { $0.move.card == move.card && Set($0.move.captures) == Set(move.captures) }?.score
            ?? options.map(\.score).min() ?? 0
        let top = options.max { $0.score < $1.score }
        // Among equals the bot picks at random, so the player's own move stands for all of them.
        let best = top.map { top in top.score == chosen ? move : top.move } ?? move
        let gap = max(0, (top?.score ?? chosen) - chosen)
        let verdict = verdict(for: move, best: best, gap: gap, options: options, view: view)
        return MoveReview(id: ordinal, round: round, seat: move.seat, view: view, move: move, best: best, gap: gap, verdict: verdict)
    }

    private static func verdict(for move: Move, best: Move, gap: Int, options: [Bot.ScoredMove], view: PlayerView) -> Verdict {
        if options.count <= 1 { return .forced }
        if gap == 0 {
            if view.isScopa(taking: move.captures) { return .scopa }
            if (move.captures + [move.card]).contains(.settebello), !move.captures.isEmpty { return .settebello }
            return .best
        }
        if gap <= fineGap { return .fine }

        let couldSweep = options.contains { view.isScopa(taking: $0.move.captures) }
        if couldSweep, !view.isScopa(taking: move.captures) { return .missedScopa }
        if move.captures.isEmpty, move.card == .settebello { return .settebelloGiven }
        let couldTakeSeven = options.contains { $0.move.captures.contains(.settebello) }
        if couldTakeSeven, !move.captures.contains(.settebello) { return .settebelloMissed }
        if move.captures.isEmpty, !best.captures.isEmpty { return .missedTake }
        // A take, but not the best one. A lesson that names the wrong reason teaches the
        // wrong thing, so which one it is turns on what the two piles actually differ in:
        // "you took the smaller pile" is nonsense when both piles were two cards and the
        // other one held a seven.
        if !move.captures.isEmpty {
            return best.captures.count > move.captures.count ? .weakTake : .tookTheWrongCards
        }
        // Both were lays, and laying costs two separate things: what the table is left
        // offering, and the card handed over. Whichever was the bigger part of the mistake
        // is the one worth telling them about.
        let mine = Bot.layCost(move.card, in: view)
        let better = Bot.layCost(best.card, in: view)
        return mine.exposure - better.exposure >= mine.card - better.card ? .exposedTable : .gaveAwayAGoodCard
    }
}
