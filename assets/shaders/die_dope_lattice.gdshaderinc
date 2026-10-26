// Die VEREDELUNG einer Seite: je Material EINE eigene Geometrie, und jede
// erzaehlt, wie ihr Material entstanden ist (Spieler-Entscheid 2026-10-25).
// Prozedural gerechnet, darum ohne Textur und in jeder Entfernung scharf.
// field_glow traegt die Flaeche als EMISSION: am Tisch liegt kein Licht ausser
// dem schwachen Ambient, eine Seite bringt ihr Aussehen also selbst mit.

uniform int kind = 0;
uniform vec3 body = vec3(1.0);
uniform vec3 light = vec3(1.0);
uniform float gain = 1.0;
uniform float cells = 4.0;
uniform float width = 0.014;
uniform float shade_amount = 0.0;
uniform float field_glow = 0.52;
uniform float extra_gain = 0.0;
uniform float metallic_amount = 0.0;
uniform float roughness_amount = 0.1;
uniform float alpha_amount = 1.0;

varying vec3 tview;

const int KIND_FACETS = 0;   // Rubin (Schliff) und Knochen (Trabekel)
const int KIND_FLOW = 1;     // Bernstein
const int KIND_RINGS = 2;    // Gold
const int KIND_CRYSTAL = 3;  // Glas
const int KIND_WEAVE = 4;    // Kupfer

float aa_line(float d, float w) {
	float e = fwidth(d) * 1.2 + 0.0005;
	return 1.0 - smoothstep(w - e, w + e, d);
}

float hash1(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// FACETTEN: Voronoi-Zellen. Beim RUBIN der Schliff eines Steins, beim KNOCHEN
// das Strebenwerk der Spongiosa - dieselbe Geometrie, umgekehrt eingefaerbt.
// Erst die naechste Zelle suchen, dann den Abstand zu ihren Raendern.
float facet_distance(vec2 uv, out float shade) {
	vec2 x = uv * cells;
	vec2 n = floor(x);
	vec2 f = fract(x);
	vec2 mg = vec2(0.0);
	vec2 mr = vec2(0.0);
	float md = 8.0;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 g = vec2(float(i), float(j));
			vec2 r = g + hash2(n + g) - f;
			float t = dot(r, r);
			if (t < md) { md = t; mr = r; mg = g; }
		}
	}
	shade = hash1(n + mg);
	md = 8.0;
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			vec2 g = mg + vec2(float(i), float(j));
			vec2 r = g + hash2(n + g) - f;
			vec2 diff = r - mr;
			if (dot(diff, diff) > 0.00001) {
				md = min(md, dot(0.5 * (mr + r), normalize(diff)));
			}
		}
	}
	return md / cells;
}

// FLUSS (Bernstein): Harz ist geflossen und erstarrt - Schlierenbaender, und
// dazwischen die Blasen, die dabei gefangen blieben.
float flow_distance(vec2 uv, out float bubble) {
	float warp = 0.14 * sin(uv.x * 6.2831) + 0.06 * sin(uv.x * 14.3 + 1.7);
	vec2 p = vec2(uv.x, uv.y + warp) * cells;
	float f = fract(p.y);
	float band = min(f, 1.0 - f) / cells;
	vec2 cell = floor(p);
	vec2 fr = fract(p) - vec2(0.5);
	vec2 j = (hash2(cell) - vec2(0.5)) * 0.45;
	float r = 0.15 + 0.13 * hash1(cell + vec2(3.1, 7.7));
	float dist = length(fr - j);
	bubble = smoothstep(r, r * 0.2, dist);
	return min(band, abs(dist - r) / cells);
}

// RINGE (Gold): die Praegung einer Muenze.
float ring_distance(vec2 uv) {
	float t = fract(length(uv - vec2(0.5)) * 2.0 * cells);
	return min(t, 1.0 - t) / (cells * 2.0);
}

// Golds Muenzrand: feine Riffelung auf dem aeusseren Saum.
float coin_reed(vec2 uv) {
	float br = max(abs(uv.x - 0.5), abs(uv.y - 0.5)) * 2.0;
	float along = abs(uv.x - 0.5) > abs(uv.y - 0.5) ? uv.y : uv.x;
	return smoothstep(0.80, 0.86, br) * (0.5 + 0.5 * cos(along * 150.0));
}

// KRISTALL (Glas): geschliffene Rauten, in jeder ein Kreuz - der Schliff eines
// Kristallglases.
float crystal_distance(vec2 uv) {
	float u = fract((uv.x + uv.y) * cells);
	float v = fract((uv.x - uv.y) * cells);
	float grid = min(min(u, 1.0 - u), min(v, 1.0 - v)) / (cells * 1.4142);
	vec2 c = vec2(u, v) - vec2(0.5);
	float star = min(abs(c.x), abs(c.y)) / (cells * 1.4142);
	float inside = step(max(abs(c.x), abs(c.y)), 0.33);
	return min(grid, mix(1.0, star, inside));
}

// GEWEBE (Kupfer): Korbgeflecht aus kurzen Staeben - gewickelter Draht.
// Die Paritaet der Zelle entscheidet, ob ihr Stab quer oder laengs liegt.
float weave_distance(vec2 uv) {
	vec2 p = uv * cells;
	vec2 cell = floor(p);
	vec2 c = fract(p) - vec2(0.5);
	float checker = mod(cell.x + cell.y, 2.0);
	float bar = (checker < 0.5) ? abs(c.y) : abs(c.x);
	return abs(bar - 0.30) / cells;
}

void dope_lattice(vec2 uv, vec3 tv, out vec3 albedo, out vec3 emission,
		out float metal, out float rough, out float alpha) {
	float d = 1.0;
	float shade = 1.0;
	float extra = 0.0;  // Blasen (Bernstein), Streiflicht und Riffelrand (Gold)
	float sheen = 0.0;  // ... davon der Anteil auf der Albedo
	float matte = 0.0;  // ... und wie matt der Rest daneben liegt
	if (kind == KIND_FACETS) {
		d = facet_distance(uv, shade);
	} else if (kind == KIND_FLOW) {
		d = flow_distance(uv, extra);
	} else if (kind == KIND_RINGS) {
		d = ring_distance(uv);
		// Das Streiflicht WANDERT beim Drehen: tangentialer Blickwinkel statt UV.
		float sweep = exp(-pow(((uv.x - uv.y) * 0.707 - tv.x * 0.35) * 3.0, 2.0));
		float reed = coin_reed(uv);
		sheen = 0.30 * sweep + 0.25 * reed;
		extra = 0.6 * sweep + reed;
		matte = 0.30 * (1.0 - sweep);
	} else if (kind == KIND_CRYSTAL) {
		d = crystal_distance(uv);
	} else {
		d = weave_distance(uv);
	}
	float on_line = aa_line(d, width);
	// Die Linie faerbt auch die ALBEDO - sonst traegt ein Gitter ohne Lampe
	// (Knochen, gain 0) gar nichts.
	vec3 base = mix(body, light, on_line)
		* (1.0 - shade_amount + shade_amount * shade);
	albedo = base + light * sheen;
	emission = base * field_glow + light * (on_line * gain + extra * extra_gain);
	metal = metallic_amount;
	rough = roughness_amount + matte;
	alpha = alpha_amount;
}
