// Renders the DMG installer background from scripts/dmg-background/background.html
// into Resources/dmg/background.png (660x420) and background@2x.png (1320x840).
// scripts/build-dmg.sh combines the two into the TIFF Finder shows.
//
// Usage: node scripts/render-dmg-background.mjs [--preview]
//   --preview also writes .build/dmg-preview.png with the two icons in place.
// Needs Playwright with Chromium (npm i -D playwright && npx playwright install chromium).
//
// The Grainient gradient moves over time, so each run gives a slightly
// different frame: look at the result before committing it.

import { chromium } from 'playwright';
import { mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const page = pathToFileURL(join(root, 'scripts/dmg-background/background.html')).href;
// Long enough for the gradient's intro to settle into its warm colours.
const SETTLE_MS = 6000;

const shots = [
  { scale: 1, hash: '', out: 'Resources/dmg/background.png' },
  { scale: 2, hash: '', out: 'Resources/dmg/background@2x.png' },
];
if (process.argv.includes('--preview')) {
  shots.push({ scale: 2, hash: '#icons', out: '.build/dmg-preview.png' });
}

// Software WebGL, so it also works on machines without a GPU.
const browser = await chromium.launch({
  args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'],
});
try {
  for (const { scale, hash, out } of shots) {
    const tab = await browser.newPage({ viewport: { width: 660, height: 420 }, deviceScaleFactor: scale });
    await tab.goto(page + hash);
    await tab.waitForTimeout(SETTLE_MS);
    const live = await tab.evaluate(() => document.querySelector('.grainient').classList.contains('is-live'));
    if (!live) throw new Error('the gradient did not start (no WebGL 2?)');
    mkdirSync(dirname(join(root, out)), { recursive: true });
    await tab.locator('#bg').screenshot({ path: join(root, out) });
    console.log(`Wrote ${out}`);
    await tab.close();
  }
} finally {
  await browser.close();
}
