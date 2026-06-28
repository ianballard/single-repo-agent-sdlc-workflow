/// <reference types="vitest/config" />
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// In dev, the frontend issues same-origin requests (e.g. /health) which Vite
// proxies to the backend. This avoids cross-origin requests entirely, so no
// CORS handling is needed on the backend. The e2e harness sets API_PROXY_TARGET.
const API_PROXY_TARGET = process.env.API_PROXY_TARGET ?? 'http://localhost:8000';

export default defineConfig({
  plugins: [react()],
  server: {
    proxy: {
      '/health': {
        target: API_PROXY_TARGET,
        changeOrigin: true,
      },
    },
  },
  test: {
    environment: 'jsdom',
  },
});
