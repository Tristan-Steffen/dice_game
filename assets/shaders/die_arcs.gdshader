shader_type spatial;
render_mode blend_add, depth_draw_never, depth_test_disabled, cull_back, unshaded,
	shadows_disabled;

// ÜBERSCHLAG (Ladung 3): FAHNEN - wenige lange Blitze, die aus den KANTEN des
// Würfels nach AUSSEN schlagen und bis zu einer Würfelbreite über ihn hinausragen,
// oft mit einem Ast (Spieler-Wahl 2026-09-07 aus fünf Fassungen: Funken, Fahnen,
// Eckstrahlen, Krone, Bogen). Dieselbe Blitz-Maschine wie die Seiten-Blitze der
// Stufe 2 (die_bolts.gdshader: Zufallsweg als Brücke, kurzer Schlag mit Zittern,
// dann eingefrorenes Nachglühen), nur der ORT ist ein anderer: EIN kamerazugewandtes
// Quad um den Würfel (wie die Hitze), das die zwölf Kanten aus der Modell-Drehung
// in die Bildebene projiziert. Gezündet wird nur an SILHOUETTEN-Kanten (eine
// Nachbarseite schaut zur Kamera, die andere weg) - von einer Rückkante käme der
// Blitz mitten aus dem Körper.

uniform vec2 quad_size = vec2(4.5, 4.5);
uniform float seed_base = 0.0;
uniform float phase = 0.0;
uniform float gain = 1.0;
uniform float rate = 1.0;
uniform vec3 halo_color = vec3(0.55, 0.65, 1.45);
uniform vec3 core_color = vec3(1.0, 0.96, 1.0);

const int SEGMENTS = 8;
const int SLOTS = 2;
const float CELL_LEN = 1.4;
const float CHANCE = 0.65;
const float STRIKE = 0.2;
const float AFTERGLOW = 0.5;
const float LIFE = STRIKE + AFTERGLOW;
// Wie weit die Fahne hinausragt (Modell-Einheiten, Würfel-Halbmaß = 1), Zackigkeit,
// Chance auf einen Ast und das Zittern im Schlag.
const float LEN_LO = 0.55;
const float LEN_HI = 0.9;
const float AMP = 0.18;
const float BRANCH_CHANCE = 0.7;
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
	return (view_rot * c).xy;
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

// Abstand zur gezackten Bahn a -> b (Brücke plus Zittern); knot = Knoten k (Ast-Ansatz).
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

float strike_age(float t, float seed, float chance, out float cell_seed) {
	float u = t / CELL_LEN + hash11(seed);
	float cell = floor(u);
	cell_seed = seed + cell * 17.3;
	if (hash11(cell_seed + 1.0) > chance) { return -1.0; }
	float start = hash11(cell_seed + 2.0) * max(CELL_LEN - LIFE, 0.0);
	float age = fract(u) * CELL_LEN - start;
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
	float chance = min(CHANCE * rate, 0.95);

	vec3 acc = vec3(0.0);
	for (int s = 0; s < SLOTS; s++) {
		float seed = seed_base * 13.7 + float(s) * 101.3;
		float cs;
		float age = strike_age(t, seed, chance, cs);
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
			if (rim) { break; }
		}
		if (!rim) { continue; }

		vec2 a = mix(e0, e1, mix(0.1, 0.9, hash11(cs + 4.0)));
		vec2 outward = normalize(a + vec2(1e-4, 2e-4));
		vec2 side = vec2(-outward.y, outward.x);
		// Nach AUSSEN, leicht schräg.
		float tilt = (hash11(cs + 8.0) - 0.5) * 0.8;
		vec2 way = normalize(outward + side * tilt);
		float len = mix(LEN_LO, LEN_HI, hash11(cs + 9.0));
		vec2 b = a + way * len;
		int k = 3 + int(hash11(cs + 10.0) * 3.0);
		vec2 knot;
		float d = bolt_dist(p, a, b, AMP, cs, jit, k, knot);
		acc += paint(d, px, striking, fade, spread, 1.0) * flicker;
		// Ein Ast, schräg vom Knoten weg, kürzer und schwächer.
		if (hash11(cs + 11.0) < BRANCH_CHANCE) {
			float ang = mix(0.5, 1.0, hash11(cs + 12.0)) * (hash11(cs + 13.0) < 0.5 ? -1.0 : 1.0);
			vec2 bway = vec2(way.x * cos(ang) - way.y * sin(ang), way.x * sin(ang) + way.y * cos(ang));
			vec2 tip = knot + bway * len * 0.45;
			vec2 dummy;
			float bd = bolt_dist(p, knot, tip, AMP * 1.3, cs + 40.0, jit, 99, dummy);
			acc += paint(bd, px, striking, fade, spread, 0.7) * flicker * 0.6;
		}
		// Aufschlag an der Kante.
		acc += halo_color * exp(-pow(length(p - a) / 0.14, 2.0)) * 0.7 * fade * flicker;
	}
	ALBEDO = acc * gain;
	ALPHA = 1.0;
}
