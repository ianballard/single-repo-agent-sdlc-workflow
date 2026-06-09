import { test, expect } from '@playwright/test';

test.describe('RNG display', () => {
  test('shows a random number on load and re-rolls via the button', async ({ page }) => {
    await page.goto('/');

    await expect(page.getByRole('heading', { name: 'Random Number' })).toBeVisible();

    const value = page.locator('section > p');
    await expect(value).toHaveText(/^\d+$/);

    const reroll = page.getByRole('button', { name: 'Re-roll' });
    await expect(reroll).toBeEnabled();

    await reroll.click();

    await expect(value).toHaveText(/^\d+$/);
    await expect(reroll).toBeEnabled();
  });
});
