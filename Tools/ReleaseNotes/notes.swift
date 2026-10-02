import Foundation

// "What's New in This Version" for the App Store, one entry per version, keyed by the
// version string exactly as App Store Connect prints it. A version with no entry here is
// refused, so one release's notes can never land on the next.
//
// The listing's voice, shorter: a thank-you line, then a line per change, the best first.
// Most people read three lines before the "more" fold. French says "vous", Italian "tu".
// Never mention the passphrases, and leave the rating prompt out.

let releaseNotes: [String: [String: String]] = [
    "1.1": [
        "en-US": """
        Thank you for playing Scopa Bella! This is a big one, and a gift is waiting for you in the game.

        • Campaign: a journey through Italy in 30 stages, from Liguria to Rome. Opponents get sharper as you go, every stage has three stars to win, and each region ends with a prize.
        • A new lobby with Ranked front and center: your league medal, your win rate and how far to the next division. Win medals to wear at your seat and app icons struck in metal.
        • A wheel to spin, free once a day: denari, card packs, shop items, and now and then the gran premio of 2,500 denari and a Forziere pack.
        • The album goes on in four volumes, Riviera, Napoli, Pergamena and Notturna, each with a prize of its own.
        • Redrawn table cloths (Campo, Lino, Maiolica, Ventaglio, Velluto), and a shop that tries them on a miniature table.
        • A thank-you gift for everyone: 2 Reliquia and 2 Forziere packs.
        • The season's ladder, among everyone or just your friends, with win rates. Before a ranked game, see who you face, what a win or a loss is worth, and your winning run. Nobody free? The house offers to play you while the search goes on.
        • Also: one-tap play, videos that pay 100 denari with no daily limit, a field for coupons and friend codes in the shop, and weekly tasks that show clearly when they're done.
        """,

        "en-GB": """
        Thank you for playing Scopa Bella! This is a big one, and a gift is waiting for you in the game.

        • Campaign: a journey through Italy in 30 stages, from Liguria to Rome. Opponents get sharper as you go, every stage has three stars to win, and each region ends with a prize.
        • A new lobby with Ranked front and centre: your league medal, your win rate and how far to the next division. Win medals to wear at your seat and app icons struck in metal.
        • A wheel to spin, free once a day: denari, card packs, shop items, and now and then the gran premio of 2,500 denari and a Forziere pack.
        • The album goes on in four volumes, Riviera, Napoli, Pergamena and Notturna, each with a prize of its own.
        • Redrawn table cloths (Campo, Lino, Maiolica, Ventaglio, Velluto), and a shop that tries them on a miniature table.
        • A thank-you gift for everyone: 2 Reliquia and 2 Forziere packs.
        • The season's ladder, among everyone or just your friends, with win rates. Before a ranked game, see who you face, what a win or a loss is worth, and your winning run. Nobody free? The house offers to play you while the search goes on.
        • Also: one-tap play, videos that pay 100 denari with no daily limit, a field for coupons and friend codes in the shop, and weekly tasks that show clearly when they're done.
        """,

        "fr-FR": """
        Merci de jouer à Scopa Bella ! Cette mise à jour est copieuse, et un cadeau vous attend dans le jeu.

        • Campagne : un voyage à travers l'Italie en 30 étapes, de la Ligurie à Rome. Des adversaires de plus en plus forts, trois étoiles à gagner à chaque étape, et un prix au bout de chaque région.
        • Un nouveau salon, avec le classé en vedette : votre médaille de ligue, votre taux de réussite et ce qu'il reste jusqu'à la division suivante. Gagnez des médailles à porter à votre place et des icônes d'app frappées dans le métal.
        • Une roue à faire tourner, gratuite chaque jour : des deniers, des paquets de cartes, des objets de la boutique et, de temps en temps, le gran premio de 2\u{202F}500 deniers avec un paquet Forziere.
        • L'album continue en quatre volumes, Riviera, Napoli, Pergamena et Notturna, chacun avec son propre prix.
        • Des tapis redessinés (Campo, Lino, Maiolica, Ventaglio, Velluto), et une boutique qui vous les montre sur une table miniature.
        • Un cadeau pour vous remercier : 2 paquets Reliquia et 2 paquets Forziere.
        • Le classement de la saison, avec tout le monde ou entre amis, et le taux de réussite de chacun. Avant une partie classée : votre adversaire, ce que rapporte une victoire ou coûte une défaite, et votre série en cours. Personne de libre ? La maison vous propose une partie pendant que la recherche continue.
        • Et aussi : jouer d'un seul toucher, des vidéos qui rapportent 100 deniers sans limite quotidienne, un champ pour les coupons et codes d'amis dans la boutique, et des tâches de la semaine qui indiquent clairement quand elles sont terminées.
        """,

        "it": """
        Grazie di giocare a Scopa Bella! Questo aggiornamento è ricco, e nel gioco ti aspetta un regalo.

        • Campagna: un viaggio attraverso l'Italia in 30 tappe, dalla Liguria a Roma. Avversari sempre più forti, tre stelle da vincere a ogni tappa e un premio alla fine di ogni regione.
        • Una nuova sala con la classificata in primo piano: la tua medaglia di lega, la tua percentuale di vittorie e quanto manca alla prossima divisione. Vinci medaglie da portare al tuo posto e icone dell'app coniate nel metallo.
        • Una ruota da girare, gratis ogni giorno: denari, pacchetti di carte, oggetti del negozio e, ogni tanto, il gran premio di 2.500 denari con un pacchetto Forziere.
        • L'album continua in quattro volumi, Riviera, Napoli, Pergamena e Notturna, ognuno con il suo premio.
        • Panni ridisegnati (Campo, Lino, Maiolica, Ventaglio, Velluto) e un negozio che te li mostra su un tavolo in miniatura.
        • Un regalo per ringraziarti: 2 pacchetti Reliquia e 2 pacchetti Forziere.
        • La classifica della stagione, tra tutti o solo tra amici, con la percentuale di vittorie di ognuno. Prima di una partita classificata: chi affronti, quanto vale una vittoria o una sconfitta, e la tua serie di vittorie. Nessuno libero? La casa ti propone una partita mentre la ricerca continua.
        • E poi: gioco con un tocco, video che danno 100 denari senza limite giornaliero, un campo per coupon e codici amico nel negozio, e compiti della settimana che mostrano chiaramente quando sono fatti.
        """,
    ],
]
