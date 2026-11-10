import { test, expect } from '@playwright/test';

const projectUrl = process.env.E2E_SUPABASE_URL || '';
const projectRef = (() => { try { return new URL(projectUrl).hostname.split('.')[0]; } catch { return ''; } })();
const stagingOnly = projectRef && projectRef !== 'xlwtpysdknjzgjiecbhm';
const enabled = process.env.E2E_ALLOW_MUTATING_TESTS === 'true'
  && stagingOnly
  && Boolean(process.env.E2E_SUPABASE_ANON_KEY)
  && Boolean(process.env.E2E_USER_A_SESSION_JSON)
  && Boolean(process.env.E2E_USER_B_SESSION_JSON);

async function useSession(page, serialized) {
  const session = JSON.parse(serialized);
  const storageKey = 'sb-' + projectRef + '-auth-token';
  await page.addInitScript(({ key, value }) => {
    localStorage.setItem(key, JSON.stringify(value));
  }, { key: storageKey, value: session });
}

test.describe('authenticated staging acceptance', () => {
  test.beforeEach(async () => {
    test.skip(!enabled, 'Requires a dedicated non-production Supabase staging project, two test sessions and explicit mutation opt-in.');
  });

  test('two members can publish, reply and receive a notification', async ({ browser }) => {
    const marker = 'SHS_E2E_' + Date.now() + '_' + Math.random().toString(36).slice(2, 8);
    const replyMarker = marker + '_REPLY';
    const contextA = await browser.newContext();
    const pageA = await contextA.newPage();
    await useSession(pageA, process.env.E2E_USER_A_SESSION_JSON);
    await pageA.goto('/community');
    await expect(pageA.locator('.community-compose-box textarea')).toBeVisible();
    await pageA.locator('.community-compose-box textarea').fill(marker);
    await pageA.getByRole('button', { name: /Publish post/ }).click();
    const postA = pageA.locator('.community-post-card').filter({ hasText: marker });
    await expect(postA).toBeVisible({ timeout: 15_000 });

    const contextB = await browser.newContext();
    const pageB = await contextB.newPage();
    await useSession(pageB, process.env.E2E_USER_B_SESSION_JSON);
    await pageA.goto('/notifications');
    await expect(pageA.locator('.notification-feed')).toBeVisible();

    await pageB.goto('/community');
    const postB = pageB.locator('.community-post-card').filter({ hasText: marker });
    await expect(postB).toBeVisible({ timeout: 15_000 });

    // Follow, report, and reply as the second member.
    const followButton = postB.locator('.community-follow-button');
    await followButton.click();
    await expect(followButton).toContainText('Following');
    await postB.getByRole('button', { name: 'Report', exact: true }).click();
    await expect(pageB.getByRole('dialog', { name: /Report post/i })).toBeVisible();
    await pageB.getByLabel('Details (optional)').fill('Automated staging moderation check: ' + marker);
    await pageB.getByRole('button', { name: 'Submit report' }).click();

    await postB.locator('.post-actions button').filter({ hasText: /replies/ }).click();
    await postB.locator('input[placeholder="Write a reply…"]').fill(replyMarker);
    await postB.getByRole('button', { name: 'Reply' }).click();

    // Blocking hides the author's posts in the blocker's feed and exposes an unblock control.
    pageB.once('dialog', dialog => dialog.accept());
    await postB.getByRole('button', { name: /^Block / }).click();
    await expect(pageB.locator('.community-post-card').filter({ hasText: marker })).toHaveCount(0);
    await expect(pageB.getByRole('heading', { name: 'Blocked members' })).toBeVisible();
    const unblock = pageB.locator('button[aria-label^="Unblock "]').first();
    await expect(unblock).toBeVisible();
    await unblock.click();
    await expect(pageB.locator('.community-post-card').filter({ hasText: marker })).toBeVisible({ timeout: 15_000 });

    // The notification arrives over Realtime while member A's inbox is already open.
    const notification = pageA.locator('.notification-card').filter({ hasText: 'Someone replied to your post.' });
    await expect(notification).toBeVisible({ timeout: 20_000 });
    await notification.getByRole('button', { name: 'Mark as read' }).click();
    await expect(notification.locator('.notification-unread-dot')).toHaveCount(0);
    await notification.getByRole('button', { name: 'Delete notification' }).click();
    await expect(pageA.locator('.notification-feed')).not.toContainText('Someone replied to your post.');

    // Verify admin moderation and audit access only when an isolated admin session is supplied.
    if (process.env.E2E_ADMIN_SESSION_JSON) {
      const adminContext = await browser.newContext();
      const adminPage = await adminContext.newPage();
      await useSession(adminPage, process.env.E2E_ADMIN_SESSION_JSON);
      await adminPage.goto('/admin');
      await expect(adminPage.getByRole('heading', { name: 'Control centre' })).toBeVisible();
      await adminPage.getByRole('button', { name: 'Moderation' }).click();
      const reportedCard = adminPage.locator('.admin-report-card').filter({ hasText: marker });
      await expect(reportedCard).toBeVisible({ timeout: 20_000 });
      await reportedCard.getByRole('button', { name: 'Hide content' }).click();
      await expect(reportedCard).toContainText('resolved');
      await adminPage.getByRole('button', { name: 'Audit log' }).click();
      await expect(adminPage.getByRole('heading', { name: 'Admin audit log' })).toBeVisible();
      await adminContext.close();
    }

    await contextB.close();
    await contextA.close();
  });

  test('member can upload a private profile banner', async ({ page }) => {
    await useSession(page, process.env.E2E_USER_A_SESSION_JSON);
    await page.goto('/profile');
    await expect(page.getByRole('heading', { name: 'My profile' })).toBeVisible();
    await page.getByRole('button', { name: /Edit profile/ }).click();
    const username = 'e2e' + Date.now().toString().slice(-8);
    await page.locator('.profile-editor input').nth(2).fill(username);
    await page.getByRole('button', { name: 'Save username' }).click();
    await expect(page.locator('.profile-name-line')).toContainText(username, { timeout: 15_000 });

    const tinyPng = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/nWQAAAAASUVORK5CYII=', 'base64');
    const fileInputs = page.locator('.profile-editor input[type="file"]');
    await fileInputs.nth(0).setInputFiles({ name: 'e2e-private-banner.png', mimeType: 'image/png', buffer: tinyPng });
    await expect(page.locator('.toast')).toContainText('Profile banner updated', { timeout: 20_000 });
    await fileInputs.nth(1).setInputFiles({ name: 'e2e-avatar.png', mimeType: 'image/png', buffer: tinyPng });
    await expect(page.locator('.toast')).toContainText('Profile avatar updated', { timeout: 20_000 });
  });

  test('non-admin member cannot open admin controls', async ({ page }) => {
    await useSession(page, process.env.E2E_USER_B_SESSION_JSON);
    await page.goto('/admin');
    await expect(page.getByRole('heading', { name: 'Access restricted' })).toBeVisible();
  });
});

test.describe('admin staging acceptance', () => {
  test('admin can open the audit log', async ({ page }) => {
    test.skip(!enabled || !process.env.E2E_ADMIN_SESSION_JSON, 'Requires a dedicated staging admin session.');
    await useSession(page, process.env.E2E_ADMIN_SESSION_JSON);
    await page.goto('/admin');
    await expect(page.getByRole('heading', { name: 'Control centre' })).toBeVisible();
    await page.getByRole('button', { name: /Audit log/ }).click();
    await expect(page.getByRole('heading', { name: 'Admin audit log' })).toBeVisible();
  });
});
