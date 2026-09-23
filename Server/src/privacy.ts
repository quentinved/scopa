/// The privacy policy, served as a page of its own.
///
/// AdMob and App Store Connect both need a public URL for it, and the Worker is already up.
/// The same three languages the app and the listing speak. Every claim here is a claim
/// about the code: keep it true.

const UPDATED = "23 September 2026";
const MISE_A_JOUR = "23 septembre 2026";
const AGGIORNATO = "23 settembre 2026";
const CONTACT = "contact@quentinvedrenne.com";

export function privacyPage(): Response {
  return new Response(page, {
    headers: {
      "content-type": "text/html; charset=utf-8",
      // Crawled by Apple and Google rather than read often. A day is plenty.
      "cache-control": "public, max-age=86400",
    },
  });
}

const style = `
  :root { color-scheme: light; }
  body { margin: 0; background: #FCF8EE; color: #1E1B18; font: 16px/1.6 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
  main { max-width: 42rem; margin: 0 auto; padding: 2.5rem 1.25rem 4rem; }
  h1 { font-size: 1.8rem; line-height: 1.2; margin: 0 0 .25rem; }
  h2 { font-size: 1.15rem; margin: 2.25rem 0 .5rem; color: #27502F; }
  h3 { font-size: 1rem; margin: 1.5rem 0 .35rem; }
  .sub { color: #5C554C; margin: 0 0 2rem; }
  hr { border: 0; border-top: 1px solid #D9CBB0; margin: 3.5rem 0; }
  a { color: #CE5A3E; }
  ul { padding-left: 1.15rem; }
  li { margin: .35rem 0; }
  code { background: #EFE7D3; padding: .1em .35em; border-radius: 3px; font-size: .9em; }
  .lang { display: inline-block; margin-bottom: 2rem; font-size: .9rem; }
`;

const french = `
<h1>Confidentialité — Scopa</h1>
<p class="sub">Dernière mise à jour : ${MISE_A_JOUR}</p>

<p>Scopa est un jeu de cartes développé par Quentin Vedrenne. Il n'y a pas de compte à créer,
pas de mot de passe et pas d'adresse e-mail à donner. Cette page explique le peu de données
qui existent, où elles vont, et comment les faire supprimer.</p>

<h2>Ce qui reste sur votre téléphone</h2>
<p>Ces éléments sont enregistrés sur l'appareil et ne sont envoyés nulle part :</p>
<ul>
  <li>de quoi espacer les publicités : combien de parties vous avez finies et quand la
      dernière publicité est passée ;</li>
  <li>votre réponse au formulaire de consentement publicitaire ;</li>
  <li>vos rappels, que le téléphone programme lui-même.</li>
</ul>
<p>Si vous ne vous connectez jamais à Game Center, le reste de votre progression reste
aussi sur l'appareil : votre nom à table, vos deniers, votre album et vos cosmétiques, vos réglages. Désinstaller
l'application efface tout cela.</p>

<h2>Votre progression sur tous vos appareils</h2>
<p>Si vous êtes connecté à Game Center, un serveur que nous exploitons (un Cloudflare Worker,
hébergé dans l'Union européenne et ailleurs selon le réseau de Cloudflare) garde une copie de
votre progression, pour que votre iPhone et votre iPad restent synchronisés. Elle est
enregistrée sous votre identifiant Game Center et contient :</p>
<ul>
  <li>le nom que vous vous donnez à table ;</li>
  <li>vos réglages et les cosmétiques utilisés : langue, aide au jeu, niveau des bots, son et
      musique, style de cartes, tapis, dos de cartes, emblèmes, et si les rappels
      sont activés ;</li>
  <li>vos deniers, sous forme d'un relevé de chaque somme gagnée ou dépensée, avec la date et
      le type de table ;</li>
  <li>votre album et vos paquets non ouverts, vos compteurs (victoires, défaites, scope,
      settebelli, expérience) et votre avancée dans le défi de la semaine.</li>
</ul>
<p>Elle ne sert à rien d'autre et n'est montrée à personne. Elle est conservée jusqu'à ce que
vous en demandiez la suppression.</p>

<h2>Jouer avec quelqu'un à proximité</h2>
<p>Une table locale passe par le Wi-Fi et le Bluetooth, d'appareil à appareil. Votre nom et
les cartes jouées vont directement aux téléphones des joueurs de la table. Rien ne passe par un
serveur et rien n'est conservé.</p>

<h2>Jouer en ligne</h2>
<p>Jouer contre des inconnus, jouer en classé ou inviter un ami Game Center passe par
<strong>Game Center</strong>. C'est Apple qui vous met en relation et qui relaie les coups ;
votre pseudo Game Center est visible des autres joueurs. Ces données sont traitées par
Apple, comme décrit dans sa
<a href="https://www.apple.com/legal/privacy/">politique de confidentialité</a>.</p>
<p>Une table ouverte avec un code passe au contraire par notre serveur, et n'a pas besoin de
Game Center. Tant que la table est ouverte, le serveur conserve son code, le nom de l'hôte
et son nombre de places. Votre nom et les coups y transitent vers les autres joueurs au fil de la
partie et ne sont pas enregistrés. La table est effacée 30 minutes après le départ du dernier
joueur, et au plus tard au bout de 12 heures.</p>

<h2>Amis en ligne</h2>
<p>Si vous êtes connecté à Game Center et que vous avez autorisé Scopa à voir vos amis, l'app
envoie un signal à notre serveur environ une fois par minute tant qu'elle est ouverte. Elle envoie votre
identifiant Game Center et ceux de vos amis Game Center qui jouent à Scopa. Le serveur conserve
l'heure du dernier signal et cette liste, pour indiquer à vos amis que vous jouez — et à vous
qu'ils jouent. Vous n'êtes visible que par les amis présents dans votre propre liste, et
seulement si vous figurez dans la leur.</p>
<p>Désactivez <em>Voir quand des amis jouent</em> dans les réglages de l'app : les signaux
s'arrêtent et le serveur efface aussitôt votre présence et votre liste. Sinon, vous
disparaissez de la liste de vos amis moins de trois minutes après avoir quitté l'app.</p>

<h2>Le classement</h2>
<p>Si vous êtes connecté à Game Center et que vous jouez la donne du jour, le défi de la
semaine ou une partie classée, le résultat est envoyé au même serveur. Il enregistre :</p>
<ul>
  <li>votre identifiant Game Center (<code>gamePlayerID</code>), le pseudo qui l'accompagne,
      et quand vous avez joué pour la dernière fois, ce qui permet au salon de compter les
      joueurs en ligne ;</li>
  <li>pour la donne du jour : la date, votre score, celui du bot, le nombre de scope et
      votre précision ;</li>
  <li>pour le défi de la semaine : la semaine, votre avancée, et si et quand vous l'avez
      terminé ;</li>
  <li>pour les parties classées : les identifiants des joueurs de la table, le vainqueur,
      votre classement et votre série de victoires, votre place à la fin de chaque saison, et
      le nombre de parties jouées contre la maison dans la journée.</li>
</ul>
<p>Cela ne sert qu'à afficher les classements, où les autres joueurs voient votre pseudo et
vos résultats. Base légale, pour le classement comme pour la copie de votre progression : notre
intérêt légitime à faire fonctionner le jeu auquel vous jouez. Aucune publicité, aucun
profilage, aucune revente : ces données ne sont transmises à personne.</p>
<p>Vous pouvez vous passer de tout cela : sans connexion à Game Center, rien n'est envoyé.
Seule une table ouverte ou rejointe avec un code passe encore par notre serveur.</p>

<h2>La publicité</h2>
<p>Scopa est gratuit et affiche des publicités fournies par <strong>Google AdMob</strong> :
un bandeau dans le salon, une publicité plein écran de temps en temps à la fin d'une partie,
et une publicité facultative que vous pouvez choisir de regarder pour gagner des deniers.</p>
<p>Pour cela, Google peut traiter des identifiants d'appareil, votre adresse IP et vos
interactions avec les publicités. Si vous y consentez via l'invite d'Apple, l'identifiant
publicitaire (IDFA) est également utilisé ; si vous refusez, les publicités restent, mais
non personnalisées. Voir
<a href="https://business.safety.google/privacy/">comment Google utilise ces données</a>.</p>
<p>Dans l'Union européenne, un formulaire de consentement s'affiche au premier lancement.
Vous pouvez changer d'avis à tout moment : <em>Réglages → Vos choix de confidentialité</em>,
dans le jeu.</p>

<h2>Enfants</h2>
<p>Scopa ne s'adresse pas aux enfants de moins de 13 ans et ne leur demande sciemment
aucune donnée.</p>

<h2>Vos droits</h2>
<p>Vous pouvez demander l'accès aux données que notre serveur conserve sur vous — vos
résultats au classement et la copie de votre progression —, leur rectification ou leur
suppression, et vous opposer à leur traitement. Écrivez à <strong>${CONTACT}</strong> en
indiquant votre pseudo Game Center ; la suppression efface vos entrées au classement,
l'ensemble de vos résultats et la copie de votre progression. Déconnectez-vous d'abord de Game Center (<em>Réglages → Game Center</em>), sinon votre appareil la
renverra à la prochaine partie. Vous pouvez aussi saisir la CNIL.</p>
<p>Pour les publicités, retirez votre consentement dans le jeu (voir plus haut) ou
désactivez le suivi dans <em>Réglages → Confidentialité et sécurité → Suivi</em>.</p>

<h2>Modifications</h2>
<p>Si cette politique change, la date en haut de page change avec elle.</p>
`;

const italian = `
<h1>Privacy — Scopa</h1>
<p class="sub">Ultimo aggiornamento: ${AGGIORNATO}</p>

<p>Scopa è un gioco di carte di Quentin Vedrenne. Non c'è nessun account da creare, nessuna
password e nessun indirizzo email da consegnare. Questa pagina dice quali pochi dati
esistono davvero, dove vanno e come farli cancellare.</p>

<h2>Cosa resta sul telefono</h2>
<p>Queste cose restano sul dispositivo e non vengono mandate da nessuna parte:</p>
<ul>
  <li>quello che serve a distanziare le pubblicità: quante partite hai finito e quando è
      stata mostrata l'ultima;</li>
  <li>la tua risposta al modulo di consenso pubblicitario;</li>
  <li>i tuoi promemoria, che il telefono programma da sé.</li>
</ul>
<p>Se non fai mai l'accesso a Game Center, anche il resto della tua partita resta qui: il tuo
nome al tavolo, i tuoi denari, l'album e gli oggetti estetici, le impostazioni. Disinstallare
l'app cancella tutto questo.</p>

<h2>La tua partita su tutti i tuoi dispositivi</h2>
<p>Se hai fatto l'accesso a Game Center, un server che gestiamo noi (un Cloudflare Worker)
tiene una copia della tua partita, perché iPhone e iPad giochino la stessa. È archiviata sotto
il tuo identificativo Game Center e contiene:</p>
<ul>
  <li>il nome che ti dai al tavolo;</li>
  <li>le impostazioni e gli oggetti estetici in uso: lingua, livello di aiuto, livello dei bot,
      suono e musica, mazzo, panno, dorso delle carte, segnaposti, e se i promemoria sono
      attivi;</li>
  <li>i tuoi denari, come registro di ogni somma guadagnata o spesa, con la data e il tipo di
      tavolo;</li>
  <li>l'album e le bustine ancora chiuse, i tuoi contatori (vittorie, sconfitte, scope,
      settebelli, esperienza) e i progressi nella sfida della settimana.</li>
</ul>
<p>Non serve a nient'altro e non è mostrata a nessuno. È conservata finché non ne chiedi la
cancellazione.</p>

<h2>Giocare accanto a qualcuno</h2>
<p>Un tavolo vicino passa per Wi-Fi e Bluetooth, da dispositivo a dispositivo. Il tuo nome e
le carte giocate vanno direttamente ai telefoni seduti a quel tavolo. Niente passa da un
server e niente viene conservato.</p>

<h2>Giocare online</h2>
<p>Giocare contro sconosciuti, giocare in classificata o invitare un amico di Game Center
passa da <strong>Game Center</strong>. Apple ti abbina ad altri giocatori e inoltra le mosse;
il tuo alias di Game Center è visibile a loro. Quel trattamento è di Apple, ed è descritto
nella sua <a href="https://www.apple.com/legal/privacy/">informativa sulla privacy</a>.</p>
<p>Un tavolo aperto con un codice passa invece dal nostro server, e non ha bisogno di Game
Center. Finché il tavolo è aperto, il server tiene il suo codice, il nome di chi l'ha aperto e
quanti posti ha. Il tuo nome e le mosse ci passano per arrivare agli altri giocatori mentre si
gioca, e non vengono registrati. Il tavolo viene cancellato 30 minuti dopo che l'ultimo
giocatore se n'è andato, e comunque entro 12 ore.</p>

<h2>Amici online</h2>
<p>Se hai fatto l'accesso a Game Center e hai permesso a Scopa di vedere i tuoi amici, l'app
avvisa il nostro server circa una volta al minuto finché è aperta. Invia il tuo identificativo
Game Center e quelli dei tuoi amici Game Center che giocano a Scopa. Il server conserva l'ora
di quest'ultimo segnale e quell'elenco, per dire ai tuoi amici che stai giocando — e a te che
giocano loro. Sei mostrato solo agli amici presenti nel tuo elenco, e solo se tu sei nel loro.</p>
<p>Disattiva <em>Avvisami quando gli amici giocano</em> nelle impostazioni dell'app: i segnali si
fermano e il server cancella subito la tua riga e il tuo elenco. Altrimenti sparisci dall'elenco
dei tuoi amici meno di tre minuti dopo aver chiuso l'app.</p>

<h2>La classifica</h2>
<p>Se hai fatto l'accesso a Game Center e giochi la smazzata del giorno, la sfida della
settimana o una partita classificata, il risultato viene mandato allo stesso server.
Registra:</p>
<ul>
  <li>il tuo identificativo Game Center (<code>gamePlayerID</code>), l'alias che lo
      accompagna, e quando hai giocato l'ultima volta, che è come la lobby conta i giocatori
      online;</li>
  <li>per la smazzata del giorno: la data, il tuo punteggio, quello del bot, quante scope hai
      fatto e la tua precisione;</li>
  <li>per la sfida della settimana: la settimana, i tuoi progressi, e se e quando l'hai
      finita;</li>
  <li>per le partite classificate: gli identificativi dei giocatori al tavolo, chi ha vinto,
      il tuo punteggio in classifica e la serie di vittorie, dove hai chiuso ogni stagione, e
      quante partite hai giocato contro la casa quel giorno.</li>
</ul>
<p>Esiste solo per mostrare le classifiche, dove gli altri giocatori vedono il tuo alias e i
tuoi risultati. Base giuridica, per la classifica e per la copia della tua partita: il nostro
legittimo interesse a far funzionare il gioco a cui giochi. Nessuna pubblicità, nessuna
profilazione, nessuna vendita — questi dati non sono condivisi con nessuno.</p>
<p>Puoi giocare senza niente di tutto questo: resta fuori da Game Center e non ne viene
mandato nulla. Solo un tavolo che apri o raggiungi con un codice passa ancora dal nostro
server.</p>

<h2>La pubblicità</h2>
<p>Scopa è gratuito e mostra pubblicità fornite da <strong>Google AdMob</strong>: un banner
nella lobby, ogni tanto una pubblicità a schermo intero a fine partita, e una pubblicità
facoltativa che scegli di guardare in cambio di denari.</p>
<p>Per farlo, Google può trattare identificativi del dispositivo, il tuo indirizzo IP e il
modo in cui interagisci con le pubblicità. Se lo consenti alla richiesta di Apple, viene
usato anche l'identificativo pubblicitario (IDFA); se rifiuti, le pubblicità restano ma non
sono personalizzate. Vedi
<a href="https://business.safety.google/privacy/">come Google usa questi dati</a>.</p>
<p>Nell'Unione Europea al primo avvio compare un modulo di consenso. Puoi cambiare idea
quando vuoi da <em>Impostazioni → Le tue scelte sulla privacy</em> dentro il gioco.</p>

<h2>Bambini</h2>
<p>Scopa non è rivolto a bambini sotto i 13 anni e non raccoglie consapevolmente dati da
loro.</p>

<h2>I tuoi diritti</h2>
<p>Puoi chiedere di accedere a ciò che il nostro server tiene su di te — i risultati in
classifica e la copia della tua partita —, di farlo correggere o cancellare, e opporti al suo
trattamento. Scrivi a <strong>${CONTACT}</strong> con il tuo alias di Game Center; la
cancellazione rimuove la tua riga in classifica, ogni risultato collegato e la copia della tua
partita. Esci prima da Game Center (<em>Impostazioni → Game Center</em>), altrimenti il dispositivo la rimanderà alla prossima
partita. Puoi
anche rivolgerti alla tua autorità per la protezione dei dati — in Italia, il Garante per la
protezione dei dati personali.</p>
<p>Per la pubblicità, revoca il consenso nel gioco (vedi sopra) oppure disattiva il
tracciamento in <em>Impostazioni → Privacy e sicurezza → Tracciamento</em>.</p>

<h2>Modifiche</h2>
<p>Se questa informativa cambia, cambia con lei la data in cima alla pagina.</p>
`;

const english = `
<h1>Privacy — Scopa</h1>
<p class="sub">Last updated: ${UPDATED}</p>

<p>Scopa is a card game made by Quentin Vedrenne. There is no account to create, no password
and no email address to hand over. This page sets out the little data that does exist, where
it goes, and how to have it deleted.</p>

<h2>What stays on your phone</h2>
<p>These are kept on the device and sent nowhere:</p>
<ul>
  <li>what is needed to space ads out: how many games you have finished and when the last
      ad was shown;</li>
  <li>your answer to the advertising consent form;</li>
  <li>your reminders, which the phone schedules itself.</li>
</ul>
<p>If you never sign in to Game Center, the rest of your game stays here too: your name at
the table, your denari, your album and cosmetics, and your settings. Deleting the app deletes
all of it.</p>

<h2>Your game on all your devices</h2>
<p>If you are signed in to Game Center, a server we run (a Cloudflare Worker) keeps a copy of
your game, so that your iPhone and your iPad play the same one. It is filed under your Game
Center identifier and holds:</p>
<ul>
  <li>the name you give yourself at the table;</li>
  <li>your settings and the cosmetics in use: language, assist level, bot strength, sound and
      music, card theme, felt, card back, seat marks, and whether reminders are on;</li>
  <li>your denari, as a record of each amount earned or spent, when, and at what kind of
      table;</li>
  <li>your album and unopened packs, your counters (wins, losses, scope, settebelli,
      experience) and your progress in this week's challenge.</li>
</ul>
<p>It is used for nothing else and shown to nobody. It is kept until you ask for it to be
deleted.</p>

<h2>Playing next to someone</h2>
<p>A nearby table runs over Wi-Fi and Bluetooth, device to device. Your name and the cards
played go straight to the phones sitting at that table. Nothing goes through a server and
nothing is kept.</p>

<h2>Playing online</h2>
<p>Playing strangers, playing ranked, or inviting a Game Center friend uses
<strong>Game Center</strong>. Apple matches you with other players and relays the moves; your
Game Center alias is visible to them. That processing is Apple's, and is described in its
<a href="https://www.apple.com/legal/privacy/">privacy policy</a>.</p>
<p>A table opened with a code goes through our server instead, and needs no Game Center.
While the table is open, the server holds its code, the host's name and how many seats it
has. Your name and the moves pass through it to the other players as they happen and are not
stored. The table is erased 30 minutes after the last player leaves, and after 12 hours at
most.</p>

<h2>Friends online</h2>
<p>If you are signed in to Game Center and have let Scopa see your friends, the app checks in
with our server about once a minute while it is open. It sends your Game Center identifier and
those of your Game Center friends who play Scopa. The server keeps the time of that last
check-in and that list, to tell your friends you are playing — and you that they are. You are
shown only to friends on your own list, and only if you are on theirs.</p>
<p>Turn off <em>Say when friends are playing</em> in the app's settings: the check-ins stop and the
server deletes your row and your list at once. Otherwise you drop off your friends' lists less
than three minutes after leaving the app.</p>

<h2>The ladder</h2>
<p>If you are signed in to Game Center and play today's deal, the weekly challenge or a
ranked game, the result is sent to the same server. It records:</p>
<ul>
  <li>your Game Center identifier (<code>gamePlayerID</code>), the alias that comes with it,
      and when you last played, which is how the lobby counts the players online;</li>
  <li>for today's deal: the date, your score, the bot's score, how many scope you took and
      your accuracy;</li>
  <li>for the weekly challenge: the week, your progress, and whether and when you finished;</li>
  <li>for ranked games: the identifiers of the players at the table, who won, your rating and
      winning streak, where you finished each season, and how many games you played against
      the house that day.</li>
</ul>
<p>It exists only to show the rankings, where other players see your alias and your results.
Legal basis, for the ladder and for the copy of your game above: our legitimate interest in
running the game you play. No advertising, no profiling, no sale — this data is not shared
with anyone.</p>
<p>You can play without any of it: stay signed out of Game Center and none of it is sent.
Only a table you open or join with a code still goes through our server.</p>

<h2>Advertising</h2>
<p>Scopa is free and shows ads supplied by <strong>Google AdMob</strong>: a banner in the
lobby, an occasional full-screen ad at the end of a game, and an optional ad you choose to
watch in exchange for denari.</p>
<p>To do that, Google may process device identifiers, your IP address and how you interact
with ads. If you allow it at Apple's prompt, the advertising identifier (IDFA) is used too;
if you decline, the ads remain but are not personalised. See
<a href="https://business.safety.google/privacy/">how Google uses this data</a>.</p>
<p>In the European Union a consent form appears on first launch. You can change your mind at
any time from <em>Settings → Your privacy choices</em> inside the game.</p>

<h2>Children</h2>
<p>Scopa is not directed at children under 13 and does not knowingly collect data from them.</p>

<h2>Your rights</h2>
<p>You can ask for access to what our server holds about you — your ladder results and the
copy of your game — for it to be corrected or deleted, and object to its processing. Write to
<strong>${CONTACT}</strong> with your Game Center alias; deletion removes your ladder row,
every result attached to it and the copy of your game. Sign out of Game Center first (<em>Settings → Game Center</em>), or your
device will send it again the next time you play. You may also complain to your data
protection authority — in France, the CNIL.</p>
<p>For advertising, withdraw consent in the game (above) or turn off tracking in
<em>Settings → Privacy &amp; Security → Tracking</em>.</p>

<h2>Changes</h2>
<p>If this policy changes, the date at the top changes with it.</p>
`;

const page = `<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Confidentialité · Scopa</title>
<style>${style}</style>
</head>
<body>
<main>
<p class="lang"><a href="#it">Leggi in italiano ↓</a> · <a href="#en">Read in English ↓</a></p>
${french}
<hr>
<div id="it" lang="it">${italian}</div>
<hr>
<div id="en" lang="en">${english}</div>
</main>
</body>
</html>`;
