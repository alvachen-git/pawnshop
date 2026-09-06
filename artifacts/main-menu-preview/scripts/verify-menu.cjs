const path = require('node:path');
const fs = require('node:fs/promises');
const assert = require('node:assert/strict');
const runtimeModules = process.argv[2];
const { chromium } = require(path.join(runtimeModules, 'playwright'));
const sharp = require(path.join(runtimeModules, 'sharp'));

(async () => {
  const out = path.resolve('verification');
  await fs.mkdir(out, { recursive: true });
  const browser = await chromium.launch({ headless: true, executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe' });
  const page = await browser.newPage({ viewport: { width: 1672, height: 941 }, deviceScaleFactor: 1 });
  const errors = [];
  const failures = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('console', message => { if (message.type() === 'error') errors.push(message.text()); });
  page.on('requestfailed', request => errors.push(request.url()));
  const checks = [];
  try {
    await page.goto('http://127.0.0.1:4173/', { waitUntil: 'networkidle' });
    await page.locator('.menu-scene.is-ready').waitFor();
    await page.screenshot({ path: path.join(out, 'idle.png') });
    assert.equal(await page.getByRole('button').count(), 3);
    for (const label of ['开启新游戏', '读取游戏', '离开游戏']) assert.equal(await page.getByRole('button', { name: label, exact: true }).count(), 1);
    checks.push('All three Chinese menu buttons are visible and accessible.');
    const restingPlaques = await page.locator('.plaque').evaluateAll(els => els.map(el => ({color:getComputedStyle(el).backgroundColor,filter:getComputedStyle(el).filter})));
    assert.deepEqual(restingPlaques[0], restingPlaques[1], 'New game must not have a permanently red resting style.');
    await page.evaluate(() => { window.testActions = []; window.addEventListener('pawnbroker:menu-action', e => window.testActions.push(e.detail.action)); });
    const scene = page.locator('.menu-scene');
    const geometry = await page.getByRole('button').evaluateAll(buttons => buttons.map(b => { const r = b.getBoundingClientRect(); return { label: b.getAttribute('aria-label'), x:r.x, y:r.y, width:r.width, height:r.height }; }));
    for (const [index, id] of ['new', 'load', 'exit'].entries()) {
      const button = page.locator(`[data-action="${id}"]`);
      const idleColor = await button.locator('.plaque').evaluate(el => getComputedStyle(el).backgroundColor);
      await button.hover();
      await page.waitForTimeout(850);
      assert.equal(await scene.getAttribute('data-active'), id);
      const motion = await button.evaluate(el => ({ transform:getComputedStyle(el).transform, animation:getComputedStyle(el.querySelector('.ink-echo')).animationName }));
      assert.notEqual(motion.transform, 'none');
      assert.equal(motion.animation, 'ink-lag');
      assert.notEqual(await button.locator('.plaque').evaluate(el=>getComputedStyle(el).backgroundColor), idleColor, 'Hover changes the plaque color.');
      await page.screenshot({ path: path.join(out, `hover-${id}.png`) });
      if (index === 0) {
        const target = await button.boundingBox();
        await page.screenshot({ path: path.join(out, 'button-hover-detail.png'), clip: { x: Math.floor(target.x)-8, y: Math.floor(target.y)-8, width:Math.ceil(target.width)+16, height:Math.ceil(target.height)+20 } });
      }
      await button.click();
      assert.equal(await scene.getAttribute('data-pressed'), id);
      await page.mouse.move(1200, 850);
      await page.waitForTimeout(1400);
      if ((await scene.getAttribute('data-active')) !== '') failures.push(`Pointer leave after clicking ${id} did not restore idle.`);
      assert.equal(await scene.getAttribute('data-pressed'), '');
      assert.equal(await button.locator('.plaque').evaluate(el=>getComputedStyle(el).backgroundColor), idleColor, 'Pointer leave restores the actual plaque color.');
    }
    checks.push('Each hover has ink echo, plaque movement and a click response.');
    assert.deepEqual(await page.evaluate(() => window.testActions), ['new', 'load', 'exit']);
    await page.keyboard.press('Escape');
    await page.getByRole('button', {name:'开启新游戏',exact:true}).focus();
    await page.keyboard.press('ArrowDown');
    assert.equal(await page.evaluate(() => document.activeElement.dataset.action), 'load');
    await page.keyboard.press('End');
    assert.equal(await page.evaluate(() => document.activeElement.dataset.action), 'exit');
    await page.keyboard.press('Home');
    assert.equal(await page.evaluate(() => document.activeElement.dataset.action), 'new');
    await page.screenshot({path:path.join(out,'keyboard-focus.png')});
    await page.keyboard.press('Escape');
    checks.push('Arrow keys, Home, End, Escape and accessible focus work.');
    for (const viewport of [{width:1280,height:720},{width:1024,height:768},{width:1920,height:1080}]) {
      await page.setViewportSize(viewport);
      const fits = await page.getByRole('button').evaluateAll(buttons => buttons.every(b => { const r=b.getBoundingClientRect(); return r.left>=0 && r.top>=0 && r.right<=innerWidth && r.bottom<=innerHeight && r.height>=44; }));
      assert.ok(fits, `Buttons fit at ${viewport.width}x${viewport.height}`);
      await page.screenshot({path:path.join(out,`idle-${viewport.width}.png`)});
    }
    checks.push('All controls fit at 1280x720, 1024x768 and 1920x1080 with at least 44px height.');
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.getByRole('button',{name:'读取游戏',exact:true}).hover();
    assert.equal(await page.locator('[data-action="load"] .ink-echo').evaluate(e=>getComputedStyle(e).animationName),'none');
    assert.equal(await page.locator('.door-afterimage').evaluate(e=>getComputedStyle(e).display),'none');
    checks.push('Reduced-motion preference disables movement and ink/light animations.');
    assert.deepEqual(errors, []);
    const src=await sharp('references/refined-menu.png').resize(1672,941,{fit:'fill'}).toBuffer();
    const impl=await sharp(path.join(out,'hover-new.png')).toBuffer();
    await sharp({create:{width:3344,height:941,channels:3,background:'#090908'}}).composite([{input:src,left:0,top:0},{input:impl,left:1672,top:0}]).png().toFile(path.join(out,'comparison-full.png'));
    const srcDetail=await sharp(src).extract({left:55,top:505,width:555,height:365}).toBuffer();
    const implDetail=await sharp(impl).extract({left:55,top:505,width:555,height:365}).toBuffer();
    await sharp({create:{width:1110,height:365,channels:3,background:'#090908'}}).composite([{input:srcDetail,left:0,top:0},{input:implDetail,left:555,top:0}]).png().toFile(path.join(out,'comparison-buttons.png'));
    await fs.writeFile(path.join(out,'results.json'),JSON.stringify({checks,failures,consoleErrors:errors,geometry},null,2));
    console.log(JSON.stringify({checks,failures,consoleErrors:errors,geometry},null,2));
    if(failures.length) process.exitCode=1;
  } finally { await browser.close(); }
})().catch(e=>{ console.error(e); process.exitCode=1; });
