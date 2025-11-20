-- Initialize PostgreSQL database for AI Chatbot
-- This script creates all necessary tables with proper constraints and indexes

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create User table
CREATE TABLE IF NOT EXISTS "User" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    "username" varchar(64) NOT NULL
);

-- Create unique index on username
CREATE UNIQUE INDEX IF NOT EXISTS "User_username_unique" ON "User" USING btree ("username");

-- Create Chat table
CREATE TABLE IF NOT EXISTS "Chat" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    "createdAt" timestamp NOT NULL,
    "title" text NOT NULL,
    "userId" uuid NOT NULL,
    "visibility" varchar DEFAULT 'private' NOT NULL,
    "lastContext" jsonb
);

-- Create Message_v2 table (current message schema)
CREATE TABLE IF NOT EXISTS "Message_v2" (
    "id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
    "chatId" uuid NOT NULL,
    "role" varchar NOT NULL,
    "parts" json NOT NULL,
    "attachments" json NOT NULL,
    "createdAt" timestamp NOT NULL
);

-- Create Vote_v2 table (current vote schema)
CREATE TABLE IF NOT EXISTS "Vote_v2" (
    "chatId" uuid NOT NULL,
    "messageId" uuid NOT NULL,
    "isUpvoted" boolean NOT NULL,
    CONSTRAINT "Vote_v2_chatId_messageId_pk" PRIMARY KEY("chatId","messageId")
);

-- Create Document table
CREATE TABLE IF NOT EXISTS "Document" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "createdAt" timestamp NOT NULL,
    "title" text NOT NULL,
    "content" text,
    "kind" varchar DEFAULT 'text' NOT NULL,
    "userId" uuid NOT NULL,
    CONSTRAINT "Document_id_createdAt_pk" PRIMARY KEY("id","createdAt")
);

-- Create Suggestion table
CREATE TABLE IF NOT EXISTS "Suggestion" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "documentId" uuid NOT NULL,
    "documentCreatedAt" timestamp NOT NULL,
    "originalText" text NOT NULL,
    "suggestedText" text NOT NULL,
    "description" text,
    "isResolved" boolean DEFAULT false NOT NULL,
    "userId" uuid NOT NULL,
    "createdAt" timestamp NOT NULL,
    CONSTRAINT "Suggestion_id_pk" PRIMARY KEY("id")
);

-- Create Stream table
CREATE TABLE IF NOT EXISTS "Stream" (
    "id" uuid DEFAULT gen_random_uuid() NOT NULL,
    "chatId" uuid NOT NULL,
    "createdAt" timestamp NOT NULL,
    CONSTRAINT "Stream_id_pk" PRIMARY KEY("id")
);

-- Create foreign key constraints
DO $$ BEGIN
    ALTER TABLE "Chat" ADD CONSTRAINT "Chat_userId_User_id_fk" FOREIGN KEY ("userId") REFERENCES "public"."User"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE "Message_v2" ADD CONSTRAINT "Message_v2_chatId_Chat_id_fk" FOREIGN KEY ("chatId") REFERENCES "public"."Chat"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE "Vote_v2" ADD CONSTRAINT "Vote_v2_chatId_Chat_id_fk" FOREIGN KEY ("chatId") REFERENCES "public"."Chat"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE "Vote_v2" ADD CONSTRAINT "Vote_v2_messageId_Message_v2_id_fk" FOREIGN KEY ("messageId") REFERENCES "public"."Message_v2"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE "Document" ADD CONSTRAINT "Document_userId_User_id_fk" FOREIGN KEY ("userId") REFERENCES "public"."User"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE "Suggestion" ADD CONSTRAINT "Suggestion_userId_User_id_fk" FOREIGN KEY ("userId") REFERENCES "public"."User"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE "Suggestion" ADD CONSTRAINT "Suggestion_documentId_documentCreatedAt_Document_id_createdAt_fk" FOREIGN KEY ("documentId","documentCreatedAt") REFERENCES "public"."Document"("id","createdAt") ON DELETE no action ON UPDATE no action;
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    ALTER TABLE "Stream" ADD CONSTRAINT "Stream_chatId_Chat_id_fk" FOREIGN KEY ("chatId") REFERENCES "public"."Chat"("id") ON DELETE no action ON UPDATE no action;
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- Create additional indexes for better performance
CREATE INDEX IF NOT EXISTS "Chat_userId_idx" ON "Chat"("userId");
CREATE INDEX IF NOT EXISTS "Chat_createdAt_idx" ON "Chat"("createdAt");
CREATE INDEX IF NOT EXISTS "Message_v2_chatId_idx" ON "Message_v2"("chatId");
CREATE INDEX IF NOT EXISTS "Message_v2_createdAt_idx" ON "Message_v2"("createdAt");
CREATE INDEX IF NOT EXISTS "Document_userId_idx" ON "Document"("userId");
CREATE INDEX IF NOT EXISTS "Document_createdAt_idx" ON "Document"("createdAt");
CREATE INDEX IF NOT EXISTS "Suggestion_userId_idx" ON "Suggestion"("userId");
CREATE INDEX IF NOT EXISTS "Suggestion_documentId_idx" ON "Suggestion"("documentId");
CREATE INDEX IF NOT EXISTS "Stream_chatId_idx" ON "Stream"("chatId");
CREATE INDEX IF NOT EXISTS "Stream_createdAt_idx" ON "Stream"("createdAt");

-- Set up proper table ownership and permissions
ALTER TABLE "User" OWNER TO ai_user;
ALTER TABLE "Chat" OWNER TO ai_user;
ALTER TABLE "Message_v2" OWNER TO ai_user;
ALTER TABLE "Vote_v2" OWNER TO ai_user;
ALTER TABLE "Document" OWNER TO ai_user;
ALTER TABLE "Suggestion" OWNER TO ai_user;
ALTER TABLE "Stream" OWNER TO ai_user;