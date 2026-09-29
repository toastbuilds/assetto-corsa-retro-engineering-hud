# Retro UI

Retro UI reúne los instrumentos CSP Lua de Assetto Corsa en una sola app. El
dial digital/analógico, GT7, Car Condition, Multiclass Relative, Delta Bar,
Leaderboard y Telemetry son ventanas independientes. GT7 y el dial pueden
mostrarse a la vez. **Retro UI Settings** ofrece una pestaña por instrumento.

## Requisitos

- Assetto Corsa para PC y Custom Shaders Patch con Lua apps habilitadas.
- Content Manager es recomendable para instalar el ZIP y activar la app.

## Instalación nueva

Ejecuta `tools/build-package.ps1` y arrastra `dist/RetroUI-v1.0.0.zip` a
Content Manager. El ZIP instala `apps/lua/RetroUI`. Activa **Retro UI** y abre
las ventanas que necesites desde la barra lateral CSP.

## Migración desde las apps separadas

Con el juego cerrado, ejecuta:

```powershell
powershell -ExecutionPolicy Bypass -File tools/install-retro-ui.ps1 -AssettoCorsaRoot 'RUTA\assettocorsa'
```

El script crea el ZIP, respalda las carpetas antiguas, copia los `classes.ini`
instalados de Relative y Leaderboard e instala Retro UI. Los récords históricos
del Delta Bar permanecen en `Documents/Assetto Corsa/CMRTRetroDeltaBar` y se
respaldan si están presentes. Las preferencias guardadas por `ac.storage` de
las apps anteriores vuelven a sus valores por defecto porque CSP las asocia a
cada app. El almacenamiento de `AC Hud` también puede reiniciarse al cambiar
el nombre de instalación. Las nuevas opciones de GT7 toman sus valores
iniciales de los ajustes del dial disponibles en Retro UI.

Abre Retro UI en el juego y comprueba los instrumentos antes de retirar las
apps anteriores. Después, con el juego cerrado, ejecuta:

```powershell
powershell -ExecutionPolicy Bypass -File tools/install-retro-ui.ps1 -AssettoCorsaRoot 'RUTA\assettocorsa' -Finalize -Validated
```

La retirada mueve las carpetas antiguas a `_RetroUI-Backups`; no borra sus
preferencias CSP ni los récords. Para revertirla, mueve las carpetas
`retired-*` del último respaldo de nuevo a `apps/lua/`.

## Ajustes

**General** controla el tema y las unidades de velocidad y temperatura de toda
la app. La lista lateral abre los ajustes de cada instrumento, ordenados en
secciones; **Advanced** contiene opciones menos frecuentes. Escala y opacidad
siguen siendo independientes por ventana. **Reset appearance** solo restaura el
aspecto; **Reset all** pide confirmación y restaura los ajustes del instrumento.
Para Relative y Leaderboard, Reset all también restaura `classes.ini` y guarda
una copia anterior en `Documents/Assetto Corsa/RetroUI/Class Backups`.

## Desarrollo

Los archivos de las cuatro apps externas están integrados bajo `modules/`.
Cada uno usa rutas `require()` y claves de almacenamiento separadas. El
manifiesto CSP expone ocho ventanas en un único proceso. El paquete distribuye
los archivos Lua, los mapas de clases, los recursos y las licencias.

## Licencia

MIT. Consulta [LICENSE](LICENSE) y [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
