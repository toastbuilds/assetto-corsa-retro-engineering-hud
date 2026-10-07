"""Coverage checklist, media catalogue, review sheets and publication ZIP."""
from pathlib import Path
import hashlib,importlib.util,json,os,zipfile
from PIL import Image,ImageChops
spec=importlib.util.spec_from_file_location('promo_generate_report',Path(__file__).with_name('generate.py'))
g=importlib.util.module_from_spec(spec);spec.loader.exec_module(g)

def main():
    os.chdir(g.ROOT); out=g.OUT
    stills=json.loads((out/'stills-manifest.json').read_text())
    motion=json.loads((out/'motion-manifest.json').read_text())
    expected=['dial_analog','dial_digital','gt7_analog','gt7_digital','tachometer_analog','tachometer_digital',
        'speedometer_analog','speedometer_digital','turbo_analog','turbo_digital','hybrid_analog','hybrid_digital',
        'hybrid_standalone','hybrid_battery_recovery','aero_analog','aero_digital','grip_limit','ffb','fuel_slosh',
        'backlighting_analog','backlighting_digital','controls_radar_flags','analog_digital_transition',
        'condition_temperature','relative','leaderboard','map','delta','timer','laps','telemetry',
        'timer_result_transition','laps_transition','delta_notifications','map_offtrack','gt7_modern','gt7_outer_pedals','gt7_steering_dial']
    for name in expected:
        assert (out/f'videos/{name}.mp4').is_file(),name
        assert (out/f'gifs/{name}.gif').is_file(),name
    for group in 'abcd':
        for i in range(1,7): assert (out/f'needles/individual/{group}{i:02d}.png').is_file()
    for r in stills: assert (out/r['path']).is_file(),r
    inv=out/'INVENTORY.md'; text=inv.read_text(encoding='utf8').replace('[ ]','[x]')
    suffix='\n## Validación de cobertura ejecutada\n\n'
    if suffix in text:text=text.split(suffix)[0]
    text+=suffix+'Todas las filas tienen PNG y una demostración correspondiente del comportamiento dinámico. Las 24 agujas seleccionables se verificaron frente al catálogo Lua; la miniaguja fija se documenta por separado. `media-index.json` lista cada archivo real; `validation/results.json` registra la decodificación completa. Las variantes discretas y los extremos de ajustes continuos están cubiertos sin generar todas sus combinaciones.\n\nLimitaciones: simulación fuera de CSP; AA/fuentes son una aproximación del backend. Las referencias de Condition marcadas ~ son estimadas. Relojes, vueltas y gráficos de historial siguen avanzando: esas demos se repiten con un reinicio de datos visible. No se afirma que sus loops sean perfectos. No hay un navegador conectado para certificar playback visual en un reproductor; se decodifican todos los frames y se revisan contact sheets.\n'
    inv.write_text(text,encoding='utf8')
    meta={r['path']:r for r in stills}; entries=[]
    for folder in ('instruments','needles','lighting','overview'):
        for path in sorted((out/folder).rglob('*.png')):
            im=Image.open(path); rel=path.relative_to(out).as_posix()
            assert min(im.size)>=1024,(rel,im.size)
            entries.append(dict(path=rel,type='PNG',width=im.width,height=im.height,mode=im.mode,
                instrument=meta.get(rel,{}).get('instrument',path.stem),bytes=path.stat().st_size,
                sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    for record in motion:
        for pathkey,typ,fps in [('path','MP4',60),('gif','GIF',30)]:
            path=out/record[pathkey]
            entries.append(dict(path=record[pathkey],type=typ,width=1920 if typ=='MP4' else 960,height=1080 if typ=='MP4' else 540,
                duration=8,fps=fps,instrument=path.stem,bytes=path.stat().st_size,sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
    (out/'media-index.json').write_text(json.dumps(entries,indent=2),encoding='utf8')
    counts={t:sum(r['type']==t for r in entries) for t in ('PNG','GIF','MP4')}
    readme=f'''# Retro HUD — paquete promocional

{counts['PNG']} PNG, {counts['GIF']} GIF y {counts['MP4']} MP4 generados ejecutando los componentes Lua actuales. Fondo uniforme #121416, vista frontal, sin cursor ni interfaz de desarrollo en los medios. No se ha modificado ningún archivo de producto: `source-audit.json` conserva los hashes de src/, ui/, modules/ y assets/.

## Imágenes recomendadas para la publicación

1. `overview/all_instruments.png`: colección general, 3840 px de ancho.
2. `overview/driving_instruments.png`: conducción, modos y auxiliares, 3840 px.
3. `overview/analog_instruments.png`: los cuatro presets GT7, dial analógico e instrumentos auxiliares.
4. `overview/digital_instruments.png`: variantes digitales y widgets de carrera.
5. `needles/needles_overview.png`: las 24 agujas A01–D06, mismo dial, 5200 RPM, escala e iluminación; miniaguja fija aparte al pie; 3840 px.
6. `overview/lighting_comparison.png`: Analog/Digital, luces OFF/ON, 3840 px.
7. `instruments/comparisons/tachometer_analog_vs_digital.png`: información equivalente, 2560 px.
8. `instruments/analog/gt7_steering_dial.png`: preset Steering Dial completo.
9. `gifs/tachometer_analog.gif`: ralentí, aceleración, warning/redline, cambio y desaceleración.
10. `gifs/hybrid_analog.gif`: regeneración, cero y entrega eléctrica.

Para galerías que admitan video, preferir los MP4 homónimos. `videos/controls_radar_flags.mp4`, `videos/backlighting_analog.mp4` y `videos/analog_digital_transition.mp4` explican controles, iluminación y cambio de modo directamente.

## Estructura

| Carpeta / archivo | Contenido |
|---|---|
| INVENTORY.md | Inventario, opciones auditadas y checklist |
| instruments/analog, digital | Dial, GT7 con todos sus presets; velocidad/fuel, RPM/turbo/híbrido/AERO; Condition, Relative, Leaderboard, Map, Delta, Timer, Laps, Telemetry |
| instruments/variants | Composición GT7, radar, flags, pedales, estados, escalas y panel inferior |
| instruments/comparisons | Mismos valores en Analog/Digital; modos mixtos |
| instruments/transparent | RGBA del dial y GT7 con sus superficies semitransparentes originales |
| needles/individual | 24 principales más `subNeedle.png`, miniaguja fija fuel/boost no seleccionable |
| lighting | Pares lights_off/on, ambos temas y modos; indicador oculto y flasher |
| gifs | Previews de 8 s, 960×540, 30 FPS, loop infinito; entre ~0,12 y ~2,65 MB |
| videos | H.264 MP4, 1920×1080, 60 FPS, 8 s, sin audio; CRF 17 y faststart |
| overview | Láminas generales a 3840 px, lecturas Condition a 2560 px |
| validation | Contact sheets y resultados de decodificación; material de revisión |
| media-index.json | Catálogo de TODOS los medios, tamaños, resolución, duración, FPS y SHA-256 |
| stills-manifest.json, motion-manifest.json | Instrumento, configuración y muestras reales de estado |
| scripts | Harness, recorder, simulación, render/export, checks y empaquetado |
| review.html | Galería para reproducción local; sus controles no aparecen en los medios |

Los individuales aproximadamente cuadrados tienen al menos 1024 px más margen; la escala siempre es uniforme. Las resoluciones exactas están en el catálogo. Se rasterizan las llamadas vectoriales a 3–6× para PNG y 2–4× para video antes de reducir. No se usa una imagen de referencia ni se reimplementan diales en HTML/SVG. Pillow sólo reproduce las primitivas registradas por el Lua real. Font regular/bold usa Consolas instalada.

## Regenerar

Desde la raíz del repositorio, con Python 3, Consolas, FFmpeg y dependencias instaladas. Entorno utilizado: Windows, Python 3.14, Pillow 12.3.0, Lupa 2.8 y NumPy 2.5.2:

```powershell
python -m pip install -r promo/scripts/requirements.txt
powershell -ExecutionPolicy Bypass -File promo/scripts/generate-promo-assets.ps1
```

`-StillsOnly` regenera PNG; `-MotionOnly` regenera movimiento. FFmpeg se busca en PATH y, en este workspace, en la instalación existente de `ffmpeg-static`. No se necesita red, CSP ni Assetto Corsa para regenerar: `scripts/track.json` congela el trazado local de Daytona; su origen figura en `track-source.json`.

```powershell
python promo/scripts/generate.py --inventory --stills --extras
python promo/scripts/coverage.py
python promo/scripts/refresh-sheets.py
python promo/scripts/generate.py --motion
python promo/scripts/generate.py --motion --shot tachometer_analog
python promo/scripts/generate.py --validate
python promo/scripts/report.py
```

Las exportaciones por `--shot` conservan las demás entradas del manifest. Para nuevos instrumentos, añadir el renderer/fixture al registro de `stills`, `extras`/`coverage` y `shots`, además de la fila de inventario. Los módulos de producto se cargan desde el repositorio en cada ejecución.

## Simulación y fidelidad

Se reutilizan `tools/preview-instruments.py` y `tests/gt7_layouts.lua`, con Lupa Lua 5.2. `scripts/panels.lua` adapta sólo APIs CSP: registra primitivas, clips, alfa y fuentes; ejecuta los widgets actuales. `src/telemetry.lua`, `src/instrument_state.lua` y `src/hybrid.lua` controlan suavizado, slosh, warnings y transiciones. Los inputs de coche son ficticios y deterministas; no pertenecen a una sesión ni a footage real.

La secuencia principal dura ocho segundos: 1600→7900 RPM, cambio 2→3, caída a 5100, nueva aceleración y frenada hasta el estado inicial. El SOC medido se mantiene al 70%; el clip de recuperación de batería muestra el fallback real de porcentaje por segundo. AERO conserva la distinción entre estimación visual, CL medido y fuerza inferida. El combustible varía con aceleraciones en G, sin vaciar un tanque en segundos. Las temperaturas de la demo cambian sólo ±2 °C.

La transición de luces usa los 220 ms originales y el cambio de modo los 150 ms originales. No se altera exposición, geometría, colores, tipografía, layout ni parámetros mecánicos del HUD. Las pruebas existentes de instrumentos, iluminación, híbridos, Condition y cronometraje pasaron.

## Validación y límites

Todos los PNG se abren/verifican; todos los GIF se decodifican frame por frame; todos los MP4 se decodifican completos, comprobando 480 frames por clip. Contact sheets permiten revisar inicio, puntos intermedios y final. La comprobación SHA-256 verifica que el producto permaneció intacto.

El antialiasing y el rasterizado de fuentes no son idénticos al backend de CSP: son renders offline del Lua original, no capturas certificadas dentro del juego. No hubo navegador conectado disponible para reproducirlos visualmente mediante esa herramienta; se incluye `review.html` para playback local y se revisaron secuencias decodificadas. Los instrumentos de conducción estabilizan el comienzo/final. Relojes, posiciones y trazas de historial requieren un reinicio al repetir; no se promete loop invisible en esas demos. La escala de turbo aprende el máximo observado y puede conservar una etiqueta distinta al final del primer ciclo: es el comportamiento real del HUD.

Condition muestra referencias estimadas y stint observado cuando el mock no proporciona datos físicos de compuesto previos. `ISSUES.md` conserva la incidencia original de ABS, corregida en 2.5.1; su clip digital se regeneró después del arreglo. También documenta las limitaciones del backend.

Para abrir la galería: `python -m http.server 8766 --bind 127.0.0.1 --directory promo`, y visitar `http://127.0.0.1:8766/review.html`.

## Catálogo por archivo

La tabla siguiente identifica cada medio publicable. Los grupos y valores están también en los manifests.

| Archivo | Instrumento / variante | Resolución | Duración / FPS |
|---|---|---|---|
'''
    for e in entries:
        duration=f'8 s / {e["fps"]} FPS' if e['type']!='PNG' else '—'
        readme+=f'| [{e["path"]}]({e["path"]}) | {e["instrument"]} | {e["width"]}×{e["height"]} | {duration} |\n'
    (out/'README.md').write_text(readme,encoding='utf8')
    # Review all static outputs in paged contact sheets.
    pngs=[out/e['path'] for e in entries if e['type']=='PNG']
    for start in range(0,len(pngs),20):
        batch=[]
        for p in pngs[start:start+20]:
            im=Image.open(p).convert('RGBA')
            bg=Image.new('RGBA',im.size,g.BG);bg.alpha_composite(im)
            batch.append((p.stem,bg.convert('RGB')))
        g.sheet(batch,out/f'validation/stills_{start//20+1:02d}.png',4,2560)
    package=out/'Retro-HUD-promo.zip'
    included=[out/e['path'] for e in entries]
    included += [out/f for f in ('README.md','INVENTORY.md','ISSUES.md','media-index.json','motion-manifest.json','stills-manifest.json','source-audit.json','review.html')]
    included += [out/'validation/results.json']
    included += [p for p in (out/'scripts').iterdir() if p.is_file() and p.suffix in ('.py','.lua','.ps1','.json','.txt') and p.name!='legacy-source-reference.json']
    with zipfile.ZipFile(package,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
        for path in sorted(set(included)):archive.write(path,path.relative_to(out))
    with zipfile.ZipFile(package) as archive:
        assert archive.testzip() is None,'ZIP CRC failure'
        for entry in entries:
            assert hashlib.sha256(archive.read(entry['path'])).hexdigest()==entry['sha256'],entry['path']
    print(json.dumps(dict(counts=counts,zipBytes=package.stat().st_size,zip=str(package)),indent=2))

if __name__=='__main__':main()
