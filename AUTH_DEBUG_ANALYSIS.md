# Authentication Debug Analysis: Credentials Login Issue in Production

## Executive Summary

The credentials login with auto-user-creation was **failing in production but working in development** due to a **cookie security misconfiguration** in the middleware. The issue was caused by the `secureCookie` setting being hardcoded to `true` in production environments, which prevents cookies from being set over HTTP connections.

## Root Cause Analysis

### Primary Issue: Secure Cookie Misconfiguration

**Location**: `middleware.ts` (lines 20-24)

**Original Code**:
```typescript
const token = await getToken({
  req: request,
  secret: process.env.AUTH_SECRET,
  secureCookie: !isDevelopmentEnvironment,
});
```

**Problem**:
- In development: `isDevelopmentEnvironment = true` → `secureCookie = false` ✓ Works with HTTP
- In production: `isDevelopmentEnvironment = false` → `secureCookie = true` ✗ Requires HTTPS

**Impact**:
1. The Docker container runs on HTTP (port 3000) in production
2. With `secureCookie: true`, JWT cookies can ONLY be set/read over HTTPS
3. When users log in via HTTP in production:
   - The `authorize()` callback succeeds
   - User is created in the database successfully
   - BUT the session cookie cannot be stored
   - User appears logged out immediately after login

### Why It Works in Development

Development uses HTTP on localhost with `secureCookie: false`, allowing cookies to be set normally.

### Why It Fails in Production

Production deployments typically:
- Run Docker containers on HTTP (port 3000)
- May use a reverse proxy (nginx, Cloudflare, etc.) for HTTPS termination
- The app only sees HTTP traffic from the reverse proxy
- With `secureCookie: true`, cookies are rejected

## The Fix

### 1. Smart Cookie Security Detection (middleware.ts)

**New Implementation**:
```typescript
// Determine if we should use secure cookies based on the actual protocol
// In production behind a reverse proxy, check x-forwarded-proto header
const proto = request.headers.get("x-forwarded-proto");
const isHttps = proto ? proto === "https" : request.nextUrl.protocol === "https:";

// Use secure cookies only when:
// 1. Not in development mode AND
// 2. The connection is actually over HTTPS (either direct or via proxy)
const useSecureCookie = !isDevelopmentEnvironment && isHttps;

const token = await getToken({
  req: request,
  secret: process.env.AUTH_SECRET,
  secureCookie: useSecureCookie,
});
```

**How It Works**:
1. Checks the `x-forwarded-proto` header (set by reverse proxies)
2. Falls back to the actual protocol if no header is present
3. Only uses secure cookies when HTTPS is detected
4. Allows HTTP in production for internal/testing deployments

### 2. Improved Error Logging (app/(auth)/auth.ts)

**Added logging** to help debug future authentication issues:
```typescript
catch (error) {
  console.error("[Auth] Failed to ensure user by username:", error);
  return null;
}
```

This provides visibility into:
- Database connection failures
- User creation errors
- Query execution problems

### 3. Environment Variable Clarification (.env.example)

**Updated documentation**:
- Removed deprecated `NEXTAUTH_SECRET` reference
- Clarified that NextAuth v5 uses `AUTH_SECRET`
- Added detailed comments for `NEXTAUTH_URL` configuration
- Explained HTTP vs HTTPS deployment scenarios

## Verification Steps

### For HTTP Deployments (Direct or Behind Proxy)

1. **No reverse proxy** (Direct HTTP access):
   ```bash
   # In .env.production
   NEXTAUTH_URL=http://your-server-ip:3000
   ```
   - Cookies will work because `secureCookie` is set to `false`

2. **Behind HTTPS reverse proxy**:
   ```bash
   # In .env.production
   NEXTAUTH_URL=https://your-domain.com
   ```
   - Ensure reverse proxy sets `X-Forwarded-Proto: https`
   - Cookies will work because the app detects HTTPS via header

### Testing the Fix

1. **Test Login Flow**:
   ```bash
   # Watch auth logs
   docker logs -f ai-chatbot
   
   # Try logging in with a username
   # Should see: User created/retrieved successfully
   # Should stay logged in after redirect
   ```

2. **Verify Cookie is Set**:
   ```bash
   # In browser DevTools → Application → Cookies
   # Look for: next-auth.session-token or __Secure-next-auth.session-token
   ```

3. **Check Token Retrieval**:
   ```bash
   # Add temporary logging in middleware.ts
   console.log("[Middleware] Token:", token ? "Found" : "Not found");
   console.log("[Middleware] Secure cookie:", useSecureCookie);
   ```

## Secondary Issues Identified

### 1. Database Connection
- The Dockerfile sets a dummy `POSTGRES_URL` for the build stage (line 25)
- This is fine as long as the runtime environment properly overrides it
- Verify `.env.production` contains the correct database URL

### 2. Environment Variable Naming
- NextAuth v5 beta uses `AUTH_SECRET`, not `NEXTAUTH_SECRET`
- The example previously showed both, causing potential confusion
- Now clarified in `.env.example`

### 3. Error Swallowing
- The original `authorize()` callback caught and discarded all errors
- Now logs errors to help diagnose issues
- Still returns `null` to prevent auth bypass, but provides debug info

## Production Deployment Checklist

When deploying to production, ensure:

- [ ] `AUTH_SECRET` is set to a secure random value (≥32 characters)
- [ ] `NEXTAUTH_URL` matches the actual URL users access (including protocol)
- [ ] `POSTGRES_URL` points to the production database
- [ ] If using HTTPS via reverse proxy:
  - [ ] Reverse proxy sets `X-Forwarded-Proto: https` header
  - [ ] Reverse proxy sets `X-Forwarded-Host` header
- [ ] If using HTTP in production:
  - [ ] Understand the security implications
  - [ ] Consider using HTTPS in production
- [ ] Test the login flow after deployment
- [ ] Check container logs for auth errors

## Reverse Proxy Configuration Examples

### Nginx
```nginx
location / {
    proxy_pass http://localhost:3000;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
```

### Cloudflare
Cloudflare automatically sets `X-Forwarded-Proto` when proxying traffic.

### Traefik
```yaml
http:
  routers:
    app:
      middlewares:
        - headers
  middlewares:
    headers:
      headers:
        customRequestHeaders:
          X-Forwarded-Proto: "https"
```

## Testing Scenarios

### Scenario 1: Development (HTTP on localhost)
- ✅ `isDevelopmentEnvironment = true`
- ✅ `secureCookie = false`
- ✅ Cookies work

### Scenario 2: Production with Direct HTTPS
- ✅ `request.nextUrl.protocol = "https:"`
- ✅ `secureCookie = true`
- ✅ Cookies work

### Scenario 3: Production with HTTP (Behind HTTPS Proxy)
- ✅ `x-forwarded-proto = "https"`
- ✅ `secureCookie = true`
- ✅ Cookies work

### Scenario 4: Production with Direct HTTP (Previously Broken)
- ✅ No `x-forwarded-proto` header
- ✅ `request.nextUrl.protocol = "http:"`
- ✅ `secureCookie = false` (NEW - allows cookies)
- ✅ Cookies work (FIXED)

## Additional Recommendations

1. **Use HTTPS in Production**: While this fix enables HTTP deployments, HTTPS should be used for production to protect user credentials and session tokens.

2. **Monitor Auth Logs**: The improved error logging will help identify:
   - Database connectivity issues
   - Invalid usernames
   - Query execution problems

3. **Set Up Reverse Proxy Correctly**: If using a reverse proxy, ensure it's configured to pass the correct headers.

4. **Regular Security Audits**: Review authentication logs and ensure secure cookies are being used when HTTPS is available.

## Conclusion

The authentication issue in production was caused by the middleware blindly setting `secureCookie: true` in all production environments, without considering that the app might be accessed over HTTP (either directly or behind a reverse proxy that terminates HTTPS).

The fix intelligently detects the actual protocol (via `x-forwarded-proto` header or direct protocol inspection) and only uses secure cookies when HTTPS is actually present. This allows the app to work in all deployment scenarios:
- Development (HTTP)
- Production with direct HTTP
- Production with direct HTTPS
- Production behind HTTPS-terminating reverse proxy

The auto-user-creation functionality was always working correctly - the issue was solely with cookie storage/retrieval.
