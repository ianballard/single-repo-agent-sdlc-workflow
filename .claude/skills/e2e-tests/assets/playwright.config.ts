import { defineConfig, devices } from '@playwright/test';

// Override when the default port is occupied (e.g., by a stale process).
const BACKEND_PORT = process.env.E2E_BACKEND_PORT ?? '8000';

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: 'html',

  use: {
    baseURL: 'http://localhost:5173',
    video: 'on',
    trace: 'on',
    screenshot: 'on',
  },

  outputDir: './test-results',

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],

  webServer: [
    {
      command: `.venv/bin/python -m uvicorn app.main:app --port ${BACKEND_PORT}`,
      cwd: '../backend',
      url: `http://localhost:${BACKEND_PORT}/docs`,
      // Never reuse: a stale process on this port is not necessarily our
      // backend. Fail loudly and re-run with E2E_BACKEND_PORT instead.
      reuseExistingServer: false,
    },
    {
      command: 'npm --prefix ../frontend run dev',
      url: 'http://localhost:5173',
      reuseExistingServer: !process.env.CI,
      env: {
        API_PROXY_TARGET: `http://localhost:${BACKEND_PORT}`,
      },
    },
  ],
});
