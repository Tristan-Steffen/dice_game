shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded, shadows_disabled;

// HITZE, die vom Würfel wegwabert, wie bei einem gefilmten heißen Körper: das
// Bild HINTER dem Feld wird wie heiße Luft verzerrt (Screen-Refraktion), nach
// oben ziehend, und eine orange-rote Glut liegt im Flimmern. EIN Billboard-Quad
// vor dem Würfel, und die Maske ist eine ENTFERNUNG zur Silhouette: an der
// Kante am stärksten (inner), nach außen weich verloschen (outer) - so hat das
// Feld keinen sichtbaren Rand. Über dem Körper selbst nur ein Rest der
// Verzerrung (inside) und keine Glut.

uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
// Kantenlänge des Quads in Modell-Einheiten (Würfel-Halbmaß = 1).
uniform vec2 quad_size = vec2(5.2, 5.2);
// Das Quad rückt der Kamera entgegen, damit es VOR dem Würfel liegt und dessen
// Kanten mitwabern.
uniform float lift = 1.6;
// Abstand vom Würfelmittelpunkt, ab dem die Hitze voll ist (die Silhouette) und
// wo sie verloschen ist.
uniform float inner = 1.05;
uniform float outer = 2.1;
// 0..1: nach oben gestreckt - Hitze steigt (Spieler-Wahl: 0,85).
uniform float rise = 0.85;
// Rest-Verzerrung über dem Körper.
uniform float inside = 0.3;
uniform float strength = 0.003;
uniform float speed = 1.0;
uniform float scale = 1.4;
uniform float phase = 0.0;
uniform vec3 tint = vec3(0.95, 0.24, 0.08);
uniform float tint_amount = 0.2;

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
	vec2 q = p;
	if (q.y > 0.0) {
		q.y /= 1.0 + rise * 1.8;
	}
	float r = length(q);
	float fall = 1.0 - smoothstep(inner, outer, r);
	float outside = smoothstep(inner - 0.3, inner + 0.12, r);
	float mask = mix(inside, 1.0, outside) * fall;
	float glow = outside * fall;
	// Zwei Oktaven, beide nach OBEN ziehend.
	vec2 p1 = vec2(p.x * scale, (p.y - t) * scale);
	vec2 p2 = vec2(p.x * scale * 2.3 + 7.3, (p.y - t * 1.7) * scale * 2.3);
	float n1 = vnoise(p1);
	float n2 = vnoise(p2);
	vec2 offset = (vec2(n1, n2) - 0.5) * 2.0 * strength * mask;
	vec3 seen = texture(screen_texture, SCREEN_UV + offset).rgb;
	ALBEDO = seen + tint * tint_amount * glow * (0.45 + 0.55 * n1);
	ALPHA = 1.0;
}
