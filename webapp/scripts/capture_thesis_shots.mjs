// Capture the four thesis screenshots that show profiler variables, from the
// live Vercel deployment, after the human-readable-label UI change.
//
//   a. "Map your columns" wizard  -> split into top/bottom at the 5th|6th var
//   b. "Sample-skew check" panel  -> webapp_07_sample_skew_ks.png
//   c. "Moderate Isolated" dossier -> webapp_11_drilldown_moderate_isolated.png
//
// Viewport 1280x900 @ DPR 2 so each max-w-4xl card is 896 CSS px = 1792 device
// px wide. Heights are left free (we do NOT crop content to match the old PNGs).
//
//   node scripts/capture_thesis_shots.mjs [outDir]
//
// Default outDir: /tmp/thesis_shots

import puppeteer from 'puppeteer';
import sharp from 'sharp';
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';

const URL = 'https://invisible-profiles.vercel.app/?section=profiler';
const DPR = 2;
const OUT = process.argv[2] || '/tmp/thesis_shots';
mkdirSync(OUT, { recursive: true });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function clickByText(page, selector, text) {
  const handle = await page.evaluateHandle(
    (sel, t) => {
      const els = [...document.querySelectorAll(sel)];
      return els.find((e) => (e.textContent || '').includes(t)) || null;
    },
    selector,
    text,
  );
  const el = handle.asElement();
  if (!el) throw new Error(`clickByText: no <${selector}> containing "${text}"`);
  await el.click();
  return el;
}

async function waitForText(page, selector, text, timeout = 20000) {
  await page.waitForFunction(
    (sel, t) =>
      [...document.querySelectorAll(sel)].some((e) =>
        (e.textContent || '').includes(t),
      ),
    { timeout },
    selector,
    text,
  );
}

async function shotWidth(file) {
  const m = await sharp(file).metadata();
  return `${m.width}x${m.height}`;
}

// Stop the sticky <nav> from overlapping the top of a card when element
// .screenshot() scrolls it into view.
async function neutralizeNav(page) {
  await page.evaluate(() => {
    document.querySelectorAll('nav').forEach((n) => {
      if (getComputedStyle(n).position === 'sticky') n.style.position = 'static';
    });
  });
}

const browser = await puppeteer.launch({
  headless: true,
  args: ['--no-sandbox', '--force-device-scale-factor=2'],
});
try {
  const page = await browser.newPage();
  await page.setViewport({ width: 1280, height: 900, deviceScaleFactor: DPR });
  await page.goto(URL, { waitUntil: 'networkidle2', timeout: 45000 });

  // Mode picker -> batch -> Italy
  await waitForText(page, 'button', 'Cohort upload');
  await clickByText(page, 'button', 'Cohort upload'); // selects batch ModeCard
  await sleep(200);
  await clickByText(page, 'button', 'Score against Italy');

  // Drop zone -> load the 30-row sample
  await waitForText(page, 'button', 'Try with sample data');
  await clickByText(page, 'button', 'Try with sample data');

  // Mapping card + pre-flight render
  await page.waitForSelector('[data-card="mapping"]', { timeout: 20000 });
  await page.waitForSelector('[data-varrow="sn_size_w9"]', { timeout: 20000 });
  await sleep(1500); // let the KS pre-flight memo settle
  await neutralizeNav(page);

  // (a) wizard card -> full element shot. Per the sub-captions ("first five"
  // / "remaining five variables") the two panels cover the ten variable rows:
  // top = coverage meter + rows 1-5, bottom = rows 6-10 (the trailing
  // missing-values / pre-flight / score block is excluded — the pre-flight is
  // captured separately as its own figure).
  const rects = await page.evaluate(() => {
    const card = document.querySelector('[data-card="mapping"]');
    const row6 = document.querySelector('[data-varrow="sn_size_w9"]');
    const row10 = document.querySelector('[data-varrow="hope_future"]');
    const c = card.getBoundingClientRect();
    return {
      cardTop: c.top,
      row6Top: row6.getBoundingClientRect().top,
      row10Bottom: row10.getBoundingClientRect().bottom,
    };
  });
  const cardHandle = await page.$('[data-card="mapping"]');
  const cardBuf = await cardHandle.screenshot({ type: 'png' });
  const meta = await sharp(cardBuf).metadata();
  const PAD = 14; // CSS px of breathing room under the last row
  const splitY = Math.round((rects.row6Top - rects.cardTop) * DPR);
  const bottomEnd = Math.min(
    meta.height,
    Math.round((rects.row10Bottom - rects.cardTop + PAD) * DPR),
  );
  await sharp(cardBuf)
    .extract({ left: 0, top: 0, width: meta.width, height: splitY })
    .toFile(join(OUT, 'webapp_06_mapping_wizard_top.png'));
  await sharp(cardBuf)
    .extract({
      left: 0,
      top: splitY,
      width: meta.width,
      height: bottomEnd - splitY,
    })
    .toFile(join(OUT, 'webapp_06_mapping_wizard_bottom.png'));

  // (b) sample-skew panel — capture at full card width (896 CSS = 1792 px) so it
  // matches the established figure width; the panel itself is inset by the card
  // padding, so we clip to the card's horizontal bounds around it.
  const ksRect = await page.evaluate(() => {
    const card = document.querySelector('[data-card="mapping"]');
    const panel = document.querySelector('[data-panel="sample-skew"]');
    if (!panel) return null;
    const c = card.getBoundingClientRect();
    const p = panel.getBoundingClientRect();
    const pad = 16; // CSS px of breathing room above/below
    return {
      x: c.left + window.scrollX,
      y: p.top + window.scrollY - pad,
      width: c.width,
      height: p.height + pad * 2,
    };
  });
  if (!ksRect) throw new Error('sample-skew panel not present (no KS warnings?)');
  await page.screenshot({
    path: join(OUT, 'webapp_07_sample_skew_ks.png'),
    type: 'png',
    clip: ksRect,
    captureBeyondViewport: true,
  });

  // (c) score the cohort -> open the Moderate Isolated dossier
  await clickByText(page, 'button', 'Score 30 rows');
  await waitForText(page, 'button', 'Moderate Isolated');
  await clickByText(page, 'button', 'Moderate Isolated');
  await page.waitForSelector('[data-card="dossier"]', { timeout: 20000 });
  await neutralizeNav(page);
  await sleep(800);
  const dossier = await page.$('[data-card="dossier"]');
  await dossier.screenshot({
    path: join(OUT, 'webapp_11_drilldown_moderate_isolated.png'),
    type: 'png',
  });

  // Report dimensions
  for (const f of [
    'webapp_06_mapping_wizard_top.png',
    'webapp_06_mapping_wizard_bottom.png',
    'webapp_07_sample_skew_ks.png',
    'webapp_11_drilldown_moderate_isolated.png',
  ]) {
    console.log(`${f}: ${await shotWidth(join(OUT, f))}`);
  }
  console.log(`OUT: ${OUT}`);
} finally {
  await browser.close();
}
