shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

// AUSKLEIDUNG der Gruben (PackPitView): Magazin, Laden und Hinterzimmer teilen
// sie. Sie kennt ZWEI Rollen und ZWEI Handschriften.
// Die Rolle sagt, WELCHE Flaeche: velvet = 1 kleidet den BODEN, velvet = 0 die
// WAENDE - beide brauchen dieselbe Tiefenrechnung und dieselbe Fugenteilung,
// darum stecken sie in einem Shader.
// Die Handschrift sagt, WOFUER: bay = 0 ist das ARCHIV (Magazin) - Samt und
// dunkle Metallpaneele, eine dezente Neon-Fuge, sonst nichts; bay = 1 ist die
// VERKAUFS-BUCHT (Laden, Hinterzimmer): tiefdunkler Lack in feinem Plattenraster,
// schmale Goldlinien in den Fugen, EIN zurueckhaltender warmer Schimmer und die
// Marquee als dezente Lichtpunktlinie. Ein Archiv wirbt nicht, eine Auslage
// zeigt - aber sie zeigt WARE: die Bucht ist die Fassung, nicht der Stein.
// In eine Grube faellt KEIN Szenenlicht - alles, was man sieht, ist EMISSION;
// ALBEDO bleibt gesetzt, damit Spill-Lichter obendrauf toenen duerfen. Die
// Basis bleibt in beiden Handschriften dunkel: die Ware muss darin poppen.

uniform float velvet : hint_range(0.0, 1.0) = 0.0;
uniform float bay : hint_range(0.0, 1.0) = 0.0;
uniform vec3 base_color : source_color = vec3(0.055, 0.052, 0.080);
uniform vec3 seam_color : source_color = vec3(0.52, 0.45, 0.62);
uniform float field_energy = 1.0;   // Grundhelligkeit der Flaeche
uniform float seam_energy = 1.0;    // Helligkeit der Neon-Fuge (Archiv)
uniform float panel_width = 2.4;    // Paneelbreite in Welteinheiten
uniform float pit_depth = 3.0;      // Tiefe der Grube (fuer den Tiefenverlauf)
uniform float glass_y = 0.0;        // Welt-Y der Glasebene (Oberkante der Grube)
// Die Grube selbst in Welt-XZ: der Schimmer des Samts ist EIN Verlauf ueber die
// ganze Flaeche, kein sich wiederholendes Muster - sonst laege ein Streifenmuster
// im Boden statt einer Lichtrichtung.
uniform vec2 field_center = vec2(0.0);
uniform vec2 field_half = vec2(1.0);

// Die Stellschrauben der BUCHT. Ihre Palette ist Kunst, keine Konfiguration -
// sie steht als Konstante darunter; regelbar ist nur, wie laut sie spricht.
uniform float sheen_energy = 1.0;       // warmer Schimmer auf dem Lack
uniform float joint_energy = 0.55;      // Goldlinien in den Fugen
uniform float bulb_energy = 0.42;       // Amber-Birnen der Marquee
// Deckel der Emission: darueber laufen die drei Kanaele zu Weiss zusammen, und
// aus einer warmen Bucht wird eine helle Flaeche (die Kondensatorbank-Lehre).
uniform float emission_cap = 1.45;

// Die Palette der Bucht: EINE warme Familie. Gold zeichnet die Fugen und den
// Schimmer, Amber die Birnen (dieselbe Farbe, in der auch Kragensaum und
// Klappenfuge stehen - die Bucht spricht mit einer Stimme).
const vec3 GOLD = vec3(1.000, 0.800, 0.450);
const vec3 AMBER = vec3(1.000, 0.745, 0.235);

// Wo die Birnenreihe sitzt (Anteil der Grubentiefe) und wie dicht sie steht
// (Anteil der Paneelbreite). Der Boden rechnet in groeberen Platten als die Wand:
// die Wand braucht viele schmale Felder nebeneinander, der Boden wenige ruhige.
const float BULB_ROW = 0.22;
const float BULB_SHARE = 0.20;
const float FLOOR_PLATE = 1.6;

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
	// Laengsrichtung der Wand und Tiefe darin - beide Handschriften rechnen damit.
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

	if (velvet > 0.5 && bay < 0.5) {
		// ARCHIV-BODEN, Samt: feiner Flor (hochfrequent) auf einer weichen
		// Wolkenlage, dazu EIN diagonaler Schimmer ueber die ganze Flaeche - der
		// Stoff hat eine Strichrichtung - und ein Auslaufen zu den Waenden hin,
		// damit der Boden als Grund einer Vertiefung liest und nicht als Platte.
		float pile = value_noise(p * 24.0) * 0.6 + value_noise(p * 61.0 + vec2(9.0, 4.0)) * 0.4;
		float clouds = value_noise(p * 3.4 + vec2(3.0, 7.0));
		float sheen = smoothstep(-0.9, 1.1, n.x * 0.55 + n.y * 0.85);
		float trough = 1.0 - 0.45 * smoothstep(0.35, 1.0, max(abs(n.x), abs(n.y)));
		field = base_color * (0.86 + 0.28 * clouds);
		field *= 1.0 + (pile - 0.5) * 0.30;
		field *= trough;
		field += seam_color * sheen * 0.030;
	} else if (velvet < 0.5 && bay < 0.5) {
		// ARCHIV-WAND, Metallpaneele: die Fugen laufen quer zur Wandrichtung, dazu
		// eine gebuerstete Struktur und ein Tiefenverlauf (unten dunkler).
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
	} else if (velvet > 0.5) {
		// BUCHT-BODEN: die Bucht ist FLACH, von ihren Waenden sieht die Tischkamera
		// kaum einen Streifen - also traegt der BODEN die Schrift, und die Schrift
		// ist hier LEISE. Von oben ist er eine tiefdunkle Lackplatte in feinem
		// Raster, deren Fugen als schmale Goldlinien stehen, dazu EIN warmer
		// Schimmer quer darueber und rings um die Auslage die Marquee als
		// Lichtpunktlinie. Kein Farbfeld: die Farbe gehoert der Ware, die DARAUF
		// liegt.
		vec2 g = p / max(panel_width * FLOOR_PLATE, 0.05);
		vec2 gi = floor(g);
		vec2 gf = fract(g);
		vec2 gsoft = max(fwidth(g), vec2(0.0005)) * 1.6;
		float seam_x = 1.0 - smoothstep(0.0, gsoft.x, min(gf.x, 1.0 - gf.x));
		float seam_y = 1.0 - smoothstep(0.0, gsoft.y, min(gf.y, 1.0 - gf.y));
		float seam = max(seam_x, seam_y);
		// Die Koernung misst sich an der Plattengroesse, nicht an Welteinheiten: fest
		// getippt wurde sie in einer grossen Bucht unterpixelig und flimmerte als
		// grobes Fleckenmuster.
		float grain = value_noise(g * 1.6);
		// Der Lack liegt fast gleichmaessig: die Platten unterscheiden sich nur um
		// eine Nuance, sonst laege ein Schachbrett unter der Auslage.
		field = base_color * (0.92 + 0.14 * hash21(gi + vec2(0.5, 0.5)));
		field *= 1.0 + (grain - 0.5) * 0.12;
		field *= 1.0 - 0.42 * seam;                       // die Fuge ist eine Rille

		// EIN diagonaler Schimmer ueber die ganze Flaeche - eine Lichtrichtung, wie
		// sie ueber poliertem Lack steht, kein sich wiederholendes Muster.
		float sheen = smoothstep(-0.9, 1.1, n.x * 0.55 + n.y * 0.85);
		field += GOLD * sheen * sheen_energy * 0.045;

		// Die Fugen leuchten schmal und in EINER Farbe: ein Rasterrahmen aus Gold,
		// keine zwei Neonfarben, die sich im Boden kreuzen.
		neon += GOLD * seam * joint_energy * 0.30;

		// Die Marquee: Birnen auf einem Rechteck knapp innerhalb der Waende. Ihre
		// Teilung laeuft LAENGS der Kante, an der sie gerade sitzen.
		float ring = 1.0 - smoothstep(0.0, 0.028, abs(max(abs(n.x), abs(n.y)) - 0.90));
		float pitch = max(panel_width * BULB_SHARE, 0.05);
		float run = abs(n.x) > abs(n.y) ? p.y : p.x;
		neon += AMBER * ring
			* (1.0 - smoothstep(0.10, 0.24, abs(fract(run / pitch) - 0.5)))
			* bulb_energy;
	} else {
		// BUCHT-WAND: derselbe Lack stehend. Dunkle Paneele mit gebuersteter
		// Struktur, ein Tiefenverlauf ins Dunkel, Goldlinien in den Fugen, eine
		// Schulterlinie knapp unter dem Kragen und darunter die Birnenreihe.
		float plate = hash21(vec2(idx, 3.0));
		float brushed = value_noise(vec2(along * 22.0, world_pos.y * 2.6));
		field = base_color * (0.94 + 0.14 * plate);
		field *= 1.0 + (brushed - 0.5) * 0.16;
		field *= 1.0 - 0.52 * sink;
		field *= 1.0 - 0.50 * joint;
		// Ein Hauch warmes Licht laeuft unter dem Kragen an und verliert sich nach
		// unten - der Schimmer des Lacks, kein Leuchtfeld.
		field += GOLD * (1.0 - smoothstep(0.0, 0.65, sink)) * sheen_energy * 0.055;

		neon += GOLD * joint * joint_energy * (1.0 - 0.55 * sink);
		float rail = 1.0 - smoothstep(0.0, 0.05, abs(sink - 0.10));
		neon += GOLD * rail * joint_energy * 0.40;

		float pitch = max(panel_width * BULB_SHARE, 0.05);
		float bx = fract(along / pitch) - 0.5;
		float drop = (glass_y - world_pos.y) / pitch;
		float row = BULB_ROW * max(pit_depth, 0.05) / pitch;
		neon += AMBER * (1.0 - smoothstep(0.09, 0.21, length(vec2(bx, drop - row))))
			* bulb_energy;
	}

	// Der Deckel wirkt auf den GANZEN Ton, nicht je Kanal: gekappt wuerde aus
	// Magenta ein Rosa und aus Amber ein Weiss.
	vec3 lit = field * field_energy + neon;
	float peak = max(max(lit.r, lit.g), lit.b);
	lit *= min(1.0, emission_cap / max(peak, 0.0001));

	ALBEDO = field;
	EMISSION = lit;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
