# Indicadores eléctricos de Dial y GT7

El diseño sigue la opción C de `assets/Triptych Automotive Gauge Comparison.png`.
El arco CHG/PWR representa recuperación y entrega eléctrica; el arco fino del
bisel y el icono con porcentaje representan la carga de batería. Los datos son
independientes. Una carga de batería inferior o igual al 15 % usa rojo.

El dial independiente lo activa en Analog con **Auxiliary gauge > Auto** para
coches híbridos, también cuando tienen turbo. **Electric** permite seleccionarlo
explícitamente. Fuel, Turbo y Off conservan sus funciones.
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

Si el coche no publica par negativo durante la recuperación, el indicador usa
la señal `kersCharging` y el aumento real de `kersCharge`. En ese caso muestra
una tasa negativa de carga en puntos porcentuales por segundo (por ejemplo,
`-2.0%/s`), en verde en el lado CHG. Con señal de carga pero sin una tasa válida,
muestra `CHG` y un segmento activo. Esta lectura describe la carga neta de la
batería; los kW siguen reservados para la potencia mecánica medida en las ruedas.
El muestreo de 0,1 segundos descarta saltos de carga, pausas, reinicios, cambios
de coche o sesión y retrocesos de tiempo. Las repeticiones no calculan tasas
contra el tiempo de actualización del HUD. El cambio entre CHG y PWR actualiza
el signo inmediatamente y suaviza la amplitud dentro de cada lado.

## Verificación de esta entrega

- Sintaxis Lua, pruebas de runtime, iluminación y layouts GT7 aprobadas.
- `tests/hybrid_instruments.lua`: conversión a kW, recuperación, cero medido,
  canales ausentes, cambio de coche, prioridad de batería en híbridos con y sin turbo, integración de
  telemetría, dos temas, luces y tamaños de Dial/GT7 aprobados.
- Ajustes y Timer final lap aprobados en la distribución completa.
- `tests/hybrid_regeneration.lua`: recuperación con par cero, ausente o positivo
  durante la frenada, prioridad de kW negativos medidos, señal de carga ausente,
  transiciones, reinicios, repeticiones y dibujo en Dial/GT7 aprobados.
- Vistas de recuperación obtenidas del cálculo y dibujo Lua reales, revisadas
  en ambos temas y en Dial/GT7 Analog/Digital: `output/hybrid-regeneration/`.
- Vistas obtenidas de las llamadas de dibujo Lua, revisadas en ambos temas:
  `python tools/preview-instruments.py --hybrid --output output/hybrid-instruments`.
- La suite completa pasa en la distribución única de Retro UI 2.5.1.

Las vistas y las pruebas usan telemetría controlada. El autor confirmó la
validación conduciendo durante la semana y las actualizaciones con cada release.

## Despliegue

`tools/install-retro-ui.ps1 -App instruments` respalda la instalación y copia
exclusivamente los dos renderizadores, los módulos compartidos necesarios y los
ajustes del dial. Verifica cada archivo con SHA256.
La distribución única incluye todos los renderizadores y opciones.
