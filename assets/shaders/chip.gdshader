shader_type spatial;
render_mode cull_back;

// Keramik-Pokerchip: satter Körper (kein Neon-auf-Schwarz), heller Rand-Punkt-
// Kranz am Mantel (Edge Spots), Inlay-Ring auf der Oberseite und ein dünner
// Neon-Akzentring an der Außenkante, den der Bloom als sauberen Halo aufgreift.
// Ober-/Unterseite vs. Mantel werden über die lokale Normale getrennt, alle
// Muster laufen prozedural aus der lokalen Position - keine Texturen.

uniform vec3 body_color : source_color = vec3(0.42, 0.06, 0.10);
uniform vec3 spot_color : source_color = vec3(0.82, 0.79, 0.70);
uniform vec3 accent_color : source_color = vec3(1.0, 0.37, 0.33);
uniform float accent_energy : hint_range(0.0, 6.0) = 1.1;
// Leises Eigenleuchten der Fläche (unter der Bloom-Schwelle): die Tischszene ist
// dunkel, ohne Selbstlicht versinken die Körper in Schwarz.
uniform float body_glow : hint_range(0.0, 1.0) = 0.55;
uniform float spot_count = 8.0;   // Rand-Punkte rund um den Chip
uniform float radius = 0.9;
uniform float height = 0.28;

varying vec3 v_local;
varying vec3 v_lnormal;   // Modellraum-Normale (NORMAL im fragment() ist Viewraum!)

void vertex() {
	v_local = VERTEX;
	v_lnormal = NORMAL;
}

void fragment() {
	float ang = atan(v_local.z, v_local.x);                 // -PI..PI um die Achse
	float rn = length(vec2(v_local.x, v_local.z)) / radius; // 0 Mitte .. 1 Rand
	float hy = v_local.y / height + 0.5;                     // 0 unten .. 1 oben
	bool is_cap = abs(v_lnormal.y) > 0.5;                    // Deckel vs. Mantel

	vec3 col = body_color;
	float rough = 0.42;
	float metal = 0.0;
	vec3 emis = vec3(0.0);

	// Punkt-Winkel: pro Segment 0..1, Punkt sitzt mittig mit Lücken dazwischen.
	// Schmal gehalten: großflächige Creme-Punkte mitteln sich aus Spielentfernung
	// sonst zu einem hellen Rosa-Körper.
	float seg = fract(ang / (2.0 * PI) * spot_count);
	float spot_ang = smoothstep(0.31, 0.37, seg) * smoothstep(0.69, 0.63, seg);

	if (is_cap) {
		// Vertiefte, glattere Mitte + heller Inlay-Ring + Punkt-Kranz am Rand.
		col = mix(col, body_color * 0.72, smoothstep(0.55, 0.0, rn));
		rough = mix(0.28, 0.42, smoothstep(0.0, 0.6, rn));
		float inlay = smoothstep(0.05, 0.0, abs(rn - 0.60));
		col = mix(col, spot_color, inlay * 0.9);
		float ring_spot = spot_ang * smoothstep(0.78, 0.84, rn) * smoothstep(0.96, 0.9, rn);
		col = mix(col, spot_color, ring_spot);
		// Dünner Neon-Akzentring ganz außen.
		emis = accent_color * accent_energy * smoothstep(0.9, 0.985, rn);
	} else {
		// Mantel: alternierende Rand-Punkte im mittleren Höhenband.
		float mid = smoothstep(0.22, 0.34, hy) * smoothstep(0.78, 0.66, hy);
		col = mix(col, spot_color, spot_ang * mid);
		// Mantel bleibt ohne Emission: die Kanten-Ringe JEDES Chips im Stapel
		// blieben sichtbar und summierten sich zu einem lachsfarbenen Leuchtkörper.
		metal = 0.15;
	}

	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	EMISSION = emis + col * body_glow;
}
