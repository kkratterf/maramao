// Renders the social preview cards from scripts/og/og.html into
// site/og.jpg (English) and site/og-it.jpg (Italian), 1200x630.
//
// Usage: node scripts/render-og.mjs
// Needs Playwright with Chromium (npm i -D playwright && npx playwright install chromium)
// and ImageMagick (magick or convert) for the JPEG step.
//
// The Grainient gradient moves over time, so each run gives a slightly
// different frame: look at the result before committing it.

import { chromium } from 'playwright';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const page = pathToFileURL(join(root, 'scripts/og/og.html')).href;
const SETTLE_MS = 6000;
const shots = [{ hash: '', out: 'site/og.jpg' }, { hash: '#it', out: 'site/og-it.jpg' }];

const tmp = mkdtempSync(join(tmpdir(), 'maramao-og-'));
const browser = await chromium.launch({
  args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
});
try {
  for (const { hash, out } of shots) {
    const tab = await browser.newPage({ viewport: { width: 1200, height: 630 } });
    await tab.goto(page + hash);
    await tab.evaluate(() => document.fonts.ready);
    await tab.waitForTimeout(SETTLE_MS);
    const live = await tab.evaluate(() => document.querySelector('.grainient').classList.contains('is-live'));
    if (!live) throw new Error('the gradient did not start (no WebGL 2?)');
    const png = join(tmp, 'og.png');
    await tab.locator('#card').screenshot({ path: png });
    let magick = 'magick';
    try { execFileSync(magick, ['-version']); } catch { magick = 'convert'; }
    execFileSync(magick, [png, '-strip', '-quality', '86', '-sampling-factor', '4:2:0', join(root, out)]);
    console.log(`Wrote ${out}`);
    await tab.close();
  }
} finally {
  await browser.close();
  rmSync(tmp, { recursive: true, force: true });
}
