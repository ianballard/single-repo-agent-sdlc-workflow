import { expect, test } from '@playwright/test';

test.describe('backend health status', () => {
  test('shows the backend status when the backend is healthy', async ({ page }) => {
    // The Playwright webServer config starts the real backend; Vite proxies
    // /health to it, so the frontend should render the healthy status.
    await page.goto('/');

    const status = page.getByTestId('backend-status');
    await expect(status).toBeVisible();
    await expect(status).toContainText('ok');
  });

  test('shows an unavailable message when the backend is unreachable', async ({ page }) => {
    // Abort the health request at the browser layer to simulate an unreachable
    // backend. Registered before navigation so the initial fetch is intercepted.
    await page.route('**/health', (route) => route.abort());

    await page.goto('/');

    const status = page.getByTestId('backend-status');
    await expect(status).toBeVisible();
    await expect(status).toContainText(/unavailable/i);
  });
});
