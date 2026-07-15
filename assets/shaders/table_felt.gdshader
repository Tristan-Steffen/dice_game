shader_type canvas_item;
// Casino-Tischfilz: der 2D-Hintergrund des Tisch-Displays (ersetzt die flache
// Hintergrundfarbe, siehe TableScreen._build_content). Alles AUSSERHALB der
// "Fenster" liest sich damit als dunkler violetter Filz - matt und stofflich:
// feine Körnung (Fasern) + großflächige Wolken (abgewetzte Stellen) + sanfte
// Abdunklung zum Rand. Die Fenster-Panels liegen darüber; dass ihr leicht
// durchscheinender Grund einen Hauch Filz durchschimmern lässt, ist gewollt
// (Glasscheiben AUF dem Filz). Spiegelnd ist nur das Fenster-Glas - der Filz
// bekommt im Glas-Shader keine Spiegelung (siehe screen_glass.gdshader).

uniform vec3 felt_color : source_color = vec3(0.145, 0.09, 0.21);  // dunkles Casino-Violett
uniform vec3 felt_shadow : source_color = vec3(0.075, 0.045, 0.115); // Tiefen (Rand/Wolken)
uniform float grain_strength : hint_range(0.0, 0.5) = 0.14;  // Faser-Körnung
uniform float cloud_strength : hint_range(0.0, 1.0) = 0.35;  // großflächige Flecken
uniform float grain_scale = 900.0;  // Körnungs-Dichte über die Fläche
uniform float cloud_scale = 9.0;    // Wolken-Dichte über die Fläche

// Klassischer Hash + Value-Noise (billig, reicht für Stoff völlig).
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

void fragment() {
	// Faser-Körnung: zwei fein versetzte Rausch-Lagen wirken wie verfilzte
	// Fasern statt wie reines Pixelrauschen.
	float grain = value_noise(UV * grain_scale) * 0.65
		+ value_noise(UV * grain_scale * 2.3 + vec2(17.0, 41.0)) * 0.35;
	// Großflächige Wolken: leicht ungleichmäßig gefärbter Stoff.
	float clouds = value_noise(UV * cloud_scale) * 0.6
		+ value_noise(UV * cloud_scale * 2.7 + vec2(5.0, 9.0)) * 0.4;
	// Sanfte Abdunklung zum Tischrand (Vignette).
	float edge = smoothstep(0.95, 0.45, length((UV - 0.5) * vec2(1.25, 1.0)));

	vec3 felt = mix(felt_shadow, felt_color, 0.55 + 0.45 * edge);
	felt = mix(felt, felt_shadow, clouds * cloud_strength);
	felt *= 1.0 + (grain - 0.5) * 2.0 * grain_strength;
	COLOR = vec4(felt, 1.0);
}
