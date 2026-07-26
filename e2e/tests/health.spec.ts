import { test, expect } from '@playwright/test';

test.describe('backend health status', () => {
  test('shows backend status as available when the backend is healthy', async ({ page }) => {
    await page.goto('/');

    await expect(page.getByTestId('health-status')).toHaveText('Backend status: Available');
  });

  test('shows backend status as unavailable when the backend is unreachable', async ({ page }) => {
    await page.route('**/health', (route) => route.abort());

    await page.goto('/');

    await expect(page.getByTestId('health-status')).toHaveText('Backend status: Unavailable');
  });
});
