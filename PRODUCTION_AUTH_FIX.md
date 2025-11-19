# Production Auth Fix - Quick Reference

## Issue Summary
Username-only credentials login with auto-user-creation was failing in production (but working in development) due to incorrect secure cookie configuration.

## Root Cause
The middleware was forcing `secureCookie: true` in all production environments, which prevents cookies from being set over HTTP connections. Production deployments running on HTTP (even behind HTTPS proxies) couldn't store session cookies, causing users to appear logged out immediately after successful login.

## Files Changed

### 1. middleware.ts
**What Changed**: Smart cookie security detection based on actual protocol (HTTP vs HTTPS)
- Now checks `x-forwarded-proto` header for reverse proxy scenarios
- Only uses secure cookies when HTTPS is actually detected
- Allows HTTP in production for internal/testing deployments

### 2. app/(auth)/auth.ts  
**What Changed**: Improved error logging in the `authorize()` callback
- Logs authentication failures with context
- Helps debug database connection issues
- Still returns `null` on errors (secure)

### 3. .env.example
**What Changed**: Clarified environment variable documentation
- Removed deprecated `NEXTAUTH_SECRET` reference
- Added detailed comments for `NEXTAUTH_URL` configuration
- Explained HTTP vs HTTPS deployment scenarios

## Deployment Instructions

### For Direct HTTP Deployments (No Reverse Proxy)
```bash
# In .env.production
AUTH_SECRET=<your-secure-random-secret>
NEXTAUTH_URL=http://your-server-ip:3000
POSTGRES_URL=postgresql://user:pass@host:5432/db
```

✅ **Result**: Auth will work because app detects HTTP and uses `secureCookie: false`

### For HTTPS Reverse Proxy Deployments
```bash
# In .env.production
AUTH_SECRET=<your-secure-random-secret>
NEXTAUTH_URL=https://your-domain.com
POSTGRES_URL=postgresql://user:pass@host:5432/db
```

**Reverse Proxy Configuration** (e.g., Nginx):
```nginx
location / {
    proxy_pass http://localhost:3000;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header X-Forwarded-Host $host;
    proxy_set_header X-Real-IP $remote_addr;
}
```

✅ **Result**: Auth will work because app detects HTTPS via `x-forwarded-proto` header

### For Direct HTTPS Deployments
```bash
# In .env.production
AUTH_SECRET=<your-secure-random-secret>
NEXTAUTH_URL=https://your-domain.com
POSTGRES_URL=postgresql://user:pass@host:5432/db
```

✅ **Result**: Auth will work because app directly sees HTTPS protocol

## Testing the Fix

### 1. Test Login Flow
```bash
# Watch auth logs
docker logs -f ai-chatbot

# Try logging in with any username
# Expected output:
# - [Auth] messages showing user creation/retrieval
# - User should stay logged in after redirect
```

### 2. Verify Cookie Storage
**Browser DevTools → Application → Cookies**
- Look for: `next-auth.session-token` (HTTP) or `__Secure-next-auth.session-token` (HTTPS)
- Should be set after successful login

### 3. Check Middleware Token Detection
Add temporary logging if needed:
```typescript
// In middleware.ts (after getToken call)
console.log("[Middleware] Token found:", !!token);
console.log("[Middleware] Using secure cookie:", useSecureCookie);
console.log("[Middleware] Protocol:", isHttps ? "HTTPS" : "HTTP");
```

## Troubleshooting

### Login succeeds but user is immediately logged out
**Symptoms**: 
- Login page shows success
- Redirects to home page
- Immediately redirects back to login page

**Cause**: Session cookie not being set

**Solution**:
1. Check `NEXTAUTH_URL` matches the actual URL users access
2. If behind reverse proxy, ensure `X-Forwarded-Proto` header is set
3. Check browser DevTools → Network → Response Headers for Set-Cookie

### "Failed to ensure user by username" error
**Symptoms**: Login fails with error in logs

**Possible Causes**:
1. Database connection issue - check `POSTGRES_URL`
2. Database table doesn't exist - run migrations
3. Invalid username format

**Solution**:
```bash
# Check database connectivity
docker exec -it ai-chatbot node -e "const pg = require('postgres'); const db = pg(process.env.POSTGRES_URL); db\`SELECT 1\`.then(console.log).catch(console.error)"

# Check if User table exists
docker exec -it ai-chatbot node -e "const pg = require('postgres'); const db = pg(process.env.POSTGRES_URL); db\`SELECT * FROM information_schema.tables WHERE table_name = 'User'\`.then(console.log)"
```

### Cookies not being sent on subsequent requests
**Symptoms**:
- Login succeeds
- Cookie visible in DevTools
- But middleware doesn't see token

**Possible Causes**:
1. Cookie domain mismatch
2. `NEXTAUTH_URL` doesn't match request origin
3. CORS issues

**Solution**:
1. Ensure `NEXTAUTH_URL` exactly matches the URL in the browser
2. No trailing slashes
3. Correct protocol (http/https)
4. Correct port

## Security Considerations

### Production Deployments
- **Always use HTTPS in production** when possible
- HTTP is supported for testing/internal deployments, but HTTPS is strongly recommended
- Secure cookies are automatically enabled when HTTPS is detected

### Environment Variables
- Use strong random values for `AUTH_SECRET` (≥32 characters)
- Never commit `.env.production` to version control
- Rotate secrets regularly

## Quick Verification Checklist

Before deploying:
- [ ] `AUTH_SECRET` is set (≥32 chars, random)
- [ ] `NEXTAUTH_URL` matches actual URL (including protocol)
- [ ] `POSTGRES_URL` points to production database
- [ ] Database migrations are up to date
- [ ] If using reverse proxy: `X-Forwarded-Proto` header is set

After deploying:
- [ ] Login with test username succeeds
- [ ] User stays logged in after redirect
- [ ] Session persists across page refreshes
- [ ] Check logs for any auth errors

## Rollback Plan

If issues occur, the previous behavior can be restored:

```typescript
// In middleware.ts, revert to:
const token = await getToken({
  req: request,
  secret: process.env.AUTH_SECRET,
  secureCookie: !isDevelopmentEnvironment,
});
```

Note: This will re-introduce the HTTP deployment issue.

## More Information

See `AUTH_DEBUG_ANALYSIS.md` for:
- Detailed technical analysis
- Step-by-step explanation of the issue
- All testing scenarios
- Reverse proxy configuration examples
- Additional recommendations

## Support

If auth issues persist after this fix:
1. Check container logs: `docker logs ai-chatbot`
2. Review `AUTH_DEBUG_ANALYSIS.md`
3. Verify environment variables are correctly set
4. Test database connectivity
5. Check reverse proxy configuration (if applicable)
