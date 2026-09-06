shader_type spatial;
render_mode blend_mix, depth_draw_never, depth_test_disabled, cull_back, unshaded,
	shadows_disabled;

// HITZE, die AUS dem Würfel kommt: das Bild HINTER dem Feld wird wie heiße Luft
// verzerrt (Screen-Refraktion), in WELLEN, die radial nach außen laufen, und eine
// orange-rote Glut reitet auf ihren Kämmen. EIN Billboard-Quad vor dem Würfel; das
// Feld beginnt an der Silhouette, verlöscht mit dem Abstand und ist vor dem
// Quad-Rand sicher null - ein Rest dort las als Kante. Wo es nichts tut, ist es
// DURCHSICHTIG (ALPHA folgt dem Feld).
//
// KEIN Tiefentest (2026-09-06): das Feld ist eine flache Scheibe in KONSTANTER
// Tiefe, die Tischfläche dagegen eine schräg weglaufende Ebene - UNTERHALB des
// Würfels liegt sie näher an der Kamera und schnitt das Feld weg. Genau das war
// der Grund, warum die Hitze nur oberhalb erschien.
//
// mode: 0 Ringe (klare, gleichmäßig auslaufende Fronten), 1 Schwaden (runde
// Ballen, die nach außen treiben), 2 Brandung (Ringe mit verbeulten Fronten).

uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
uniform float mode = 0.0;
// Kantenlänge des Quads in Modell-Einheiten (Würfel-Halbmaß = 1).
uniform vec2 quad_size = vec2(7.0, 7.0);
// Das Quad rückt der Kamera entgegen, damit es VOR dem Würfel liegt.
uniform float lift = 1.6;
// Die Silhouette (Würfel-Halbmaß) und wie schnell die Hitze mit dem Abstand fällt.
uniform float inner = 1.0;
uniform float reach = 1.9;
// Rest-Verzerrung über dem Körper.
uniform float inside = 0.25;
uniform float strength = 0.0022;
// Wellenzahl (Fronten je Modell-Einheit) und wie schnell sie auslaufen - das
// Tempo ist bewusst niedrig: eine Front braucht rund zehn Sekunden nach außen.
uniform float wave_freq = 4.4;
uniform float wave_speed = 0.15;
// Zahl der Ballen rundum - ganzzahlig, damit das Winkel-Rauschen nahtlos schließt.
uniform float blobs = 7.0;
uniform float phase = 0.0;
uniform vec3 tint = vec3(0.95, 0.24, 0.08);
uniform float tint_amount = 0.26;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Wert-Rauschen, das in x nahtlos schließt (Periode period): der Ring aus Ballen
// hat damit keine Naht bei ±π.
float ring_noise(vec2 p, float period) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float x0 = mod(i.x, period);
	float x1 = mod(i.x + 1.0, period);
	return mix(
		mix(hash21(vec2(x0, i.y)), hash21(vec2(x1, i.y)), f.x),
		mix(hash21(vec2(x0, i.y + 1.0)), hash21(vec2(x1, i.y + 1.0)), f.x), f.y);
}

void vertex() {
	// Billboard mit Modell-Skalierung, dann der Kamera entgegen.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(0.0, 0.0, s, 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX[3].z += lift * s;
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	float t = TIME + phase;
	// Lage im Quad in Modell-Einheiten, y nach OBEN.
	vec2 p = (UV - 0.5) * quad_size;
	p.y = -p.y;
	float r = length(p);
	// Abstand zur Silhouette: halb Kreis, halb Quadrat - der Würfel ist beides.
	float d = mix(r, max(abs(p.x), abs(p.y)), 0.5) - inner;
	// Über dem Körper (d < 0) nur der Rest, ab der Silhouette voll.
	float body = smoothstep(-0.35, 0.05, d);
	float field = exp(-max(d, 0.0) * 2.0 / reach);
	float half_span = min(quad_size.x, quad_size.y) * 0.5;
	field *= 1.0 - smoothstep(half_span - 1.4, half_span - 0.2,
		max(abs(p.x), abs(p.y)));
	vec2 dir = normalize(p + vec2(0.0001, 0.0002));
	// Winkel als nahtlos schließende Achse: 0..blobs, ganzzahlige Periode.
	float ang = (atan(p.y, p.x) / TAU + 0.5) * blobs;

	// Die WELLE (-1..1) läuft mit r - t nach AUSSEN, in jede Richtung gleich.
	float front = r - t * wave_speed;
	float wave;
	if (mode < 0.5) {
		wave = sin(front * wave_freq);
	} else if (mode < 1.5) {
		// Schwaden: das Rauschen wandert MIT der Front, seine Ballen sind darum
		// runde Wolken statt radialer Striche.
		float n = ring_noise(vec2(ang, front * wave_freq * 0.16), blobs);
		wave = smoothstep(0.28, 0.86, n) * 2.0 - 1.0;
	} else {
		// Brandung: Ringe, deren Fronten das Rauschen verbeult.
		float wob = ring_noise(vec2(ang, t * 0.25), blobs) - 0.5;
		wave = sin((front + wob * 1.1) * wave_freq);
	}

	// Der Versatz zeigt RADIAL: eine auslaufende Front schiebt das Bild vor sich
	// her. dir.y ist Modell-oben, SCREEN_UV.y läuft nach unten.
	float amp = field * mix(inside, 1.0, body);
	vec2 offset = vec2(dir.x, -dir.y) * wave * strength * amp;
	vec3 seen = texture(screen_texture, SCREEN_UV + offset).rgb;
	// Die Glut reitet auf den Kämmen, aber nur noch schwach: sie ATMET, sie
	// blinkt nicht (Spieler-Wunsch 2026-09-06 "langsamer und weniger auffällig").
	float glow = field * body * (0.78 + 0.22 * wave);
	ALBEDO = seen + tint * tint_amount * max(glow, 0.0);
	// Durchsichtig, wo das Feld nichts tut - kein Quadrat.
	ALPHA = clamp(field * 2.5 + max(glow, 0.0), 0.0, 1.0);
}
