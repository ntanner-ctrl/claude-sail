## Triage Result

**Change:** Migrate from session-based authentication to JWT with refresh token rotation
**Steps:** 14 discrete actions
**Risk flags:** Authentication, authorization, security-sensitive operations, user-facing behavior change
**Execution preference:** Auto

**Recommended path:** Full — `/blueprint jwt-migration` for guided workflow

---

## Step Breakdown

1. Add `jsonwebtoken` and `cookie-parser` dependencies
2. Create `src/auth/jwt.ts` — token generation and validation utilities
3. Create `src/auth/refresh.ts` — refresh token rotation logic
4. Add `refresh_tokens` database table migration
5. Update `POST /auth/login` — issue access + refresh tokens
6. Update `POST /auth/logout` — invalidate refresh token in DB
7. Add `POST /auth/refresh` endpoint
8. Update `src/middleware/requireAuth.ts` — validate JWT instead of session
9. Update `src/middleware/requireRole.ts` — read claims from JWT payload
10. Remove `express-session` configuration from `app.ts`
11. Update client-side `AuthContext` — store tokens, handle refresh
12. Update client-side `apiClient.ts` — attach Bearer header, retry on 401
13. Add integration tests for token expiry and rotation edge cases
14. Update `.env.example` with `JWT_SECRET` and `JWT_REFRESH_SECRET` entries

---

## Risk Assessment

This change directly touches the **authentication** and **authorization** stack. Security is a primary concern — token leakage, improper refresh rotation, or misconfigured expiry windows could expose user accounts. The 14-step count combined with the security risk flags places this firmly in the Full path.

All three security risk dimensions are present:
- Authentication flow is being replaced wholesale
- Authorization middleware reads from the new token format
- Security-sensitive secrets management is involved

---

## Recommendation

Run `/blueprint jwt-migration` to create a full planning protocol with spec, adversarial review, and staged execution. Do not proceed without a written spec reviewed for security edge cases.

Next steps:
  - Full path → `/blueprint jwt-migration` for guided workflow
