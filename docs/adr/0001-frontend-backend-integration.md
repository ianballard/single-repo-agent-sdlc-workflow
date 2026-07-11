# ADR 0001: Frontend–backend integration and cross-origin handling

- Status: Accepted
- Context: KAN-8 (Add backend health endpoint and display backend status in the frontend)

## Context

The frontend (React + Vite, `http://localhost:5173`) and the backend (FastAPI,
`http://localhost:8000`) run on different origins during development. The first
integration — a `GET /health` endpoint consumed by a status indicator — needs a
cross-origin strategy that future features will reuse. Two options were on the
table:

1. **Backend CORS middleware** — add `CORSMiddleware` to FastAPI allowing the
   frontend origin.
2. **Vite dev-server proxy** — the browser calls a same-origin `/api` path and
   the Vite dev server proxies it to the backend.

The existing `e2e/playwright.config.ts` already starts the backend via uvicorn
and injects `API_PROXY_TARGET=http://localhost:8000` into the frontend dev
server's environment — the harness is pre-wired for a proxy.

## Decision

Use a **Vite dev-server proxy**. The frontend fetches `/api/health`; Vite's
`server.proxy` forwards `/api/*` to `API_PROXY_TARGET` (default
`http://localhost:8000`), stripping the `/api` prefix. The backend has no CORS
middleware.

Consequences:

- Browser requests are always same-origin (`localhost:5173`), so no CORS
  preflight or headers are involved and CORS errors cannot occur.
- The backend stays minimal — no permissive CORS config is shipped.
- The proxy target is configurable per environment via `API_PROXY_TARGET`.

## Consequences / future work

- This proxy is a **dev-server** mechanism. A production deployment must provide
  its own equivalent — a reverse proxy that serves the frontend and routes
  `/api` to the backend, or explicit CORS configuration if the two are served
  from different origins. That is out of scope for KAN-8 and should be addressed
  when the deployment story is defined.
