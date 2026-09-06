shader_type spatial;
render_mode blend_add, depth_draw_never, cull_back, unshaded, shadows_disabled;

// BLITZE des Kriechstroms: echte ENTLADUNGEN, die über eine Seite des Würfels
// SPRINGEN - von einer Kante zur anderen. Ein Blitz ist eine GEZACKTE Bahn
// (Zufallsweg mit Brücke: die groben Ausschläge tragen den Kanal, ein feines
// Zittern läuft darüber), an beiden Enden ein Aufschlag, manchmal ABZWEIGUNGEN.
// Er lebt kurz (schlagartig an, Abklingen, Nachschlag), dann ist er weg, und
// die Lücke bis zum nächsten ist zufällig.
//
// EIN Quad je Seite, knapp über der Fläche, in SEITEN-Koordinaten -1..1 (der
// Rand liegt in der Mitte der Kantenröhre - die Blitze KOMMEN aus den Kanten).
// Additiv und unbeleuchtet: sie hellen nur auf. Aus der Ferne liest ein Blitz
// über BREITE: Kern und Hof werden nie dünner als ein Pixel (fwidth).
//
// bolt_style wählt den ZEICHENSTIL auf derselben Maschine (Autoren-Schalter):
// 0 NEON     - dünner weißer Kern, violetter Hof, Einschlag und Nachschlag
// 1 PLASMA   - weiche, breite Fäden, die langsam wandern wie in einer Plasmakugel
// 2 COMIC    - flacher, dicker Zickzack mit harter Kante, Stop-Motion in 8 Bildern
// 3 PIXEL    - auf ein grobes Raster gerastert, zweifarbig, blinkend
// 4 LICHTENBERG - ein Baum, der von einer Kante her WÄCHST, verjüngt und verästelt

uniform float face_seed = 0.0;
uniform float phase = 0.0;
uniform float bolt_style = 0.0;
// Helligkeit und Häufigkeit (Überschlag: mehr und heißer).
uniform float gain = 1.0;
uniform float rate = 1.0;
uniform vec3 halo_color = vec3(0.86, 0.66, 1.35);
uniform vec3 core_color = vec3(1.0, 0.96, 1.0);

const int MAIN_SEGMENTS = 10;
const int BRANCH_SEGMENTS = 5;
const float PIXEL_GRID = 14.0;

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
// (endet wieder auf b). Zwei Seeds, zwischen denen morph blendet (Plasma
// wandert damit stetig); jit ist das feine Zittern; grow deckt die Bahn von a
// her auf (Lichtenberg wächst). along = Lage des nächsten Punkts auf der Bahn
// (0 an a, 1 an b, für die Verjüngung), knot_out = Knoten k (Ansatz eines Asts).
float bolt_dist(vec2 p, vec2 a, vec2 b, int n, float amp, float seed, float seed2,
		float morph, float jit, float grow, int k, out float along, out vec2 knot_out) {
	vec2 dir = b - a;
	float len = max(length(dir), 1e-4);
	vec2 nrm = vec2(-dir.y, dir.x) / len;
	float total = 0.0;
	for (int i = 1; i <= MAIN_SEGMENTS; i++) {
		if (i > n) { break; }
		float f = float(i) * 3.1;
		total += mix(hash11(seed + f), hash11(seed2 + f), morph) - 0.5;
	}
	float best = 1e9;
	along = 0.0;
	float walk = 0.0;
	vec2 prev = a;
	knot_out = a;
	for (int i = 1; i <= MAIN_SEGMENTS; i++) {
		if (i > n) { break; }
		float t = float(i) / float(n);
		float f = float(i) * 3.1;
		walk += mix(hash11(seed + f), hash11(seed2 + f), morph) - 0.5;
		float env = sin(t * PI);
		float off = (walk - t * total) * amp * len;
		off += (hash11(seed + jit + float(i) * 7.7) - 0.5) * amp * 0.4 * len * env;
		vec2 v = mix(a, b, t) + nrm * off;
		if (i == k) { knot_out = v; }
		if (t > grow + 1e-4) { break; }
		vec2 ab = v - prev;
		float h = clamp(dot(p - prev, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
		float d = length(p - prev - ab * h);
		if (d < best) {
			best = d;
			along = (float(i - 1) + h) / float(n);
		}
		prev = v;
	}
	return best;
}

// Wann ein Schlitz zündet: Zellen der Länge cell_len, je Zelle mit Chance
// chance EIN Blitz, der an zufälliger Stelle beginnt und life lang lebt.
// Liefert das Alter 0..1 (negativ = aus) und den Zellen-Seed.
float strike_age(float t, float seed, float cell_len, float chance, float life,
		out float cell_seed) {
	float u = t / cell_len + hash11(seed);
	float cell = floor(u);
	cell_seed = seed + cell * 17.3;
	if (hash11(cell_seed + 1.0) > chance) { return -1.0; }
	float start = hash11(cell_seed + 2.0) * max(cell_len - life, 0.0);
	float age = fract(u) * cell_len - start;
	if (age < 0.0 || age > life) { return -1.0; }
	return age / life;
}

// Das Licht einer Bahn im Abstand d, je Stil anders gezeichnet.
vec3 paint(float d, float along, float px, float env, int style, float x) {
	if (style == 1) {
		// PLASMA: weich und breit, kaum Kern, viel bläulicher Hof.
		float cw = max(0.04, px * 1.2);
		float hw = max(0.28, px * 4.0);
		float core = exp(-(d * d) / (cw * cw));
		float halo = exp(-d / hw);
		vec3 blue = mix(halo_color, vec3(0.45, 0.55, 1.4), 0.5);
		return (core_color * core * 1.1 + blue * halo * 0.55) * env;
	}
	if (style == 2) {
		// COMIC: flache Fläche, harte Kante, kein Hof; das erste Viertel ist der
		// weiße Blitz-Frame, danach steht die Farbe.
		float w = max(0.05, px * 1.6);
		float solid = 1.0 - smoothstep(w * 0.75, w, d);
		vec3 col = x < 0.25 ? core_color * 2.4 : halo_color * 1.7;
		return col * solid * env;
	}
	if (style == 3) {
		// PIXEL: zwei Stufen, keine Weichheit - der Abstand ist am Rasterpunkt gemessen.
		float w1 = max(0.032, px * 1.2);
		float w2 = w1 * 2.2;
		float core = step(d, w1);
		float halo = step(d, w2) * 0.5;
		return (core_color * core * 2.2 + halo_color * halo) * env;
	}
	if (style == 4) {
		// LICHTENBERG: verjüngt sich zur Spitze, warmer Kern, blasser Hof, dazu ein
		// breites, schwaches Brandlicht.
		float taper = mix(1.0, 0.3, along);
		float cw = max(0.02 * taper, px * 0.8);
		float hw = max(0.06, px * 2.0);
		float core = exp(-(d * d) / (cw * cw));
		float halo = exp(-d / hw);
		float burn = exp(-d / 0.22) * 0.12;
		vec3 warm = mix(core_color, vec3(1.0, 0.85, 0.75), 0.4);
		return (warm * core * 2.4 + halo_color * (halo * 0.5 + burn)) * env;
	}
	// NEON: dünner weißer Kern, violetter Hof.
	float cw = max(0.014, px * 0.8);
	float hw = max(0.09, px * 2.5);
	float core = exp(-(d * d) / (cw * cw));
	float halo = exp(-d / hw);
	return (core_color * core * 3.0 + halo_color * halo * 0.8) * env;
}

// Der Aufschlag an einem Ende (q = p - Ende), je Stil.
vec3 touch(vec2 q, float px, float env, int style) {
	if (style == 1) {
		return halo_color * exp(-pow(length(q) / 0.16, 2.0)) * 0.6 * env;
	}
	if (style == 2) {
		// Ein vierzackiger Stern mit harter Kante.
		float star = max(abs(q.x) + abs(q.y), max(abs(q.x), abs(q.y)) * 2.2);
		return core_color * (1.0 - smoothstep(0.08, 0.1, star)) * 2.0 * env;
	}
	if (style == 3) {
		return core_color * step(max(abs(q.x), abs(q.y)), 0.075) * 1.6 * env;
	}
	if (style == 4) {
		return halo_color * exp(-pow(length(q) / 0.09, 2.0)) * 1.2 * env;
	}
	return halo_color * exp(-pow(length(q) / 0.07, 2.0)) * 0.9 * env;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	p.y = -p.y;
	float t = TIME + phase;
	float px = length(fwidth(p));
	int style = int(bolt_style + 0.5);
	if (style == 3) {
		// Raster: jeder Rasterpunkt mißt an seiner Mitte, die Zelle ist EINE Farbe.
		p = (floor(p * PIXEL_GRID * 0.5) + 0.5) / (PIXEL_GRID * 0.5);
	}

	// Je Stil: Schlitze je Seite, Zellenlänge, Zünd-Chance, Lebensdauer, Äste,
	// Zackigkeit, Segmente und der Takt des Zitterns.
	int slots = 2;
	float cell_len = 1.1;
	float chance = 0.6;
	float life = 0.4;
	int branches = 1;
	float amp = 0.16;
	int segments = MAIN_SEGMENTS;
	float jitter_rate = 12.0;
	if (style == 1) { cell_len = 2.4; chance = 0.8; life = 2.4; branches = 0; amp = 0.2; jitter_rate = 3.0; }
	if (style == 2) { slots = 1; cell_len = 1.2; chance = 0.6; life = 0.5; branches = 1; amp = 0.26; segments = 5; jitter_rate = 8.0; }
	if (style == 3) { cell_len = 1.0; chance = 0.6; life = 0.4; branches = 1; amp = 0.2; segments = 7; jitter_rate = 10.0; }
	if (style == 4) { slots = 1; cell_len = 1.8; chance = 0.7; life = 1.4; branches = 3; amp = 0.18; jitter_rate = 6.0; }
	chance = min(chance * rate, 0.95);
	float jit = floor(t * jitter_rate) * 0.913;

	vec3 acc = vec3(0.0);
	for (int s = 0; s < 2; s++) {
		if (s >= slots) { break; }
		float seed = face_seed * 13.7 + float(s) * 101.3;
		float cs;
		float x = strike_age(t, seed, cell_len, chance, life, cs);
		if (x < 0.0) { continue; }

		// Hüllkurve und Aufdecken je Stil.
		float env = 1.0;
		float grow = 1.0;
		float morph = 0.0;
		float seed2 = cs;
		if (style == 0) {
			env = exp(-x * 2.5);
			if (x > 0.5) { env = max(env, 0.8 * exp(-(x - 0.5) * 5.0)); }
			grow = min(x / 0.08, 1.0);
		} else if (style == 1) {
			env = pow(sin(x * PI), 0.7) * (0.85 + 0.15 * sin(t * 23.0 + cs));
			float cycle = t * 0.7 + hash11(cs);
			seed = cs + floor(cycle) * 5.7;
			seed2 = seed + 5.7;
			morph = smoothstep(0.0, 1.0, fract(cycle));
		} else if (style == 2) {
			env = x < 0.25 ? 1.0 : 0.85;
			seed = cs + floor(t * 8.0) * 3.3;  // Stop-Motion: alle 1/8 s eine neue Zeichnung
			seed2 = seed;
		} else if (style == 3) {
			env = step(0.25, hash11(floor(t * 10.0) + cs));  // Blinken
		} else {
			grow = min(x / 0.45, 1.0);
			env = x < 0.45 ? 1.0 : 1.0 - smoothstep(0.45, 1.0, x);
		}
		if (env <= 0.0) { continue; }

		// Endpunkte: von einer Kante zu einer ANDEREN - Lichtenberg endet im Feld.
		float h0 = hash11(cs + 3.0);
		float h1 = hash11(cs + 4.0);
		float h2 = hash11(cs + 5.0);
		float h3 = hash11(cs + 6.0);
		float e1 = floor(h0 * 4.0);
		vec2 a = rim_point(e1 / 4.0 + 0.01, mix(0.15, 0.85, h2));
		vec2 b;
		if (style == 4) {
			vec2 inward = -normalize(a);
			vec2 tangent = vec2(-inward.y, inward.x);
			b = a + inward * mix(0.8, 1.3, h1) + tangent * (h3 - 0.5) * 0.7;
		} else {
			float e2 = fract((e1 + 1.0 + floor(h1 * 3.0)) / 4.0 + 0.01);
			b = rim_point(e2, mix(0.15, 0.85, h3));
		}

		int k = 3 + int(hash11(cs + 8.0) * 4.0);
		float along;
		vec2 knot;
		vec2 dummy_knot;
		float dummy_along;
		float d = bolt_dist(p, a, b, segments, amp, seed, seed2, morph, jit, grow, k, along, knot);
		acc += paint(d, along, px, env, style, x);
		acc += touch(p - a, px, env, style);
		if (style != 4) { acc += touch(p - b, px, env, style); }

		// ABZWEIGUNGEN: aus Knoten heraus, schräg weg, kürzer und schwächer; sie
		// wachsen erst, wenn die Hauptbahn ihren Knoten erreicht hat.
		vec2 dir = normalize(b - a);
		for (int br = 0; br < 3; br++) {
			if (br >= branches) { break; }
			float bs = cs + 40.0 + float(br) * 9.0;
			if (branches == 1 && hash11(bs) > 0.6) { break; }
			float knot_t = float(k) / float(segments);
			vec2 root = knot;
			if (br > 0) {
				// Weitere Äste setzen an anderen Knoten an.
				int k2 = 2 + int(hash11(bs + 4.0) * float(segments - 3));
				knot_t = float(k2) / float(segments);
				bolt_dist(p, a, b, segments, amp, seed, seed2, morph, jit, 1.0, k2, dummy_along, root);
			}
			float ang = mix(0.5, 1.1, hash11(bs + 1.0)) * (hash11(bs + 2.0) < 0.5 ? -1.0 : 1.0);
			vec2 way = vec2(dir.x * cos(ang) - dir.y * sin(ang), dir.x * sin(ang) + dir.y * cos(ang));
			vec2 tip = root + way * length(b - a) * mix(0.25, 0.45, hash11(bs + 3.0));
			float bgrow = clamp((grow - knot_t) / max(1.0 - knot_t, 0.05) * 1.5, 0.0, 1.0);
			if (bgrow <= 0.0) { continue; }
			float balong;
			float bd = bolt_dist(p, root, tip, BRANCH_SEGMENTS, amp * 1.3, bs, bs, 0.0, jit,
				bgrow, 99, balong, dummy_knot);
			acc += paint(bd, 0.5 + balong * 0.5, px, env * 0.6, style, x);
		}
	}
	ALBEDO = acc * gain;
	ALPHA = 1.0;
}
