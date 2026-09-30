import Foundation

// What each App Store screenshot says above the frame. The first three show in search
// results, so they carry the pitch: what the game is, friends, and real players online.
//
// `*word*` in a headline is drawn in terracotta. French keeps vous and Italian tu, as the
// app does.

struct Caption {
    let headline: String
    let line: String
}

struct Frame {
    /// The raw shot in Artwork/Screenshots this frame is built on, and the one standing in
    /// for it in a set shot before it existed.
    let shot: String
    var fallback: String? = nil
    /// The framed file's name; the App Store orders a set by it.
    let name: String
    let captions: [String: Caption]
}

let frames: [Frame] = [
    Frame(shot: "1-table", name: "1-table", captions: [
        "en-US": Caption(headline: "Italy’s *favorite* card game",
                         line: "Play against bots, friends or the world"),
        "en-GB": Caption(headline: "Italy’s *favourite* card game",
                         line: "Play against bots, friends or the world"),
        "fr-FR": Caption(headline: "Le jeu de cartes *préféré* des Italiens",
                         line: "Contre des bots, vos amis ou le monde entier"),
        "it": Caption(headline: "Il gioco di carte *più amato* d’Italia",
                      line: "Contro i bot, gli amici o tutto il mondo"),
    ]),
    Frame(shot: "8-friends", fallback: "3-teams", name: "2-friends", captions: [
        "en": Caption(headline: "Play with *friends*",
                      line: "Same room or far apart, 2 to 4 players"),
        "fr-FR": Caption(headline: "Jouez *entre amis*",
                         line: "Côte à côte ou à distance, de 2 à 4 joueurs"),
        "it": Caption(headline: "Gioca con gli *amici*",
                      line: "Vicini o lontani, da 2 a 4 giocatori"),
    ]),
    Frame(shot: "4-ranked", name: "3-ranked", captions: [
        "en": Caption(headline: "Take on *real players*",
                      line: "Climb the ladder from Bronze to Diamond"),
        "fr-FR": Caption(headline: "Affrontez de *vrais joueurs*",
                         line: "Grimpez au classement, du Bronze au Diamant"),
        "it": Caption(headline: "Sfida *giocatori veri*",
                      line: "Scala la classifica, dal Bronzo al Diamante"),
    ]),
    Frame(shot: "5-lobby", name: "4-daily", captions: [
        "en": Caption(headline: "A new deal *every day*",
                      line: "Same cards for everyone, only skill decides"),
        "fr-FR": Caption(headline: "Une nouvelle donne *chaque jour*",
                         line: "Les mêmes cartes pour tous, seul le talent compte"),
        "it": Caption(headline: "Una smazzata nuova *ogni giorno*",
                      line: "Stesse carte per tutti, decide solo il gioco"),
    ]),
    Frame(shot: "2-coach", name: "5-coach", captions: [
        "en": Caption(headline: "Learn *as you play*",
                      line: "A coach explains every card in your hand"),
        "fr-FR": Caption(headline: "Apprenez *en jouant*",
                         line: "Un coach vous explique chaque carte de votre main"),
        "it": Caption(headline: "Impara *giocando*",
                      line: "Un maestro ti spiega ogni carta che hai in mano"),
    ]),
    Frame(shot: "6-shop", name: "6-shop", captions: [
        "en": Caption(headline: "Make the table *yours*",
                      line: "Felts, card backs and decks to collect"),
        "fr-FR": Caption(headline: "Une table *à votre image*",
                         line: "Tapis, dos de cartes et jeux à collectionner"),
        "it": Caption(headline: "Il tavolo *a modo tuo*",
                      line: "Panni, dorsi e mazzi da collezionare"),
    ]),
    Frame(shot: "7-rules", name: "7-rules", captions: [
        "en": Caption(headline: "New to *Scopa*?",
                      line: "The rules in one minute, then deal"),
        "fr-FR": Caption(headline: "Vous découvrez *la Scopa*\u{00A0}?",
                         line: "Les règles en une minute, et c’est parti"),
        "it": Caption(headline: "Mai giocato *a scopa*?",
                      line: "Le regole in un minuto, e si gioca"),
    ]),
]

/// Store locales framed from another locale's shots: en-GB is the English app, captioned
/// in British spelling where it differs.
let borrowedShots = ["en-GB": "en-US"]

extension Frame {
    func caption(for locale: String) -> Caption? {
        captions[locale] ?? captions[String(locale.prefix(2))]
    }
}
