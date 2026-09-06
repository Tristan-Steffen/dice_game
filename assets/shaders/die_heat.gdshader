shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded, shadows_disabled;

// HITZE, die AUS dem Würfel kommt: das Bild HINTER dem Feld wird wie heiße Luft
// verzerrt (Screen-Refraktion), die Schlieren werden vom Körper WEG getrieben,
// und eine orange-rote Glut liegt darin. EIN Billboard-Quad vor dem Würfel; das
// Feld beginnt an der Silhouette und verlöscht mit dem Abstand. Wo es nichts tut,
// ist es DURCHSICHTIG (ALPHA folgt dem Feld) - der Bildschirm-Abzug hinkt einen
// Frame nach, ein deckend geschriebener Rand zeichnete sich als Quadrat ab.
// Die Schlieren strömen RUNDUM nach außen, oben etwas weiter (Spieler-Wahl
// 2026-09-06 "Ausdünstung" nach vier Runden Varianten).

uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
// Kantenlänge des Quads in Modell-Einheiten (Würfel-Halbmaß = 1).
uniform vec2 quad_size = vec2(5.6, 5.6);
// Das Quad rückt der Kamera entgegen, damit es VOR dem Würfel liegt.
uniform float lift = 1.6;
// Die Silhouette (Würfel-Halbmaß) und wie schnell die Hitze mit dem Abstand fällt.
uniform float inner = 1.0;
uniform float reach = 1.6;
// Rest-Verzerrung über dem Körper.
uniform float inside = 0.25;
uniform float strength = 0.0022;
uniform float speed = 0.9;
uniform float scale = 1.5;
uniform float phase = 0.0;
uniform vec3 tint = vec3(0.95, 0.24, 0.08);
uniform float tint_amount = 0.18;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Wert-Rauschen, weich interpoliert - Hitzeschlieren, keine Kanten.
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x), f.y);
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
	float t = TIME * speed + phase;
	// Lage im Quad in Modell-Einheiten, y nach OBEN.
	vec2 p = (UV - 0.5) * quad_size;
	p.y = -p.y;
	// Abstand zur Silhouette: halb Kreis, halb Quadrat - der Würfel ist beides.
	float d = mix(length(p), max(abs(p.x), abs(p.y)), 0.5) - inner;
	// Über dem Körper (d < 0) nur der Rest, ab der Silhouette voll.
	float body = smoothstep(-0.35, 0.05, d);
	// Rundum nach außen, oben etwas weiter.
	float lift_up = 1.0 + 0.5 * clamp(p.y / inner, 0.0, 1.0);
	float field = exp(-max(d, 0.0) * 2.0 / (reach * lift_up));
	float a = atan(p.y, p.x);
	// Polar: die Wellen laufen mit r - t nach AUSSEN.
	vec2 drift = vec2(a * 2.2 - p.x * scale, -(length(p) - t * 0.8) * scale + p.y * scale);
	float mask = field * mix(inside, 1.0, body);
	// Zwei Oktaven, mit der Drift vom Körper weg.
	vec2 p1 = (p + drift) * scale;
	vec2 p2 = (p + drift * 1.7) * scale * 2.3 + vec2(7.3, 1.9);
	float n1 = vnoise(p1);
	float n2 = vnoise(p2);
	vec2 offset = (vec2(n1, n2) - 0.5) * 2.0 * strength * mask;
	vec3 seen = texture(screen_texture, SCREEN_UV + offset).rgb;
	float glow = field * body * (0.4 + 0.6 * n1);
	ALBEDO = seen + tint * tint_amount * glow;
	// Durchsichtig, wo das Feld nichts tut - kein Quadrat.
	ALPHA = clamp(mask * 2.5 + glow, 0.0, 1.0);
}
