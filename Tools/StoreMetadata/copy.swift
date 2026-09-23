import Foundation

// The App Store listing, in the three languages the app speaks. Kept here rather than in
// the web form so the wording is reviewable and can be pushed again after an edit.

struct Listing {
    let locale: String
    let name: String
    let subtitle: String        // 30 characters
    let promotional: String     // 170 characters
    let keywords: String        // 100 characters, comma separated, no spaces after commas
    let description: String     // 4000 characters
}

let privacyURL = "https://scopa-ladder.quentin-vedrenne.workers.dev/privacy"

// Apple wants the support link to answer a question, not restate the privacy policy.
// Served by the same Worker; `SCOPA_SUPPORT_URL` still overrides it.
let defaultSupportURL = "https://scopa-ladder.quentin-vedrenne.workers.dev/support"

let listings: [Listing] = [
    Listing(
        locale: "en-US",
        name: "Scopa Bella",
        subtitle: "The classic Italian card game",
        promotional: "A free ranked ladder where everyone plays the same daily deal: same cards, same luck, so only the play tells you apart.",
        keywords: "scopa,italian,cards,napoletane,scopone,briscola,settebello,card game,offline,2 players,family",
        description: """
        Forty cards, four on the table, and one question every turn: what can you take?

        Scopa is the game Italy plays at the kitchen table. Learned in a round, and decided as much by what you leave behind as by what you take.

        WAYS TO PLAY
        • Quick game — sit down against a bot in one tap. Three strengths, from a gentle opponent to one that counts the deck alongside you.
        • Pass the phone — friends and bots take turns on a single device.
        • Nearby — open a table and the people around you join over Wi-Fi and Bluetooth. No accounts, no internet.
        • A friend anywhere — invite them through Game Center, or agree on a code word and both type it in.
        • Ranked — a free ladder. Everybody plays the same daily deal, so the luck is identical and only the play tells you apart.

        Two to four players, head to head or in pairs.

        THE SCORING, IN FULL
        Most cards, most coins, the settebello and primiera — and a point every time you sweep the table. Count primiera the classic way or by sevens, whichever your family plays.

        A COACH, IF YOU WANT ONE
        Switch it on and it tells you what each card in your hand would do, and what the player before you just did to the table. Switch it off and it never says a word. When the game ends, a reading of how you played: the moves that were best, the ones that were close, and where a point slipped away.

        SOMETHING TO PLAY FOR
        Denari for every game, and a shop of felts, card backs and table marks to spend them on. Cosmetic only — nothing in it changes a hand.

        Five decks: the house Riviera, plus Napoli, Piacenza, Bergamo and an aged Pergamena.

        English, French and Italian throughout. iPhone and iPad. Free, with ads between games. No account, no sign-up.
        """),

    Listing(
        locale: "fr-FR",
        name: "Scopa Bella",
        subtitle: "Le jeu de cartes italien",
        promotional: "Un classement gratuit où tout le monde joue la même donne du jour : mêmes cartes, même chance, seul votre talent fait la différence.",
        keywords: "scopa,cartes,italien,napolitaines,briscola,scopone,settebello,jeu de cartes,hors ligne,famille",
        description: """
        Quarante cartes, quatre sur la table, et une question à chaque tour : que pouvez-vous prendre ?

        La Scopa, c'est le jeu de cartes des tablées italiennes, celui qu'on sort en famille après le repas. On l'apprend en une manche, et la victoire se joue autant sur ce que vous laissez que sur ce que vous ramassez.

        MODES DE JEU
        • Partie rapide — affrontez un bot d'un simple toucher. Trois niveaux, de l'adversaire débonnaire à celui qui compte les cartes aussi bien que vous.
        • Sur un seul téléphone — amis et bots jouent chacun leur tour sur le même appareil.
        • À proximité — ouvrez une table et les joueurs autour de vous la rejoignent en Wi-Fi et Bluetooth. Sans compte, sans Internet.
        • Avec un ami, où qu'il soit — invitez-le via Game Center, ou choisissez ensemble un mot secret et tapez-le tous les deux.
        • Classé — un classement gratuit. Tout le monde joue la même donne du jour : la chance est la même pour tous, seul votre talent fait la différence.

        De deux à quatre joueurs, en tête-à-tête ou en équipes.

        TOUT LE DÉCOMPTE
        Le plus de cartes, le plus de deniers, le settebello et la primiera — plus un point à chaque scopa, quand vous videz la table. La primiera se compte à la classique ou aux sept, selon vos habitudes.

        UN COACH, SI VOUS LE SOUHAITEZ
        Activé, il vous dit ce que ferait chaque carte de votre main, et ce que votre adversaire vient de jouer. Désactivé, il se tait. En fin de partie, une analyse de votre jeu : les meilleurs coups, ceux qui l'étaient presque, et les points qui vous ont échappé.

        DE QUOI SE FAIRE PLAISIR
        Des deniers à chaque partie, à dépenser en boutique : tapis, dos de cartes et emblèmes. Purement cosmétique : rien n'influence la donne.

        Cinq jeux de cartes : la Riviera de la maison, plus Napoli, Piacenza, Bergamo et une Pergamena patinée.

        Entièrement en français, en anglais et en italien. iPhone et iPad. Gratuit, avec des publicités entre les parties. Sans compte, sans inscription.
        """),

    Listing(
        locale: "it",
        name: "Scopa Bella",
        subtitle: "Il gioco di carte italiano",
        promotional: "Una classifica gratuita dove tutti giocano la stessa mano del giorno: stesse carte, stessa fortuna, decide solo il gioco.",
        keywords: "scopa,carte,napoletane,piacentine,briscola,scopone,settebello,gioco di carte,offline,famiglia",
        description: """
        Quaranta carte, quattro sul tavolo, e una domanda a ogni turno: cosa puoi prendere?

        La scopa è il gioco che in Italia si fa al tavolo di cucina. Si impara in una mano, e si decide tanto per quello che lasci quanto per quello che prendi.

        MODI DI GIOCARE
        • Partita veloce — siediti contro un bot con un tocco. Tre livelli, dall'avversario tranquillo a quello che conta il mazzo insieme a te.
        • Passa il telefono — amici e bot giocano a turno sullo stesso dispositivo.
        • Qui vicino — apri un tavolo e chi ti sta intorno entra via Wi-Fi e Bluetooth. Senza account, senza Internet.
        • Un amico ovunque — invitalo da Game Center, oppure mettetevi d'accordo su una parola e digitatela entrambi.
        • Classificata — una classifica gratuita. Tutti giocano la stessa mano del giorno: la fortuna è identica, decide solo il gioco.

        Da due a quattro giocatori, uno contro uno o a coppie.

        IL PUNTEGGIO, PER INTERO
        Carte, denari, settebello e primiera — e un punto ogni volta che fai scopa. La primiera si conta alla classica o a sette, come si usa da voi.

        UN MAESTRO, SE LO VUOI
        Accendilo e ti dice cosa farebbe ogni carta in mano, e cosa ha appena fatto al tavolo chi ha giocato prima di te. Spegnilo e non dice più una parola. A fine partita, una lettura del tuo gioco: le mosse migliori, quelle vicine, e dove è scappato un punto.

        QUALCOSA PER CUI GIOCARE
        Denari a ogni partita, e un negozio di panni, dorsi e segnaposti dove spenderli. Solo estetica: niente cambia una mano.

        Cinque mazzi: la Riviera della casa, più Napoli, Piacenza, Bergamo e una Pergamena invecchiata.

        Italiano, inglese e francese ovunque. iPhone e iPad. Gratis, con pubblicità tra una partita e l'altra. Senza account, senza registrazione.
        """),
]
