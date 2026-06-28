# Frontend

React 18 + TypeScript (Vite, Vitest).

## Setup

```bash
npm install
```

## Run

```bash
npm run dev
```

Serves at http://localhost:5173.

## Test

```bash
npm test
```

## Backend API / CORS

The frontend talks to the backend using **same-origin relative paths** (e.g.
`/health`). In development the Vite dev server proxies these to the backend
(see `server.proxy` in `vite.config.ts`), so the browser never makes a
cross-origin request and **no CORS configuration is needed on the backend**.

The proxy target defaults to `http://localhost:8000` and can be overridden with
the `API_PROXY_TARGET` environment variable (the e2e harness sets this).
