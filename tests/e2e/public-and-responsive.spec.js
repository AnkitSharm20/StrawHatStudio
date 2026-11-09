import { test, expect } from '@playwright/test';

const routes = [
  { path: '/', expected: /STRAW HAT/i },
  { path: '/explore', expected: /Explore|anime/i },
  { path: '/community', expected: /Community|crew/i },
  { path: '/membership', expected: /Membership|Nakama/i },
];

for (const route of routes) {
  test(`renders ${route.path} without a blank screen`, async ({ page }) => {
    const pageErrors = [];
    page.on('pageerror', error => pageErrors.push(error.message));
    await page.goto(route.path, { waitUntil: 'domcontentloaded' });
    await expect(page.locator('body')).toContainText(route.expected, { timeout: 15_000 });
    await expect(page.locator('main')).toBeVisible();
    expect(pageErrors, pageErrors.join('\n')).toEqual([]);
  });
}

test('does not create horizontal page overflow at the target device viewport', async ({ page }) => {
  for (const path of ['/', '/explore', '/community', '/membership']) {
    await page.goto(path, { waitUntil: 'domcontentloaded' });
    await expect(page.locator('main')).toBeVisible();
    const dimensions = await page.evaluate(() => ({
      viewport: document.documentElement.clientWidth,
      document: document.documentElement.scrollWidth,
      body: document.body.scrollWidth,
    }));
    expect(dimensions.document, `${path}: document overflow ${JSON.stringify(dimensions)}`).toBeLessThanOrEqual(dimensions.viewport + 2);
    expect(dimensions.body, `${path}: body overflow ${JSON.stringify(dimensions)}`).toBeLessThanOrEqual(dimensions.viewport + 2);
  }
});

test('membership shows the server-controlled checkout state and no fake success state', async ({ page }) => {
  await page.goto('/membership', { waitUntil: 'domcontentloaded' });
  await expect(page.locator('main')).toContainText(/Membership/i);
  await expect(page.locator('main')).toContainText(/test mode|test checkout|sign in/i);
  await expect(page.locator('main')).not.toContainText(/Payment successful/i);
});
