shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

// AUSKLEIDUNG der MAGAZIN-Grube (PackPitView). Sie kennt ZWEI Rollen: velvet = 1
// kleidet den BODEN, velvet = 0 die WAENDE - beide brauchen dieselbe
// Tiefenrechnung und dieselbe Fugenteilung, darum stecken sie in einem Shader.
// Die Handschrift ist das ARCHIV und nur das: Samt und dunkle Metallpaneele, eine
// dezente Neon-Fuge, sonst nichts. Ein Archiv wirbt nicht - die Laeden stehen
// flaechig auf dem Tisch und brauchen keine Auskleidung.
// In eine Grube faellt KEIN Szenenlicht - alles, was man sieht, ist EMISSION;
// ALBEDO bleibt gesetzt, damit Spill-Lichter obendrauf toenen duerfen. Die Basis
// bleibt dunkel: die Ware muss darin poppen.

uniform float velvet : hint_range(0.0, 1.0) = 0.0;
uniform vec3 base_color : source_color = vec3(0.055, 0.052, 0.080);
uniform vec3 seam_color : source_color = vec3(0.52, 0.45, 0.62);
uniform float field_energy = 1.0;   // Grundhelligkeit der Flaeche
uniform float seam_energy = 1.0;    // Helligkeit der Neon-Fuge
uniform float panel_width = 2.4;    // Paneelbreite in Welteinheiten
uniform float pit_depth = 3.0;      // Tiefe der Grube (fuer den Tiefenverlauf)
uniform float glass_y = 0.0;        // Welt-Y der Glasebene (Oberkante der Grube)
// Die Grube selbst in Welt-XZ: der Schimmer des Samts ist EIN Verlauf ueber die
// ganze Flaeche, kein sich wiederholendes Muster - sonst laege ein Streifenmuster
// im Boden statt einer Lichtrichtung.
uniform vec2 field_center = vec2(0.0);
uniform vec2 field_half = vec2(1.0);
// Deckel der Emission: darueber laufen die drei Kanaele zu Weiss zusammen, und
// aus einer Farbe wird eine helle Flaeche (die Kondensatorbank-Lehre).
uniform float emission_cap = 1.45;

varying vec3 world_pos;
varying vec3 world_normal;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 field;
	vec3 neon = vec3(0.0);
	// Laengsrichtung der Wand und Tiefe darin.
	float along = abs(world_normal.x) > 0.5 ? world_pos.z : world_pos.x;
	float cell = along / max(panel_width, 0.05);
	float idx = floor(cell);
	float f = fract(cell);
	float edge = min(f, 1.0 - f);
	float soft = max(fwidth(cell), 0.0005) * 1.6;
	float joint = 1.0 - smoothstep(0.0, soft, edge);
	float sink = clamp((glass_y - world_pos.y) / max(pit_depth, 0.05), 0.0, 1.0);
	vec2 p = world_pos.xz;
	vec2 n = (p - field_center) / max(field_half, vec2(0.01));

	if (velvet > 0.5) {
		// BODEN, Samt: feiner Flor (hochfrequent) auf einer weichen Wolkenlage,
		// dazu EIN diagonaler Schimmer ueber die ganze Flaeche - der Stoff hat eine
		// Strichrichtung - und ein Auslaufen zu den Waenden hin, damit der Boden als
		// Grund einer Vertiefung liest und nicht als Platte.
		float pile = value_noise(p * 24.0) * 0.6 + value_noise(p * 61.0 + vec2(9.0, 4.0)) * 0.4;
		float clouds = value_noise(p * 3.4 + vec2(3.0, 7.0));
		float sheen = smoothstep(-0.9, 1.1, n.x * 0.55 + n.y * 0.85);
		float trough = 1.0 - 0.45 * smoothstep(0.35, 1.0, max(abs(n.x), abs(n.y)));
		field = base_color * (0.86 + 0.28 * clouds);
		field *= 1.0 + (pile - 0.5) * 0.30;
		field *= trough;
		field += seam_color * sheen * 0.030;
	} else {
		// WAND, Metallpaneele: die Fugen laufen quer zur Wandrichtung, dazu eine
		// gebuerstete Struktur und ein Tiefenverlauf (unten dunkler).
		float plate = hash21(vec2(idx, 3.0));
		float brushed = value_noise(vec2(along * 26.0, world_pos.y * 2.2));
		field = base_color * (0.85 + 0.30 * plate);
		field *= 1.0 + (brushed - 0.5) * 0.28;
		field *= 1.0 - 0.62 * sink;                       // nach unten ins Dunkel
		field *= 1.0 - 0.45 * joint;                      // die Fuge ist eine Rille
		// Neon IN der Rille, oben am hellsten - der Saum unter dem Kragen speist sie.
		neon = seam_color * seam_energy * joint * (1.0 - 0.72 * sink);
		// Eine einzelne waagerechte Schulterlinie knapp unter der Kante.
		float rail = 1.0 - smoothstep(0.0, 0.045, abs(sink - 0.12));
		neon += seam_color * seam_energy * rail * 0.30;
	}

	// Der Deckel wirkt auf den GANZEN Ton, nicht je Kanal: gekappt wuerde aus
	// Magenta ein Rosa.
	vec3 lit = field * field_energy + neon;
	float peak = max(max(lit.r, lit.g), lit.b);
	lit *= min(1.0, emission_cap / max(peak, 0.0001));

	ALBEDO = field;
	EMISSION = lit;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
