# API Request Check: GitHub API and Carforce Prelive API

## What I Did

I ran requests against two APIs and inspected the status codes, headers, and response bodies. No valid credentials were used; one login attempt with made-up credentials was sent to prelive (using the base URL from the app's `BASE_URL` setting).

## GitHub API

| Request | Status | Headers That Matter and Why |
| :-: | :-: | :-- |
| `GET /repos/facebook/react-native/license` | 301 → `/repositories/29028775/license` | `location` shows the new canonical URL because the repo was renamed or moved. `x-ratelimit-limit: 60` and `x-ratelimit-remaining` indicate the unauthenticated limit of 60 requests per hour per IP. |
| `POST /markdown` with JSON `{"text":"**hello**","mode":"markdown"}` | 200, `text/html` | Sending `Content-Type: application/json` makes the server parse the body, while the response returns rendered HTML instead of JSON. |
| `GET /repos/facebook/this-repo-does-not-exist-xyz` | 404 | Returns a JSON error body (`{message, documentation_url, status}`). Failed requests still consume rate-limit quota. Quote `x-github-request-id` when contacting support. |
| `POST /markdown` with `text` field missing | 422 | Same JSON error shape. The payload was valid JSON, but failed field validation. |

## Carforce Prelive API

| Request | Status | Headers That Matter and Why |
| :-: | :-: | :-- |
| `GET /terms-and-conditions` | 200, `text/html` | `server: cloudflare` and `cf-ray` confirm the API sits behind Cloudflare. `cf-cache-status: DYNAMIC` indicates the response is not cached at the edge. |
| `POST /auth/sign_in` with JSON and fake credentials | 401, `{"success":false,"errors":["Invalid login credentials…"]}` | Quote `x-request-id` when asking backend for logs. `x-runtime: 0.027` shows server processing time. `cache-control: no-cache` prevents caching, while `nosniff` and `x-frame-options` reflect default Rails security headers. |
| `GET /api/crm/crm_leads` with no auth headers | 401, `{"errors":["You need to sign in…"]}` | `x-runtime: 0.004`. Authentication rejects the request before any lead database query runs. |
| `POST /auth/sign_in` with malformed JSON | 400, `text/html` | Body parsing failed before reaching the controller, returning an HTML error page instead of JSON. |

## What Happens on the Server When the App Calls an Endpoint

1. **Edge:** Cloudflare terminates TLS and proxies the request to the origin server without caching.
2. **Rails Stack (Inferred):** Rails assigns a unique request ID (`x-request-id`), starts a runtime timer (`x-runtime`), and parses the incoming body based on `Content-Type`.
3. **Body Parsing:** Malformed JSON terminates here with a 400 status and an HTML error body.
4. **Authentication (Inferred: `devise_token_auth`-style):** The app passes `authorization`, `client`, `uid`, and refresh-token headers. Missing or invalid tokens trigger a 401 response in ~4 ms. `/auth/sign_in` bypasses token checks and validates email and password instead.
5. **Controller and Database:** Only authenticated requests reach this stage (not directly observed in this check).
6. **Response:** Rails attaches security headers along with `cache-control: no-cache`, and Cloudflare relays the response back to the app.

## Key Findings

- **Non-Uniform Error Bodies:** 401 and 422 responses return JSON with an `errors` array, whereas a 400 from malformed JSON returns HTML. Client error-handling code must not assume every error response is valid JSON.
- **Global 401 Handling:** Any 401 response logs the user out via the app's global interceptor. The `sign_out` endpoint explicitly opts out of this behavior to prevent an infinite logout loop.
- **Backend Log Debugging:** Always include the `x-request-id` header value from a failing response when requesting server logs from the backend team.

## Limits

- **Unauthenticated Scope:** Because no valid credentials were used, no successful POST mutations or authenticated GET data responses were observed.
- **Inferred Internals:** The server-side execution flow above is inferred from HTTP response headers and payload shapes rather than direct inspection of backend source code.
