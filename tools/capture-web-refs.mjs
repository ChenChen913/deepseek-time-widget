// 把审查台里每个方案的原始设计稿「卡片本体」单独截出来，作为「以网页为准」的参照图。
// 用法：在仓库根目录执行 node tools/capture-web-refs.mjs，并确保已安装 playwright。
// 可用 PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH 指定 Chromium 路径，未指定时使用 playwright 默认浏览器。
import { chromium } from 'playwright';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const WEB = path.join(ROOT, 'design/_states/web');
const manifest = JSON.parse(fs.readFileSync(path.join(ROOT, 'design/_states/manifest.json'), 'utf8'));

// 每份设计稿里「卡片本体」的类名都不一样，逐个指定
const CARD_SEL = {
  live: '.card',
  do: '.widget',
  v2: '.w',
  v3: '.w',
  v4: '.w',
  code01: '.widgets-grid > div',
  code02: 'div[class^="w-"]',
  code03: '.w-osci',
};

const executablePath = process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH;
const browser = await chromium.launch({
  ...(executablePath ? { executablePath } : {}),
  args: ['--hide-scrollbars'],
});
const ctx = await browser.newContext({ deviceScaleFactor: 2, viewport: { width: 1440, height: 1000 } });
const page = await ctx.newPage();

let ok = 0;
const fail = [];
for (const it of manifest) {
  const file = path.join(WEB, it.key + '.html');
  if (!fs.existsSync(file)) { fail.push(it.num + ' (no doc)'); continue; }
  await page.goto('file:///' + file.replace(/\\/g, '/'));
  await page.waitForTimeout(300);
  const section = it.target.id
    ? page.locator('#' + it.target.id).first()
    : page.locator(it.target.sel).nth(it.target.idx || 0);
  try {
    await section.scrollIntoViewIfNeeded({ timeout: 5000 });
    await page.waitForTimeout(150);
    const card = section.locator(CARD_SEL[it.key]).first();
    const out = path.join(WEB, 'ref-' + it.num + '.png');
    await card.screenshot({ path: out });
    const box = await card.boundingBox();
    console.log('OK  ' + it.num + '  ' + Math.round(box.width) + 'x' + Math.round(box.height));
    ok++;
  } catch (e) {
    fail.push(it.num + ' (' + e.message.split('\n')[0] + ')');
  }
}
console.log('---- ok=' + ok + ' fail=' + fail.length);
fail.forEach(f => console.log('FAIL ' + f));
await browser.close();
