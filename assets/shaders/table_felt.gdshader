shader_type canvas_item;
// Casino-Tischfilz: der 2D-Hintergrund des Tisch-Displays (ersetzt die flache
// Hintergrundfarbe, siehe TableScreen._build_content). Alles AUSSERHALB der
// "Fenster" liest sich damit als dunkler violetter Filz - matt und stofflich:
// feine Körnung (Fasern) + großflächige Wolken (abgewetzte Stellen). KEINE
// Rand-Vignette mehr: der Filz läuft hinter dem Glas als endloser Boden weiter
// (table_ground.gdshader), eine Abdunklung zur Screen-Kante läse sich als
// Geisterbild des alten Tischrands. Die Fenster-Panels liegen darüber; dass ihr leicht
// durchscheinender Grund einen Hauch Filz durchschimmern lässt, ist gewollt
// (Glasscheiben AUF dem Filz). Spiegelnd ist nur das Fenster-Glas - der Filz
// bekommt im Glas-Shader keine Spiegelung (siehe screen_glass.gdshader).

// Dunkler Raum: der Filz ist unbeleuchteter Stoff (Werte für die alte helle
// Szene: ~1.7x), aber mit deutlich sichtbarer Faser, Wolken und Steppmuster -
// dunkler Casino-Tisch, kein schwarzes Loch.
uniform vec3 felt_color : source_color = vec3(0.088, 0.056, 0.128);  // dunkles Casino-Violett
uniform vec3 felt_shadow : source_color = vec3(0.042, 0.026, 0.066); // Tiefen (Rand/Wolken)
uniform float grain_strength : hint_range(0.0, 0.5) = 0.2;   // Faser-Körnung
uniform float cloud_strength : hint_range(0.0, 1.0) = 0.3;   // großflächige Flecken
uniform float grain_scale = 900.0;  // Körnungs-Dichte über die Fläche
uniform float cloud_scale = 9.0;    // Wolken-Dichte über die Fläche

// Rauten-Steppmuster (Karo-Filz): diagonales Gitter, dessen Kante von zwei
// Nähten eingefasst wird - dazwischen ein leicht hellerer Steg.
uniform float diamond_scale = 21.0;      // Diagonal-Linien über die Breite
uniform float diamond_strength : hint_range(0.0, 1.0) = 0.5;
uniform float aspect = 1.4717;           // Breite/Höhe: Rauten bleiben symmetrisch

// Unter den leicht durchscheinenden Fenstergründen darf KEINE Textur liegen -
// dort bleibt der Filz glatt (dieselben Rechtecke wie screen_glass.gdshader,
// TableScreen._sync_reflection_windows speist beide).
uniform vec2 rect_size = vec2(4680.0, 3180.0);
const int MAX_WINDOWS = 24;  // Fenster-Budget wie in screen_glass.gdshader
uniform int window_count = 0;
uniform vec4 window_rects[MAX_WINDOWS];   // xy = Pixel-Min, zw = Pixel-Max
uniform float window_radius[MAX_WINDOWS]; // Eckenradius in Pixeln

// Abdeckung eines abgerundeten Fenster-Rechtecks am Pixel p (SDF, weiche Kante).
float window_mask(vec2 p, vec4 rect, float radius) {
	vec2 c = (rect.xy + rect.zw) * 0.5;
	vec2 half_size = (rect.zw - rect.xy) * 0.5 - vec2(radius);
	vec2 d = abs(p - c) - half_size;
	float dist = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - radius;
	return 1.0 - smoothstep(-4.0, 4.0, dist);
}

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

	// Rauten-Gitter: 45° gedrehte Zellkoordinaten; e = Abstand zur nächsten
	// Zellkante. Kante = dunkle Fuge, daneben eine zweite Naht, der Steg
	// dazwischen hebt sich leicht - Steppdecken-Relief wie auf echtem Karo-Filz.
	vec2 q = vec2(UV.x * aspect, UV.y) * diamond_scale;
	vec2 dg = vec2(q.x + q.y, q.x - q.y);
	float e = min(0.5 - abs(fract(dg.x) - 0.5), 0.5 - abs(fract(dg.y) - 0.5));
	float seam = 1.0 - smoothstep(0.0, 0.035, e);
	float inner = 1.0 - smoothstep(0.0, 0.025, abs(e - 0.12));
	float band = smoothstep(0.035, 0.055, e) - smoothstep(0.095, 0.115, e);

	// Unter Fenstern alle Texturlagen ausblenden (glatter Grundton).
	float glass = 0.0;
	vec2 p = UV * rect_size;
	for (int i = 0; i < window_count; i++) {
		glass = max(glass, window_mask(p, window_rects[i], window_radius[i]));
	}
	float fabric = 1.0 - glass;

	vec3 felt = mix(felt_color, felt_shadow, clouds * cloud_strength * fabric);
	felt *= 1.0 - diamond_strength * (seam * 0.8 + inner * 0.5 - band * 0.35) * fabric;
	felt *= 1.0 + (grain - 0.5) * 2.0 * grain_strength * fabric;
	COLOR = vec4(felt, 1.0);
}
