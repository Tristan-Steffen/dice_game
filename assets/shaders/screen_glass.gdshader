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

void fragment() {
	vec3 ui = texture(screen_texture, UV).rgb;
	vec2 mirror_uv = vec2(1.0 - SCREEN_UV.x, SCREEN_UV.y);
	vec4 reflection = texture(reflection_texture, mirror_uv);
	float grazing = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), fresnel_power);
	float amount = reflection_strength * mix(fresnel_base, 1.0, grazing);
	// Alles ins ALBEDO (unshaded gibt ALBEDO unverändert aus); überhelle Werte
	// blühen weiterhin über den Umgebungs-Glow (WorldEnvironment.glow).
	ALBEDO = ui * emission_energy + reflection.rgb * reflection.a * amount;
}
