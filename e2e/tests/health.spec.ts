import { test, expect } from '@playwright/test';

test('shows backend status when backend is healthy', async ({ page }) => {
  await page.goto('/');
  await expect(page.getByText('Backend status: ok')).toBeVisible();
});

test('shows unavailable message when backend returns an error', async ({ page }) => {
  await page.route('/api/health', (route) =>
    route.fulfill({
      status: 503,
      contentType: 'application/json',
      body: JSON.stringify({ detail: 'Service Unavailable' }),
    }),
  );
  await page.goto('/');
  await expect(page.getByText('Backend unavailable (HTTP 503)')).toBeVisible();
});
