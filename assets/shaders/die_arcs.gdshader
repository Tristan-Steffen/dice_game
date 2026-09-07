shader_type spatial;
render_mode blend_add, depth_draw_never, depth_test_disabled, cull_back, unshaded,
	shadows_disabled;

// ÜBERSCHLAG (Ladung 3): FAHNEN - wenige lange Blitze, die aus den KANTEN des
// Würfels nach AUSSEN schlagen und bis zu einer Würfelbreite über ihn hinausragen,
// oft mit einem Ast (Spieler-Wahl 2026-09-07 aus Funken, Fahnen, Eckstrahlen,
// Krone, Bogen). Dieselbe Blitz-Maschine wie auf den Seiten, nur der ORT ist ein
// anderer: EIN kamerazugewandtes Quad um den Würfel (wie die Hitze), das die
// zwölf Kanten aus der Modell-Drehung in die Bildebene projiziert. Gezündet
// wird nur an SILHOUETTEN-Kanten (eine Nachbarseite schaut zur Kamera, die
// andere weg) - von einer Rückkante käme der Blitz mitten aus dem Körper.

#include "res://assets/shaders/die_lightning.gdshaderinc"

uniform vec2 quad_size = vec2(4.5, 4.5);
uniform float seed_base = 0.0;
uniform float phase = 0.0;
uniform float gain = 1.0;
uniform float rate = 1.0;
uniform vec3 halo_color = vec3(0.55, 0.65, 1.45);
uniform vec3 core_color = vec3(1.0, 0.96, 1.0);

const int SLOTS = 2;
const float CELL_LEN = 1.4;
const float CHANCE = 0.65;
const float STRIKE = 0.2;
const float AFTERGLOW = 0.5;
// Wie weit die Fahne hinausragt (Würfel-Halbmaß = 1), Zackigkeit, Ast-Chance.
const float LEN_LO = 0.55;
const float LEN_HI = 0.9;
const float AMP = 0.18;
const float BRANCH_CHANCE = 0.7;

varying mat3 view_rot;

void vertex() {
	// Billboard mit Modell-Skalierung (wie die_heat.gdshader).
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1],
		INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(0.0, 0.0, s, 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	// Die Drehung des Würfels im Blick der Kamera, ohne Skalierung.
	view_rot = mat3(VIEW_MATRIX) * mat3(MODEL_MATRIX) / s;
}

// Kante i (0..11): zwei festgenagelte Achsen, die dritte läuft. Liefert die
// Endpunkte in der Bildebene (Modell-Einheiten) und ob sie auf der SILHOUETTE liegt.
void edge(int i, out vec2 e0, out vec2 e1, out bool rim) {
	int run_axis = i / 4;
	int quad = i - run_axis * 4;
	float sa = (quad < 2) ? -1.0 : 1.0;
	float sb = (quad == 0 || quad == 2) ? -1.0 : 1.0;
	vec3 a = vec3(0.0);
	vec3 b = vec3(0.0);
	vec3 r = vec3(0.0);
	if (run_axis == 0) { r = vec3(1.0, 0.0, 0.0); a = vec3(0.0, sa, 0.0); b = vec3(0.0, 0.0, sb); }
	else if (run_axis == 1) { r = vec3(0.0, 1.0, 0.0); a = vec3(sa, 0.0, 0.0); b = vec3(0.0, 0.0, sb); }
	else { r = vec3(0.0, 0.0, 1.0); a = vec3(sa, 0.0, 0.0); b = vec3(0.0, sb, 0.0); }
	e0 = (view_rot * (a + b - r)).xy;
	e1 = (view_rot * (a + b + r)).xy;
	rim = ((view_rot * a).z > 0.0) != ((view_rot * b).z > 0.0);
}

void fragment() {
	vec2 p = (UV - 0.5) * quad_size;
	p.y = -p.y;
	float t = TIME + phase;
	float px = length(fwidth(p));
	float chance = min(CHANCE * rate, 0.95);

	vec3 acc = vec3(0.0);
	for (int s = 0; s < SLOTS; s++) {
		float cs;
		float age = strike_age(t, seed_base * 13.7 + float(s) * 101.3, CELL_LEN, chance,
			STRIKE + AFTERGLOW, cs);
		if (age < 0.0) { continue; }
		bool striking;
		float fade;
		float spread;
		float jit;
		float flicker;
		strike_shape(t, age, cs, STRIKE, AFTERGLOW, striking, fade, spread, jit, flicker);

		// Eine SILHOUETTEN-Kante: von der gewürfelten aus die nächste auf dem Umriss.
		int pick = int(hash11(cs + 3.0) * 12.0);
		vec2 e0;
		vec2 e1;
		bool rim = false;
		for (int k = 0; k < 12; k++) {
			int idx = pick + k;
			if (idx >= 12) { idx -= 12; }
			edge(idx, e0, e1, rim);
			if (rim) { break; }
		}
		if (!rim) { continue; }

		// Von der Kante nach AUSSEN, leicht schräg.
		vec2 a = mix(e0, e1, mix(0.1, 0.9, hash11(cs + 4.0)));
		vec2 outward = normalize(a + vec2(1e-4, 2e-4));
		vec2 side = vec2(-outward.y, outward.x);
		vec2 way = normalize(outward + side * (hash11(cs + 8.0) - 0.5) * 0.8);
		float len = mix(LEN_LO, LEN_HI, hash11(cs + 9.0));
		vec2 b = a + way * len;
		vec2 knot;
		float d = bolt_dist(p, a, b, 8, AMP, cs, jit, 3 + int(hash11(cs + 10.0) * 3.0), knot);
		acc += plasma_paint(d, px, striking, fade, spread, 1.0, halo_color, core_color) * flicker;
		if (hash11(cs + 11.0) < BRANCH_CHANCE) {
			vec2 tip = branch_tip(knot, way, len * 0.45, cs + 12.0);
			vec2 dummy;
			float bd = bolt_dist(p, knot, tip, 5, AMP * 1.3, cs + 40.0, jit, 99, dummy);
			acc += plasma_paint(bd, px, striking, fade, spread, 0.7, halo_color, core_color)
				* flicker * 0.6;
		}
		acc += halo_color * touch_glow(p, a, 0.14) * 0.7 * fade * flicker;
	}
	ALBEDO = acc * gain;
	ALPHA = 1.0;
}
