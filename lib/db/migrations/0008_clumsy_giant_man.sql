ALTER TABLE "User" RENAME COLUMN "email" TO "username";--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "User_username_unique" ON "User" USING btree ("username");--> statement-breakpoint
ALTER TABLE "User" DROP COLUMN IF EXISTS "password";