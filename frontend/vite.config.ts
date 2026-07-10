/// <reference types="vitest/config" />
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    // Cross-origin backend calls are handled via this dev-server proxy
    // rather than backend CORS middleware, so the browser only ever talks
    // to this origin. Target is overridable via API_PROXY_TARGET so e2e can
    // point it at a non-default backend port.
    proxy: {
      '/api': {
        target: process.env.API_PROXY_TARGET ?? 'http://localhost:8000',
        changeOrigin: true,
        rewrite: (path) => path.replace(/^\/api/, ''),
      },
    },
  },
  test: {
    environment: 'jsdom',
  },
});
