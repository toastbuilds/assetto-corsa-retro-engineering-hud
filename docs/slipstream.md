# GT7 slipstream background

Enable **Show slipstream background** under GT7 → Personalization → Side dials.
It is enabled by default and restored by Reset all.

All selectable speed dial styles, analog and digital, add a radial background in
the theme's amber accent. Stronger slipstream produces a brighter, wider glow,
with a maximum combined opacity of 0.52. The glow pulses with a smooth fade in
and out, accelerating from about 0.55 pulses per second at low intensity to
1.6 at maximum intensity. The shape stays inside the central face and leaves
fuel, graduations, readouts and needles in the foreground. RPM dials and the
standalone Dial are not affected.

The display follows the focused car. It estimates a wake behind moving traffic
within 120 m, at speeds above 60 km/h. Cars must travel in a similar direction,
be laterally aligned and lie near the same local road plane. AI traffic can
produce a wake. Disconnected online cars, pitlane traffic and recently jumped
cars are excluded. Multiple wakes are not added together.

For a live focused car with available physics, CSP's `StateCarPhysics.airDensity` can provide
additional evidence. A clean-air reference is learned while no eligible car is
ahead within 240 m. Pressure and ambient temperature compensate for atmospheric
changes. Before a reference is available, or when physics/environment data is
missing, detection uses geometry. Replays and remote focused cars also use
geometry. Both sources share the same color; neither is a horsepower meter.

Physics intensity is scaled relative to the learned reference, reaching the
visual maximum at a 20% density reduction. That is a presentation scale, not an
assertion of a 20% power or drag benefit. Geometric intensity is approximate and
depends on distance, alignment and vehicle speeds. It cannot reproduce every
car's or server's slipstream physics settings.

The tint fades in with a 0.2 s time constant and out with a 0.5 s time constant.
Pausing freezes the filter and the pulse. Changing focus, restarting a session, seeking a
replay or jumping clears the old reference and intensity. Pitlane hides it.

GT7's developer view exposes `WAKE` source, relative intensity, target index,
distance and relative density reduction. It displays `estimated`, `physics` or
`unavailable`.

Generate real instrument drawing previews with `python tools/preview-slipstream.py`.
The script generates every selectable speed face in both themes, at off, medium
and maximum intensity, without launching the game or running test suites.

Preview the animated glow with `python tools/preview-slipstream-gif.py`.
It writes `output/slipstream/slipstream-pulse.gif` using the real Lua dial renderer
and simulated wake strength. Add `--mode digital` to preview the digital face.
