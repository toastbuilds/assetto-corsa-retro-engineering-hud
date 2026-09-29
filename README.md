# Retro UI

Retro UI reúne los instrumentos CSP Lua de Assetto Corsa en una sola app. El
dial digital/analógico, GT7, Car Condition, Multiclass Relative, Delta Bar,
Leaderboard, Telemetry y Map son ventanas independientes. GT7 y el dial pueden
mostrarse a la vez. **Retro UI Settings** ofrece una pestaña por instrumento.

## Requisitos

- Assetto Corsa para PC y Custom Shaders Patch con Lua apps habilitadas.
- Content Manager es recomendable para instalar el ZIP y activar la app.

## Instalación nueva

Descarga `RetroUI-vX.Y.Z.zip` desde la [última versión publicada](https://github.com/yukkine0704/assetto-corsa-retro-engineering-hud/releases/latest)
y arrastra el ZIP a Content Manager para instalarlo. No necesitas ejecutar
scripts ni compilar nada. El ZIP instala `apps/lua/RetroUI`. Activa **Retro UI**
y abre las ventanas que necesites desde la barra lateral CSP.

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

**Map** abre una ventana transparente y redimensionable. En **Retro UI
Settings > Map** se elige entre el circuito completo y el mini mapa centrado
en el coche. **Orientation** permite girarlo con el coche o mantener fija la
orientación del circuito mientras el mapa se desplaza. El cambio de modo conserva
el tamaño y la posición de la ventana. El radio visible del mini mapa empieza
en 500 m. **Background** permite elegir entre puntos o una superficie radial;
solo se dibuja el modo seleccionado. **Radial surface** controla la opacidad
de la superficie en el centro, que baja a 0 en el borde circular.
**Background dots** controla la intensidad de los puntos; **Dot thickness**
permite ampliarlos hasta 4×. Por defecto son un 15 % más gruesos que antes y se
desvanecen hacia los bordes. **Radial dot taper** reduce su grosor desde el
centro hacia el exterior y se puede desactivar. Las alertas amarillas, rojas o
azules producen una onda repetida en los puntos; en modo Superficie, colorean el
trazado de la pista. Una opacidad de 0 % deja el fondo transparente.
El trazado, la meta y los sectores dependen de los datos de la pista cargada.
El mapa resalta tu coche, líder, último y dos posiciones por delante y detrás,
con su posición dentro del marcador; el resto son puntos sin etiquetas. El
encuadre reserva espacio para los marcadores grandes cerca del borde.
**Highlighted markers** permite ajustar el tamaño de los indicadores con
posición sin modificar los puntos normales. **Track width** controla el grosor
del trazado hasta 4× y **Car dots** el tamaño de los coches sin número.

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
manifiesto CSP expone nueve ventanas en un único proceso. El paquete distribuye
los archivos Lua, los mapas de clases, los recursos y las licencias.

Para crear un ZIP local desde el código fuente, ejecuta
`tools/build-package.ps1`. Las etiquetas `vX.Y.Z` publican el mismo paquete
automáticamente mediante GitHub Actions.

## Licencia

MIT. Consulta [LICENSE](LICENSE) y [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
