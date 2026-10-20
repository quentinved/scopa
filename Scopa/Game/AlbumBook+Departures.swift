import ScopaRewards

/// The album as the page shows it: what was found, less the cards that have left it.
///
/// What was found is kept as it always was, and travels as it always did, by the larger
/// count. What left is the ledger's, which travels by union. So the page is the one place
/// the two meet, and nothing written down is ever lowered. See `Departures`.
extension AlbumBook {
    /// One volume less what has left it.
    func shown(_ volume: Volume) -> Album { album(volume).less(departures, in: volume) }

    /// Reads what has left the album off the ledger again: after a gift, or after the
    /// other device's ledger arrived.
    func noteDepartures(in purse: Purse) {
        let read = Departures(keys: purse.keys)
        if read != departures { departures = read }
    }
}
