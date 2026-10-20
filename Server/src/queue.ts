/// The Durable Object behind the ranked queue. The pairing itself is in rankedline.ts.

import { DurableObject } from "cloudflare:workers";
import { openTable } from "./room.ts";
import { FollowBody, Format, invalidFollow, invalidSeek, Line, SeekAnswer, SeekBody, Teammate } from "./rankedline.ts";

const MAX_NAME_LENGTH = 40;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}

/// One instance for the whole game, so every search sees every other.
export class RankedQueue extends DurableObject<{ ROOMS: DurableObjectNamespace }> {
  private line = new Line();

  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);
    const body = (await request.json().catch(() => ({}))) as SeekBody;
    if (url.pathname === "/leave") {
      if (typeof body?.player === "string") this.line.leave(body.player);
      return json({ ok: true });
    }
    if (url.pathname === "/follow") {
      const follow = body as FollowBody;
      const problem = invalidFollow(follow);
      if (problem) return json({ error: problem }, 400);
      return json(this.line.follow(follow.player as string, follow.leader as string, Date.now()));
    }
    const problem = invalidSeek(body);
    if (problem) return json({ error: problem }, 400);
    const name = (body.name as string).trim().slice(0, MAX_NAME_LENGTH);
    const teammate: Teammate | undefined = body.format === "duo"
      ? { player: body.teammate as string, name: (body.teammateName as string).trim().slice(0, MAX_NAME_LENGTH) }
      : undefined;
    return json(await this.seek(body.player as string, name, body.format as Format, (body.search as string | undefined) ?? "", teammate));
  }

  private async seek(player: string, name: string, format: Format, search: string, teammate?: Teammate): Promise<SeekAnswer> {
    const answer = this.line.seek(player, name, format, Date.now(), search, teammate);
    if (answer.pairing) return answer;
    const match = this.line.match(player);
    if (!match) return answer;
    // Two humans sit at a solo room, the house chairs the host's to fill; four at a duo's.
    const humans = match.host.format === "duo" ? 4 : 2;
    const code = await openTable(this.env.ROOMS, match.host.player, match.host.name, humans);
    if (!code) {
      this.line.unmatch(match);
      return { searching: answer.searching };
    }
    // Not seeking again on failure: a player who left during the await must not be put back.
    if (!this.line.settle(match, code, Date.now())) return { searching: answer.searching };
    return this.line.seek(player, name, format, Date.now(), search, teammate);
  }
}
