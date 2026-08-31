shader_type spatial;
render_mode unshaded;
// Die Anzeige-Haut des GRUBEN-SCHIRMS: dieselbe Weltpositions-Abbildung wie
// display_skin, aber die Quelle ist der EIGENE, nicht-HDR-SubViewport der
// Glas-Ansicht - der trägt echtes Per-Pixel-ALPHA. Die opaken Raster-Kacheln decken
// also ihren Würfel, die Zwischenräume bleiben durchsichtig und zeigen das fast
// durchsichtige Glas samt der versenkten Würfel. Kein Helligkeits-Key mehr: der
// Kanal sagt es selbst.

uniform sampler2D screen_texture : source_color, filter_linear_mipmap;
uniform vec4 display_map = vec4(0.0, 1.0, 0.0, 1.0);
uniform float emission_energy = 1.2;
// Deckel der Kachel-Deckkraft (1 = die Kachel deckt voll).
uniform float skin_alpha : hint_range(0.0, 1.0) = 1.0;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = vec2((world_position.z - display_map.x) / display_map.y,
		(display_map.z - world_position.x) / display_map.w);
	vec4 sample = texture(screen_texture, clamp(uv, vec2(0.0), vec2(1.0)));
	// Der Viewport liefert VORMULTIPLIZIERTES Alpha - zurückrechnen, sonst
	// verdunkelt jede halbdeckende Kante ihre eigene Farbe.
	ALBEDO = sample.rgb / max(sample.a, 0.0001) * emission_energy;
	ALPHA = sample.a * skin_alpha;
}
