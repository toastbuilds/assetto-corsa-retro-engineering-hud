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

**GT7 > Gauges and layout > Layout** permite elegir entre **Classic**, **Modern**,
**Outer Pedals** y **Steering Dial**. Classic conserva la composición original.
Modern usa un centro angular sin barra horizontal de RPM y ensancha hacia fuera
los dos bloques superiores de cada pedal. Sus tres franjas laterales por lado
actúan como radar, sin arcos adicionales. Durante la intervención del ABS, los
dos bloques superiores ensanchados del freno se rellenan en blanco; con TC,
los dos del acelerador se rellenan en rojo, independientemente de la posición
del pedal. Al terminar la intervención vuelven a mostrar la entrada normal.
Las dos luces superiores del centro muestran la bandera de forma continua,
siempre encendidas: verde sin bandera, amarillo, rojo, azul, blanco o negro
según el estado de CSP, y cuadros blancos y negros al terminar. No parpadean
ni se ocultan cuando actúa el radar; también representan los estados especiales
de pista deslizante, avería mecánica y Code 60.
Outer Pedals coloca las barras fuera
de los diales y usa tres luces verticales por lado. Steering Dial incorpora un
dial de dirección de ±90°, un panel inferior ancho y nueve luces por lado.
Todos conservan la elección entre Grip limit, FFB, Pedal history y Hidden.
Los dos últimos layouts fijan el radar en luces verticales: sus tres niveles
encienden 1/2/3 o 3/6/9 luces desde abajo. El radar tiene prioridad sobre la
bandera solo en el lado con tráfico; los intermitentes son independientes en
los nuevos layouts y los bordes de los diales siguen mostrando la bandera.
Sin radar, las columnas muestran banderas. El layout se guarda por separado y
Reset all restaura Classic.

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

Para crear los paquetes locales, ejecuta `tools/build-package.ps1` con
`-Edition free` o `-Edition premium`. El paquete Free conserva el layout GT7
Classic; Premium incluye Classic, Modern, Outer Pedals y Steering Dial. El
instalador usa Premium por defecto; para instalar Free, añade `-Edition free`.
Las etiquetas `vX.Y.Z` generan y adjuntan ambos ZIP mediante GitHub Actions.
La distribución en ZIP separados no cambia la licencia MIT del código que ya
la incluye ni impide por sí sola redistribuirlo.

`npm run check:lua` comprueba sintaxis, módulos y callbacks CSP. Con Lua 5.2
o LuaJIT, ejecuta `lua tests/runtime_smoke.lua` y `lua tests/gt7_layouts.lua`
para comprobar las ventanas principales y los layouts GT7 con una interfaz CSP
simulada. Las pruebas de GT7 incluyen persistencia, geometría de pedales,
prioridad de alertas, dirección y 384 combinaciones de dibujo. La revisión visual
final se realiza dentro de Assetto Corsa con CSP.

## Licencia

MIT. Consulta [LICENSE](LICENSE) y [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
