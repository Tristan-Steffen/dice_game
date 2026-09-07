// Die BLITZ-MASCHINE der Ladung, geteilt von die_bolts (Seiten, Stufe 2),
// die_arcs (außen, Stufe 3) und die_burn (eingefrorene Bruchlinien der Asche).
// Eine Bahn ist ein Zufallsweg quer zur Strecke als BRÜCKE (endet wieder auf b)
// plus feinem Zittern; ein Schlag ist kurz und glimmt eingefroren nach.

const int MAX_SEGMENTS = 10;
const vec3 PLASMA_BLUE = vec3(0.45, 0.55, 1.4);
const float JITTER_RATE = 30.0;

float hash11(float x) {
	return fract(sin(x * 12.9898 + 4.1414) * 43758.5453);
}

// Ein Punkt auf dem Seitenrand (-1..1): u wählt die Kante, v die Stelle darauf.
vec2 rim_point(float u, float v) {
	float e = floor(u * 4.0);
	float s = v * 2.0 - 1.0;
	if (e < 0.5) { return vec2(s, -1.0); }
	if (e < 1.5) { return vec2(1.0, s); }
	if (e < 2.5) { return vec2(-s, 1.0); }
	return vec2(-1.0, -s);
}

// Zwei Kanten einer Seite, nie dieselbe: Start und Ziel einer Bahn.
void rim_pair(float seed, out vec2 a, out vec2 b) {
	float e1 = floor(hash11(seed + 3.0) * 4.0);
	float e2 = fract((e1 + 1.0 + floor(hash11(seed + 4.0) * 3.0)) / 4.0 + 0.01);
	a = rim_point(e1 / 4.0 + 0.01, mix(0.12, 0.88, hash11(seed + 5.0)));
	b = rim_point(e2, mix(0.12, 0.88, hash11(seed + 6.0)));
}

// Abstand von p zur gezackten Bahn a -> b mit n Segmenten (amp = Zackigkeit,
// jit = Zitter-Takt); knot liefert den Knoten k, den Ansatz eines Asts.
float bolt_dist(vec2 p, vec2 a, vec2 b, int n, float amp, float seed, float jit, int k,
		out vec2 knot) {
	vec2 dir = b - a;
	float len = max(length(dir), 1e-4);
	vec2 nrm = vec2(-dir.y, dir.x) / len;
	float total = 0.0;
	for (int i = 1; i <= MAX_SEGMENTS; i++) {
		if (i > n) { break; }
		total += hash11(seed + float(i) * 3.1) - 0.5;
	}
	float best = 1e9;
	float walk = 0.0;
	vec2 prev = a;
	knot = a;
	for (int i = 1; i <= MAX_SEGMENTS; i++) {
		if (i > n) { break; }
		float t = float(i) / float(n);
		walk += hash11(seed + float(i) * 3.1) - 0.5;
		float off = (walk - t * total) * amp * len;
		off += (hash11(seed + jit + float(i) * 7.7) - 0.5) * amp * 0.4 * len * sin(t * PI);
		vec2 v = mix(a, b, t) + nrm * off;
		if (i == k) { knot = v; }
		vec2 ab = v - prev;
		float h = clamp(dot(p - prev, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
		best = min(best, length(p - prev - ab * h));
		prev = v;
	}
	return best;
}

// Ein Ast: schräg vom Knoten weg, ein Stück der Hauptlänge.
vec2 branch_tip(vec2 knot, vec2 dir, float len, float seed) {
	float ang = mix(0.5, 1.1, hash11(seed + 1.0)) * (hash11(seed + 2.0) < 0.5 ? -1.0 : 1.0);
	vec2 way = vec2(dir.x * cos(ang) - dir.y * sin(ang), dir.x * sin(ang) + dir.y * cos(ang));
	return knot + way * len;
}

// Wann ein Schlitz zündet: Zellen der Länge cell_len, je Zelle mit Chance chance
// EIN Schlag, der an zufälliger Stelle beginnt und life lang lebt. Liefert das
// Alter in Sekunden (negativ = aus) und den Zellen-Seed.
float strike_age(float t, float seed, float cell_len, float chance, float life,
		out float cell_seed) {
	float u = t / cell_len + hash11(seed);
	cell_seed = seed + floor(u) * 17.3;
	if (hash11(cell_seed + 1.0) > chance) { return -1.0; }
	float start = hash11(cell_seed + 2.0) * max(cell_len - life, 0.0);
	float age = fract(u) * cell_len - start;
	if (age < 0.0 || age > life) { return -1.0; }
	return age;
}

// Die Form eines Schlags über sein Alter: im SCHLAG (age < strike) zittert die
// Bahn mit JITTER_RATE und flackert; danach friert sie ein und GLIMMT NACH
// (fade 1 -> 0, der Hof wird breiter: spread).
void strike_shape(float t, float age, float cs, float strike, float afterglow,
		out bool striking, out float fade, out float spread, out float jit, out float flicker) {
	striking = age < strike;
	float x = (age - strike) / afterglow;
	fade = striking ? 1.0 : pow(1.0 - x, 1.2);
	spread = striking ? 1.0 : 1.0 + 0.8 * x;
	jit = floor((t - age + min(age, strike)) * JITTER_RATE) * 0.913;
	flicker = striking ? 0.75 + 0.25 * hash11(jit + cs) : 1.0;
}

// PLASMA-Zeichnung: weicher Kern, breiter blau-violetter Hof; im Nachglühen
// verlischt der Kern schnell, der Hof bleibt. Nie dünner als ein Pixel (px).
vec3 plasma_paint(float d, float px, bool striking, float fade, float spread, float width,
		vec3 halo_color, vec3 core_color) {
	float cw = max(0.04 * width, px * 1.2);
	float hw = max(0.28 * width, px * 4.0) * spread;
	float core = exp(-(d * d) / (cw * cw)) * (striking ? 1.1 : 0.6 * fade);
	float halo = exp(-d / hw) * (striking ? 0.55 : 0.9 * fade);
	return core_color * core + mix(halo_color, PLASMA_BLUE, 0.5) * halo;
}

// Weicher Aufschlag an einem Ende der Bahn.
float touch_glow(vec2 p, vec2 at, float radius) {
	return exp(-pow(length(p - at) / radius, 2.0));
}
