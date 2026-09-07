shader_type spatial;
render_mode blend_add, depth_draw_never, depth_test_disabled, cull_back, unshaded,
	shadows_disabled;

// ÜBERSCHLAG (Ladung 3): Blitze, die aus den KANTEN des Würfels nach AUSSEN
// schlagen und ein Stück über ihn hinausragen. Dieselbe Blitz-Maschine wie die
// Seiten-Blitze der Stufe 2 (die_bolts.gdshader: Zufallsweg als Brücke, kurzer
// Schlag mit Zittern, dann eingefrorenes Nachglühen), nur der ORT ist ein anderer:
// EIN kamerazugewandtes Quad um den Würfel (wie die Hitze), das die zwölf Kanten
// aus der Modell-Drehung in die Bildebene projiziert. Gezündet wird nur an
// SILHOUETTEN-Kanten (eine Nachbarseite schaut zur Kamera, die andere weg) -
// von einer Rückkante käme der Blitz mitten aus dem Körper.
//
// arc_style ist der Autoren-Schalter der fünf Fassungen (Spieler-Wahl offen):
// 0 FUNKEN     - viele kurze Zacken aus zufälligen Kanten
// 1 FAHNEN     - wenige lange Bahnen mit einem Ast
// 2 ECKSTRAHLEN - aus den Silhouetten-Ecken, gegabelt
// 3 KRONE      - ein Schlag fächert drei Bahnen aus derselben Stelle
// 4 BOGEN      - der Blitz schlägt AUSSEN um den Würfel von Kante zu Kante über

uniform vec2 quad_size = vec2(4.5, 4.5);
uniform float seed_base = 0.0;
uniform float phase = 0.0;
uniform float arc_style = 0.0;
uniform float gain = 1.0;
uniform float rate = 1.0;
uniform vec3 halo_color = vec3(0.86, 0.66, 1.35);
uniform vec3 core_color = vec3(1.0, 0.96, 1.0);

const int SEGMENTS = 8;
const float STRIKE = 0.2;
const float AFTERGLOW = 0.5;
const float LIFE = STRIKE + AFTERGLOW;
const float JITTER_RATE = 30.0;
const vec3 PLASMA_BLUE = vec3(0.45, 0.55, 1.4);

varying mat3 view_rot;

float hash11(float x) {
	return fract(sin(x * 12.9898 + 4.1414) * 43758.5453);
}

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

// Ecke c (±1 je Achse) in der Bildebene (Modell-Einheiten, y nach oben).
vec2 corner2d(vec3 c) {
	vec3 v = view_rot * c;
	return v.xy;
}

// Schaut die Seite mit Normale n zur Kamera?
bool facing(vec3 n) {
	return (view_rot * n).z > 0.0;
}

// Kante i (0..11): zwei festgenagelte Achsen, die dritte läuft. Liefert die
// Endpunkte in der Bildebene und ob sie auf der SILHOUETTE liegt.
void edge(int i, out vec2 e0, out vec2 e1, out bool rim) {
	int run_axis = i / 4;          // 0 = läuft längs X, 1 längs Y, 2 längs Z
	int quad = i - run_axis * 4;   // welche der vier parallelen Kanten
	float sa = (quad < 2) ? -1.0 : 1.0;
	float sb = (quad == 0 || quad == 2) ? -1.0 : 1.0;
	vec3 a = vec3(0.0);
	vec3 b = vec3(0.0);
	vec3 r = vec3(0.0);
	if (run_axis == 0) { r = vec3(1.0, 0.0, 0.0); a = vec3(0.0, sa, 0.0); b = vec3(0.0, 0.0, sb); }
	else if (run_axis == 1) { r = vec3(0.0, 1.0, 0.0); a = vec3(sa, 0.0, 0.0); b = vec3(0.0, 0.0, sb); }
	else { r = vec3(0.0, 0.0, 1.0); a = vec3(sa, 0.0, 0.0); b = vec3(0.0, sb, 0.0); }
	e0 = corner2d(a + b - r);
	e1 = corner2d(a + b + r);
	rim = facing(a) != facing(b);
}

// Abstand zur gezackten Bahn a -> b (Brücke plus Zittern), amp = Zackigkeit.
float bolt_dist(vec2 p, vec2 a, vec2 b, float amp, float seed, float jit, int k, out vec2 knot) {
	vec2 dir = b - a;
	float len = max(length(dir), 1e-4);
	vec2 nrm = vec2(-dir.y, dir.x) / len;
	float total = 0.0;
	for (int i = 1; i <= SEGMENTS; i++) {
		total += hash11(seed + float(i) * 3.1) - 0.5;
	}
	float best = 1e9;
	float walk = 0.0;
	vec2 prev = a;
	knot = a;
	for (int i = 1; i <= SEGMENTS; i++) {
		float t = float(i) / float(SEGMENTS);
		walk += hash11(seed + float(i) * 3.1) - 0.5;
		float env = sin(t * PI);
		float off = (walk - t * total) * amp * len;
		off += (hash11(seed + jit + float(i) * 7.7) - 0.5) * amp * 0.4 * len * env;
		vec2 v = mix(a, b, t) + nrm * off;
		if (i == k) { knot = v; }
		vec2 ab = v - prev;
		float h = clamp(dot(p - prev, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
		best = min(best, length(p - prev - ab * h));
		prev = v;
	}
	return best;
}

float strike_age(float t, float seed, float cell_len, float chance, out float cell_seed) {
	float u = t / cell_len + hash11(seed);
	float cell = floor(u);
	cell_seed = seed + cell * 17.3;
	if (hash11(cell_seed + 1.0) > chance) { return -1.0; }
	float start = hash11(cell_seed + 2.0) * max(cell_len - LIFE, 0.0);
	float age = fract(u) * cell_len - start;
	if (age < 0.0 || age > LIFE) { return -1.0; }
	return age;
}

// Plasma-Zeichnung wie auf den Seiten: weicher Kern, breiter Hof, im
// Nachglühen verlischt der Kern und der Hof wird breiter.
vec3 paint(float d, float px, bool striking, float fade, float spread, float width) {
	float cw = max(0.04 * width, px * 1.2);
	float hw = max(0.24 * width, px * 4.0) * spread;
	float core = exp(-(d * d) / (cw * cw)) * (striking ? 1.1 : 0.6 * fade);
	float halo = exp(-d / hw) * (striking ? 0.55 : 0.9 * fade);
	vec3 blue = mix(halo_color, PLASMA_BLUE, 0.5);
	return core_color * core + blue * halo;
}

void fragment() {
	vec2 p = (UV - 0.5) * quad_size;
	p.y = -p.y;
	float t = TIME + phase;
	float px = length(fwidth(p));
	int style = int(arc_style + 0.5);

	// Je Fassung: Schlitze, Zellen, Chance, Länge (Modell-Einheiten), Äste, Breite.
	int slots = 4;
	float cell_len = 0.8;
	float chance = 0.6;
	float len_lo = 0.25;
	float len_hi = 0.45;
	float amp = 0.22;
	int branches = 0;
	float width = 0.8;
	int fan = 1;
	if (style == 1) { slots = 2; cell_len = 1.4; chance = 0.65; len_lo = 0.55; len_hi = 0.9; amp = 0.18; branches = 1; width = 1.0; }
	if (style == 2) { slots = 3; cell_len = 1.2; chance = 0.6; len_lo = 0.4; len_hi = 0.7; amp = 0.2; branches = 1; width = 0.9; }
	if (style == 3) { slots = 2; cell_len = 1.8; chance = 0.6; len_lo = 0.35; len_hi = 0.6; amp = 0.2; width = 0.9; fan = 3; }
	if (style == 4) { slots = 2; cell_len = 1.4; chance = 0.65; amp = 0.16; width = 1.0; }
	chance = min(chance * rate, 0.95);

	vec3 acc = vec3(0.0);
	for (int s = 0; s < 4; s++) {
		if (s >= slots) { break; }
		float seed = seed_base * 13.7 + float(s) * 101.3;
		float cs;
		float age = strike_age(t, seed, cell_len, chance, cs);
		if (age < 0.0) { continue; }
		bool striking = age < STRIKE;
		float fade = striking ? 1.0 : pow(1.0 - (age - STRIKE) / AFTERGLOW, 1.2);
		float spread = striking ? 1.0 : 1.0 + 0.8 * (age - STRIKE) / AFTERGLOW;
		float jit = floor((t - age + min(age, STRIKE)) * JITTER_RATE) * 0.913;
		float flicker = striking ? 0.75 + 0.25 * hash11(jit + cs) : 1.0;

		// Eine SILHOUETTEN-Kante wählen: von der gewürfelten aus die nächste, die
		// auf dem Umriss liegt (höchstens sechs von zwölf liegen dort).
		int pick = int(hash11(cs + 3.0) * 12.0);
		vec2 e0;
		vec2 e1;
		bool rim = false;
		for (int k = 0; k < 12; k++) {
			int idx = pick + k;
			if (idx >= 12) { idx -= 12; }
			edge(idx, e0, e1, rim);
			if (rim) { pick = idx; break; }
		}
		if (!rim) { continue; }

		vec2 a;
		if (style == 2) {
			// Aus der Ecke: eines der beiden Enden der Silhouetten-Kante.
			a = hash11(cs + 4.0) < 0.5 ? e0 : e1;
		} else {
			a = mix(e0, e1, mix(0.1, 0.9, hash11(cs + 4.0)));
		}
		vec2 outward = normalize(a + vec2(1e-4, 2e-4));
		vec2 side = vec2(-outward.y, outward.x);

		if (style == 4) {
			// BOGEN: Ziel ist eine ANDERE Silhouetten-Kante, die Bahn baucht nach außen.
			int pick2 = pick + 1 + int(hash11(cs + 5.0) * 10.0);
			vec2 f0;
			vec2 f1;
			bool rim2 = false;
			for (int k = 0; k < 11; k++) {
				int idx = pick2 + k;
				while (idx >= 12) { idx -= 12; }
				if (idx == pick) { continue; }
				edge(idx, f0, f1, rim2);
				if (rim2) { break; }
			}
			if (!rim2) { continue; }
			vec2 b = mix(f0, f1, mix(0.1, 0.9, hash11(cs + 6.0)));
			// Der Bogen: Mittelpunkt nach außen geschoben, zwei Halbbahnen.
			vec2 mid = (a + b) * 0.5;
			vec2 bulge = normalize(mid + vec2(1e-4, 2e-4)) * mix(0.35, 0.6, hash11(cs + 7.0));
			vec2 m = mid + bulge;
			vec2 knot;
			float d = min(bolt_dist(p, a, m, amp, cs, jit, 99, knot),
				bolt_dist(p, m, b, amp, cs + 31.0, jit, 99, knot));
			acc += paint(d, px, striking, fade, spread, width) * flicker;
			float touch = exp(-pow(length(p - a) / 0.14, 2.0)) + exp(-pow(length(p - b) / 0.14, 2.0));
			acc += halo_color * touch * 0.6 * fade * flicker;
			continue;
		}

		// Nach AUSSEN, leicht schräg; die Krone fächert drei Bahnen.
		for (int f = 0; f < 3; f++) {
			if (f >= fan) { break; }
			float fs = cs + float(f) * 23.0;
			float tilt = (hash11(fs + 8.0) - 0.5) * (fan > 1 ? 1.6 : 0.8);
			vec2 way = normalize(outward + side * tilt);
			float len = mix(len_lo, len_hi, hash11(fs + 9.0));
			vec2 b = a + way * len;
			int k = 3 + int(hash11(fs + 10.0) * 3.0);
			vec2 knot;
			float d = bolt_dist(p, a, b, amp, fs, jit, k, knot);
			acc += paint(d, px, striking, fade, spread, width) * flicker;
			for (int br = 0; br < 1; br++) {
				if (br >= branches || hash11(fs + 11.0) > 0.7) { break; }
				float ang = mix(0.5, 1.0, hash11(fs + 12.0)) * (hash11(fs + 13.0) < 0.5 ? -1.0 : 1.0);
				vec2 bway = vec2(way.x * cos(ang) - way.y * sin(ang), way.x * sin(ang) + way.y * cos(ang));
				vec2 tip = knot + bway * len * 0.45;
				vec2 dummy;
				float bd = bolt_dist(p, knot, tip, amp * 1.3, fs + 40.0, jit, 99, dummy);
				acc += paint(bd, px, striking, fade, spread, width * 0.7) * flicker * 0.6;
			}
		}
		// Aufschlag an der Kante.
		acc += halo_color * exp(-pow(length(p - a) / 0.14, 2.0)) * 0.7 * fade * flicker;
	}
	ALBEDO = acc * gain;
	ALPHA = 1.0;
}
