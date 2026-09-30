// Just enough of D1 over node's own SQLite to run the Worker's statements against the real
// schema, so a test catches SQL that D1 would refuse rather than a mock that agrees with it.

import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";

/** An empty database with each file run into it, paths relative to Server/. */
export function memoryD1(...files: string[]): D1Database {
  const db = new DatabaseSync(":memory:");
  for (const file of files) db.exec(readFileSync(new URL(`../${file}`, import.meta.url), "utf8"));
  return { prepare: (sql: string) => statement(db, sql, []) } as unknown as D1Database;
}

function statement(db: DatabaseSync, sql: string, values: unknown[]) {
  return {
    bind: (...next: unknown[]) => statement(db, sql, next),
    first: async () => (db.prepare(sql).get(...(values as never[])) as unknown) ?? null,
    all: async () => ({ results: db.prepare(sql).all(...(values as never[])) }),
    run: async () => ({ success: true, meta: { changes: Number(db.prepare(sql).run(...(values as never[])).changes) } }),
  };
}
