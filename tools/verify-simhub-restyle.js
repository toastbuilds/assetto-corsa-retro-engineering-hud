async page => {
  const browserErrors = [];
  const failedRequests = [];
  page.on('pageerror', error => browserErrors.push(error.message));
  page.on('requestfailed', request => failedRequests.push({url: request.url(), error: request.failure()?.errorText}));
  await page.waitForSelector('.screen[data-name="Startup"]', {state: 'attached'});
  await page.evaluate(() => {
    const style = document.createElement('style');
    style.id = 'verification-preview-style';
    style.textContent = '.verification-hide-flags [data-name^="race_flag_"] { visibility: hidden !important; } .verification-manual-pages .screen { display: none !important; } .verification-manual-pages .screen.verification-active { display: block !important; }';
    document.head.appendChild(style);
    document.body.classList.add('verification-manual-pages');
  });
  const reports = [];
  for (const screenName of ['Startup', 'Engineering', 'Strategy', 'Awareness']) {
    if (screenName !== 'Startup') {
      await page.evaluate(() => document.body.classList.remove('verification-manual-pages'));
      for (let attempt = 0; attempt < 4; attempt++) {
        const currentScreen = await page.evaluate(() => Array.from(document.querySelectorAll('.screen')).find(element => getComputedStyle(element).display !== 'none')?.dataset.name);
        if (currentScreen === screenName) break;
        await page.getByRole('cell', {name: 'Next page', exact: true}).click();
        await page.waitForFunction(previous => Array.from(document.querySelectorAll('.screen')).find(element => getComputedStyle(element).display !== 'none')?.dataset.name !== previous, currentScreen);
      }
      await page.waitForFunction(name => {
        const value = document.querySelector('.screen[data-name="' + name + '"] [data-name="session_value"]');
        return value && value.textContent.trim() !== '--';
      }, screenName);
    }
    await page.evaluate(name => {
      for (const element of document.querySelectorAll('.screen')) {
        element.classList.toggle('verification-active', element.dataset.name === name);
      }
    }, screenName);
    const screen = page.locator('.screen[data-name="' + screenName + '"]:visible');
    await screen.waitFor({state: 'visible'});
    if (screenName === 'Engineering') {
      for (const name of ['fuel_arc', 'rpm_arc']) {
        if (await screen.locator('[data-name="' + name + '"]').isVisible()) {
          throw new Error('Duplicate continuous dial fill: ' + name);
        }
      }
      for (const name of ['retro_ui_fuel_digital', 'retro_ui_rpm_digital']) {
        if (await screen.locator('[data-name="' + name + '"]').count() !== 1) {
          throw new Error('Duplicate digital dial layer: ' + name);
        }
      }
    }
    await page.waitForFunction(() => Array.from(document.querySelectorAll('.screen:not([style*="display: none"]) [data-name]')).every(element => {
      const source = element.SourceItem;
      if (!source?.Image) return true;
      return Array.from(element.querySelectorAll('img')).every(image => image.complete && image.naturalWidth > 0);
    }));
    const menu = page.locator('#controls2');
    await menu.evaluate(element => { element.style.visibility = 'hidden'; });
    await page.screenshot({path: 'output/simhub/after/' + screenName.toLowerCase() + '-live.png'});
    await page.evaluate(() => document.body.classList.add('verification-hide-flags'));
    await page.screenshot({path: 'output/simhub/after/' + screenName.toLowerCase() + '.png'});
    const report = await screen.evaluate(element => {
      const components = Array.from(element.querySelectorAll('.dash-item[data-name]'));
      const images = components.filter(component => component.SourceItem?.Image);
      const liveComponents = components.filter(component => !component.dataset.name.startsWith('retro_ui_'));
      const readings = components.filter(component => /^(fuel_liters|rpm_value|throttle_value|brake_value|tyre_[A-Z]+_wear|rel_name_4|s_fuel_value|pit_count_value|sector_S1_cur)$/.test(component.dataset.name)).map(component => ({name: component.dataset.name, value: component.textContent.trim()}));
      return {screen: element.dataset.name, width: element.offsetWidth, height: element.offsetHeight,
        components: components.length, liveComponents: liveComponents.length, imageComponents: images.length,
        loadedImages: images.filter(component => component.querySelector('img')?.naturalWidth > 0 || getComputedStyle(component.firstElementChild || component).backgroundImage !== 'none').length,
        flagComponents: components.filter(component => component.dataset.name.startsWith('race_flag_')).length,
        readings};
    });
    const expectedOriginalCounts = {Startup: 4, Engineering: 237, Strategy: 195, Awareness: 185};
    if (report.width !== 852 || report.height !== 639 ||
        report.loadedImages !== report.imageComponents ||
        report.liveComponents !== expectedOriginalCounts[screenName]) {
      throw new Error('Invalid native rendering: ' + JSON.stringify(report));
    }
    reports.push(report);
    await page.evaluate(() => document.body.classList.remove('verification-hide-flags'));
    await menu.evaluate(element => { element.style.visibility = ''; });
  }
  await page.evaluate(() => {
    document.body.classList.remove('verification-manual-pages');
    for (const element of document.querySelectorAll('.screen')) {
      element.classList.remove('verification-active');
    }
    document.getElementById('verification-preview-style')?.remove();
  });
  if (browserErrors.length || failedRequests.length) {
    throw new Error(JSON.stringify({browserErrors, failedRequests}));
  }
  return {screens: reports, browserErrors, failedRequests};
}
