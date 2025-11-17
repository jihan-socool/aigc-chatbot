import NextAuth, { type DefaultSession } from "next-auth";
import type { DefaultJWT } from "next-auth/jwt";
import Credentials from "next-auth/providers/credentials";
import { ensureUserByUsername } from "@/lib/db/queries";
import { authConfig } from "./auth.config";

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
  providers: [
    Credentials({
      credentials: {
        username: { label: "Username", type: "text" },
      },
      async authorize(credentials) {
        const rawUsername = credentials?.username;

        if (!rawUsername || typeof rawUsername !== "string") {
          return null;
        }

        try {
          const userRecord = await ensureUserByUsername(rawUsername);

          return {
            id: userRecord.id,
            name: userRecord.username,
            username: userRecord.username,
            type: "regular" as const,
          };
        } catch (_error) {
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
