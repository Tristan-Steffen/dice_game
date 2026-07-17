// Stasis-Emitter unter jedem Tray-Würfel: flache Leuchtscheibe auf dem Filz.
// Instrumenten-Optik: Platin-Blendenring, feiner Innenring, drei langsam
// rotierende Bogensegmente dazwischen, atmendes Innenfeld. Beim Einrasten
// eines Würfels (impact 0->1, siehe DiceTrayView.add_die) läuft ein heller
// Ring nach außen.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec3 tint : source_color = vec3(0.25, 0.5, 1.0);   // Tray-Identitätsfarbe
uniform vec3 rim_color : source_color = vec3(0.78, 0.82, 0.94);  // Platin
uniform float impact : hint_range(0.0, 1.0) = 0.0;  // 0 = ruhig, läuft beim Einrasten 0->1
uniform float intensity : hint_range(0.0, 4.0) = 1.0;
uniform float arc_speed = 0.03;  // Umdrehungen/s der Bogensegmente

varying vec2 uv;

void vertex() {
	uv = UV;
}

void fragment() {
	vec2 p = uv * 2.0 - 1.0;
	float r = length(p);
	float ang = atan(p.y, p.x) / TAU;  // -0.5 .. 0.5
	// Atmendes Feld innerhalb der Blende, zur Mitte hin heller.
	float breathe = 0.8 + 0.2 * sin(TIME * 1.3);
	float field = smoothstep(0.8, 0.0, r) * 0.13 * breathe;
	// Blendenring (Platin) + feiner Innenring in Tray-Farbe.
	float rim = smoothstep(0.05, 0.0, abs(r - 0.84));
	float ring2 = smoothstep(0.025, 0.0, abs(r - 0.56)) * 0.45;
	// Drei rotierende Bogensegmente zwischen den Ringen (je ~60% Bogen, 40% Lücke).
	float arc_gate = 1.0 - smoothstep(0.28, 0.35, abs(fract((ang + TIME * arc_speed) * 3.0) - 0.5));
	float arcs = smoothstep(0.045, 0.0, abs(r - 0.7)) * arc_gate * 0.8;
	// Einrast-Ripple: Ringradius wandert mit impact nach außen, blendet zum Rand aus.
	float ripple = smoothstep(0.09, 0.0, abs(r - impact)) * impact * (1.0 - impact);
	float outside = step(1.0, r);
	vec3 col = tint * (field + ring2 + arcs + ripple * 3.0) + rim_color * rim * 0.85;
	float a = (field + rim + ring2 + arcs + ripple * 3.0) * intensity * (1.0 - outside);
	ALBEDO = col;
	ALPHA = clamp(a, 0.0, 1.0);
}
