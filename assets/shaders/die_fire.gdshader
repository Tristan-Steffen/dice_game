shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded, shadows_disabled;

// Der BRAND der Ladung (Stufe 2 orange, Stufe 3 blau): ein FLAMMENSAUM, der vom
// Kantenrahmen aus in die SEITE brennt (Spieler-Wahl 2026-09-11 in vier Runden -
// der Rahmen trägt die Essenz-Farbe und bleibt darum frei). EINE durchgehende
// Front aus Rauschen rund um die Seite: sie atmet, wirft Spitzen nach innen und
// läßt die Mitte mit dem Wert frei. Neon-Zeichnung in zwei Tönen (Füllung, Kern),
// heller Saum an der Front und am Rahmen. EIN Quad je Seite zwischen
// Runen-Auflage und Ziffer.

uniform float face_seed = 0.0;
uniform float phase = 0.0;
uniform float gain = 1.0;
uniform vec3 mid_color = vec3(1.35, 0.45, 0.08);
uniform vec3 core_color = vec3(1.45, 1.15, 0.55);

// Sockel der Front, Spitzenhöhe und Zittern, in Halbseiten (1 = bis zur Mitte).
const float BASE = 0.16;
const float PEAKS = 0.5;
const float JITTER = 0.12;
const float CORE_SHARE = 0.45;

float hash11(float x) { return fract(sin(x * 12.9898 + 4.1414) * 43758.5453); }
float hash21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vnoise(p);
		p = p * 2.07 + vec2(3.1, 1.7);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	float t = TIME + phase;
	vec2 p = (UV - 0.5) * 2.0;
	p.y = -p.y;
	float px = length(fwidth(p));
	// Abstand vom Rahmen nach innen; die Front läuft als Winkel-Rauschen rundum
	// (auf dem Einheitskreis abgetastet, damit sie an keiner Ecke reißt).
	float dr = 1.0 - max(abs(p.x), abs(p.y));
	float a = atan(p.y, p.x);
	vec2 ring = vec2(cos(a), sin(a));
	float n1 = fbm(ring * 2.2 + vec2(face_seed, -t * 0.9));
	float n2 = vnoise(ring * 6.0 + vec2(-t * 1.6, face_seed * 3.0));
	float peaks = pow(clamp(n1 * 1.6 - 0.35, 0.0, 1.0), 1.4);
	float h = (BASE + PEAKS * peaks + JITTER * n2) * gain;
	float f = h - dr;
	float fill = smoothstep(-px, px, f);
	float rim = 1.0 - smoothstep(-px * 2.5 - 0.022, 0.0, abs(f));
	float inner = smoothstep(-px, px, h * CORE_SHARE - dr + 0.02 * n2);
	rim = max(rim, (1.0 - smoothstep(0.0, 0.05, dr)) * 0.8);
	vec3 col = mix(mid_color, core_color, inner);
	col = mix(col, core_color * 1.15, rim);
	ALBEDO = col;
	ALPHA = clamp(fill * 0.85 + rim * 0.6, 0.0, 1.0);
	EMISSION = col * rim * 0.6;
}
