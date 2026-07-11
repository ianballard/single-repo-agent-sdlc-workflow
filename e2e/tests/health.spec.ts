import { expect, test } from '@playwright/test';

test.describe('backend health status', () => {
  test('shows the backend status when the backend is healthy', async ({ page }) => {
    await page.goto('/');

    await expect(page.getByTestId('backend-status')).toHaveText('Backend: ok');
  });

  test('shows an unavailable message when the backend is unreachable', async ({ page }) => {
    // Simulate an unreachable backend at the browser layer, independent of
    // whether the real backend is running.
    await page.route('**/api/health', (route) => route.abort());

    await page.goto('/');

    await expect(page.getByTestId('backend-status')).toHaveText('Backend: unavailable');
  });
});
