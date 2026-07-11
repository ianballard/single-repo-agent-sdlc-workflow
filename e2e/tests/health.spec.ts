import { test, expect } from '@playwright/test';

test.describe('backend health status', () => {
  test('shows backend available when healthy', async ({ page }) => {
    await page.goto('/');
    await expect(page.getByTestId('backend-status')).toHaveText(/available/i);
  });

  test('shows backend unavailable when health check fails', async ({ page }) => {
    await page.route('**/api/health', (route) => route.abort());
    await page.goto('/');
    await expect(page.getByTestId('backend-status')).toHaveText(/unavailable/i);
  });
});
