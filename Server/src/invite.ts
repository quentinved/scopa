/// The page behind an invitation link, and the association file iOS reads to skip it.
///
/// A link like https://scopa-ladder.…/j/K7QM is a universal link: on a phone with Scopa
/// installed, iOS opens the app at the table instead. Everybody else gets this page.

/// Team id and bundle id, as Apple wants them: the personal team, then the app.
const APP_ID = "7WBNUC3KR9.com.quentinvedrenne.scopa";
/// Empty until Scopa is on the store: paste "https://apps.apple.com/app/id<the id>" here
/// and the button appears. Left blank, the page still shows the code.
const APP_STORE = "";

/// What iOS fetches to decide this app may open its links. Unsigned JSON, at the exact
/// path Apple looks in, with no redirect, or it is ignored.
export function siteAssociation(): Response {
  const body = {
    applinks: {
      details: [
        {
          appIDs: [APP_ID],
          // Only invitation links. Nothing else on this Worker should open the app.
          components: [{ "/": "/j/*", comment: "An invitation to a table" }],
        },
      ],
    },
  };
  return new Response(JSON.stringify(body), {
    headers: {
      "content-type": "application/json",
      "cache-control": "public, max-age=3600",
    },
  });
}

export function invitePage(code: string): Response {
  return new Response(page(code), {
    status: code ? 200 : 404,
    headers: {
      "content-type": "text/html; charset=utf-8",
      // The code is in the URL and the page is the same for everyone who has it.
      "cache-control": "public, max-age=600",
    },
  });
}

const style = `
  :root { color-scheme: light; }
  body { margin: 0; background: #0E3B2E; color: #FCF8EE;
         font: 16px/1.6 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
  main { max-width: 30rem; margin: 0 auto; padding: 4rem 1.5rem; text-align: center; }
  h1 { font-size: 1.9rem; line-height: 1.2; margin: 0 0 .5rem; letter-spacing: .01em; }
  p { color: rgba(252,248,238,.78); margin: 0 0 1.5rem; }
  .code { display: inline-block; font: 700 2.6rem/1 ui-monospace, SFMono-Regular, Menlo, monospace;
          letter-spacing: .22em; padding: 1.1rem 1.4rem 1.1rem 1.6rem; margin: .5rem 0 1.75rem;
          border-radius: 1rem; background: rgba(252,248,238,.08);
          border: 1px solid rgba(212,175,90,.45); color: #E8C877; }
  a.get { display: inline-block; background: #C4622D; color: #FCF8EE; text-decoration: none;
          font-weight: 600; padding: .85rem 1.6rem; border-radius: 999px; }
  small { display: block; margin-top: 2.5rem; color: rgba(252,248,238,.5); font-size: .82rem; }
`;

function page(code: string): string {
  if (!code) {
    return shell(
      "That link is not a table",
      `<h1>Nothing here</h1>
       <p>An invitation link ends in a four-letter table code. This one does not.</p>
       ${getScopa()}`,
    );
  }
  return shell(
    `Table ${code} · Scopa`,
    `<h1>You are invited to a game of Scopa</h1>
     <p>Open this link on an iPhone with Scopa installed and you will be seated straight away.
        Otherwise, get the app and type the code in.</p>
     <div class="code">${code}</div>
     ${getScopa()}
     <small>Tables are kept for a few hours and then they are gone.</small>`,
  );
}

/// A button while there is somewhere to send them, a line when there is not.
function getScopa(): string {
  return APP_STORE
    ? `<p><a class="get" href="${APP_STORE}">Get Scopa</a></p>`
    : `<p>Scopa is on the App Store for iPhone and iPad.</p>`;
}

function shell(title: string, body: string): string {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title}</title>
<style>${style}</style>
</head>
<body><main>${body}</main></body>
</html>`;
}
