shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded, shadows_disabled;

// DURCHGEBRANNT: die Auflage einer Seite. EIN Quad je Seite zwischen Runen-
// Auflage und Ziffer (die Ziffer bleibt lesbar - der Würfel zählt für die Hand),
// in SEITEN-Koordinaten -1..1. Alphagemischt: sie DECKT und DUNKELT, sie leuchtet
// nur dort, wo Glut sitzt.
//
// burn_style ist der Autoren-Schalter der fünf Fassungen (Spieler-Wahl offen):
// 0 RUSS       - ungleichmäßige Rußflecken, matt, tot
// 1 RISSE      - der Körper ist geborsten, in den Rissen glimmt Restglut
// 2 ASCHE      - ausgebrannt zu hellgrauer Asche mit Flocken
// 3 VERKOHLT   - schwarz verkohlt, an den Kanten sprühen letzte Funken (+ Rauch)
// 4 GESCHMOLZEN - die Fläche ist versengt und verglast, dunkel zur Mitte

uniform float burn_style = 0.0;
uniform float face_seed = 0.0;
uniform float phase = 0.0;

const int SEGMENTS = 8;
const vec3 SOOT = vec3(0.03, 0.025, 0.03);
const vec3 DUST = vec3(0.16, 0.15, 0.15);
const vec3 EMBER = vec3(1.0, 0.36, 0.08);
const vec3 ASH = vec3(0.64, 0.62, 0.6);
const vec3 SCORCH = vec3(0.34, 0.19, 0.09);

float hash11(float x) {
	return fract(sin(x * 12.9898 + 4.1414) * 43758.5453);
}

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Wert-Rauschen und drei Oktaven davon.
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	return noise(p) * 0.5 + noise(p * 2.1 + 3.7) * 0.3 + noise(p * 4.3 + 9.1) * 0.2;
}

vec2 rim_point(float u, float v) {
	float e = floor(u * 4.0);
	float s = v * 2.0 - 1.0;
	if (e < 0.5) { return vec2(s, -1.0); }
	if (e < 1.5) { return vec2(1.0, s); }
	if (e < 2.5) { return vec2(-s, 1.0); }
	return vec2(-1.0, -s);
}

// Abstand zu einer gezackten Bahn (die Blitz-Maschine, hier EINGEFROREN: ein Riss).
float crack_dist(vec2 p, vec2 a, vec2 b, float amp, float seed, int k, out vec2 knot) {
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
		vec2 v = mix(a, b, t) + nrm * (walk - t * total) * amp * len;
		if (i == k) { knot = v; }
		vec2 ab = v - prev;
		float h = clamp(dot(p - prev, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
		best = min(best, length(p - prev - ab * h));
		prev = v;
	}
	return best;
}

// Die Risse der Seite: zwei Bahnen von Kante zu Kante, je ein Ast.
float cracks(vec2 p, float seed) {
	float best = 1e9;
	for (int c = 0; c < 2; c++) {
		float cs = seed + float(c) * 53.0;
		float e1 = floor(hash11(cs + 1.0) * 4.0);
		float e2 = fract((e1 + 1.0 + floor(hash11(cs + 2.0) * 3.0)) / 4.0 + 0.01);
		vec2 a = rim_point(e1 / 4.0 + 0.01, mix(0.1, 0.9, hash11(cs + 3.0)));
		vec2 b = rim_point(e2, mix(0.1, 0.9, hash11(cs + 4.0)));
		vec2 knot;
		best = min(best, crack_dist(p, a, b, 0.22, cs, 3 + int(hash11(cs + 5.0) * 3.0), knot));
		vec2 dir = normalize(b - a);
		float ang = mix(0.6, 1.1, hash11(cs + 6.0)) * (hash11(cs + 7.0) < 0.5 ? -1.0 : 1.0);
		vec2 way = vec2(dir.x * cos(ang) - dir.y * sin(ang), dir.x * sin(ang) + dir.y * cos(ang));
		vec2 dummy;
		best = min(best, crack_dist(p, knot, knot + way * 0.5, 0.3, cs + 40.0, 99, dummy));
	}
	return best;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	p.y = -p.y;
	float px = length(fwidth(p));
	float t = TIME + phase;
	int style = int(burn_style + 0.5);
	vec2 q = p * 2.4 + vec2(face_seed * 1.7, face_seed * 0.9);
	float grain = fbm(q);
	float fine = noise(p * 40.0 + face_seed);
	float rim = 1.0 - min(min(1.0 - abs(p.x), 1.0 - abs(p.y)), 1.0);  // 1 an der Kante
	vec3 col = SOOT;
	float alpha = 0.0;

	if (style == 1) {
		// RISSE: Ruß dazu, und in den Rissen glimmt Restglut, langsam wandernd.
		float cd = cracks(p, face_seed * 13.7);
		float soot = smoothstep(0.3, 0.7, grain) * 0.55;
		col = mix(DUST, SOOT, smoothstep(0.4, 0.8, grain));
		alpha = soot;
		float pulse = 0.5 + 0.5 * sin(t * 0.9 + p.x * 2.0 + p.y * 1.3);
		float ember = exp(-cd / max(0.035, px * 1.5)) * (0.35 + 0.65 * pulse);
		float dark = 1.0 - smoothstep(0.0, max(0.05, px * 2.5), cd);
		col = mix(col, SOOT, dark);
		alpha = max(alpha, dark * 0.9);
		col = mix(col, EMBER, ember);
		alpha = max(alpha, ember);
	} else if (style == 2) {
		// ASCHE: hellgrau, flockig, mit dunklen Bruchlinien.
		float cd = cracks(p, face_seed * 13.7);
		col = ASH * (0.8 + 0.4 * grain) * (0.9 + 0.2 * fine);
		float flake = 1.0 - smoothstep(0.0, max(0.03, px * 2.0), cd);
		col = mix(col, DUST, flake * 0.8);
		alpha = 0.78;
	} else if (style == 3) {
		// VERKOHLT: schwerer Ruß, und an den Kanten sprühen letzte Funken.
		float soot = smoothstep(0.15, 0.6, grain) * 0.85;
		col = mix(DUST * 0.7, SOOT, smoothstep(0.3, 0.7, grain));
		alpha = soot;
		vec2 cell = floor(p * 14.0);
		float spark = hash21(cell + face_seed);
		float lit = step(0.9, spark) * smoothstep(0.45, 0.85, rim);
		float flick = 0.3 + 0.7 * hash21(cell + floor(t * (2.0 + spark * 6.0)));
		float dot_glow = 1.0 - smoothstep(0.0, 0.5, length(fract(p * 14.0) - 0.5) * 2.0);
		float ember = lit * flick * dot_glow;
		col = mix(col, EMBER, ember);
		alpha = max(alpha, ember);
	} else if (style == 4) {
		// GESCHMOLZEN: versengt und verglast - dunkel zur Mitte, braun zur Kante,
		// die Wellen der Schmelze schimmern schwach.
		vec2 warp = vec2(noise(q * 1.5), noise(q * 1.5 + 7.0)) - 0.5;
		float r = length(p + warp * 0.35);
		col = mix(SOOT, SCORCH, smoothstep(0.25, 1.0, r));
		float sheen = pow(noise(p * 6.0 + warp * 4.0 + face_seed), 6.0) * 0.5;
		col += vec3(0.55, 0.42, 0.3) * sheen;
		alpha = 0.82;
	} else {
		// RUSS: ungleichmäßige Flecken, dazwischen Staub.
		float soot = smoothstep(0.3, 0.75, grain);
		col = mix(DUST, SOOT, soot);
		alpha = mix(0.35, 0.8, soot) * (0.85 + 0.15 * fine);
	}
	ALBEDO = col;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
