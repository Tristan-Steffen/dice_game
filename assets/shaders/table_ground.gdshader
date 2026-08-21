shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

// "Endloser" Pokertisch-Filz unter und um den Screen: exakt dieselbe Stoff-
// Rechnung wie table_felt.gdshader, aber über VIRTUELLE Screen-UVs aus den
// Welt-Koordinaten - jenseits des Glases extrapoliert (UV < 0 / > 1), damit
// Rauten, Wolken und Körnung an der elliptischen Glaskante IN PHASE
// weiterlaufen. Der Tisch hat keinen Rand: Sichtbarkeit kommt aus einem
// AUTORISIERTEN Lichtpool (EMISSION; glass_energy = emission_energy des
// screen_glass, damit die Kante den Anzeigeton exakt trifft), der mit dem
// Abstand zum Screen-Rechteck ins Dunkel ausläuft - die Szenenlichter
// (Reichweite ~55) trügen den weiten Boden allein nicht. ALBEDO bleibt
// gesetzt, damit Spill-Lichter künftiger Features obendrauf tönen.

uniform vec3 felt_color : source_color = vec3(0.088, 0.056, 0.128);  // wie table_felt.gdshader
uniform vec3 felt_shadow : source_color = vec3(0.042, 0.026, 0.066);
uniform float grain_strength : hint_range(0.0, 0.5) = 0.2;
uniform float cloud_strength : hint_range(0.0, 1.0) = 0.3;
uniform float grain_scale = 900.0;   // Skalen wie im 2D-Filz (je Screen-Breite/-Höhe)
uniform float cloud_scale = 9.0;
uniform float diamond_scale = 21.0;
uniform float diamond_strength : hint_range(0.0, 1.0) = 0.5;

// Screen-Halbmaße in Welteinheiten: x = Höhe (84.8/2), z = Breite (124.8/2).
uniform vec2 screen_half = vec2(42.4, 62.4);
uniform float pool_fade = 110.0;    // Weltstrecke des Auslaufs hinter der Screen-Kante
uniform float glass_energy = 1.2;   // screen_glass.emission_energy: Anschluss-Ton der Kante

// Die Löcher des Tisches sind echt (siehe screen_glass.pit_rects): der Boden darf
// nicht dahinterstehen, sonst blickt man auf Filz statt in Grube oder Schacht.
// Platz 0 ist dauerhaft die Magazin-Grube, der Rest sind die Hebebühnen-Schächte.
// xy = Welt-Min (x, z), zw = Welt-Max; min == max = kein Loch.
const int MAX_PITS = 5;
uniform int pit_count = 0;
uniform vec4 pit_bounds[MAX_PITS];

varying vec2 world_xz;

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
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	for (int i = 0; i < pit_count; i++) {
		vec4 hole = pit_bounds[i];
		if (hole.z > hole.x && world_xz.x > hole.x && world_xz.x < hole.z
				&& world_xz.y > hole.y && world_xz.y < hole.w) {
			discard;
		}
	}
	// Virtuelle Display-UVs: Welt-Z = Screen-Breite, Welt-X = Screen-Höhe.
	// Ein Vorzeichen-Irrtum spiegelte nur das Rauschen - das Rauten-Gitter
	// ist spiegelsymmetrisch und bliebe trotzdem in Phase.
	vec2 uv = vec2((world_xz.y + screen_half.y) / (screen_half.y * 2.0),
		(screen_half.x - world_xz.x) / (screen_half.x * 2.0));
	float aspect = screen_half.y / screen_half.x;

	// Ab hier 1:1 die Rechnung aus table_felt.gdshader (fabric = 1).
	float grain = value_noise(uv * grain_scale) * 0.65
		+ value_noise(uv * grain_scale * 2.3 + vec2(17.0, 41.0)) * 0.35;
	float clouds = value_noise(uv * cloud_scale) * 0.6
		+ value_noise(uv * cloud_scale * 2.7 + vec2(5.0, 9.0)) * 0.4;

	vec2 q = vec2(uv.x * aspect, uv.y) * diamond_scale;
	vec2 dg = vec2(q.x + q.y, q.x - q.y);
	float e = min(0.5 - abs(fract(dg.x) - 0.5), 0.5 - abs(fract(dg.y) - 0.5));
	float seam = 1.0 - smoothstep(0.0, 0.035, e);
	float inner = 1.0 - smoothstep(0.0, 0.025, abs(e - 0.12));
	float band = smoothstep(0.035, 0.055, e) - smoothstep(0.095, 0.115, e);

	vec3 felt = mix(felt_color, felt_shadow, clouds * cloud_strength);
	felt *= 1.0 - diamond_strength * (seam * 0.8 + inner * 0.5 - band * 0.35);
	felt *= 1.0 + (grain - 0.5) * 2.0 * grain_strength;

	// Abstand zum Screen-Rechteck (SDF-Box): 0 unterm Screen, dann Auslauf.
	float dist = length(max(abs(world_xz) - screen_half, vec2(0.0)));
	float pool = (1.0 - smoothstep(0.0, pool_fade, dist)) * glass_energy;

	EMISSION = felt * pool;
	ALBEDO = felt;
	ROUGHNESS = 1.0;
}
