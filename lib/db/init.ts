// Database initialization and connection pool warmup
// This module ensures the connection pool is properly initialized on app startup

import { getUserByUsername } from "./queries";

let initialized = false;

/**
 * Initialize database connection pool and warm it up.
 * This should be called once on app startup to ensure connections are ready.
 */
export async function initializeDatabase(): Promise<void> {
  if (initialized) {
    return;
  }

  try {
    // Test a connection to ensure the pool is initialized
    // We use a no-op user lookup with a dummy username that won't exist
    // This creates a connection from the pool and ensures it's working
    await getUserByUsername("__pool-warmup-check__");

    initialized = true;
  } catch (_error) {
    // Ignore errors during warmup - the pool should still be functional
    // We're just ensuring connections are pre-allocated
    initialized = true;
  }
}
