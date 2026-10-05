import Foundation

// "What's New in This Version" for the App Store, one entry per version, keyed by the
// version string exactly as App Store Connect prints it. A version with no entry here is
// refused, so one release's notes can never land on the next.
//
// The listing's voice, shorter: a thank-you line, then a line per change, the best first.
// Most people read three lines before the "more" fold. French says "vous", Italian "tu".
// Never mention the passphrases, and leave the rating prompt out.

let releaseNotes: [String: [String: String]] = [
    "1.2": [
        "en-US": """
        Thank you for playing Scopa Bella! This one brings Italy's regional rules to the table, and music to play them to.

        • House rules: play Scopone (four in two teams, ten cards each), Re bello, Napola and Asso piglia tutto. Mix them at any table with friends, or meet them one by one in the campaign, each with a short lesson the first time.
        • A rule in every region of the campaign: the Napola in Napoli, Asso piglia tutto in Sicily, Re bello in Venice and the Scopone in Rome. Liguria stays classic, and every stage says which rules it plays.
        • Six new songs for the table, from a slow Pomeriggio waltz to a Tarantella and the legendary Mergellina. Listen before you buy, in the shop's new Songs section.
        • The campaign has its own leaderboard, among everyone or just your friends, and the map shows who has reached each stage, friends first.
        • Ranked finds you an opponent faster and more reliably, and the screen before a game is simpler: two medals, and what a win or a loss is worth.
        • The wheel shows what everyone else won today, friends first.
        • A clearer shop, with a bar to jump between sections, a short guide to rarities and packs, and rarities named in your language.
        • Scopa without ads: a one-time purchase in Settings that removes the banner and the ads between games. The videos that pay denari stay, for whenever you want them.
        • Fewer notifications: one a day at most, when the wheel's free spin is back.
        • Also: questions like "Forget this game?" now appear in the middle of the screen on every device, and a pack marks the cards that are new in your album.
        """,

        "en-GB": """
        Thank you for playing Scopa Bella! This one brings Italy's regional rules to the table, and music to play them to.

        • House rules: play Scopone (four in two teams, ten cards each), Re bello, Napola and Asso piglia tutto. Mix them at any table with friends, or meet them one by one in the campaign, each with a short lesson the first time.
        • A rule in every region of the campaign: the Napola in Napoli, Asso piglia tutto in Sicily, Re bello in Venice and the Scopone in Rome. Liguria stays classic, and every stage says which rules it plays.
        • Six new songs for the table, from a slow Pomeriggio waltz to a Tarantella and the legendary Mergellina. Listen before you buy, in the shop's new Songs section.
        • The campaign has its own leaderboard, among everyone or just your friends, and the map shows who has reached each stage, friends first.
        • Ranked finds you an opponent faster and more reliably, and the screen before a game is simpler: two medals, and what a win or a loss is worth.
        • The wheel shows what everyone else won today, friends first.
        • A clearer shop, with a bar to jump between sections, a short guide to rarities and packs, and rarities named in your language.
        • Scopa without ads: a one-time purchase in Settings that removes the banner and the ads between games. The videos that pay denari stay, for whenever you want them.
        • Fewer notifications: one a day at most, when the wheel's free spin is back.
        • Also: questions like "Forget this game?" now appear in the centre of the screen on every device, and a pack marks the cards that are new in your album.
        """,

        "fr-FR": """
        Merci de jouer à Scopa Bella ! Cette version apporte à la table les règles des régions d'Italie, et la musique pour les jouer.

        • Règles maison : jouez au Scopone (à quatre en deux équipes, dix cartes chacun), au Re bello, à la Napola et à l'Asso piglia tutto. Mélangez-les à n'importe quelle table entre amis, ou découvrez-les une à une dans la campagne, chacune avec une courte leçon la première fois.
        • Une règle dans chaque région de la campagne : la Napola à Naples, l'Asso piglia tutto en Sicile, le Re bello à Venise et le Scopone à Rome. La Ligurie reste classique, et chaque étape dit quelles règles elle joue.
        • Six nouvelles chansons pour la table, de la lente valse Pomeriggio à la Tarantella et à la légendaire Mergellina. Écoutez-les avant d'acheter, dans le nouveau rayon Chansons de la boutique.
        • La campagne a son classement, avec tout le monde ou entre amis, et la carte montre qui a atteint chaque étape, vos amis en premier.
        • Le classé vous trouve un adversaire plus vite et plus sûrement, et l'écran avant une partie est plus simple : deux médailles, et ce que vaut une victoire ou une défaite.
        • La roue montre ce que les autres ont gagné aujourd'hui, vos amis en premier.
        • Une boutique plus claire, avec une barre pour passer d'un rayon à l'autre, un petit guide des raretés et des paquets, et des raretés nommées dans votre langue.
        • Scopa sans pub : un achat unique, dans les Réglages, qui retire la bannière et les pubs entre les parties. Les vidéos qui rapportent des deniers restent, pour quand vous en voulez.
        • Moins de notifications : une par jour au plus, quand le tour gratuit de la roue revient.
        • Et aussi : les questions comme « Abandonner cette partie ? » s'affichent au milieu de l'écran sur tous les appareils, et un paquet signale les cartes nouvelles dans votre album.
        """,

        "it": """
        Grazie di giocare a Scopa Bella! Questa versione porta al tavolo le regole delle regioni d'Italia, e la musica per giocarle.

        • Regole della casa: gioca a Scopone (in quattro in due squadre, dieci carte a testa), Re bello, Napola e Asso piglia tutto. Mescolale a qualsiasi tavolo con gli amici, o scoprile una alla volta nella campagna, ognuna con una breve lezione la prima volta.
        • Una regola in ogni regione della campagna: la Napola a Napoli, l'Asso piglia tutto in Sicilia, il Re bello a Venezia e lo Scopone a Roma. La Liguria resta classica, e ogni tappa dice con quali regole si gioca.
        • Sei nuove canzoni per il tavolo, dal lento valzer Pomeriggio alla Tarantella fino alla leggendaria Mergellina. Ascoltale prima di comprarle, nel nuovo reparto Canzoni del negozio.
        • La campagna ha la sua classifica, tra tutti o solo tra amici, e la mappa mostra chi è arrivato a ogni tappa, prima i tuoi amici.
        • La classificata ti trova un avversario più in fretta e in modo più affidabile, e la schermata prima di una partita è più semplice: due medaglie, e quanto vale una vittoria o una sconfitta.
        • La ruota mostra cosa hanno vinto gli altri oggi, prima i tuoi amici.
        • Un negozio più chiaro, con una barra per saltare da un reparto all'altro, una piccola guida a rarità e pacchetti, e le rarità nella tua lingua.
        • Scopa senza pubblicità: un acquisto unico, nelle Impostazioni, che toglie il banner e la pubblicità tra le partite. I video che pagano denari restano, per quando li vuoi tu.
        • Meno notifiche: al massimo una al giorno, quando torna il giro gratis della ruota.
        • E poi: domande come «Dimenticare questa partita?» compaiono al centro dello schermo su ogni dispositivo, e un pacchetto segnala le carte nuove nel tuo album.
        """,
    ],

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
