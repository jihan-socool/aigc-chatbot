import { registerOTel } from "@vercel/otel";

export function register() {
  registerOTel({ serviceName: "ai-chatbot" });

  // Database initialization is now handled in lib/db/server-init.ts
  // which is imported only in server-side API routes and server components
  // This prevents webpack from analyzing the postgres dependency chain
}
