// Server-only database initialization
// This file should only be imported in server contexts

import { initializeDatabase } from "./init";

// Initialize database connection pool on server startup
export function initDatabaseOnServer(): void {
  initializeDatabase().catch((error) => {
    console.error("[Init] Failed to initialize database:", error);
  });
}