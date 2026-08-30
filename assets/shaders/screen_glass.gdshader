shader_type spatial;
render_mode unshaded;
// Display-Glas des Tisch-Bildschirms (siehe TableScreen.attach_to): zeigt die
// UI-ViewportTexture als leuchtende Anzeige UND mischt die planare Spiegelung
// der Würfel darüber (siehe ScreenReflection - der Compatibility-Renderer hat
// keine SSR, deshalb rendert eine gespiegelte Kamera die Würfel in eine eigene
// Textur). Die Spiegel-Kamera folgt der Hauptkamera, ihr Bild deckt sich daher
// pixelgenau mit dem Bildschirm: SCREEN_UV greift die Spiegelung genau dort ab,
// wo sie auf dem Glas erscheinen muss. Da die Spiegel-Kamera eine gültige
// (rechtshändige) Basis braucht, ist ihre X-Achse zusätzlich negiert - das
// Bild kommt seitenverkehrt an und wird hier per (1 - SCREEN_UV.x) zurückgedreht.
//
// unshaded: die Anzeige ist SELBSTLEUCHTEND. Szenenlichter (das Tischlicht über
// der Grube, die Eigenlichter der Würfel) dürfen KEINE Glanz-/Lichtflecken auf
// dem Glas erzeugen - sichtbar ist ausschließlich die Anzeige plus die echte
// Würfel-Spiegelung, nichts sonst.

uniform sampler2D screen_texture : source_color, filter_linear_mipmap;
// Spiegelbild der Würfel (transparenter Grund; ohne Spiegel-Viewport bleibt
// die Textur leer und nur die Anzeige leuchtet).
uniform sampler2D reflection_texture : source_color, hint_default_transparent, filter_linear;
uniform float emission_energy = 1.2;  // lässt die Anzeige im dunklen Raum als Display leuchten
// Stärke der Würfel-Spiegelung: fresnel_base wirkt bei senkrechtem Blick,
// Richtung streifendem Blick steigt sie auf reflection_strength an (Fresnel -
// echtes Glas spiegelt flach betrachtet deutlich stärker).
uniform float reflection_strength : hint_range(0.0, 2.0) = 0.9;
uniform float fresnel_base : hint_range(0.0, 1.0) = 0.4;
uniform float fresnel_power : hint_range(0.5, 8.0) = 3.0;

// NUR die "Fenster" des Displays sind spiegelndes Glas - der Rest der Fläche
// ist Casino-Filz (matt, siehe table_felt.gdshader als 2D-Hintergrund der
// Anzeige) und spiegelt NICHT. TableScreen meldet die Fenster-Rechtecke in
// Display-Pixeln samt Eckenradius (siehe _sync_reflection_windows).
// 6 Charm-Konsolen + 4 Vorrats-Schubladen + der Rest; mit Luft nach oben, denn
// bei exakt passender Größe verschluckt das nächste Fenster still seine Spiegelung.
const int MAX_WINDOWS = 24;
uniform int window_count = 0;
uniform vec4 window_rects[MAX_WINDOWS];   // xy = Pixel-Min, zw = Pixel-Max
uniform float window_radius[MAX_WINDOWS]; // Eckenradius in Pixeln
uniform vec2 screen_px = vec2(1.0, 1.0);  // Display-Auflösung (UV -> Pixel)

// Die LÖCHER des Tisches: innerhalb eines dieser Rechtecke wird die Anzeige
// verworfen, damit der Blick nach unten fällt. Platz 0 gehört dauerhaft der
// MAGAZIN-Grube (PackPitView stellt Wände und Boden), die übrigen sind die
// flüchtigen SCHÄCHTE der Hebebühnen (LiftShaftView) - offen nur, solange eine
// Auslage auffährt. KEINE Fenster: sie fressen keinen der MAX_WINDOWS-Plätze,
// und ein Null-Rechteck heißt "kein Loch". Geschrieben wird die Liste allein von
// TableScreen (ein zweiter Schreiber ließe irgendwann ein Loch offen).
const int MAX_PITS = 10;
uniform int pit_count = 0;
uniform vec4 pit_rects[MAX_PITS];   // xy = Pixel-Min, zw = Pixel-Max
uniform float pit_radii[MAX_PITS];  // Eckenradius in Pixeln

// Abdeckung eines abgerundeten Fenster-Rechtecks am Pixel p (SDF, weiche
// 4-Pixel-Kante, damit die Spiegelung am Rahmen nicht hart abreißt).
float window_mask(vec2 p, vec4 rect, float radius) {
	vec2 center = (rect.xy + rect.zw) * 0.5;
	vec2 half_size = (rect.zw - rect.xy) * 0.5 - vec2(radius);
	vec2 d = abs(p - center) - half_size;
	float dist = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - radius;
	return 1.0 - smoothstep(-4.0, 4.0, dist);
}

void fragment() {
	vec2 pixel = UV * screen_px;
	// Zuerst die Löcher: was in einer Grube oder einem Schacht liegt, wird gar
	// nicht erst gezeichnet.
	for (int i = 0; i < pit_count; i++) {
		if (pit_rects[i].z > pit_rects[i].x
				&& window_mask(pixel, pit_rects[i], pit_radii[i]) > 0.5) {
			discard;
		}
	}
	vec3 ui = texture(screen_texture, UV).rgb;
	vec2 mirror_uv = vec2(1.0 - SCREEN_UV.x, SCREEN_UV.y);
	vec4 reflection = texture(reflection_texture, mirror_uv);
	float grazing = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), fresnel_power);
	float amount = reflection_strength * mix(fresnel_base, 1.0, grazing);

	float glass = 0.0;
	for (int i = 0; i < window_count; i++) {
		glass = max(glass, window_mask(pixel, window_rects[i], window_radius[i]));
	}

	// Alles ins ALBEDO (unshaded gibt ALBEDO unverändert aus); überhelle Werte
	// blühen weiterhin über den Umgebungs-Glow (WorldEnvironment.glow).
	ALBEDO = ui * emission_energy + reflection.rgb * reflection.a * amount * glass;
}
