async page => {
  const result = await page.evaluate(async () => {
    const name = decodeURIComponent(GetCurrentTemplate());
    const endpoint = '/Dashtemplates/Definition/?dash=' + encodeURIComponent(name) + '&widget=' + encodeURIComponent(name + '.djson');
    const definition = await (await fetch(endpoint)).json();
    const original = document.querySelector('.screen[data-name="Engineering"]');
    const preview = original.cloneNode(true);
    preview.id = 'digital-dial-verification-preview';
    preview.style.cssText += ';display:block!important;position:absolute;left:0;top:0;z-index:10000';
    preview.querySelector('#controls2')?.remove();
    for (const element of preview.querySelectorAll('[id], [data-uid]')) {
      element.removeAttribute('id');
      element.removeAttribute('data-uid');
    }
    for (const element of preview.querySelectorAll('[data-name^="race_flag_"], [data-name="fuel_low_pulse"], [data-name="fuel_low_text"], [data-name="rpm_redline_pulse"]')) {
      element.style.visibility = 'hidden';
    }
    const states = {fuel: 75, rpm: 90};
    const reports = [];
    for (const [role, percent] of Object.entries(states)) {
      const name = 'retro_ui_' + role + '_digital_' + percent;
      const image = definition.Images.find(image => image.Name === name);
      if (!image) throw new Error('Missing digital frame: ' + name);
      image.Uid = 'digital_verification_' + role;
      createImageStyle(image.Uid, image.Data, image.WebPath);
      const component = preview.querySelector('[data-name="retro_ui_' + role + '_digital"]');
      SetImage($(component.firstElementChild), name, definition);
      preview.querySelector('[data-name="' + role + '_needle"]').style.transform = 'rotate(' + ((role === 'fuel' ? -135 : -105) + percent * 2.7) + 'deg)';
      preview.querySelector('[data-name="' + (role === 'fuel' ? 'fuel_liters' : 'rpm_value') + '"]').firstElementChild.textContent = percent + '%';
      preview.querySelector('[data-name="' + (role === 'fuel' ? 'fuel_l_unit' : 'rpm_unit') + '"]').firstElementChild.textContent = 'PRUEBA';
      reports.push({role, percent, image: name, imageClass: component.firstElementChild.className});
    }
    const banner = document.createElement('div');
    banner.textContent = 'PRUEBA VISUAL LOCAL · FUEL 75% · RPM 90% · SIN CAMBIAR LA TELEMETRÍA';
    banner.style.cssText = 'position:absolute;left:18px;top:8px;width:814px;height:38px;display:grid;place-items:center;background:#15110d;color:#f2dbae;font:12px Consolas;z-index:10001';
    preview.appendChild(banner);
    document.querySelector('#d').appendChild(preview);
    return reports;
  });
  const controls = page.locator('#controls2');
  await controls.evaluate(element => { element.style.visibility = 'hidden'; });
  try {
    await page.locator('#digital-dial-verification-preview').screenshot({path: 'output/simhub/after/engineering-digital-demo.png'});
    return {simulatedPreviewOnly: true, states: result};
  } finally {
    await page.evaluate(() => document.getElementById('digital-dial-verification-preview')?.remove());
    await controls.evaluate(element => { element.style.visibility = ''; });
  }
}
