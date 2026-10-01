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

**Condition > Appearance > Core weight** permite mezclar la temperatura del
núcleo y la superficie de los neumáticos entre 0 % y 100 % core. El porcentaje
surface es el complementario; el valor inicial es 80 % core / 20 % surface y
se guarda entre sesiones. Se aplica a **General zones** y **General (uniform)**;
**Surface zones** utiliza las lecturas de superficie. Los resets restauran 80/20.

**GT7 Premium > Components and presets** permite combinar por separado la
velocidad, marcha, dirección, barra RPM, posición y diseño de pedales, radar,
banderas y apariencia del panel inferior. **Classic**, **Modern**,
**Outer Pedals** y **Steering Dial** siguen disponibles como presets que aplican
esas selecciones sin bloquear la edición posterior. El marco central se resuelve
automáticamente según los componentes elegidos y el HUD conserva el ajuste
uniforme a la ventana.

Radar y banderas tienen estilos independientes. Cuando comparten espacio, el
radar sustituye la bandera únicamente en el lado con tráfico durante toda la
situación de proximidad, incluida la fase apagada del parpadeo. Las franjas
continuas Modern permanecen visibles con la bandera actual incluso mientras
actúa el radar, y los intermitentes siguen siendo independientes. Los estados
de bandera conservan sus colores y patrones, incluidos los cuadros.

Los pedales pueden colocarse dentro o fuera y usar bloques Classic o Modern de
forma independiente. En cualquier combinación, la intervención del ABS rellena
en blanco los dos bloques superiores del freno y la del TC rellena en rojo los
dos del acelerador; al terminar vuelven a representar la entrada normal. El
contenido del panel inferior mantiene Grip limit, FFB, Pedal history y Hidden,
y los diales conservan sus modos analógico/digital y sus opciones de visibilidad
y animación. **Reset appearance** conserva la composición; **Reset all** también
restaura la composición Classic.

Los dials laterales **Premium** tienen modos Analog y Digital independientes.
Analog usa escalas concéntricas y miniagujas para fuel/boost; Digital presenta
velocidad y RPM grandes con aros de bloques y subinstrumentos segmentados.
**Speed needle style** y **RPM needle style** seleccionan 24 variantes de
aguja, identificadas como **A01–D06** según los seis recuadros inferiores de
`assets/needle a.png` a `assets/needle d.png`. Cada variante conserva su cuerpo,
punta, contrapeso y centro; sus ranuras y perforaciones dejan ver el fondo real.
Las nueve selecciones anteriores migran automáticamente a su referencia equivalente.
Las luces reales del coche activan una retroiluminación gradual, incluso si se
oculta el indicador de luces.

En **Advanced**, **Simulate vacuum when boost is zero** añade un vacío estimado
por acelerador mientras gira el motor. Su mínimo inicial es −0.5 bar y se puede
ajustar o desactivar; cualquier boost positivo sigue usando el valor real de CSP.
El SDK de apps no ofrece vacío real. **Instrument preview (temporary)** permite
probar modos, agujas, luces, velocidad, RPM, reserva, boost y datos ausentes sin
modificar el coche ni las otras ventanas; no se guarda al reiniciar.

En **GT7 → Appearance**, **Side dial scale** ajusta ambos instrumentos entre
0.75× y 1.25× y **Side dial spacing** añade de 0 a 160 píxeles de separación
respecto al centro. Los valores neutros son 1× y 0; el encaje en la ventana se
recalcula para incluir los dials y sus indicadores. En la composición de pedales
exteriores, esas barras acompañan al grupo lateral para conservar su espacio.
Fuel y boost analógicos superponen los segmentos de llenado sobre el mismo arco
de divisiones, con la aguja por encima. Las marcas principales son más anchas
y las subdivisiones menores más finas y próximas.
Fuel y boost comparten la superficie del dial; una banda elevada respalda las
cifras de las escalas principales.

**Lower indicator scale** ajusta los indicadores circulares inferiores entre
0.65× y 1.50×, con separación y encaje adaptados. La zona de redline conserva
segmentos digitales incluso en analógico: quedan tenues antes del umbral real
y se iluminan al alcanzarlo. El arco interno analógico usa pequeñas marcas y
puntos alineados con los números de cada escala.

Los parámetros visuales se centralizan en `src/instrument_config.lua`: escalas,
segmentos, tamaños, grosores, subinstrumentos, agujas/hub y transiciones. Sus
colores usan los roles de `src/theme.lua`, compatibles con ambos temas.

Los dials laterales Premium comparten una retroiluminación interna continua:
con luces encendidas se iluminan números, graduaciones, agujas, iconos y
segmentos activos, manteniendo el aro exterior discreto. La transición ease-out
dura 220 ms; no modifica escalas ni la respuesta de las agujas. El tema claro
conserva su fondo y usa una respuesta más tenue. Los botones externos y el dial
independiente conservan su iluminación anterior.

`instrument_config.illumination` permite ajustar intensidad, radio y opacidad
de los halos por elemento, núcleo de agujas, hub, luz ambiental interior y aro
Analog/Digital. `lightTransition` controla la duración; `Theme.dialBacklight`
contiene los colores destino por tema. Los núcleos geométricos de las agujas se
preparan al cargar el catálogo y respetan ranuras, perforaciones y centros abiertos.

En **Dial > Gauge and display**, el modo Analog ofrece **RPM needle style**
con las mismas 24 variantes. Su selección es independiente de las dos agujas
GT7 y se guarda al reiniciar; velocidad mantiene su lectura numérica.
Los estilos conservan los valores, escalas y respuesta mecánica de cada aguja.
Fuel y boost mantienen sus miniagujas. **Reset appearance** y **Reset all**
restauran B01 en GT7 y A01 en el dial independiente.

La edición **Free** mantiene el GT7 Classic y sus indicadores ABS/TC sin incluir
el editor Premium. Las selecciones Premium se guardan en claves propias, por lo
que alternar entre ediciones no las elimina.

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

**Relative** muestra los récords de sesión y pista sobre la tabla. El de sesión
es tu vuelta válida más rápida de la sesión; el de pista conserva tu mejor
vuelta registrada localmente entre sesiones, por coche, circuito y variante.
Los tiempos de rivales e IA no cuentan para ninguno de los dos récords.
El historial anterior de parrilla se conserva pero no se importa al personal.
Sin referencia se muestra `-:--.---`. Los sectores ocupan una franja compacta
sin tiempos: morado para el mejor sector de la clase, verde para una mejora
personal, ámbar para un sector más lento y rojo con X para uno inválido. El
borde y el punto indican el sector activo. Los récords, los sectores y las
condiciones se pueden mostrar por separado desde los ajustes de Relative.

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
Classic; Premium incluye el editor por componentes y los presets Classic,
Modern, Outer Pedals y Steering Dial. El
instalador usa Premium por defecto; para instalar Free, añade `-Edition free`.
Las etiquetas `vX.Y.Z` generan y adjuntan ambos ZIP mediante GitHub Actions.
La distribución en ZIP separados no cambia la licencia MIT del código que ya
la incluye ni impide por sí sola redistribuirlo.

`npm run check:lua` comprueba sintaxis, módulos y callbacks CSP. Con Lua 5.2
o LuaJIT, ejecuta `lua tests/runtime_smoke.lua` y `lua tests/gt7_layouts.lua`
para comprobar las ventanas principales y los layouts GT7 con una interfaz CSP
simulada. Las pruebas de GT7 incluyen migración y persistencia de la composición,
independencia de secciones, geometría de pedales, prioridad de radar/banderas,
dirección y 384 combinaciones de dibujo. La revisión visual final se realiza
dentro de Assetto Corsa con CSP.

`lua tests/relative.lua` comprueba los récords personales de Relative, su
persistencia por coche y variante, la exclusión de rivales, la validez de las
vueltas y 96 combinaciones de dibujo con ambos temas,
tres tamaños de ventana y las secciones opcionales.

`lua tests/instruments.lua` verifica las transiciones, los valores compartidos,
el vacío simulado, las 24 geometrías de aguja, sus huecos reales, la migración,
los tres selectores independientes, la persistencia, los resets y el aislamiento
del preview, con 768 escenarios GT7 y 864 del dial independiente. También ejecuta
la suite de layouts GT7. Si no hay un ejecutable Lua, se puede usar Python con
`lupa.lua52`.

`python tools/preview-instruments.py` genera capturas desde las llamadas reales
de dibujo en `output/instruments/` (requiere Pillow, Lupa y Consolas). Incluye
ambos modos/temas, luces OFF/ON, las 24 agujas y alertas. `needle-styles.png`
muestra el catálogo GT7, `standalone-needle-styles.png` el dial independiente y
`needle-details.png` las geometrías ampliadas. Estas capturas ayudan
a revisar composición y legibilidad; la rasterización final depende de CSP.

`python tools/preview-instruments.py --output output/backlight/after` genera las
comparativas OFF/ON con 139 km/h, 5200 RPM, 60 % fuel y 0.7 bar boost. Incluye
`modes-and-lights-no-ring.png`, sin aro luminoso ni bezel, y
`needle-styles-on.png`, con las 24 agujas retroiluminadas. El preview compone
explícitamente la opacidad de los textos para no exagerar el halo.

`lua tests/instrument_illumination.lua` ejecuta las suites de instrumentos y
layouts y añade verificaciones de duración, inversión de luces, jerarquía,
geometría, segmentos inactivos, controles externos y datos ausentes. La revisión
de antialiasing y rendimiento durante gameplay requiere Assetto Corsa con CSP.

## Licencia

MIT. Consulta [LICENSE](LICENSE) y [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
