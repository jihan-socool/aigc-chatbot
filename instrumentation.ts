import { registerOTel } from "@vercel/otel";

export function register() {
  registerOTel({ serviceName: "ai-chatbot" });

  // Warm up database connection pool on startup
  // Only run on server side
  if (typeof window === "undefined") {
    // Use setTimeout to defer the import and avoid build-time analysis
    setTimeout(async () => {
      try {
        // Dynamic import with Next.js path alias to avoid webpack bundling issues
        const { initDatabaseOnServer } = await import("@/lib/db/server-init");
        initDatabaseOnServer();
      } catch (error) {
        console.error("[Init] Failed to initialize database:", error);
      }
    }, 100);
  }
}
