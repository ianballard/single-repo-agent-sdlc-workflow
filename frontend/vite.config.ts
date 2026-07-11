/// <reference types="vitest/config" />
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// The frontend talks to the backend through a same-origin `/api` prefix that
// the dev server proxies to the backend. This keeps browser requests
// same-origin, avoiding CORS entirely. Override the target via API_PROXY_TARGET
// (the e2e harness sets this per run).
const apiProxyTarget = process.env.API_PROXY_TARGET ?? 'http://localhost:8000';

export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      '/api': {
        target: apiProxyTarget,
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, ''),
      },
    },
  },
  test: {
    environment: 'jsdom',
  },
});
