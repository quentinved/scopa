import Foundation

// What each App Store screenshot says above the frame. The first three show in search
// results, so they carry the pitch: what the game is, the road through Italy, and every
// way to play from the lobby.
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
    /// The framed file's name; the App Store orders a set by it, as text, so the number is
    /// padded to two digits or the tenth would land second.
    let name: String
    let captions: [String: Caption]
}

let frames: [Frame] = [
    Frame(shot: "1-table", name: "01-table", captions: [
        "en-US": Caption(headline: "Italy’s *favorite* card game",
                         line: "Play against bots, friends or the world"),
        "en-GB": Caption(headline: "Italy’s *favourite* card game",
                         line: "Play against bots, friends or the world"),
        "fr-FR": Caption(headline: "Le jeu de cartes *préféré* des Italiens",
                         line: "Contre des bots, vos amis ou le monde entier"),
        "it": Caption(headline: "Il gioco di carte *più amato* d’Italia",
                      line: "Contro i bot, gli amici o tutto il mondo"),
    ]),
    Frame(shot: "9-campaign", name: "02-campaign", captions: [
        "en": Caption(headline: "A journey through *Italy*",
                      line: "30 tables, region by region"),
        "fr-FR": Caption(headline: "Un voyage à travers *l’Italie*",
                         line: "30 tables, de région en région"),
        "it": Caption(headline: "Un viaggio attraverso *l’Italia*",
                      line: "30 tavoli, di regione in regione"),
    ]),
    Frame(shot: "5-lobby", name: "03-lobby", captions: [
        "en": Caption(headline: "Play at *your own pace*",
                      line: "Ranked, the campaign, or a quick game in one tap"),
        "fr-FR": Caption(headline: "Jouez *à votre rythme*",
                         line: "Classé, campagne ou partie rapide en un geste"),
        "it": Caption(headline: "Gioca *coi tuoi tempi*",
                      line: "Classificata, campagna o partita veloce in un tocco"),
    ]),
    Frame(shot: "4-ranked", name: "04-ranked", captions: [
        "en": Caption(headline: "Take on *real players*",
                      line: "Climb the ladder from Bronze to Diamond"),
        "fr-FR": Caption(headline: "Affrontez de *vrais joueurs*",
                         line: "Grimpez au classement, du Bronze au Diamant"),
        "it": Caption(headline: "Sfida *giocatori veri*",
                      line: "Scala la classifica, dal Bronzo al Diamante"),
    ]),
    Frame(shot: "10-wheel", name: "05-wheel", captions: [
        "en": Caption(headline: "A free spin *every day*",
                      line: "Denari, packs and the gran premio to win"),
        "fr-FR": Caption(headline: "Un tour de roue *offert chaque jour*",
                         line: "Des deniers, des paquets et le gran premio à gagner"),
        "it": Caption(headline: "Un giro di ruota *gratis ogni giorno*",
                      line: "Denari, pacchetti e il gran premio da vincere"),
    ]),
    Frame(shot: "8-friends", fallback: "3-teams", name: "06-friends", captions: [
        "en": Caption(headline: "Play with *friends*",
                      line: "Same room or far apart, 2 to 4 players"),
        "fr-FR": Caption(headline: "Jouez *entre amis*",
                         line: "Côte à côte ou à distance, de 2 à 4 joueurs"),
        "it": Caption(headline: "Gioca con gli *amici*",
                      line: "Vicini o lontani, da 2 a 4 giocatori"),
    ]),
    Frame(shot: "6-shop", name: "07-shop", captions: [
        "en": Caption(headline: "Dress the table *your way*",
                      line: "Cloths, companions and more to collect"),
        "fr-FR": Caption(headline: "Habillez la table *à\u{00A0}votre goût*",
                         line: "Tapis, compagnons et bien plus à collectionner"),
        "it": Caption(headline: "Vesti il tavolo *a modo tuo*",
                      line: "Panni, compagni e molto altro da collezionare"),
    ]),
    Frame(shot: "2-coach", name: "08-coach", captions: [
        "en": Caption(headline: "Learn *as you play*",
                      line: "A coach explains every card in your hand"),
        "fr-FR": Caption(headline: "Apprenez *en jouant*",
                         line: "Un coach vous explique chaque carte de votre main"),
        "it": Caption(headline: "Impara *giocando*",
                      line: "Un maestro ti spiega ogni carta che hai in mano"),
    ]),
    Frame(shot: "11-album", name: "09-album", captions: [
        "en": Caption(headline: "Collect *every card*",
                      line: "Four volumes, each in a deck of its own"),
        "fr-FR": Caption(headline: "Collectionnez *toutes les cartes*",
                         line: "Quatre volumes, chacun dans son propre jeu"),
        "it": Caption(headline: "Colleziona *tutte le carte*",
                      line: "Quattro volumi, ognuno con il suo mazzo"),
    ]),
    Frame(shot: "7-rules", name: "10-rules", captions: [
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
