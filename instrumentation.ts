import { registerOTel } from "@vercel/otel";

export function register() {
  registerOTel({ serviceName: "ai-chatbot" });

  // Warm up database connection pool on startup
  // Use indirect import to prevent webpack from analyzing the dependency chain
  // The import is constructed dynamically to avoid bundling analysis
  try {
    const modulePath = "./lib/db/server-init";
    const dynamicImport = () => import(modulePath);
    
    // Only run on server side
    if (typeof window === "undefined") {
      // Use setTimeout to defer the import and avoid build-time analysis
      setTimeout(async () => {
        try {
          const { initDatabaseOnServer } = await dynamicImport();
          initDatabaseOnServer();
        } catch (error) {
          console.error("[Init] Failed to initialize database:", error);
        }
      }, 100);
    }
  } catch (error) {
    // Silently ignore any errors during build
    console.debug("[Init] Database initialization deferred:", error);
  }
}
