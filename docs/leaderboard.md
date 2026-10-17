# Leaderboard

The header combines the current lap and session total. A timed race marks the
projected total with `~`. Time remaining and lap values use larger numerals;
position changes use a wider column beside the position badge. Time, lap and
temperature values omit their labels to use the available height. Air temperature
is displayed before track temperature. The tyre compound column has been removed
to leave more space around the larger connection bars.

## Connection quality

Enable **Show online connection quality** in Leaderboard → Personalization.
Five bars appear beside each human driver's status in live online sessions.
AI and replays have no indicator. Hover over the bars for the smoothed ping.

| Smoothed ping | Lit bars |
| --- | --- |
| ≤60 ms | 5 |
| ≤100 ms | 4 |
| ≤150 ms | 3 |
| ≤250 ms | 2 |
| >250 ms | 1 |
| Missing or disconnected | Dim bars |

The smoothing uses a two-second time constant. Disconnects, missing samples,
driver replacements and session changes clear the previous reading.

## Fuel calculator

- **FUEL:** current fuel in litres.
- **USE:** median fuel consumption of up to five valid observed laps, in litres
  per lap. No consumption estimate is shown before a usable lap is observed.
- **RANGE:** complete laps available after subtracting the configured reserve.
- **FINISH:** estimated surplus or shortfall in litres at the end of the race,
  after allowing for the reserve. Green is a surplus; red is a shortfall.
- **TANK:** current fuel divided by tank capacity. The horizontal bar represents
  this percentage, not the fuel required to reach the finish.
- **RES:** the configured fuel reserve, in litres.

`--` means there is no usable estimate yet. FINISH also needs a race-distance
estimate; in timed races this depends on the leader's best lap. It uses the
existing conservative remaining-lap calculation, including the current lap.

Fuel calculations continue to refer to the local player's car.

Generate previews of the actual Lua renderer with
`python tools/preview-leaderboard.py`. Add `--before-ref <git-ref>` to compare
against an earlier committed layout. Images are written to `output/leaderboard/`.
