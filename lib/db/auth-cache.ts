// Simple in-memory cache for authentication lookups
// This cache is short-lived to prevent stale data issues
// Entries expire after 5 minutes or on app restart

type CacheEntry<T> = {
  value: T;
  timestamp: number;
};

const CACHE_TTL = 5 * 60 * 1000; // 5 minutes in milliseconds

class AuthCache<K, V> {
  private readonly cache = new Map<K, CacheEntry<V>>();

  set(key: K, value: V): void {
    this.cache.set(key, {
      value,
      timestamp: Date.now(),
    });
  }

  get(key: K): V | null {
    const entry = this.cache.get(key);
    if (!entry) {
      return null;
    }

    const isExpired = Date.now() - entry.timestamp > CACHE_TTL;
    if (isExpired) {
      this.cache.delete(key);
      return null;
    }

    return entry.value;
  }

  clear(): void {
    this.cache.clear();
  }

  has(key: K): boolean {
    return this.get(key) !== null;
  }
}

export const userCache = new AuthCache<
  string,
  { id: string; username: string }
>();
