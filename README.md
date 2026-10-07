# Retro UI

Retro UI reúne los instrumentos CSP Lua de Assetto Corsa en una sola app. El
dial digital/analógico, GT7, Car Condition, Multiclass Relative, Delta Bar,
Leaderboard, Telemetry y Map son ventanas independientes. GT7 y el dial pueden
mostrarse a la vez. **Retro UI Settings** ofrece una pestaña por instrumento.

## Requisitos

- Assetto Corsa para PC y Custom Shaders Patch con Lua apps habilitadas.
- Content Manager es recomendable para instalar el ZIP y activar la app.

## Lock in place

Haz clic derecho sobre cualquier ventana del HUD para fijar su posición; otro
clic derecho la libera. Cada ventana recuerda su posición y bloqueo de forma
independiente. Las marcas de alineación muestran brevemente **FIXED** (ámbar)
o **MOVE** (cian), siguiendo el tema seleccionado. En **FIXED**, el clic izquierdo
no activa controles ni arrastra el HUD; el clic derecho permite desbloquearlo.
Requiere CSP 0.2.3-preview62 o posterior para
mover ventanas IMGUI mediante la API de ventanas.

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

## Mapa, neumáticos y clasificación (2.5)

Las mejoras están disponibles en Free y Premium, con los temas retro claro y
oscuro. Los ajustes existentes y las cinco filas iniciales se conservan.

- **Map:** numeración de coches seleccionados o de todos. Jugador ámbar,
  líder morado, rivales de carrera verde y doblados/dobladores cian con distinta
  intensidad, según vueltas completadas. El aro ámbar señala cuatro ruedas
  fuera de pista y no se activa en el pitlane.
- **General:** unidades de presión psi, bar o kPa, además de °C/°F.
- **Condition > Wheel readout:** vida, presión actual/delta ideal o temperatura
  core/superficie/mezcla. El selector aplica a las cuatro ruedas. Si no existe
  una medición, se oculta el número correspondiente.
- **Condition > Keep tyre detail open:** fija el detalle aun con el HUD bloqueado.
  También se abre por hover en la zona superior o al entrar en pitlane, y permanece
  diez segundos después de salir. Funciona con cualquier leyenda, incluida None.
- El detalle presenta stint en vueltas/km, compuesto, presión ideal por eje,
  rango térmico y perfil de grip cuando está disponible. Las referencias de la
  física tienen prioridad, también en GT3. **Estimated references** permite
  editar los valores de respaldo; `~` identifica referencias y stints estimados.
  **FROM OBSERVATION** indica que no se ha podido reconstruir el uso anterior.
- **Leaderboard:** permite 3–10 filas. Práctica/clasificación muestran sectores,
  mejor vuelta y gap; carrera muestra cambios de posición, intervalos respecto
  al jugador y última vuelta. Prioriza tiempos de CSP e historial de posición;
  si falta historial, estima por distancia y velocidad y lo indica con `~`.
  Los sectores de validez desconocida quedan
  neutros. Las vueltas inválidas no actualizan récords de sectores.
  Las filas son compactas y no repiten etiquetas bajo los datos; los cambios de
  posición aparecen junto al puesto y se ocultan los ceros redundantes.
- Las repeticiones reconstruyen el estado al cambiar de momento. No se añade
  un registro propio al archivo: algunos datos pueden faltar o ser aproximados,
  Los intervalos reconstruyen su historial tras cada salto; las estimaciones
  por distancia y velocidad se indican con `~`.

## Ajustes

Los híbridos sin turbo sustituyen automáticamente el indicador de boost por
entrega eléctrica y carga de batería, siguiendo la opción C de Triptych. En el
dial independiente se usa **Analog > Auxiliary gauge > Auto**; **Electric**
permite forzarlo también en híbridos con turbo. GT7 lo muestra en su indicador
auxiliar de RPM. El arco CHG/PWR usa verde para recuperación y cian para entrega;
el arco del bisel y el porcentaje indican la batería. Si el mod no ofrece par
eléctrico válido, la lectura se identifica como **ERS %**. Más detalles y
verificación en [Indicadores eléctricos](docs/hybrid-instruments.md).

**Condition > Personalization > Core weight** permite mezclar la temperatura del
núcleo y la superficie de los neumáticos entre 0 % y 100 % core. El porcentaje
surface es el complementario; el valor inicial es 80 % core / 20 % surface y
se guarda entre sesiones. Se aplica a **Core + surface zones** y **Core + surface uniform**;
**Surface zones** utiliza las lecturas de superficie. Los resets restauran 80/20.

**GT7 Premium > Personalization** permite combinar por separado la
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
**Speed needle** y **RPM needle** usan sliders de 24 pasos independientes.
Se encuentran en **GT7 → Personalization → Side dials**, aparecen únicamente
en modo Analog y aplican el cambio directamente al HUD. Las variantes están identificadas como **A01–D06** según los seis recuadros inferiores de
`assets/needle a.png` a `assets/needle d.png`. Cada variante conserva su cuerpo,
punta, contrapeso y centro; sus ranuras y perforaciones dejan ver el fondo real.
Las nueve selecciones anteriores migran automáticamente a su referencia equivalente.
Las luces reales del coche activan una retroiluminación gradual, incluso si se
oculta el indicador de luces.

En **Advanced**, **Simulate vacuum near zero boost** añade un vacío estimado
por acelerador mientras gira el motor. Su mínimo inicial es −0.5 bar y se puede
ajustar o desactivar; entre 0 y 0.02 bar se mezcla gradualmente con el vacío
para tolerar residuos de telemetría. Desde 0.02 bar se usa el boost real de CSP.
El SDK de apps no ofrece vacío real. Los ajustes se comprueban directamente
con la telemetría del HUD; el antiguo simulador de previsualización se ha retirado.

En **GT7 → Personalization → Side dials**, **Side dial scale** ajusta ambos instrumentos entre
0.75× y 1.25× y **Side dial spacing** añade de 0 a 160 píxeles de separación
respecto al centro. Los valores neutros son 1× y 0; el encaje en la ventana se
recalcula para incluir los dials y sus indicadores. En la composición de pedales
exteriores, esas barras acompañan al grupo lateral para conservar su espacio.
Fuel y boost analógicos superponen los segmentos de llenado sobre el mismo arco
de divisiones, con la aguja por encima. Las marcas principales son más anchas
y las subdivisiones menores más finas y próximas.
Fuel y boost comparten la superficie del dial; una banda elevada respalda las
cifras de las escalas principales.

**Status indicator scale** ajusta los indicadores circulares inferiores entre
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

En **Dial > Personalization**, el modo Analog ofrece el slider **RPM needle**
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
solo se dibuja el modo seleccionado. **General > Background opacity** controla
la intensidad de ambos fondos y la superficie se desvanece hacia el borde circular.
**Dot thickness** permite ampliar los puntos hasta 4×. Por defecto son un 15 % más gruesos que antes y se
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

**General** controla tema, unidades y opacidades de contenido y fondo para
las diez ventanas del HUD. Los fondos conservan la intensidad propia de cada
diseño: los puntos del mapa siguen siendo más sutiles que su superficie.
Escala, proporciones y tamaños continúan siendo locales. Los umbrales RPM,
RPM de respaldo y parpadeos de Dial y GT7 también se configuran en General.
Depuración y detección de clases permanecen en cada instrumento.

En cualquiera de las diez ventanas HUD, haz clic derecho para anclarla en su
posición actual. Otro clic derecho sobre ella la libera. El anclaje y la
posición se conservan al reiniciar el juego; mientras está anclada, la ventana
deja pasar el mouse para que puedas interactuar con lo que queda debajo. Este
paso requiere CSP 0.2.8 o una versión posterior.
**Retro UI Settings** permanece interactiva.

Todas las páginas abren **Basics**; **Personalization** y **Advanced** se
despliegan cuando hacen falta. En GT7 Premium, Basics contiene cuatro botones
de preset, escala y modos de los diales. Los presets cambian solo composición;
**Custom** identifica una combinación personalizada y cualquier preset puede
reaplicarse con un clic. Personalization agrupa Side dials, Center and pedals,
Lower panel y Radar and flags. Free muestra los controles de GT7 Classic.
Dial usa su propio slider de aguja en Personalization cuando está en Analog.

Al actualizar, tema, unidades y ajustes locales se conservan. Los nuevos
valores globales arrancan una sola vez con contenido al 100 %, fondo al 72 %,
umbrales RPM al 86 % y 96 %, respaldo de 8000 RPM y parpadeos activados.
**Reset appearance** restaura el aspecto local; **Reset all** pide confirmación
para restaurar el instrumento. General dispone de sus propios resets compartidos.
En Relative y Leaderboard, Reset all también restaura `classes.ini` y guarda
una copia anterior en `Documents/Assetto Corsa/RetroUI/Class Backups`.

## Desarrollo

Los archivos de las cuatro apps externas están integrados bajo `modules/`.
Cada uno usa rutas `require()` y claves de almacenamiento separadas. El
manifiesto CSP expone diez ventanas HUD y Settings en un único proceso. El
paquete distribuye los archivos Lua, los mapas de clases, los recursos y las licencias.

Para crear los paquetes locales, ejecuta `tools/build-package.ps1` con
`-Edition free` o `-Edition premium`. El paquete Free conserva el layout GT7
Classic; Premium incluye el editor por componentes y los presets Classic,
Modern, Outer Pedals y Steering Dial. El
instalador usa Premium por defecto; para instalar Free, añade `-Edition free`.
Las etiquetas `vX.Y.Z` generan y adjuntan ambos ZIP mediante GitHub Actions.
La distribución en ZIP separados no cambia la licencia MIT del código que ya
la incluye ni impide por sí sola redistribuirlo.

`npm run check:lua` comprueba sintaxis, módulos y callbacks CSP, incluidos
los archivos Free y las pruebas. `python tools/test-lua.py` ejecuta todas las
suites con Lupa y Lua 5.2, incluyendo los ajustes Premium y Free en runtimes
separados. `tests/settings.lua` verifica las once páginas, migración, sliders,
presets, resets y aplicación única de opacidad en las diez ventanas HUD. Con Lua 5.2
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
los tres sliders independientes, la persistencia y los resets, con 768 escenarios GT7 y 864 del dial independiente. También ejecuta
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
