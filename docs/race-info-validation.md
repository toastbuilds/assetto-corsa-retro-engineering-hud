# Retro UI 2.5 — verificación

## Cambios comprobados

- Mapa: 72 escenarios de dibujo; numeración, vueltas completadas, colores,
  coches ocultos/desconectados, pitlane, aro de cuatro ruedas y límites de ventana.
- Neumáticos: unidades, lecturas ausentes, referencias reales/estimadas,
  reposición del mismo compuesto, cruces de meta, reinicios, reconexiones,
  distancia real, calibración del uso previo y saltos en repeticiones.
- Condition: selector único para las cuatro ruedas; detalle por hover, Settings
  y pitlane; cuenta atrás pausada con el juego; ambos temas y escalas.
- Leaderboard: 3–10 filas, sectores de color sin tiempos numéricos, validez,
  clases, balance y notificaciones, FIN, modos personales e intervalos medidos.
- Se corrigió la carga del compuesto base y la conservación del punto inicial
  de las curvas de grip, cubiertas por `tests/tyre_grip.lua`.

Las suites nuevas están registradas en `tools/test-lua.py`. La comprobación
`npm run check:lua` incluye los módulos, ambas ediciones, pruebas y callbacks.
Las previsualizaciones de Condition se generan con:

```powershell
python tools/preview-race-info.py
```

Utilizan el renderer Lua real y métricas de Consolas sobre dobles del SDK;
no sustituyen la comprobación de telemetría y antialiasing dentro del juego.

## Resultado global

`npm run check:lua` y `python tools/test-lua.py` completan sin errores en
Premium y Free. La validación incluye el sombreado final de Laps y el balance
compacto de posiciones del Leaderboard.

## Comprobación pendiente en Assetto Corsa

- Conducir un stint, atravesar boxes y reponer el mismo compuesto.
- Verificar datos de un coche oficial y un mod sin referencias físicas.
- Comprobar práctica, clasificación y carrera online con cambios de posición.
- Abrir una repetición y cambiar de momento; comprobar reconstrucción e
  intervalos ausentes hasta disponer de cruces comparables.

Las repeticiones no incorporan un registro adicional. Un stint anterior
puede quedar aproximado o contar desde observación cuando faltan datos.
