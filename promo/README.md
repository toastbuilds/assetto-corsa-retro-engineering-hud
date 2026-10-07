# Retro HUD — paquete promocional

317 PNG, 38 GIF y 38 MP4 generados ejecutando los componentes Lua actuales. Fondo uniforme #121416, vista frontal, sin cursor ni interfaz de desarrollo en los medios. No se ha modificado ningún archivo de producto: `source-audit.json` conserva los hashes de src/, ui/, modules/ y assets/.

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
| [instruments/analog/aero_coefficient.png](instruments/analog/aero_coefficient.png) | AERO | 1166×1190 | — |
| [instruments/analog/aero_downforce.png](instruments/analog/aero_downforce.png) | AERO | 1166×1190 | — |
| [instruments/analog/aero_visual_high.png](instruments/analog/aero_visual_high.png) | AERO | 1166×1190 | — |
| [instruments/analog/aero_visual_mid.png](instruments/analog/aero_visual_mid.png) | AERO | 1166×1190 | — |
| [instruments/analog/aero_visual_minimum.png](instruments/analog/aero_visual_minimum.png) | AERO | 1166×1190 | — |
| [instruments/analog/dial_aero_coefficient.png](instruments/analog/dial_aero_coefficient.png) | Dial AERO | 1166×1166 | — |
| [instruments/analog/dial_aero_downforce.png](instruments/analog/dial_aero_downforce.png) | Dial AERO kN | 1166×1166 | — |
| [instruments/analog/dial_analog.png](instruments/analog/dial_analog.png) | Dial | 1166×1166 | — |
| [instruments/analog/dial_auxiliary_auto.png](instruments/analog/dial_auxiliary_auto.png) | Dial auxiliary | 1166×1166 | — |
| [instruments/analog/dial_auxiliary_electric.png](instruments/analog/dial_auxiliary_electric.png) | Dial auxiliary | 1166×1166 | — |
| [instruments/analog/dial_auxiliary_fuel.png](instruments/analog/dial_auxiliary_fuel.png) | Dial auxiliary | 1166×1166 | — |
| [instruments/analog/dial_auxiliary_off.png](instruments/analog/dial_auxiliary_off.png) | Dial auxiliary | 1166×1166 | — |
| [instruments/analog/dial_auxiliary_turbo.png](instruments/analog/dial_auxiliary_turbo.png) | Dial auxiliary | 1166×1166 | — |
| [instruments/analog/dial_hybrid_regeneration.png](instruments/analog/dial_hybrid_regeneration.png) | Dial hybrid | 1166×1166 | — |
| [instruments/analog/dial_idle.png](instruments/analog/dial_idle.png) | Dial | 1166×1166 | — |
| [instruments/analog/dial_mid.png](instruments/analog/dial_mid.png) | Dial | 1166×1166 | — |
| [instruments/analog/dial_redline.png](instruments/analog/dial_redline.png) | Dial | 1166×1166 | — |
| [instruments/analog/dial_warning.png](instruments/analog/dial_warning.png) | Dial | 1166×1166 | — |
| [instruments/analog/gt7_classic.png](instruments/analog/gt7_classic.png) | GT7 | 3031×1106 | — |
| [instruments/analog/gt7_classic_dark_kmh.png](instruments/analog/gt7_classic_dark_kmh.png) | GT7 | 3031×1106 | — |
| [instruments/analog/gt7_classic_light_kmh.png](instruments/analog/gt7_classic_light_kmh.png) | GT7 | 3031×1106 | — |
| [instruments/analog/gt7_free_classic.png](instruments/analog/gt7_free_classic.png) | GT7 Free | 3031×1106 | — |
| [instruments/analog/gt7_modern.png](instruments/analog/gt7_modern.png) | GT7 | 3031×1106 | — |
| [instruments/analog/gt7_outer_pedals.png](instruments/analog/gt7_outer_pedals.png) | GT7 | 3277×1106 | — |
| [instruments/analog/gt7_steering_dial.png](instruments/analog/gt7_steering_dial.png) | GT7 | 3031×1106 | — |
| [instruments/analog/hybrid_ers_fallback.png](instruments/analog/hybrid_ers_fallback.png) | Hybrid | 1166×1190 | — |
| [instruments/analog/hybrid_maximum.png](instruments/analog/hybrid_maximum.png) | Hybrid | 1166×1190 | — |
| [instruments/analog/hybrid_partial.png](instruments/analog/hybrid_partial.png) | Hybrid | 1166×1190 | — |
| [instruments/analog/hybrid_regeneration.png](instruments/analog/hybrid_regeneration.png) | Hybrid | 1166×1190 | — |
| [instruments/analog/hybrid_zero.png](instruments/analog/hybrid_zero.png) | Hybrid | 1166×1190 | — |
| [instruments/analog/speedometer_high.png](instruments/analog/speedometer_high.png) | speedometer | 1166×1190 | — |
| [instruments/analog/speedometer_maximum.png](instruments/analog/speedometer_maximum.png) | speedometer | 1166×1190 | — |
| [instruments/analog/speedometer_mid.png](instruments/analog/speedometer_mid.png) | speedometer | 1166×1190 | — |
| [instruments/analog/speedometer_minimum.png](instruments/analog/speedometer_minimum.png) | speedometer | 1166×1190 | — |
| [instruments/analog/tachometer_dark.png](instruments/analog/tachometer_dark.png) | Tachometer | 1166×1190 | — |
| [instruments/analog/tachometer_high.png](instruments/analog/tachometer_high.png) | tachometer | 1166×1190 | — |
| [instruments/analog/tachometer_light.png](instruments/analog/tachometer_light.png) | Tachometer | 1166×1190 | — |
| [instruments/analog/tachometer_maximum.png](instruments/analog/tachometer_maximum.png) | tachometer | 1166×1190 | — |
| [instruments/analog/tachometer_mid.png](instruments/analog/tachometer_mid.png) | tachometer | 1166×1190 | — |
| [instruments/analog/tachometer_minimum.png](instruments/analog/tachometer_minimum.png) | tachometer | 1166×1190 | — |
| [instruments/analog/turbo_maximum.png](instruments/analog/turbo_maximum.png) | Turbo | 1166×1190 | — |
| [instruments/analog/turbo_partial.png](instruments/analog/turbo_partial.png) | Turbo | 1166×1190 | — |
| [instruments/analog/turbo_vacuum.png](instruments/analog/turbo_vacuum.png) | Turbo | 1166×1190 | — |
| [instruments/comparisons/dial_analog_vs_digital.png](instruments/comparisons/dial_analog_vs_digital.png) | dial_analog_vs_digital | 2560×1114 | — |
| [instruments/comparisons/gt7_mixed_modes.png](instruments/comparisons/gt7_mixed_modes.png) | GT7 mixed modes | 3031×1106 | — |
| [instruments/comparisons/speedometer_analog_vs_digital.png](instruments/comparisons/speedometer_analog_vs_digital.png) | speedometer_analog_vs_digital | 2560×1114 | — |
| [instruments/comparisons/tachometer_analog_vs_digital.png](instruments/comparisons/tachometer_analog_vs_digital.png) | tachometer_analog_vs_digital | 2560×1114 | — |
| [instruments/digital/aero_coefficient.png](instruments/digital/aero_coefficient.png) | AERO | 1166×1190 | — |
| [instruments/digital/aero_downforce.png](instruments/digital/aero_downforce.png) | AERO | 1166×1190 | — |
| [instruments/digital/aero_visual_high.png](instruments/digital/aero_visual_high.png) | AERO | 1166×1190 | — |
| [instruments/digital/aero_visual_mid.png](instruments/digital/aero_visual_mid.png) | AERO | 1166×1190 | — |
| [instruments/digital/aero_visual_minimum.png](instruments/digital/aero_visual_minimum.png) | AERO | 1166×1190 | — |
| [instruments/digital/condition_cold_dark.png](instruments/digital/condition_cold_dark.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_cold_light.png](instruments/digital/condition_cold_light.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_damage.png](instruments/digital/condition_damage.png) | Condition damage | 1320×1166 | — |
| [instruments/digital/condition_detail.png](instruments/digital/condition_detail.png) | Condition detail | 1287×1106 | — |
| [instruments/digital/condition_hot_dark.png](instruments/digital/condition_hot_dark.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_hot_light.png](instruments/digital/condition_hot_light.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_legend_grip_dark.png](instruments/digital/condition_legend_grip_dark.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_legend_grip_light.png](instruments/digital/condition_legend_grip_light.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_legend_none_dark.png](instruments/digital/condition_legend_none_dark.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_legend_none_light.png](instruments/digital/condition_legend_none_light.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_legend_temperature_dark.png](instruments/digital/condition_legend_temperature_dark.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_legend_temperature_light.png](instruments/digital/condition_legend_temperature_light.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_life_remaining_dark.png](instruments/digital/condition_life_remaining_dark.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_life_remaining_light.png](instruments/digital/condition_life_remaining_light.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_optimal_dark.png](instruments/digital/condition_optimal_dark.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_optimal_light.png](instruments/digital/condition_optimal_light.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_pressure_current_dark.png](instruments/digital/condition_pressure_current_dark.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_pressure_current_light.png](instruments/digital/condition_pressure_current_light.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_pressure_delta_dark.png](instruments/digital/condition_pressure_delta_dark.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_pressure_delta_light.png](instruments/digital/condition_pressure_delta_light.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_temperature_blend_dark.png](instruments/digital/condition_temperature_blend_dark.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_temperature_blend_light.png](instruments/digital/condition_temperature_blend_light.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_temperature_core_dark.png](instruments/digital/condition_temperature_core_dark.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_temperature_core_light.png](instruments/digital/condition_temperature_core_light.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_temperature_surface_dark.png](instruments/digital/condition_temperature_surface_dark.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_temperature_surface_light.png](instruments/digital/condition_temperature_surface_light.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_units_bar.png](instruments/digital/condition_units_bar.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_units_C.png](instruments/digital/condition_units_C.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_units_F.png](instruments/digital/condition_units_F.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_units_kPa.png](instruments/digital/condition_units_kPa.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_units_psi.png](instruments/digital/condition_units_psi.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_wear_critical.png](instruments/digital/condition_wear_critical.png) | Tyre wear | 1320×1166 | — |
| [instruments/digital/condition_wear_new.png](instruments/digital/condition_wear_new.png) | Tyre wear | 1320×1166 | — |
| [instruments/digital/condition_wear_used.png](instruments/digital/condition_wear_used.png) | Tyre wear | 1320×1166 | — |
| [instruments/digital/condition_wear_worn.png](instruments/digital/condition_wear_worn.png) | Tyre wear | 1320×1166 | — |
| [instruments/digital/condition_zones_general_dark.png](instruments/digital/condition_zones_general_dark.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_zones_general_light.png](instruments/digital/condition_zones_general_light.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_zones_surface_dark.png](instruments/digital/condition_zones_surface_dark.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_zones_surface_light.png](instruments/digital/condition_zones_surface_light.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_zones_uniform_dark.png](instruments/digital/condition_zones_uniform_dark.png) | Condition | 1320×1166 | — |
| [instruments/digital/condition_zones_uniform_light.png](instruments/digital/condition_zones_uniform_light.png) | Condition | 1320×1166 | — |
| [instruments/digital/delta_barOnly.png](instruments/digital/delta_barOnly.png) | Delta | 2898×1106 | — |
| [instruments/digital/delta_dark.png](instruments/digital/delta_dark.png) | delta | 2898×1106 | — |
| [instruments/digital/delta_default.png](instruments/digital/delta_default.png) | delta | 2898×1106 | — |
| [instruments/digital/delta_full.png](instruments/digital/delta_full.png) | Delta | 2898×1106 | — |
| [instruments/digital/delta_light.png](instruments/digital/delta_light.png) | delta | 2898×1106 | — |
| [instruments/digital/delta_minimized.png](instruments/digital/delta_minimized.png) | Delta | 2898×1106 | — |
| [instruments/digital/delta_reference_fastest_lap.png](instruments/digital/delta_reference_fastest_lap.png) | Delta reference | 2898×1106 | — |
| [instruments/digital/delta_reference_fastest_optimal.png](instruments/digital/delta_reference_fastest_optimal.png) | Delta reference | 2898×1106 | — |
| [instruments/digital/delta_reference_multiplayer_lap.png](instruments/digital/delta_reference_multiplayer_lap.png) | Delta reference | 2898×1106 | — |
| [instruments/digital/delta_reference_previous_lap.png](instruments/digital/delta_reference_previous_lap.png) | Delta reference | 2898×1106 | — |
| [instruments/digital/delta_reference_session_lap.png](instruments/digital/delta_reference_session_lap.png) | Delta reference | 2898×1106 | — |
| [instruments/digital/delta_reference_session_optimal.png](instruments/digital/delta_reference_session_optimal.png) | Delta reference | 2898×1106 | — |
| [instruments/digital/dial_digital.png](instruments/digital/dial_digital.png) | Dial | 1166×1166 | — |
| [instruments/digital/dial_hybrid_regeneration.png](instruments/digital/dial_hybrid_regeneration.png) | Dial hybrid | 1166×1166 | — |
| [instruments/digital/dial_idle.png](instruments/digital/dial_idle.png) | Dial | 1166×1166 | — |
| [instruments/digital/dial_mid.png](instruments/digital/dial_mid.png) | Dial | 1166×1166 | — |
| [instruments/digital/dial_redline.png](instruments/digital/dial_redline.png) | Dial | 1166×1166 | — |
| [instruments/digital/dial_warning.png](instruments/digital/dial_warning.png) | Dial | 1166×1166 | — |
| [instruments/digital/gt7_classic.png](instruments/digital/gt7_classic.png) | GT7 | 3031×1106 | — |
| [instruments/digital/gt7_classic_dark_kmh.png](instruments/digital/gt7_classic_dark_kmh.png) | GT7 | 3031×1106 | — |
| [instruments/digital/gt7_classic_light_kmh.png](instruments/digital/gt7_classic_light_kmh.png) | GT7 | 3031×1106 | — |
| [instruments/digital/gt7_free_classic.png](instruments/digital/gt7_free_classic.png) | GT7 Free | 3031×1106 | — |
| [instruments/digital/gt7_modern.png](instruments/digital/gt7_modern.png) | GT7 | 3031×1106 | — |
| [instruments/digital/gt7_outer_pedals.png](instruments/digital/gt7_outer_pedals.png) | GT7 | 3277×1106 | — |
| [instruments/digital/gt7_steering_dial.png](instruments/digital/gt7_steering_dial.png) | GT7 | 3031×1106 | — |
| [instruments/digital/hybrid_ers_fallback.png](instruments/digital/hybrid_ers_fallback.png) | Hybrid | 1166×1190 | — |
| [instruments/digital/hybrid_maximum.png](instruments/digital/hybrid_maximum.png) | Hybrid | 1166×1190 | — |
| [instruments/digital/hybrid_partial.png](instruments/digital/hybrid_partial.png) | Hybrid | 1166×1190 | — |
| [instruments/digital/hybrid_regeneration.png](instruments/digital/hybrid_regeneration.png) | Hybrid | 1166×1190 | — |
| [instruments/digital/hybrid_zero.png](instruments/digital/hybrid_zero.png) | Hybrid | 1166×1190 | — |
| [instruments/digital/laps_dark.png](instruments/digital/laps_dark.png) | laps | 2471×1106 | — |
| [instruments/digital/laps_default.png](instruments/digital/laps_default.png) | laps | 2471×1106 | — |
| [instruments/digital/laps_light.png](instruments/digital/laps_light.png) | laps | 2471×1106 | — |
| [instruments/digital/leaderboard_dark.png](instruments/digital/leaderboard_dark.png) | leaderboard | 2229×1106 | — |
| [instruments/digital/leaderboard_default.png](instruments/digital/leaderboard_default.png) | leaderboard | 2229×1106 | — |
| [instruments/digital/leaderboard_light.png](instruments/digital/leaderboard_light.png) | leaderboard | 2229×1106 | — |
| [instruments/digital/leaderboard_practice.png](instruments/digital/leaderboard_practice.png) | Leaderboard | 2229×1106 | — |
| [instruments/digital/leaderboard_qualify.png](instruments/digital/leaderboard_qualify.png) | Leaderboard | 2229×1106 | — |
| [instruments/digital/leaderboard_race.png](instruments/digital/leaderboard_race.png) | Leaderboard | 2229×1106 | — |
| [instruments/digital/leaderboard_rows_10.png](instruments/digital/leaderboard_rows_10.png) | Leaderboard | 2229×1106 | — |
| [instruments/digital/leaderboard_rows_3.png](instruments/digital/leaderboard_rows_3.png) | Leaderboard | 2229×1106 | — |
| [instruments/digital/leaderboard_sectors_Class.png](instruments/digital/leaderboard_sectors_Class.png) | Leaderboard | 2229×1106 | — |
| [instruments/digital/leaderboard_sectors_General.png](instruments/digital/leaderboard_sectors_General.png) | Leaderboard | 2229×1106 | — |
| [instruments/digital/map_caution.png](instruments/digital/map_caution.png) | Map | 1166×1166 | — |
| [instruments/digital/map_dark.png](instruments/digital/map_dark.png) | map | 1106×1106 | — |
| [instruments/digital/map_default.png](instruments/digital/map_default.png) | map | 1166×1166 | — |
| [instruments/digital/map_full_fixed_dots.png](instruments/digital/map_full_fixed_dots.png) | Map | 1166×1166 | — |
| [instruments/digital/map_full_fixed_surface.png](instruments/digital/map_full_fixed_surface.png) | Map | 1166×1166 | — |
| [instruments/digital/map_light.png](instruments/digital/map_light.png) | map | 1106×1106 | — |
| [instruments/digital/map_mini_fixed_dots.png](instruments/digital/map_mini_fixed_dots.png) | Map | 1166×1166 | — |
| [instruments/digital/map_mini_fixed_surface.png](instruments/digital/map_mini_fixed_surface.png) | Map | 1166×1166 | — |
| [instruments/digital/map_mini_heading_dots.png](instruments/digital/map_mini_heading_dots.png) | Map | 1166×1166 | — |
| [instruments/digital/map_mini_heading_surface.png](instruments/digital/map_mini_heading_surface.png) | Map | 1166×1166 | — |
| [instruments/digital/map_numbers_all.png](instruments/digital/map_numbers_all.png) | Map | 1166×1166 | — |
| [instruments/digital/map_numbers_selected.png](instruments/digital/map_numbers_selected.png) | Map | 1166×1166 | — |
| [instruments/digital/relative_all_classes.png](instruments/digital/relative_all_classes.png) | Relative | 1436×1106 | — |
| [instruments/digital/relative_dark.png](instruments/digital/relative_dark.png) | relative | 1436×1106 | — |
| [instruments/digital/relative_default.png](instruments/digital/relative_default.png) | relative | 1436×1106 | — |
| [instruments/digital/relative_light.png](instruments/digital/relative_light.png) | relative | 1436×1106 | — |
| [instruments/digital/relative_same_class.png](instruments/digital/relative_same_class.png) | Relative | 1436×1106 | — |
| [instruments/digital/speedometer_high.png](instruments/digital/speedometer_high.png) | speedometer | 1166×1190 | — |
| [instruments/digital/speedometer_maximum.png](instruments/digital/speedometer_maximum.png) | speedometer | 1166×1190 | — |
| [instruments/digital/speedometer_mid.png](instruments/digital/speedometer_mid.png) | speedometer | 1166×1190 | — |
| [instruments/digital/speedometer_minimum.png](instruments/digital/speedometer_minimum.png) | speedometer | 1166×1190 | — |
| [instruments/digital/tachometer_dark.png](instruments/digital/tachometer_dark.png) | Tachometer | 1166×1190 | — |
| [instruments/digital/tachometer_high.png](instruments/digital/tachometer_high.png) | tachometer | 1166×1190 | — |
| [instruments/digital/tachometer_light.png](instruments/digital/tachometer_light.png) | Tachometer | 1166×1190 | — |
| [instruments/digital/tachometer_maximum.png](instruments/digital/tachometer_maximum.png) | tachometer | 1166×1190 | — |
| [instruments/digital/tachometer_mid.png](instruments/digital/tachometer_mid.png) | tachometer | 1166×1190 | — |
| [instruments/digital/tachometer_minimum.png](instruments/digital/tachometer_minimum.png) | tachometer | 1166×1190 | — |
| [instruments/digital/telemetry_auto_expanded.png](instruments/digital/telemetry_auto_expanded.png) | Telemetry | 4143×1106 | — |
| [instruments/digital/telemetry_dark.png](instruments/digital/telemetry_dark.png) | telemetry | 4143×1106 | — |
| [instruments/digital/telemetry_default.png](instruments/digital/telemetry_default.png) | telemetry | 4143×1106 | — |
| [instruments/digital/telemetry_left_collapsed.png](instruments/digital/telemetry_left_collapsed.png) | Telemetry | 4143×1106 | — |
| [instruments/digital/telemetry_left_expanded.png](instruments/digital/telemetry_left_expanded.png) | Telemetry | 4143×1106 | — |
| [instruments/digital/telemetry_light.png](instruments/digital/telemetry_light.png) | telemetry | 4143×1106 | — |
| [instruments/digital/telemetry_right_expanded.png](instruments/digital/telemetry_right_expanded.png) | Telemetry | 4143×1106 | — |
| [instruments/digital/timer_dark.png](instruments/digital/timer_dark.png) | timer | 6724×1106 | — |
| [instruments/digital/timer_default.png](instruments/digital/timer_default.png) | timer | 6724×1106 | — |
| [instruments/digital/timer_final_lap.png](instruments/digital/timer_final_lap.png) | Timer | 6724×1106 | — |
| [instruments/digital/timer_invalid.png](instruments/digital/timer_invalid.png) | Timer | 6724×1106 | — |
| [instruments/digital/timer_light.png](instruments/digital/timer_light.png) | timer | 6724×1106 | — |
| [instruments/digital/timer_pit.png](instruments/digital/timer_pit.png) | Timer | 6724×1106 | — |
| [instruments/digital/timer_result_invalid.png](instruments/digital/timer_result_invalid.png) | Timer result | 6724×1106 | — |
| [instruments/digital/timer_result_personal_best.png](instruments/digital/timer_result_personal_best.png) | Timer result | 6724×1106 | — |
| [instruments/digital/timer_result_session_best.png](instruments/digital/timer_result_session_best.png) | Timer result | 6724×1106 | — |
| [instruments/digital/timer_result_slower.png](instruments/digital/timer_result_slower.png) | Timer result | 6724×1106 | — |
| [instruments/digital/turbo_maximum.png](instruments/digital/turbo_maximum.png) | Turbo | 1166×1190 | — |
| [instruments/digital/turbo_partial.png](instruments/digital/turbo_partial.png) | Turbo | 1166×1190 | — |
| [instruments/digital/turbo_vacuum.png](instruments/digital/turbo_vacuum.png) | Turbo | 1166×1190 | — |
| [instruments/transparent/dial_analog.png](instruments/transparent/dial_analog.png) | dial_analog | 1166×1166 | — |
| [instruments/transparent/gt7_analog.png](instruments/transparent/gt7_analog.png) | gt7_analog | 3031×1106 | — |
| [instruments/variants/flag_black.png](instruments/variants/flag_black.png) | flag | 3031×1106 | — |
| [instruments/variants/flag_blue.png](instruments/variants/flag_blue.png) | flag | 3031×1106 | — |
| [instruments/variants/flag_checkered.png](instruments/variants/flag_checkered.png) | flag | 3031×1106 | — |
| [instruments/variants/flag_green.png](instruments/variants/flag_green.png) | flag | 3031×1106 | — |
| [instruments/variants/flag_mechanical.png](instruments/variants/flag_mechanical.png) | flag | 3031×1106 | — |
| [instruments/variants/flag_purple.png](instruments/variants/flag_purple.png) | flag | 3031×1106 | — |
| [instruments/variants/flag_red.png](instruments/variants/flag_red.png) | flag | 3031×1106 | — |
| [instruments/variants/flag_slippery.png](instruments/variants/flag_slippery.png) | flag | 3031×1106 | — |
| [instruments/variants/flag_split.png](instruments/variants/flag_split.png) | flag | 3031×1106 | — |
| [instruments/variants/flag_white.png](instruments/variants/flag_white.png) | flag | 3031×1106 | — |
| [instruments/variants/flag_yellow.png](instruments/variants/flag_yellow.png) | flag | 3031×1106 | — |
| [instruments/variants/gt7DialScale_0.75.png](instruments/variants/gt7DialScale_0.75.png) | GT7 scale | 3031×1106 | — |
| [instruments/variants/gt7DialScale_1.25.png](instruments/variants/gt7DialScale_1.25.png) | GT7 scale | 3031×1106 | — |
| [instruments/variants/gt7DialScale_1.png](instruments/variants/gt7DialScale_1.png) | GT7 scale | 3031×1106 | — |
| [instruments/variants/gt7DialSpacing_0.png](instruments/variants/gt7DialSpacing_0.png) | GT7 scale | 3031×1106 | — |
| [instruments/variants/gt7DialSpacing_160.png](instruments/variants/gt7DialSpacing_160.png) | GT7 scale | 3031×1106 | — |
| [instruments/variants/gt7FlagPresentation_classic_lights.png](instruments/variants/gt7FlagPresentation_classic_lights.png) | GT7 configuration | 3031×1106 | — |
| [instruments/variants/gt7FlagPresentation_column_3.png](instruments/variants/gt7FlagPresentation_column_3.png) | GT7 configuration | 3031×1106 | — |
| [instruments/variants/gt7FlagPresentation_column_9.png](instruments/variants/gt7FlagPresentation_column_9.png) | GT7 configuration | 3031×1106 | — |
| [instruments/variants/gt7FlagPresentation_modern_strips.png](instruments/variants/gt7FlagPresentation_modern_strips.png) | GT7 configuration | 3031×1106 | — |
| [instruments/variants/gt7GearStyle_classic.png](instruments/variants/gt7GearStyle_classic.png) | GT7 configuration | 3031×1106 | — |
| [instruments/variants/gt7GearStyle_high.png](instruments/variants/gt7GearStyle_high.png) | GT7 configuration | 3031×1106 | — |
| [instruments/variants/gt7GearStyle_modern.png](instruments/variants/gt7GearStyle_modern.png) | GT7 configuration | 3031×1106 | — |
| [instruments/variants/gt7IndicatorScale_0.65.png](instruments/variants/gt7IndicatorScale_0.65.png) | GT7 scale | 3031×1106 | — |
| [instruments/variants/gt7IndicatorScale_1.5.png](instruments/variants/gt7IndicatorScale_1.5.png) | GT7 scale | 3031×1106 | — |
| [instruments/variants/gt7IndicatorScale_1.png](instruments/variants/gt7IndicatorScale_1.png) | GT7 scale | 3031×1106 | — |
| [instruments/variants/gt7LowerFrameStyle_classic.png](instruments/variants/gt7LowerFrameStyle_classic.png) | GT7 configuration | 3031×1106 | — |
| [instruments/variants/gt7LowerFrameStyle_modern.png](instruments/variants/gt7LowerFrameStyle_modern.png) | GT7 configuration | 3031×1106 | — |
| [instruments/variants/gt7LowerFrameStyle_wide.png](instruments/variants/gt7LowerFrameStyle_wide.png) | GT7 configuration | 3031×1106 | — |
| [instruments/variants/gt7LowerPanelMode_ffb.png](instruments/variants/gt7LowerPanelMode_ffb.png) | GT7 configuration | 3031×1106 | — |
| [instruments/variants/gt7LowerPanelMode_invisible.png](instruments/variants/gt7LowerPanelMode_invisible.png) | GT7 configuration | 3031×1106 | — |
| [instruments/variants/gt7LowerPanelMode_limit.png](instruments/variants/gt7LowerPanelMode_limit.png) | GT7 configuration | 3031×1106 | — |
| [instruments/variants/gt7LowerPanelMode_pedal_history.png](instruments/variants/gt7LowerPanelMode_pedal_history.png) | GT7 configuration | 3031×1106 | — |
| [instruments/variants/gt7PedalPosition_inner.png](instruments/variants/gt7PedalPosition_inner.png) | GT7 configuration | 3031×1106 | — |
| [instruments/variants/gt7PedalPosition_outer.png](instruments/variants/gt7PedalPosition_outer.png) | GT7 configuration | 3031×1106 | — |
| [instruments/variants/gt7PedalStyle_classic.png](instruments/variants/gt7PedalStyle_classic.png) | GT7 configuration | 3031×1106 | — |
| [instruments/variants/gt7PedalStyle_modern.png](instruments/variants/gt7PedalStyle_modern.png) | GT7 configuration | 3031×1106 | — |
| [instruments/variants/gt7RadarPresentation_arcs.png](instruments/variants/gt7RadarPresentation_arcs.png) | GT7 configuration | 3031×1106 | — |
| [instruments/variants/gt7RadarPresentation_classic_lights.png](instruments/variants/gt7RadarPresentation_classic_lights.png) | GT7 configuration | 3031×1106 | — |
| [instruments/variants/gt7RadarPresentation_column_3.png](instruments/variants/gt7RadarPresentation_column_3.png) | GT7 configuration | 3031×1106 | — |
| [instruments/variants/gt7RadarPresentation_column_9.png](instruments/variants/gt7RadarPresentation_column_9.png) | GT7 configuration | 3031×1106 | — |
| [instruments/variants/gt7RadarPresentation_modern_bars.png](instruments/variants/gt7RadarPresentation_modern_bars.png) | GT7 configuration | 3031×1106 | — |
| [instruments/variants/gt7SpeedStyle_classic.png](instruments/variants/gt7SpeedStyle_classic.png) | GT7 configuration | 3031×1106 | — |
| [instruments/variants/gt7SpeedStyle_large.png](instruments/variants/gt7SpeedStyle_large.png) | GT7 configuration | 3031×1106 | — |
| [instruments/variants/gt7SpeedStyle_modern.png](instruments/variants/gt7SpeedStyle_modern.png) | GT7 configuration | 3031×1106 | — |
| [instruments/variants/gt7SteeringStyle_classic.png](instruments/variants/gt7SteeringStyle_classic.png) | GT7 configuration | 3031×1106 | — |
| [instruments/variants/gt7SteeringStyle_dial.png](instruments/variants/gt7SteeringStyle_dial.png) | GT7 configuration | 3031×1106 | — |
| [instruments/variants/gt7SteeringStyle_modern.png](instruments/variants/gt7SteeringStyle_modern.png) | GT7 configuration | 3031×1106 | — |
| [instruments/variants/lower_ffb_clipping.png](instruments/variants/lower_ffb_clipping.png) | FFB | 3031×1106 | — |
| [instruments/variants/lower_ffb_mid.png](instruments/variants/lower_ffb_mid.png) | FFB | 3031×1106 | — |
| [instruments/variants/lower_ffb_minimum.png](instruments/variants/lower_ffb_minimum.png) | FFB | 3031×1106 | — |
| [instruments/variants/lower_limit_high.png](instruments/variants/lower_limit_high.png) | Grip limit | 3031×1106 | — |
| [instruments/variants/lower_limit_low.png](instruments/variants/lower_limit_low.png) | Grip limit | 3031×1106 | — |
| [instruments/variants/lower_limit_mid.png](instruments/variants/lower_limit_mid.png) | Grip limit | 3031×1106 | — |
| [instruments/variants/lower_limit_warning.png](instruments/variants/lower_limit_warning.png) | Grip limit | 3031×1106 | — |
| [instruments/variants/lower_pedal_history_active.png](instruments/variants/lower_pedal_history_active.png) | Pedal history | 3031×1106 | — |
| [instruments/variants/radar_arcs_left.png](instruments/variants/radar_arcs_left.png) | Radar | 3031×1106 | — |
| [instruments/variants/radar_arcs_right.png](instruments/variants/radar_arcs_right.png) | Radar | 3031×1106 | — |
| [instruments/variants/radar_classic_lights_left.png](instruments/variants/radar_classic_lights_left.png) | Radar | 3031×1106 | — |
| [instruments/variants/radar_classic_lights_right.png](instruments/variants/radar_classic_lights_right.png) | Radar | 3031×1106 | — |
| [instruments/variants/radar_column_3_left.png](instruments/variants/radar_column_3_left.png) | Radar | 3031×1106 | — |
| [instruments/variants/radar_column_3_right.png](instruments/variants/radar_column_3_right.png) | Radar | 3031×1106 | — |
| [instruments/variants/radar_column_9_left.png](instruments/variants/radar_column_9_left.png) | Radar | 3031×1106 | — |
| [instruments/variants/radar_column_9_right.png](instruments/variants/radar_column_9_right.png) | Radar | 3031×1106 | — |
| [instruments/variants/radar_modern_bars_left.png](instruments/variants/radar_modern_bars_left.png) | Radar | 3031×1106 | — |
| [instruments/variants/radar_modern_bars_right.png](instruments/variants/radar_modern_bars_right.png) | Radar | 3031×1106 | — |
| [instruments/variants/status_assists.png](instruments/variants/status_assists.png) | status | 3031×1106 | — |
| [instruments/variants/status_damage.png](instruments/variants/status_damage.png) | status | 3031×1106 | — |
| [instruments/variants/status_indicators.png](instruments/variants/status_indicators.png) | status | 3031×1106 | — |
| [instruments/variants/status_neutral.png](instruments/variants/status_neutral.png) | status | 3031×1106 | — |
| [instruments/variants/status_pit.png](instruments/variants/status_pit.png) | status | 3031×1106 | — |
| [instruments/variants/status_reverse.png](instruments/variants/status_reverse.png) | status | 3031×1106 | — |
| [needles/fixed_auxiliary_needle.png](needles/fixed_auxiliary_needle.png) | fixed_auxiliary_needle | 1920×1670 | — |
| [needles/individual/a01.png](needles/individual/a01.png) | needle | 1166×1190 | — |
| [needles/individual/a02.png](needles/individual/a02.png) | needle | 1166×1190 | — |
| [needles/individual/a03.png](needles/individual/a03.png) | needle | 1166×1190 | — |
| [needles/individual/a04.png](needles/individual/a04.png) | needle | 1166×1190 | — |
| [needles/individual/a05.png](needles/individual/a05.png) | needle | 1166×1190 | — |
| [needles/individual/a06.png](needles/individual/a06.png) | needle | 1166×1190 | — |
| [needles/individual/b01.png](needles/individual/b01.png) | needle | 1166×1190 | — |
| [needles/individual/b02.png](needles/individual/b02.png) | needle | 1166×1190 | — |
| [needles/individual/b03.png](needles/individual/b03.png) | needle | 1166×1190 | — |
| [needles/individual/b04.png](needles/individual/b04.png) | needle | 1166×1190 | — |
| [needles/individual/b05.png](needles/individual/b05.png) | needle | 1166×1190 | — |
| [needles/individual/b06.png](needles/individual/b06.png) | needle | 1166×1190 | — |
| [needles/individual/c01.png](needles/individual/c01.png) | needle | 1166×1190 | — |
| [needles/individual/c02.png](needles/individual/c02.png) | needle | 1166×1190 | — |
| [needles/individual/c03.png](needles/individual/c03.png) | needle | 1166×1190 | — |
| [needles/individual/c04.png](needles/individual/c04.png) | needle | 1166×1190 | — |
| [needles/individual/c05.png](needles/individual/c05.png) | needle | 1166×1190 | — |
| [needles/individual/c06.png](needles/individual/c06.png) | needle | 1166×1190 | — |
| [needles/individual/d01.png](needles/individual/d01.png) | needle | 1166×1190 | — |
| [needles/individual/d02.png](needles/individual/d02.png) | needle | 1166×1190 | — |
| [needles/individual/d03.png](needles/individual/d03.png) | needle | 1166×1190 | — |
| [needles/individual/d04.png](needles/individual/d04.png) | needle | 1166×1190 | — |
| [needles/individual/d05.png](needles/individual/d05.png) | needle | 1166×1190 | — |
| [needles/individual/d06.png](needles/individual/d06.png) | needle | 1166×1190 | — |
| [needles/individual/subNeedle.png](needles/individual/subNeedle.png) | fixed fuel/boost mini needle | 1254×1166 | — |
| [needles/needles_overview.png](needles/needles_overview.png) | needles_overview | 3840×5370 | — |
| [lighting/dial_analog_dark/lights_off.png](lighting/dial_analog_dark/lights_off.png) | Dial | 1166×1166 | — |
| [lighting/dial_analog_dark/lights_on.png](lighting/dial_analog_dark/lights_on.png) | Dial | 1166×1166 | — |
| [lighting/dial_analog_light/lights_off.png](lighting/dial_analog_light/lights_off.png) | Dial | 1166×1166 | — |
| [lighting/dial_analog_light/lights_on.png](lighting/dial_analog_light/lights_on.png) | Dial | 1166×1166 | — |
| [lighting/dial_digital_dark/lights_off.png](lighting/dial_digital_dark/lights_off.png) | Dial | 1166×1166 | — |
| [lighting/dial_digital_dark/lights_on.png](lighting/dial_digital_dark/lights_on.png) | Dial | 1166×1166 | — |
| [lighting/dial_digital_light/lights_off.png](lighting/dial_digital_light/lights_off.png) | Dial | 1166×1166 | — |
| [lighting/dial_digital_light/lights_on.png](lighting/dial_digital_light/lights_on.png) | Dial | 1166×1166 | — |
| [lighting/headlight_flasher.png](lighting/headlight_flasher.png) | GT7 headlight flash | 3031×1106 | — |
| [lighting/hidden_lights_indicator/lights_off.png](lighting/hidden_lights_indicator/lights_off.png) | GT7 | 3031×1106 | — |
| [lighting/hidden_lights_indicator/lights_on.png](lighting/hidden_lights_indicator/lights_on.png) | GT7 | 3031×1106 | — |
| [lighting/speedometer_analog_dark/lights_off.png](lighting/speedometer_analog_dark/lights_off.png) | speedometer | 1166×1190 | — |
| [lighting/speedometer_analog_dark/lights_on.png](lighting/speedometer_analog_dark/lights_on.png) | speedometer | 1166×1190 | — |
| [lighting/speedometer_analog_light/lights_off.png](lighting/speedometer_analog_light/lights_off.png) | speedometer | 1166×1190 | — |
| [lighting/speedometer_analog_light/lights_on.png](lighting/speedometer_analog_light/lights_on.png) | speedometer | 1166×1190 | — |
| [lighting/speedometer_digital_dark/lights_off.png](lighting/speedometer_digital_dark/lights_off.png) | speedometer | 1166×1190 | — |
| [lighting/speedometer_digital_dark/lights_on.png](lighting/speedometer_digital_dark/lights_on.png) | speedometer | 1166×1190 | — |
| [lighting/speedometer_digital_light/lights_off.png](lighting/speedometer_digital_light/lights_off.png) | speedometer | 1166×1190 | — |
| [lighting/speedometer_digital_light/lights_on.png](lighting/speedometer_digital_light/lights_on.png) | speedometer | 1166×1190 | — |
| [lighting/tachometer_analog_dark/lights_off.png](lighting/tachometer_analog_dark/lights_off.png) | tachometer | 1166×1190 | — |
| [lighting/tachometer_analog_dark/lights_on.png](lighting/tachometer_analog_dark/lights_on.png) | tachometer | 1166×1190 | — |
| [lighting/tachometer_analog_light/lights_off.png](lighting/tachometer_analog_light/lights_off.png) | tachometer | 1166×1190 | — |
| [lighting/tachometer_analog_light/lights_on.png](lighting/tachometer_analog_light/lights_on.png) | tachometer | 1166×1190 | — |
| [lighting/tachometer_digital_dark/lights_off.png](lighting/tachometer_digital_dark/lights_off.png) | tachometer | 1166×1190 | — |
| [lighting/tachometer_digital_dark/lights_on.png](lighting/tachometer_digital_dark/lights_on.png) | tachometer | 1166×1190 | — |
| [lighting/tachometer_digital_light/lights_off.png](lighting/tachometer_digital_light/lights_off.png) | tachometer | 1166×1190 | — |
| [lighting/tachometer_digital_light/lights_on.png](lighting/tachometer_digital_light/lights_on.png) | tachometer | 1166×1190 | — |
| [overview/all_instruments.png](overview/all_instruments.png) | all_instruments | 3840×4456 | — |
| [overview/analog_instruments.png](overview/analog_instruments.png) | analog_instruments | 3840×8350 | — |
| [overview/condition_readouts.png](overview/condition_readouts.png) | condition_readouts | 2560×1484 | — |
| [overview/digital_instruments.png](overview/digital_instruments.png) | digital_instruments | 3840×6684 | — |
| [overview/driving_instruments.png](overview/driving_instruments.png) | driving_instruments | 3840×4456 | — |
| [overview/lighting_comparison.png](overview/lighting_comparison.png) | lighting_comparison | 3840×1670 | — |
| [videos/tachometer_analog.mp4](videos/tachometer_analog.mp4) | tachometer_analog | 1920×1080 | 8 s / 60 FPS |
| [gifs/tachometer_analog.gif](gifs/tachometer_analog.gif) | tachometer_analog | 960×540 | 8 s / 30 FPS |
| [videos/tachometer_digital.mp4](videos/tachometer_digital.mp4) | tachometer_digital | 1920×1080 | 8 s / 60 FPS |
| [gifs/tachometer_digital.gif](gifs/tachometer_digital.gif) | tachometer_digital | 960×540 | 8 s / 30 FPS |
| [videos/speedometer_analog.mp4](videos/speedometer_analog.mp4) | speedometer_analog | 1920×1080 | 8 s / 60 FPS |
| [gifs/speedometer_analog.gif](gifs/speedometer_analog.gif) | speedometer_analog | 960×540 | 8 s / 30 FPS |
| [videos/speedometer_digital.mp4](videos/speedometer_digital.mp4) | speedometer_digital | 1920×1080 | 8 s / 60 FPS |
| [gifs/speedometer_digital.gif](gifs/speedometer_digital.gif) | speedometer_digital | 960×540 | 8 s / 30 FPS |
| [videos/turbo_analog.mp4](videos/turbo_analog.mp4) | turbo_analog | 1920×1080 | 8 s / 60 FPS |
| [gifs/turbo_analog.gif](gifs/turbo_analog.gif) | turbo_analog | 960×540 | 8 s / 30 FPS |
| [videos/turbo_digital.mp4](videos/turbo_digital.mp4) | turbo_digital | 1920×1080 | 8 s / 60 FPS |
| [gifs/turbo_digital.gif](gifs/turbo_digital.gif) | turbo_digital | 960×540 | 8 s / 30 FPS |
| [videos/hybrid_analog.mp4](videos/hybrid_analog.mp4) | hybrid_analog | 1920×1080 | 8 s / 60 FPS |
| [gifs/hybrid_analog.gif](gifs/hybrid_analog.gif) | hybrid_analog | 960×540 | 8 s / 30 FPS |
| [videos/hybrid_digital.mp4](videos/hybrid_digital.mp4) | hybrid_digital | 1920×1080 | 8 s / 60 FPS |
| [gifs/hybrid_digital.gif](gifs/hybrid_digital.gif) | hybrid_digital | 960×540 | 8 s / 30 FPS |
| [videos/fuel_slosh.mp4](videos/fuel_slosh.mp4) | fuel_slosh | 1920×1080 | 8 s / 60 FPS |
| [gifs/fuel_slosh.gif](gifs/fuel_slosh.gif) | fuel_slosh | 960×540 | 8 s / 30 FPS |
| [videos/dial_analog.mp4](videos/dial_analog.mp4) | dial_analog | 1920×1080 | 8 s / 60 FPS |
| [gifs/dial_analog.gif](gifs/dial_analog.gif) | dial_analog | 960×540 | 8 s / 30 FPS |
| [videos/dial_digital.mp4](videos/dial_digital.mp4) | dial_digital | 1920×1080 | 8 s / 60 FPS |
| [gifs/dial_digital.gif](gifs/dial_digital.gif) | dial_digital | 960×540 | 8 s / 30 FPS |
| [videos/gt7_analog.mp4](videos/gt7_analog.mp4) | gt7_analog | 1920×1080 | 8 s / 60 FPS |
| [gifs/gt7_analog.gif](gifs/gt7_analog.gif) | gt7_analog | 960×540 | 8 s / 30 FPS |
| [videos/gt7_digital.mp4](videos/gt7_digital.mp4) | gt7_digital | 1920×1080 | 8 s / 60 FPS |
| [gifs/gt7_digital.gif](gifs/gt7_digital.gif) | gt7_digital | 960×540 | 8 s / 30 FPS |
| [videos/backlighting_analog.mp4](videos/backlighting_analog.mp4) | backlighting_analog | 1920×1080 | 8 s / 60 FPS |
| [gifs/backlighting_analog.gif](gifs/backlighting_analog.gif) | backlighting_analog | 960×540 | 8 s / 30 FPS |
| [videos/backlighting_digital.mp4](videos/backlighting_digital.mp4) | backlighting_digital | 1920×1080 | 8 s / 60 FPS |
| [gifs/backlighting_digital.gif](gifs/backlighting_digital.gif) | backlighting_digital | 960×540 | 8 s / 30 FPS |
| [videos/controls_radar_flags.mp4](videos/controls_radar_flags.mp4) | controls_radar_flags | 1920×1080 | 8 s / 60 FPS |
| [gifs/controls_radar_flags.gif](gifs/controls_radar_flags.gif) | controls_radar_flags | 960×540 | 8 s / 30 FPS |
| [videos/analog_digital_transition.mp4](videos/analog_digital_transition.mp4) | analog_digital_transition | 1920×1080 | 8 s / 60 FPS |
| [gifs/analog_digital_transition.gif](gifs/analog_digital_transition.gif) | analog_digital_transition | 960×540 | 8 s / 30 FPS |
| [videos/hybrid_standalone.mp4](videos/hybrid_standalone.mp4) | hybrid_standalone | 1920×1080 | 8 s / 60 FPS |
| [gifs/hybrid_standalone.gif](gifs/hybrid_standalone.gif) | hybrid_standalone | 960×540 | 8 s / 30 FPS |
| [videos/condition_temperature.mp4](videos/condition_temperature.mp4) | condition_temperature | 1920×1080 | 8 s / 60 FPS |
| [gifs/condition_temperature.gif](gifs/condition_temperature.gif) | condition_temperature | 960×540 | 8 s / 30 FPS |
| [videos/map_offtrack.mp4](videos/map_offtrack.mp4) | map_offtrack | 1920×1080 | 8 s / 60 FPS |
| [gifs/map_offtrack.gif](gifs/map_offtrack.gif) | map_offtrack | 960×540 | 8 s / 30 FPS |
| [videos/relative.mp4](videos/relative.mp4) | relative | 1920×1080 | 8 s / 60 FPS |
| [gifs/relative.gif](gifs/relative.gif) | relative | 960×540 | 8 s / 30 FPS |
| [videos/leaderboard.mp4](videos/leaderboard.mp4) | leaderboard | 1920×1080 | 8 s / 60 FPS |
| [gifs/leaderboard.gif](gifs/leaderboard.gif) | leaderboard | 960×540 | 8 s / 30 FPS |
| [videos/map.mp4](videos/map.mp4) | map | 1920×1080 | 8 s / 60 FPS |
| [gifs/map.gif](gifs/map.gif) | map | 960×540 | 8 s / 30 FPS |
| [videos/delta.mp4](videos/delta.mp4) | delta | 1920×1080 | 8 s / 60 FPS |
| [gifs/delta.gif](gifs/delta.gif) | delta | 960×540 | 8 s / 30 FPS |
| [videos/timer.mp4](videos/timer.mp4) | timer | 1920×1080 | 8 s / 60 FPS |
| [gifs/timer.gif](gifs/timer.gif) | timer | 960×540 | 8 s / 30 FPS |
| [videos/laps.mp4](videos/laps.mp4) | laps | 1920×1080 | 8 s / 60 FPS |
| [gifs/laps.gif](gifs/laps.gif) | laps | 960×540 | 8 s / 30 FPS |
| [videos/telemetry.mp4](videos/telemetry.mp4) | telemetry | 1920×1080 | 8 s / 60 FPS |
| [gifs/telemetry.gif](gifs/telemetry.gif) | telemetry | 960×540 | 8 s / 30 FPS |
| [videos/hybrid_battery_recovery.mp4](videos/hybrid_battery_recovery.mp4) | hybrid_battery_recovery | 1920×1080 | 8 s / 60 FPS |
| [gifs/hybrid_battery_recovery.gif](gifs/hybrid_battery_recovery.gif) | hybrid_battery_recovery | 960×540 | 8 s / 30 FPS |
| [videos/aero_analog.mp4](videos/aero_analog.mp4) | aero_analog | 1920×1080 | 8 s / 60 FPS |
| [gifs/aero_analog.gif](gifs/aero_analog.gif) | aero_analog | 960×540 | 8 s / 30 FPS |
| [videos/aero_digital.mp4](videos/aero_digital.mp4) | aero_digital | 1920×1080 | 8 s / 60 FPS |
| [gifs/aero_digital.gif](gifs/aero_digital.gif) | aero_digital | 960×540 | 8 s / 30 FPS |
| [videos/grip_limit.mp4](videos/grip_limit.mp4) | grip_limit | 1920×1080 | 8 s / 60 FPS |
| [gifs/grip_limit.gif](gifs/grip_limit.gif) | grip_limit | 960×540 | 8 s / 30 FPS |
| [videos/ffb.mp4](videos/ffb.mp4) | ffb | 1920×1080 | 8 s / 60 FPS |
| [gifs/ffb.gif](gifs/ffb.gif) | ffb | 960×540 | 8 s / 30 FPS |
| [videos/timer_result_transition.mp4](videos/timer_result_transition.mp4) | timer_result_transition | 1920×1080 | 8 s / 60 FPS |
| [gifs/timer_result_transition.gif](gifs/timer_result_transition.gif) | timer_result_transition | 960×540 | 8 s / 30 FPS |
| [videos/laps_transition.mp4](videos/laps_transition.mp4) | laps_transition | 1920×1080 | 8 s / 60 FPS |
| [gifs/laps_transition.gif](gifs/laps_transition.gif) | laps_transition | 960×540 | 8 s / 30 FPS |
| [videos/delta_notifications.mp4](videos/delta_notifications.mp4) | delta_notifications | 1920×1080 | 8 s / 60 FPS |
| [gifs/delta_notifications.gif](gifs/delta_notifications.gif) | delta_notifications | 960×540 | 8 s / 30 FPS |
| [videos/gt7_modern.mp4](videos/gt7_modern.mp4) | gt7_modern | 1920×1080 | 8 s / 60 FPS |
| [gifs/gt7_modern.gif](gifs/gt7_modern.gif) | gt7_modern | 960×540 | 8 s / 30 FPS |
| [videos/gt7_outer_pedals.mp4](videos/gt7_outer_pedals.mp4) | gt7_outer_pedals | 1920×1080 | 8 s / 60 FPS |
| [gifs/gt7_outer_pedals.gif](gifs/gt7_outer_pedals.gif) | gt7_outer_pedals | 960×540 | 8 s / 30 FPS |
| [videos/gt7_steering_dial.mp4](videos/gt7_steering_dial.mp4) | gt7_steering_dial | 1920×1080 | 8 s / 60 FPS |
| [gifs/gt7_steering_dial.gif](gifs/gt7_steering_dial.gif) | gt7_steering_dial | 960×540 | 8 s / 30 FPS |
