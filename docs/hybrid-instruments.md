# Indicadores eléctricos de Dial y GT7

El diseño sigue la opción C de `assets/Triptych Automotive Gauge Comparison.png`.
El arco CHG/PWR representa recuperación y entrega eléctrica; el arco fino del
bisel y el icono con porcentaje representan la carga de batería. Los datos son
independientes. Una carga de batería inferior o igual al 15 % usa rojo.

El dial independiente lo activa en Analog con **Auxiliary gauge > Auto** para
coches híbridos sin turbo. **Electric** permite seleccionarlo explícitamente,
también cuando el coche tiene turbo. Fuel, Turbo y Off conservan sus funciones.
GT7 lo activa automáticamente en el subinstrumento de RPM, tanto en Analog como
en Digital y en todas las composiciones. Su indicador de combustible se conserva.

## Telemetría

`src/hybrid.lua` detecta KERS/ERS mediante los campos que ofrece el coche en CSP.
Lee la carga desde `kersCharge`. Con física disponible, calcula la potencia
mecánica eléctrica total como la suma de `electricTorque * angularSpeed / 1000`
en las cuatro ruedas. La recuperación conserva el signo negativo. La escala se
amplía en pasos de 50 kW según los picos observados y se reinicia al cambiar de
coche; solo el relleno de los segmentos tiene suavizado.

Un canal de par siempre a cero se considera sin confirmar hasta recibir un valor
distinto de cero. Si faltan datos físicos o alguna rueda, se muestra **ERS %**
desde `kersInput`, sin convertir la carga de batería en potencia. Sin entrada ERS
se muestra `ERS --`; sin carga se muestra `--%` y el arco de batería queda inactivo.
Las repeticiones y los coches remotos no usan datos físicos indisponibles.

## Verificación de esta entrega

- Sintaxis Lua, pruebas de runtime, iluminación y layouts GT7 aprobadas.
- `tests/hybrid_instruments.lua`: conversión a kW, recuperación, cero medido,
  canales ausentes, cambio de coche, prioridad del turbo, integración de
  telemetría, dos temas, luces y tamaños de Dial/GT7 aprobados.
- Ajustes aprobados en Free y Premium. Timer final lap aprobado.
- El renderizador GT7 de Free y el dial con su paleta también se comprobaron
  mostrando potencia eléctrica y porcentaje de batería en ambos temas.
- Vistas obtenidas de las llamadas de dibujo Lua, revisadas en ambos temas:
  `python tools/preview-instruments.py --hybrid --output output/hybrid-instruments`.
- La suite completa sigue fallando en `tests/tyre_grip.lua:16` (media nil).
  `tests/timing_apps.lua:439` también falla porque espera el degradado antiguo de
  Laps. Ambos fallos se reprodujeron cargando los archivos originales de HEAD,
  anteriores a esta entrega; esos archivos no se modificaron.

Las vistas y las pruebas usan telemetría controlada. No se ha comprobado esta
entrega en una sesión de conducción con los hypercars instalados.

## Despliegue

`tools/install-retro-ui.ps1 -App instruments` respalda la instalación y copia
exclusivamente los dos renderizadores, los módulos compartidos necesarios y los
ajustes del dial. Verifica cada archivo con SHA256.
Para una instalación Free, añade `-Edition free` para copiar su renderizador GT7.
