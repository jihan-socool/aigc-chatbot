import { registerOTel } from "@vercel/otel";
import { initializeDatabase } from "./lib/db/init";

export function register() {
  registerOTel({ serviceName: "ai-chatbot" });

  // Warm up database connection pool on startup
  initializeDatabase().catch((error) => {
    console.error("[Init] Failed to initialize database:", error);
  });
}
