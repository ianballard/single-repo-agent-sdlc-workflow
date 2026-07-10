import { test, expect } from '@playwright/test';

test.describe('backend health status', () => {
  test('shows online status when the backend is reachable', async ({ page }) => {
    await page.goto('/');
    await expect(page.getByTestId('backend-status')).toHaveText('Backend status: online');
  });

  test('shows unavailable status when the backend is unreachable', async ({ page }) => {
    await page.route('**/api/health', (route) => route.abort());
    await page.goto('/');
    await expect(page.getByTestId('backend-status')).toHaveText('Backend status: unavailable');
  });
});
