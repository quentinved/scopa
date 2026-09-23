/// Bot names, shared by the quick game, the daily deal and the bots that fill an online table.
enum BotNames {
    /// The house dealer: first bot at any table.
    static let dealer = "Hugo"

    /// The rest of the table, in the order they take a seat.
    static let table = ["Laurence", "Lucas", "Timothée", "Alexis", "Loïc", "Arthur", "Camille"]

    /// The dealer first, then the others. Read by `addBots` and by a hot seat table.
    static let all = [dealer] + table
}
