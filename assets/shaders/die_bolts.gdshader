shader_type spatial;
render_mode blend_add, depth_draw_never, cull_back, unshaded, shadows_disabled;

// BLITZE des Kriechstroms: echte ENTLADUNGEN, die über eine Seite des Würfels
// SPRINGEN - von einer Kante zur anderen, an einer Kante entlang oder von Ecke
// zu Ecke. Ein Blitz ist eine dünne, GEZACKTE Bahn (Zufallsweg mit Brücke: die
// groben Ausschläge tragen den Kanal, ein feines Zittern läuft darüber und
// wechselt 30-mal je Sekunde), weißer Kern mit farbigem Hof, an beiden Enden
// ein kleiner Aufschlag-Funke, manchmal mit ABZWEIGUNGEN. Er lebt nur einen
// Wimpernschlag (schlagartig an, Abklingen, ein Nachschlag), dann ist er weg,
// und die Lücke bis zum nächsten ist zufällig.
//
// EIN Quad je Seite, knapp über der Fläche, in SEITEN-Koordinaten -1..1 (der
// Rand liegt in der Mitte der Kantenröhre - die Blitze KOMMEN also aus den
// Kanten). Additiv und unbeleuchtet: sie hellen nur auf. Aus der Ferne liest
// ein Blitz über BREITE: Kern und Hof werden nie dünner als ein Pixel (fwidth).

uniform float face_seed = 0.0;
uniform float phase = 0.0;
// Fassung (Autoren-Schalter): 0 Sprung, 1 Kriecher, 2 Geäst, 3 Knistern, 4 Eckschlag.
uniform float bolt_style = 0.0;
// Helligkeit und Häufigkeit (Überschlag: mehr und heißer).
uniform float gain = 1.0;
uniform float rate = 1.0;
uniform vec3 halo_color = vec3(0.86, 0.66, 1.35);
uniform vec3 core_color = vec3(1.0, 0.96, 1.0);

const int MAIN_SEGMENTS = 10;
const int BRANCH_SEGMENTS = 5;
const float CORE_WIDTH = 0.014;
const float HALO_WIDTH = 0.09;
const float CORE_GAIN = 3.0;
const float HALO_GAIN = 0.8;
const float TOUCH_RADIUS = 0.07;
const float JITTER_RATE = 30.0;

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

vec2 corner_point(float u) {
	float c = floor(u * 4.0);
	if (c < 0.5) { return vec2(-1.0, -1.0); }
	if (c < 1.5) { return vec2(1.0, -1.0); }
	if (c < 2.5) { return vec2(1.0, 1.0); }
	return vec2(-1.0, 1.0);
}

// Abstand zur gezackten Bahn a -> b: Zufallsweg quer zur Strecke, als BRÜCKE
// (endet wieder auf b), plus feines Zittern (jit) und bei Bedarf ein Ausbauchen
// zur Seitenmitte hin (bulge, für Bahnen längs einer Kante). vertex_out liefert
// den Knoten k, den Ansatz einer Abzweigung.
float bolt_dist(vec2 p, vec2 a, vec2 b, int n, float amp, float bulge, float seed,
		float jit, int k, out vec2 vertex_out) {
	vec2 dir = b - a;
	float len = max(length(dir), 1e-4);
	vec2 nrm = vec2(-dir.y, dir.x) / len;
	vec2 mid = (a + b) * 0.5;
	float inward = dot(nrm, -mid) < 0.0 ? -1.0 : 1.0;
	float total = 0.0;
	for (int i = 1; i <= MAIN_SEGMENTS; i++) {
		if (i > n) { break; }
		total += hash11(seed + float(i) * 3.1) - 0.5;
	}
	float best = 1e9;
	float walk = 0.0;
	vec2 prev = a;
	vertex_out = a;
	for (int i = 1; i <= MAIN_SEGMENTS; i++) {
		if (i > n) { break; }
		float t = float(i) / float(n);
		walk += hash11(seed + float(i) * 3.1) - 0.5;
		float env = sin(t * 3.14159);
		float off = (walk - t * total) * amp * len;
		off += (hash11(seed + jit + float(i) * 7.7) - 0.5) * amp * 0.5 * len * env;
		off += bulge * len * env * inward;
		vec2 v = mix(a, b, t) + nrm * off;
		if (i == k) { vertex_out = v; }
		vec2 ab = v - prev;
		float h = clamp(dot(p - prev, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
		best = min(best, length(p - prev - ab * h));
		prev = v;
	}
	return best;
}

// Wann ein Schlitz zündet: Zellen der Länge cell_len, je Zelle mit Chance
// chance EIN Blitz, der an zufälliger Stelle beginnt und life lang lebt.
// Hüllkurve: schlagartig an, Abklingen, ein Nachschlag bei 45 Prozent.
float strike_env(float t, float seed, float cell_len, float chance, float life,
		out float cell_seed) {
	float u = t / cell_len + hash11(seed);
	float cell = floor(u);
	cell_seed = seed + cell * 17.3;
	if (hash11(cell_seed + 1.0) > chance) { return 0.0; }
	float start = hash11(cell_seed + 2.0) * max(cell_len - life, 0.0);
	float age = fract(u) * cell_len - start;
	if (age < 0.0 || age > life) { return 0.0; }
	float x = age / life;
	float e = exp(-x * 4.0);
	if (x > 0.45) { e = max(e, 0.7 * exp(-(x - 0.45) * 7.0)); }
	return e;
}

// Wie eine Bahn im Abstand d leuchtet: harter Kern, weicher Hof, nie dünner
// als ein Pixel.
vec3 shade(float d, float px, float env) {
	float cw = max(CORE_WIDTH, px * 0.8);
	float hw = max(HALO_WIDTH, px * 2.5);
	float core = exp(-(d * d) / (cw * cw));
	float halo = exp(-d / hw);
	return (core_color * core * CORE_GAIN + halo_color * halo * HALO_GAIN) * env;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	p.y = -p.y;
	float t = TIME + phase;
	float px = length(fwidth(p));
	float jit = floor(t * JITTER_RATE) * 0.913;
	int style = int(bolt_style + 0.5);

	// Je Fassung: Schlitze je Seite, Zellenlänge, Zünd-Chance je Zelle, Lebensdauer,
	// Abzweigungen, Zackigkeit. Ein Blitz lebt nur Bruchteile einer Sekunde, also
	// muss oft gezündet werden, damit der Zustand überhaupt LESBAR ist.
	int slots = 2;
	float cell_len = 0.6;
	float chance = 0.6;
	float life = 0.12;
	int branches = 1;
	float amp = 0.16;
	if (style == 1) { slots = 3; cell_len = 0.4; chance = 0.6; life = 0.09; branches = 0; amp = 0.12; }
	if (style == 2) { cell_len = 0.9; chance = 0.7; life = 0.18; branches = 2; amp = 0.2; }
	if (style == 3) { slots = 3; cell_len = 0.2; chance = 0.55; life = 0.06; branches = 0; amp = 0.22; }
	if (style == 4) { cell_len = 0.8; chance = 0.55; life = 0.15; branches = 1; amp = 0.14; }
	chance = min(chance * rate, 0.95);

	vec3 acc = vec3(0.0);
	for (int s = 0; s < 3; s++) {
		if (s >= slots) { break; }
		float seed = face_seed * 13.7 + float(s) * 101.3;
		float cs;
		float env = strike_env(t, seed, cell_len, chance, life, cs);
		if (env <= 0.0) { continue; }
		vec2 a;
		vec2 b;
		float bulge = 0.0;
		float h0 = hash11(cs + 3.0);
		float h1 = hash11(cs + 4.0);
		float h2 = hash11(cs + 5.0);
		float h3 = hash11(cs + 6.0);
		if (style == 1) {
			// KRIECHER: beide Enden auf DERSELBEN Kante, die Bahn baucht zur Mitte.
			float e = floor(h0 * 4.0) / 4.0 + 0.01;
			float v1 = mix(0.05, 0.95, h1);
			float span = mix(0.25, 0.6, h2) * (h3 < 0.5 ? -1.0 : 1.0);
			a = rim_point(e, v1);
			b = rim_point(e, clamp(v1 + span, 0.02, 0.98));
			bulge = mix(0.12, 0.3, hash11(cs + 7.0));
		} else if (style == 3) {
			// KNISTERN: winzige Bahnen, die von einer Kante ein Stück ins Feld springen.
			a = rim_point(h0, h1);
			vec2 inward = -normalize(a);
			vec2 tangent = vec2(-inward.y, inward.x);
			vec2 way = normalize(inward * (0.3 + h2) + tangent * (h3 - 0.5) * 1.6);
			b = a + way * mix(0.18, 0.38, hash11(cs + 7.0));
		} else if (style == 4) {
			// ECKSCHLAG: von Ecke zu Ecke - benachbart oder über die Diagonale.
			a = corner_point(h0);
			float step_c = h1 < 0.4 ? 1.0 : (h1 < 0.7 ? 2.0 : 3.0);
			b = corner_point(fract(floor(h0 * 4.0) / 4.0 + step_c * 0.25 + 0.01));
			bulge = mix(-0.08, 0.08, h2);
		} else {
			// SPRUNG / GEÄST: von einer Kante zu einer ANDEREN.
			float e1 = floor(h0 * 4.0);
			float e2 = fract((e1 + 1.0 + floor(h1 * 3.0)) / 4.0 + 0.01);
			a = rim_point(e1 / 4.0 + 0.01, mix(0.15, 0.85, h2));
			b = rim_point(e2, mix(0.15, 0.85, h3));
		}
		int k = 3 + int(hash11(cs + 8.0) * 5.0);
		vec2 knot;
		float d = bolt_dist(p, a, b, MAIN_SEGMENTS, amp, bulge, cs, jit, k, knot);
		acc += shade(d, px, env);
		// Aufschlag-Funken an beiden Enden.
		float touch = exp(-pow(length(p - a) / TOUCH_RADIUS, 2.0))
			+ exp(-pow(length(p - b) / TOUCH_RADIUS, 2.0));
		acc += halo_color * touch * env * 0.9;
		// ABZWEIGUNGEN: aus dem Knoten heraus, schräg weg, kürzer und schwächer.
		for (int br = 0; br < 2; br++) {
			if (br >= branches) { break; }
			float bs = cs + 40.0 + float(br) * 9.0;
			if (branches == 1 && hash11(bs) > 0.6) { break; }
			vec2 dir = normalize(b - a);
			float ang = mix(0.5, 1.1, hash11(bs + 1.0)) * (hash11(bs + 2.0) < 0.5 ? -1.0 : 1.0);
			vec2 way = vec2(dir.x * cos(ang) - dir.y * sin(ang), dir.x * sin(ang) + dir.y * cos(ang));
			vec2 tip = knot + way * length(b - a) * mix(0.25, 0.45, hash11(bs + 3.0));
			vec2 dummy;
			float bd = bolt_dist(p, knot, tip, BRANCH_SEGMENTS, amp * 1.3, 0.0, bs, jit, 99, dummy);
			acc += shade(bd, px, env * 0.55);
		}
	}
	ALBEDO = acc * gain;
	ALPHA = 1.0;
}
