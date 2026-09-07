shader_type spatial;
render_mode blend_add, depth_draw_never, cull_back, unshaded, shadows_disabled;

// PLASMA-BLITZE des Kriechstroms (Spieler-Wahl 2026-09-06 aus fünf Zeichenstilen):
// weiche, breite Fäden, die von einer Kante zu einer anderen über die Seite
// springen. Der SCHLAG ist KURZ (STRIKE 0,2 s), dann steht die Bahn still und
// GLIMMT NACH (AFTERGLOW 0,5 s) - das langsame Wandern über zwei Sekunden war
// dem Spieler zu träge. Lange, zufällige Lücke bis zum nächsten.
//
// EIN Quad je Seite, knapp über der Fläche, in SEITEN-Koordinaten -1..1 (der
// Rand liegt in der Mitte der Kantenröhre - die Fäden KOMMEN aus den Kanten).
// Additiv und unbeleuchtet: sie hellen nur auf.
//
// Verworfen (2026-09-06): Licht AUF der Kantenröhre (las als Lichterkette) und
// die Stile Neon, Comic, Pixel, Lichtenberg.

#include "res://assets/shaders/die_lightning.gdshaderinc"

uniform float face_seed = 0.0;
uniform float phase = 0.0;
// Helligkeit und Häufigkeit (Überschlag: mehr und heißer).
uniform float gain = 1.0;
uniform float rate = 1.0;
uniform vec3 halo_color = vec3(0.86, 0.66, 1.35);
uniform vec3 core_color = vec3(1.0, 0.96, 1.0);

// Zellenlänge und Zünd-Chance je Zelle (1,6 s: 3,2 war dem Spieler zu selten),
// Schlag und Nachglühen in Sekunden, Zackigkeit.
const float CELL_LEN = 1.6;
const float CHANCE = 0.6;
const float STRIKE = 0.2;
const float AFTERGLOW = 0.5;
const float AMP = 0.2;

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	p.y = -p.y;
	float t = TIME + phase;
	float px = length(fwidth(p));

	vec3 acc = vec3(0.0);
	float cs;
	float age = strike_age(t, face_seed * 13.7, CELL_LEN, min(CHANCE * rate, 0.95),
		STRIKE + AFTERGLOW, cs);
	if (age >= 0.0) {
		bool striking;
		float fade;
		float spread;
		float jit;
		float flicker;
		strike_shape(t, age, cs, STRIKE, AFTERGLOW, striking, fade, spread, jit, flicker);
		vec2 a;
		vec2 b;
		rim_pair(cs, a, b);
		vec2 knot;
		float d = bolt_dist(p, a, b, 10, AMP, cs, jit, 99, knot);
		acc += plasma_paint(d, px, striking, fade, spread, 1.0, halo_color, core_color) * flicker;
		acc += halo_color * (touch_glow(p, a, 0.16) + touch_glow(p, b, 0.16)) * 0.6 * fade * flicker;
	}
	ALBEDO = acc * gain;
	ALPHA = 1.0;
}
