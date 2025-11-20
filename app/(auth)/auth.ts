import NextAuth, { type DefaultSession } from "next-auth";
import type { DefaultJWT } from "next-auth/jwt";
import Credentials from "next-auth/providers/credentials";
import { ensureUserByUsername } from "@/lib/db/queries";
import { AuthTimer } from "@/lib/perf/auth-timer";
import { authConfig } from "./auth.config";

// Initialize database connection pool on first auth request
// This ensures the database is ready without webpack bundling issues
let dbInitialized = false;

function ensureDbInitialized() {
  if (!dbInitialized) {
    // Import and initialize database only when needed
    import("@/lib/db/server-init").then(({ initDatabaseOnServer }) => {
      initDatabaseOnServer();
      dbInitialized = true;
    }).catch((error) => {
      console.error("[Auth] Failed to initialize database:", error);
    });
  }
}

export type UserType = "regular";

declare module "next-auth" {
  interface Session extends DefaultSession {
    user: {
      id: string;
      username: string;
      type: UserType;
    } & DefaultSession["user"];
  }

  // biome-ignore lint/nursery/useConsistentTypeDefinitions: "Required"
  interface User {
    id?: string;
    name?: string | null;
    username: string;
    type: UserType;
  }
}

declare module "next-auth/jwt" {
  interface JWT extends DefaultJWT {
    id: string;
    username: string;
    type: UserType;
  }
}

export const {
  handlers: { GET, POST },
  auth,
  signIn,
  signOut,
} = NextAuth({
  ...authConfig,
  trustHost: true,
  providers: [
    Credentials({
      credentials: {
        username: { label: "Username", type: "text" },
      },
      async authorize(credentials) {
        const timer = new AuthTimer();
        const rawUsername = credentials?.username;

        timer.mark("validate");

        // Ensure database is initialized before any database operations
        ensureDbInitialized();

        if (!rawUsername || typeof rawUsername !== "string") {
          console.error("[Auth] Invalid credentials: username is required");
          return null;
        }

        try {
          timer.mark("beforeUserLookup");
          const userRecord = await ensureUserByUsername(rawUsername);
          timer.mark("afterUserLookup");

          timer.logMetrics("Credentials");

          return {
            id: userRecord.id,
            name: userRecord.username,
            username: userRecord.username,
            type: "regular" as const,
          };
        } catch (error) {
          console.error("[Auth] Failed to ensure user by username:", error);
          return null;
        }
      },
    }),
  ],
  callbacks: {
    jwt({ token, user }) {
      if (user) {
        token.id = user.id as string;
        token.type = user.type;
        token.username = user.username;
      }

      return token;
    },
    session({ session, token }) {
      if (session.user) {
        session.user.id = token.id;
        session.user.type = token.type;
        session.user.username = token.username;
        session.user.name = token.username;
      }

      return session;
    },
  },
});
