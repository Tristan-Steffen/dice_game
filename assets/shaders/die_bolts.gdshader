shader_type spatial;
render_mode blend_add, depth_draw_never, cull_back, unshaded, shadows_disabled;

// PLASMA-BLITZE des Kriechstroms (Spieler-Wahl 2026-09-06 aus fünf Zeichenstilen):
// weiche, breite Fäden, die von einer Kante zu einer anderen über die Seite
// springen und dabei STETIG WANDERN wie in einer Plasmakugel - kein Zucken.
// Die Bahn ist ein Zufallsweg als Brücke (endet wieder auf der Zielkante); der
// Faden blendet zwischen zwei Seeds, darum fließt er statt zu springen. Ein
// Faden lebt gut zwei Sekunden (weich an, weich aus) mit langer, zufälliger
// Lücke bis zum nächsten; an beiden Enden ein weicher Aufschlag.
//
// EIN Quad je Seite, knapp über der Fläche, in SEITEN-Koordinaten -1..1 (der
// Rand liegt in der Mitte der Kantenröhre - die Fäden KOMMEN aus den Kanten).
// Additiv und unbeleuchtet: sie hellen nur auf. Aus der Ferne liest ein Faden
// über BREITE: Kern und Hof werden nie dünner als ein Pixel (fwidth).
//
// Verworfen (2026-09-06): Licht AUF der Kantenröhre (las als Lichterkette) und
// die Stile Neon, Comic, Pixel, Lichtenberg.

uniform float face_seed = 0.0;
uniform float phase = 0.0;
// Helligkeit und Häufigkeit (Überschlag: mehr und heißer).
uniform float gain = 1.0;
uniform float rate = 1.0;
uniform vec3 halo_color = vec3(0.86, 0.66, 1.35);
uniform vec3 core_color = vec3(1.0, 0.96, 1.0);

const int SEGMENTS = 10;
// Zellenlänge, Zünd-Chance je Zelle und Lebensdauer eines Fadens - die Dichte
// ist bewusst niedrig (Spieler-Wunsch: weniger Blitze).
const float CELL_LEN = 3.2;
const float CHANCE = 0.6;
const float LIFE = 2.2;
// Zackigkeit, Wander-Tempo (Seed-Wechsel je Sekunde) und das feine Zittern.
const float AMP = 0.2;
const float DRIFT_RATE = 0.7;
const float JITTER_RATE = 3.0;
const vec3 PLASMA_BLUE = vec3(0.45, 0.55, 1.4);

float hash11(float x) {
	return fract(sin(x * 12.9898 + 4.1414) * 43758.5453);
}

// Ein Punkt auf dem Seitenrand: u wählt die Kante, v die Stelle darauf.
vec2 rim_point(float u, float v) {
	float e = floor(u * 4.0);
	float s = v * 2.0 - 1.0;
	if (e < 0.5) { return vec2(s, -1.0); }
	if (e < 1.5) { return vec2(1.0, s); }
	if (e < 2.5) { return vec2(-s, 1.0); }
	return vec2(-1.0, -s);
}

// Abstand zur gezackten Bahn a -> b: Zufallsweg quer zur Strecke, als BRÜCKE
// (endet wieder auf b), zwischen zwei Seeds geblendet (morph) plus feinem
// Zittern (jit).
float bolt_dist(vec2 p, vec2 a, vec2 b, float seed, float seed2, float morph, float jit) {
	vec2 dir = b - a;
	float len = max(length(dir), 1e-4);
	vec2 nrm = vec2(-dir.y, dir.x) / len;
	float total = 0.0;
	for (int i = 1; i <= SEGMENTS; i++) {
		float f = float(i) * 3.1;
		total += mix(hash11(seed + f), hash11(seed2 + f), morph) - 0.5;
	}
	float best = 1e9;
	float walk = 0.0;
	vec2 prev = a;
	for (int i = 1; i <= SEGMENTS; i++) {
		float t = float(i) / float(SEGMENTS);
		float f = float(i) * 3.1;
		walk += mix(hash11(seed + f), hash11(seed2 + f), morph) - 0.5;
		float env = sin(t * PI);
		float off = (walk - t * total) * AMP * len;
		off += (hash11(seed + jit + float(i) * 7.7) - 0.5) * AMP * 0.4 * len * env;
		vec2 v = mix(a, b, t) + nrm * off;
		vec2 ab = v - prev;
		float h = clamp(dot(p - prev, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
		best = min(best, length(p - prev - ab * h));
		prev = v;
	}
	return best;
}

// Wann die Seite zündet: Zellen der Länge CELL_LEN, je Zelle mit Chance chance
// EIN Faden, der an zufälliger Stelle beginnt und LIFE lang lebt. Liefert das
// Alter 0..1 (negativ = aus) und den Zellen-Seed.
float strike_age(float t, float seed, float chance, out float cell_seed) {
	float u = t / CELL_LEN + hash11(seed);
	float cell = floor(u);
	cell_seed = seed + cell * 17.3;
	if (hash11(cell_seed + 1.0) > chance) { return -1.0; }
	float start = hash11(cell_seed + 2.0) * max(CELL_LEN - LIFE, 0.0);
	float age = fract(u) * CELL_LEN - start;
	if (age < 0.0 || age > LIFE) { return -1.0; }
	return age / LIFE;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	p.y = -p.y;
	float t = TIME + phase;
	float px = length(fwidth(p));
	float jit = floor(t * JITTER_RATE) * 0.913;

	vec3 acc = vec3(0.0);
	float cs;
	float x = strike_age(t, face_seed * 13.7, min(CHANCE * rate, 0.95), cs);
	if (x >= 0.0) {
		// Weich an, weich aus, ein leises Flackern darüber.
		float env = pow(sin(x * PI), 0.7) * (0.85 + 0.15 * sin(t * 23.0 + cs));
		// Der Faden wandert: alle 1/DRIFT_RATE s ein neues Ziel, stetig geblendet.
		float cycle = t * DRIFT_RATE + hash11(cs);
		float seed = cs + floor(cycle) * 5.7;
		float morph = smoothstep(0.0, 1.0, fract(cycle));

		// Von einer Kante zu einer ANDEREN.
		float h0 = hash11(cs + 3.0);
		float h1 = hash11(cs + 4.0);
		float e1 = floor(h0 * 4.0);
		float e2 = fract((e1 + 1.0 + floor(h1 * 3.0)) / 4.0 + 0.01);
		vec2 a = rim_point(e1 / 4.0 + 0.01, mix(0.15, 0.85, hash11(cs + 5.0)));
		vec2 b = rim_point(e2, mix(0.15, 0.85, hash11(cs + 6.0)));

		float d = bolt_dist(p, a, b, seed, seed + 5.7, morph, jit);
		// Weich und breit: kaum Kern, viel bläulicher Hof.
		float cw = max(0.04, px * 1.2);
		float hw = max(0.28, px * 4.0);
		float core = exp(-(d * d) / (cw * cw));
		float halo = exp(-d / hw);
		vec3 blue = mix(halo_color, PLASMA_BLUE, 0.5);
		acc += (core_color * core * 1.1 + blue * halo * 0.55) * env;
		// Weicher Aufschlag an beiden Enden.
		float touch = exp(-pow(length(p - a) / 0.16, 2.0)) + exp(-pow(length(p - b) / 0.16, 2.0));
		acc += halo_color * touch * 0.6 * env;
	}
	ALBEDO = acc * gain;
	ALPHA = 1.0;
}
