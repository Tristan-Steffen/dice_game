// Emitter-Iris: flacher, in die Tischfläche eingelassener Dunkelglas-Port, aus
// dem der Strahl austritt (siehe DiceTrayView) - dieselbe Sprache wie die
// Charm-Projektor-Linsen. Dunkle Mitte, ein heißer Apertur-Ring in Tray-Farbe
// und ein winziger ÜBERHELLER Kern, den der HDR-Glow zum Sternpunkt aufblüht.
// pulse hebt Ring + Kern mit der Last (siehe _process).
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec3 tint : source_color = vec3(0.3, 0.68, 1.0);
uniform vec3 core_color : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 rim_color : source_color = vec3(0.78, 0.82, 0.94);  // Platin-Fassung
uniform float pulse : hint_range(0.0, 2.0) = 1.0;
uniform float core_gain : hint_range(0.0, 8.0) = 4.0;  // Überhelligkeit des Kerns (HDR -> Bloom)

varying vec2 uv;

void vertex() {
	uv = UV;
}

void fragment() {
	vec2 p = uv * 2.0 - 1.0;
	float r = length(p);
	float breathe = 0.85 + 0.15 * sin(TIME * 1.3);
	// Hauch farbiges Glas zum Rand hin (die Mitte bleibt dunkel = Port-Tiefe).
	float glass = smoothstep(1.0, 0.55, r) * smoothstep(0.15, 0.4, r) * 0.06;
	// Heißer Apertur-Ring, wo der Strahl austritt.
	float ring = smoothstep(0.07, 0.0, abs(r - 0.7));
	// Platin-Fassung am Rand (physische Lippe des eingelassenen Ports).
	float rim = smoothstep(0.05, 0.0, abs(r - 0.94));
	// Winziger überheller Kern -> HDR-Glow macht daraus einen Sternpunkt.
	float core = smoothstep(0.14, 0.0, r);
	float outside = step(1.0, r);
	vec3 col = tint * (glass + ring * (0.9 + 0.4 * pulse))
		+ rim_color * rim * 0.7
		+ core_color * core * core_gain * pulse;
	float a = (glass + ring * (0.7 + 0.3 * pulse) + rim * 0.6 + core * pulse) * breathe;
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0) * (1.0 - outside);
}
