import Foundation

// "What's New in This Version" for the App Store, one entry per version, keyed by the
// version string exactly as App Store Connect prints it. A version with no entry here is
// refused, so one release's notes can never land on the next.
//
// The listing's voice, shorter: a thank-you line, then a line per change, the best first.
// Most people read three lines before the "more" fold. French says "vous", Italian "tu".
// Never mention the passphrases, and leave the rating prompt out.

let releaseNotes: [String: [String: String]] = [
    "1.3.1": [
        "en-US": """
        Thank you for playing Scopa Bella! The rules are easier to learn now.

        • A clearer How to play: it starts with how to win in four steps, then follows a game in the order it is played, with a short tip for each rule worth remembering.
        • Fix: a video offer (free denari in the shop, an extra turn of the wheel, double winnings after a game) could do nothing once the app had been open a long while. It plays now.
        • Fix: in Settings, a medal and a badge frame no longer run over your name.
        """,

        "en-GB": """
        Thank you for playing Scopa Bella! The rules are easier to learn now.

        • A clearer How to play: it starts with how to win in four steps, then follows a game in the order it is played, with a short tip for each rule worth remembering.
        • Fix: a video offer (free denari in the shop, an extra turn of the wheel, double winnings after a game) could do nothing once the app had been open a long while. It plays now.
        • Fix: in Settings, a medal and a badge frame no longer run over your name.
        """,

        "fr-FR": """
        Merci de jouer à Scopa Bella ! Les règles s'apprennent plus facilement.

        • Un « Comment jouer » plus clair : il commence par comment gagner, en quatre étapes, puis suit une partie dans l'ordre où elle se joue, avec une courte astuce pour chaque règle à retenir.
        • Au pluriel, on dit maintenant « scopas » et non plus « scope ».
        • Correction : une vidéo proposée (deniers offerts dans la boutique, un tour de roue en plus, gains doublés après une partie) pouvait ne rien faire quand l'app était ouverte depuis longtemps. Elle se lance désormais.
        • Correction : dans les Réglages, une médaille et un cadre sur votre badge ne débordent plus sur votre nom.
        """,

        "it": """
        Grazie di giocare a Scopa Bella! Ora le regole si imparano più facilmente.

        • Un «Come si gioca» più chiaro: comincia da come si vince, in quattro passi, poi segue una partita nell'ordine in cui si gioca, con un breve consiglio per ogni regola da ricordare.
        • Correzione: un video proposto (denari in regalo nel negozio, un giro di ruota in più, vincite doppie dopo una partita) poteva non fare nulla quando l'app era aperta da tanto. Ora parte.
        • Correzione: nelle Impostazioni, una medaglia e una cornice sul tuo stemma non coprono più il tuo nome.
        """,
    ],

    "1.3": [
        "en-US": """
        Thank you for playing Scopa Bella! A brighter icon, and more denari from every game.

        • Going ad free now pays you too: 2,000 denari once, and half as much again on every game you finish, for good. Already bought it? Your 2,000 are waiting.
        • New in the shop, Double winnings: for 250 denari, your next 10 games pay twice. Buy another run and they add up.
        • A brighter emerald icon on your home screen, with the name written bigger.
        • The Platinum medal has a touch of teal, so it no longer looks like Silver.
        • Fix: the red "Scopa!" band no longer stays on the table after a sweep.
        """,

        "en-GB": """
        Thank you for playing Scopa Bella! A brighter icon, and more denari from every game.

        • Going ad free now pays you too: 2,000 denari once, and half as much again on every game you finish, for good. Already bought it? Your 2,000 are waiting.
        • New in the shop, Double winnings: for 250 denari, your next 10 games pay twice. Buy another run and they add up.
        • A brighter emerald icon on your home screen, with the name written bigger.
        • The Platinum medal has a touch of teal, so it no longer looks like Silver.
        • Fix: the red "Scopa!" band no longer stays on the table after a sweep.
        """,

        "fr-FR": """
        Merci de jouer à Scopa Bella ! Une icône plus vive, et plus de deniers à chaque partie.

        • L'achat sans pub vous rapporte aussi : 2\u{202F}000 deniers une fois, puis moitié plus à chaque partie terminée, pour de bon. Déjà acheté ? Vos 2\u{202F}000 deniers vous attendent.
        • Nouveau dans la boutique, Gains doublés : pour 250 deniers, vos 10 prochaines parties paient deux fois. Achetez-en une autre série et elles s'ajoutent.
        • Une icône vert émeraude plus vive sur votre écran d'accueil, avec le nom écrit plus grand.
        • La médaille Platine prend une touche de bleu-vert, pour ne plus ressembler à l'Argent.
        • Correction : le bandeau rouge « Scopa ! » ne reste plus sur la table après une scopa.
        """,

        "it": """
        Grazie di giocare a Scopa Bella! Un'icona più viva, e più denari da ogni partita.

        • L'acquisto senza pubblicità ora ti ripaga anche: 2.000 denari una volta, poi metà in più a ogni partita finita, per sempre. L'avevi già comprato? I tuoi 2.000 denari ti aspettano.
        • Novità nel negozio, Vincite doppie: con 250 denari le tue prossime 10 partite pagano il doppio. Comprane un'altra serie e si sommano.
        • Un'icona verde smeraldo più viva nella schermata Home, con il nome scritto più grande.
        • La medaglia Platino prende un tocco di verde acqua, così non sembra più d'Argento.
        • Correzione: la fascia rossa «Scopa!» non resta più sul tavolo dopo una scopa.
        """,
    ],

    "1.2.1": [
        "en-US": """
        Thank you for playing Scopa Bella! A new region on the road, and a table that celebrates with you.

        • Piemonte joins the campaign: six tables from Torino to the Mole Antonelliana, between Liguria and Napoli, and the Wine seat mark at the end. Every star you had won is kept.
        • A proper "Scopa!": a broom sweeps the cloth, the word stamps down in gold, and the phone feels it. The settebello, re bello, napola and asso piglia tutto get their own moments too.
        • A new Game Center achievement, Tre Sette: hold three sevens in one hand.
        • The ranked card shows your points and how many more the next division needs.
        • The ranked road pays on the way up: denari at three stops inside every division, and a pack in your album at the top of it, once a season. Its message now comes once, after the game's result.
        • Tap a card twice to play it, even one you had already picked up.
        • New players choose between the coach and a plain table on their first visit.
        • One more turn of the wheel each day, for a short video, after the free one.
        • A new setting to hide the tag in the corner of the table that recaps each move.
        • At a table with friends, each sweep now plays the flourish its player chose, not only yours.
        • The no-ads purchase now shows its price in your own currency.
        • Ads stay away from your cards, the no-ads page and a pack being opened.
        • Fixes: a card no longer stays stuck in the air when a call interrupts a drag, quick taps no longer count a game twice or put a stake down twice, a tap that lands with the clock no longer plays two moves, and the shop scrolls more smoothly.
        """,

        "en-GB": """
        Thank you for playing Scopa Bella! A new region on the road, and a table that celebrates with you.

        • Piemonte joins the campaign: six tables from Torino to the Mole Antonelliana, between Liguria and Napoli, and the Wine seat mark at the end. Every star you had won is kept.
        • A proper "Scopa!": a broom sweeps the cloth, the word stamps down in gold, and the phone feels it. The settebello, re bello, napola and asso piglia tutto get their own moments too.
        • A new Game Center achievement, Tre Sette: hold three sevens in one hand.
        • The ranked card shows your points and how many more the next division needs.
        • The ranked road pays on the way up: denari at three stops inside every division, and a pack in your album at the top of it, once a season. Its message now comes once, after the game's result.
        • Tap a card twice to play it, even one you had already picked up.
        • New players choose between the coach and a plain table on their first visit.
        • One more turn of the wheel each day, for a short video, after the free one.
        • A new setting to hide the tag in the corner of the table that recaps each move.
        • At a table with friends, each sweep now plays the flourish its player chose, not only yours.
        • The no-ads purchase now shows its price in your own currency.
        • Ads stay away from your cards, the no-ads page and a pack being opened.
        • Fixes: a card no longer stays stuck in the air when a call interrupts a drag, quick taps no longer count a game twice or put a stake down twice, a tap that lands with the clock no longer plays two moves, and the shop scrolls more smoothly.
        """,

        "fr-FR": """
        Merci de jouer à Scopa Bella ! Une nouvelle région sur la route, et une table qui fête avec vous.

        • Le Piémont rejoint la campagne : six tables de Turin à la Mole Antonelliana, entre la Ligurie et Naples, et la marque de place Vin au bout. Toutes les étoiles que vous aviez gagnées sont gardées.
        • Une vraie « Scopa ! » : un balai traverse le tapis, le mot s'imprime en or, et le téléphone le sent. Le settebello, le re bello, la napola et l'asso piglia tutto ont aussi leur moment.
        • Un nouveau succès Game Center, Tre Sette : avoir trois sept en main.
        • La carte du classé montre vos points et combien il en faut encore pour la division suivante.
        • La route du classé paie en chemin : des deniers à trois étapes dans chaque division, et un paquet dans votre album au sommet, une fois par saison. Son message arrive maintenant une seule fois, après le résultat de la partie.
        • Touchez une carte deux fois pour la jouer, même si vous l'aviez déjà levée.
        • Les nouveaux joueurs choisissent entre le coach et une table nue dès leur première visite.
        • Un tour de roue de plus chaque jour, contre une courte vidéo, après le tour gratuit.
        • Un nouveau réglage pour masquer l'étiquette du coin de la table qui rappelle chaque coup.
        • À une table entre amis, chaque scopa joue désormais l'effet choisi par son joueur, pas seulement le vôtre.
        • L'achat sans pub affiche maintenant son prix dans votre devise.
        • Les pubs restent loin de vos cartes, de la page sans pub et d'un paquet qu'on ouvre.
        • Corrections : une carte ne reste plus suspendue quand un appel interrompt un glissement, les tapes rapides ne comptent plus une partie deux fois et ne misent plus deux fois, une tape qui tombe avec la fin du chrono ne joue plus deux coups, et la boutique défile plus en douceur.
        """,

        "it": """
        Grazie di giocare a Scopa Bella! Una nuova regione sulla strada, e un tavolo che festeggia con te.

        • Il Piemonte entra nella campagna: sei tavoli da Torino alla Mole Antonelliana, tra la Liguria e Napoli, e il segno Vino per il tuo posto alla fine. Tutte le stelle che avevi vinto restano tue.
        • Una vera «Scopa!»: una scopa attraversa il panno, la parola si stampa in oro, e il telefono la sente. Anche il settebello, il re bello, la napola e l'asso piglia tutto hanno il loro momento.
        • Un nuovo obiettivo Game Center, Tre Sette: tieni in mano tre sette insieme.
        • La carta della classificata mostra i tuoi punti e quanti ne servono ancora per la prossima divisione.
        • La strada della classificata paga lungo la salita: denari a tre tappe dentro ogni divisione, e un pacchetto nell'album in cima, una volta a stagione. Il suo messaggio ora arriva una volta sola, dopo il risultato della partita.
        • Tocca una carta due volte per giocarla, anche se l'avevi già alzata.
        • I nuovi giocatori scelgono tra il coach e un tavolo semplice alla prima visita.
        • Un giro di ruota in più ogni giorno, con un breve video, dopo quello gratis.
        • Una nuova impostazione per nascondere l'etichetta nell'angolo del tavolo che riassume ogni mossa.
        • A un tavolo con gli amici, ogni scopa ora mostra l'effetto scelto da chi la fa, non solo il tuo.
        • L'acquisto senza pubblicità ora mostra il prezzo nella tua valuta.
        • La pubblicità sta lontana dalle tue carte, dalla pagina senza pubblicità e da un pacchetto che si apre.
        • Correzioni: una carta non resta più sospesa quando una chiamata interrompe un trascinamento, i tocchi veloci non contano più una partita due volte e non puntano più due volte, un tocco che arriva con lo scadere del tempo non gioca più due mosse, e il negozio scorre più fluido.
        """,
    ],

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
