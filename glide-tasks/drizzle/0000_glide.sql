CREATE TABLE tasks (
 id TEXT NOT NULL,
 user_id TEXT NOT NULL,
 title TEXT NOT NULL,
 status TEXT NOT NULL DEFAULT 'todo',
 due TEXT,
 priority INTEGER NOT NULL DEFAULT 0,
 created_at INTEGER NOT NULL,
 updated_at INTEGER NOT NULL,
 version INTEGER NOT NULL DEFAULT 1,
 deleted INTEGER NOT NULL DEFAULT 0,
 PRIMARY KEY (user_id, id)
);
--> statement-breakpoint
CREATE INDEX tasks_user_status ON tasks (user_id, deleted, status);
--> statement-breakpoint
CREATE TABLE sessions (
 token_hash TEXT PRIMARY KEY NOT NULL,
 user_id TEXT NOT NULL,
 email TEXT NOT NULL,
 name TEXT NOT NULL,
 expires_at INTEGER NOT NULL
);
--> statement-breakpoint
CREATE INDEX sessions_expiry ON sessions (expires_at);
--> statement-breakpoint
CREATE TABLE ai_usage (
 user_id TEXT NOT NULL,
 bucket INTEGER NOT NULL,
 count INTEGER NOT NULL DEFAULT 0,
 PRIMARY KEY (user_id, bucket)
);
