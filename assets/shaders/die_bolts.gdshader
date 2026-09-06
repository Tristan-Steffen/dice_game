shader_type spatial;
render_mode blend_add, depth_draw_never, cull_back, unshaded, shadows_disabled;

// PLASMA-BLITZE des Kriechstroms (Spieler-Wahl 2026-09-06 aus fünf Zeichenstilen):
// weiche, breite Fäden, die von einer Kante zu einer anderen über die Seite
// springen. Die Bahn ist ein Zufallsweg als Brücke (endet wieder auf der
// Zielkante). Der SCHLAG ist KURZ (STRIKE 0,2 s, die Bahn zittert dabei mit
// 30 Hz), dann steht sie still und GLIMMT NACH (AFTERGLOW 0,5 s: der Kern
// verlischt, der Hof wird breiter und blasser) - Spieler-Wunsch 2026-09-06,
// das langsame Wandern über zwei Sekunden war ihm zu träge. Lange, zufällige
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
// Zellenlänge und Zünd-Chance je Zelle - die Dichte ist bewusst niedrig
// (Spieler-Wunsch: weniger Blitze). Schlag und Nachglühen in Sekunden.
const float CELL_LEN = 3.2;
const float CHANCE = 0.6;
const float STRIKE = 0.2;
const float AFTERGLOW = 0.5;
const float LIFE = STRIKE + AFTERGLOW;
// Zackigkeit und das Zittern während des Schlags.
const float AMP = 0.2;
const float JITTER_RATE = 30.0;
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
// (endet wieder auf b), plus feinem Zittern (jit).
float bolt_dist(vec2 p, vec2 a, vec2 b, float seed, float jit) {
	vec2 dir = b - a;
	float len = max(length(dir), 1e-4);
	vec2 nrm = vec2(-dir.y, dir.x) / len;
	float total = 0.0;
	for (int i = 1; i <= SEGMENTS; i++) {
		float f = float(i) * 3.1;
		total += hash11(seed + f) - 0.5;
	}
	float best = 1e9;
	float walk = 0.0;
	vec2 prev = a;
	for (int i = 1; i <= SEGMENTS; i++) {
		float t = float(i) / float(SEGMENTS);
		float f = float(i) * 3.1;
		walk += hash11(seed + f) - 0.5;
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
// Alter in Sekunden (negativ = aus) und den Zellen-Seed.
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

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	p.y = -p.y;
	float t = TIME + phase;
	float px = length(fwidth(p));

	vec3 acc = vec3(0.0);
	float cs;
	float age = strike_age(t, face_seed * 13.7, min(CHANCE * rate, 0.95), cs);
	if (age >= 0.0) {
		bool striking = age < STRIKE;
		// Nachglühen 1 -> 0, im Schlag 1.
		float fade = striking ? 1.0 : pow(1.0 - (age - STRIKE) / AFTERGLOW, 1.2);
		// Im Schlag zittert die Bahn mit JITTER_RATE, danach friert sie ein.
		float jit = floor((t - age + min(age, STRIKE)) * JITTER_RATE) * 0.913;
		float flicker = striking ? 0.75 + 0.25 * hash11(jit + cs) : 1.0;

		// Von einer Kante zu einer ANDEREN.
		float h0 = hash11(cs + 3.0);
		float h1 = hash11(cs + 4.0);
		float e1 = floor(h0 * 4.0);
		float e2 = fract((e1 + 1.0 + floor(h1 * 3.0)) / 4.0 + 0.01);
		vec2 a = rim_point(e1 / 4.0 + 0.01, mix(0.15, 0.85, hash11(cs + 5.0)));
		vec2 b = rim_point(e2, mix(0.15, 0.85, hash11(cs + 6.0)));

		float d = bolt_dist(p, a, b, cs, jit);
		// Weich und breit: kaum Kern, viel bläulicher Hof. Im Nachglühen verlischt
		// der Kern schnell, der Hof wird breiter und blasser.
		float spread = striking ? 1.0 : 1.0 + 0.8 * (age - STRIKE) / AFTERGLOW;
		float cw = max(0.04, px * 1.2);
		float hw = max(0.28, px * 4.0) * spread;
		float core = exp(-(d * d) / (cw * cw)) * (striking ? 1.1 : 0.6 * fade);
		float halo = exp(-d / hw) * (striking ? 0.55 : 0.9 * fade);
		vec3 blue = mix(halo_color, PLASMA_BLUE, 0.5);
		acc += (core_color * core + blue * halo) * flicker;
		// Weicher Aufschlag an beiden Enden.
		float touch = exp(-pow(length(p - a) / 0.16, 2.0)) + exp(-pow(length(p - b) / 0.16, 2.0));
		acc += halo_color * touch * 0.6 * fade * flicker;
	}
	ALBEDO = acc * gain;
	ALPHA = 1.0;
}
