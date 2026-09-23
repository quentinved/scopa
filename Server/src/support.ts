/// The support page, served as a page of its own.
///
/// App Store Connect requires a support URL a player can get help from. The same three
/// languages the app and the listing speak. Every answer here is an answer about the code:
/// keep it true.

const CONTACT = "contact@quentinvedrenne.com";
const PRIVACY = "/privacy";

export function supportPage(): Response {
  return new Response(page, {
    headers: {
      "content-type": "text/html; charset=utf-8",
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
  .sub { color: #5C554C; margin: 0 0 2rem; }
  hr { border: 0; border-top: 1px solid #D9CBB0; margin: 3.5rem 0; }
  a { color: #CE5A3E; }
  ul { padding-left: 1.15rem; }
  li { margin: .35rem 0; }
  .mail { display: inline-block; margin: .5rem 0 0; font-weight: 600; }
  .lang { display: inline-block; margin-bottom: 2rem; font-size: .9rem; }
`;

const french = `
<h1>Aide — Scopa</h1>
<p class="sub">Une question, un bug, une idée ? Écrivez-nous, on vous répond.</p>

<p class="mail"><a href="mailto:${CONTACT}">${CONTACT}</a></p>
<p>Précisez votre modèle d'iPhone ou d'iPad et ce que vous faisiez au moment du problème :
c'est presque toujours suffisant pour le reproduire.</p>

<h2>Jouer à plusieurs sur le même appareil</h2>
<p><em>Jouer → Passer le téléphone</em>. Chacun joue à son tour, et l'écran est masqué entre
deux joueurs. Aucune connexion n'est nécessaire.</p>

<h2>Jouer avec quelqu'un à proximité</h2>
<p><em>Jouer → Ouvrir une table</em> sur un appareil, <em>Rejoindre une table</em> sur
l'autre. La connexion se fait en Wi-Fi et en Bluetooth, directement d'un appareil à l'autre :
activez les deux, et autorisez l'accès au réseau local quand l'app vous le demande.</p>

<h2>Jouer avec quelqu'un à distance</h2>
<p>Connectez-vous d'abord à Game Center (<em>Réglages iOS → Game Center</em>). Ensuite,
invitez un ami, ou choisissez ensemble un mot secret et tapez-le tous les deux.</p>

<h2>Mes deniers, mes achats, mes succès</h2>
<p>Si vous êtes connecté à Game Center, vos deniers, vos achats en boutique, votre album et
vos réglages vous suivent d'un appareil à l'autre : il suffit de connecter le nouveau
téléphone au même compte Game Center. Sans Game Center, tout reste sur l'appareil, et rien
n'est transféré sur un nouveau téléphone. Les succès sont liés à votre compte Game Center.</p>

<h2>La publicité</h2>
<p>Le jeu est gratuit, et des publicités s'affichent entre les parties. Dans l'Union européenne,
un formulaire de consentement apparaît au premier lancement ; vous pouvez changer d'avis
à tout moment depuis <em>Réglages → Vos choix de confidentialité</em> dans le jeu.</p>

<h2>Supprimer mes données</h2>
<p>Désinstaller l'application efface tout ce qui se trouve sur l'appareil. Pour effacer vos
scores au classement et la copie de votre progression sur notre serveur, écrivez à ${CONTACT}
en indiquant votre pseudo Game Center.</p>

<p><a href="${PRIVACY}">Politique de confidentialité</a></p>
`;

const italian = `
<h1>Aiuto — Scopa</h1>
<p class="sub">Una domanda, un problema, un'idea: scrivi, ti si risponde.</p>

<p class="mail"><a href="mailto:${CONTACT}">${CONTACT}</a></p>
<p>Di' quale iPhone o iPad hai e cosa stavi facendo quando è successo. Quasi sempre basta
per riprodurlo.</p>

<h2>Giocare in più persone sullo stesso dispositivo</h2>
<p><em>Gioca → Passa il telefono</em>. Ognuno gioca il suo turno e lo schermo si copre tra
un giocatore e l'altro. Non serve nessuna connessione.</p>

<h2>Giocare con chi ti sta vicino</h2>
<p><em>Gioca → Apri un tavolo</em> su un dispositivo, <em>Entra in un tavolo</em> sull'altro.
Passa per Wi-Fi e Bluetooth, direttamente da un dispositivo all'altro: attivali entrambi e
consenti all'app di trovare i dispositivi sulla rete locale.</p>

<h2>Giocare con chi è lontano</h2>
<p>Bisogna aver fatto l'accesso a Game Center (<em>Impostazioni iOS → Game Center</em>).
Poi invita un amico, oppure mettetevi d'accordo su una parola e digitatela entrambi.</p>

<h2>I miei denari, i miei acquisti, i miei obiettivi</h2>
<p>Con l'accesso a Game Center, i denari, gli acquisti del negozio, l'album e le
impostazioni ti seguono da un dispositivo all'altro: accedi con lo stesso account Game Center
sul nuovo telefono. Senza Game Center resta tutto sul dispositivo, e un
nuovo telefono non se lo porta dietro. Gli obiettivi appartengono al tuo account Game
Center.</p>

<h2>La pubblicità</h2>
<p>Il gioco è gratuito e le pubblicità passano tra una partita e l'altra. Nell'Unione
Europea al primo avvio compare un modulo di consenso; puoi cambiare idea quando vuoi da
<em>Impostazioni → Le tue scelte sulla privacy</em> dentro il gioco.</p>

<h2>Cancellare i miei dati</h2>
<p>Disinstallare l'app cancella tutto quello che sta sul dispositivo. Per cancellare la tua
riga in classifica e la copia della tua partita sul nostro server, scrivi a ${CONTACT} con il
tuo alias di Game Center.</p>

<p><a href="${PRIVACY}">Informativa sulla privacy</a></p>
`;

const english = `
<h1>Help — Scopa</h1>
<p class="sub">A question, a bug, an idea: write, and you get an answer.</p>

<p class="mail"><a href="mailto:${CONTACT}">${CONTACT}</a></p>
<p>Say which iPhone or iPad you have and what you were doing when it happened. That is
almost always enough to reproduce it.</p>

<h2>Playing together on one device</h2>
<p><em>Play → Pass the phone</em>. Everyone takes their turn and the screen is covered in
between. No connection needed.</p>

<h2>Playing with someone next to you</h2>
<p><em>Play → Host a table</em> on one device, <em>Join a table</em> on the other. It goes
over Wi-Fi and Bluetooth, straight between devices: turn both on, and allow the app to find
devices on the local network.</p>

<h2>Playing with someone far away</h2>
<p>You need to be signed in to Game Center (<em>iOS Settings → Game Center</em>). Then
invite a friend, or agree on a word and both type it in.</p>

<h2>My denari, my purchases, my achievements</h2>
<p>Signed in to Game Center, your denari, what you bought in the shop, your album and your
settings follow you from one device to the next: sign the new phone in to the same Game
Center account. Without Game Center everything stays on the device, and a
new phone does not bring it along. Achievements belong to your Game Center account.</p>

<h2>Advertising</h2>
<p>The game is free and ads run between games. In the European Union a consent form appears
on first launch; you can change your mind at any time from <em>Settings → Your privacy
choices</em> inside the game.</p>

<h2>Deleting my data</h2>
<p>Uninstalling the app erases everything held on the device. To erase your ladder row and
the copy of your game on our server, write to ${CONTACT} with your Game Center alias.</p>

<p><a href="${PRIVACY}">Privacy policy</a></p>
`;

const page = `<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Aide · Scopa</title>
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
