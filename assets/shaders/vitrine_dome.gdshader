// Glashaube der Charm-Vitrine (siehe CharmRowView): fast klares Glas mit einem
// feinen Fresnel-Saum in der Raritaetsfarbe und einer leichten Reflex-Aufhellung
// auf dem Deckel. Kein Flackern, keine Scanlines - das Modell darunter bleibt
// von der 15-Grad-Station klar lesbar (Flaechen-Alpha bleibt unter 0,08).
shader_type spatial;
render_mode blend_mix, unshaded, cull_back, shadows_disabled, depth_draw_never;

uniform vec3 edge_color : source_color = vec3(0.72, 0.82, 1.0);  // Saumfarbe (Raritaet)
uniform float edge_power = 3.0;    // Schaerfe des Saums: hoeher = schmaler
uniform float edge_gain = 1.0;     // Helligkeit des Saums
uniform float edge_alpha : hint_range(0.0, 1.0) = 0.42;  // Deckkraft am Silhouettenrand
uniform vec3 glass_tint : source_color = vec3(0.6, 0.72, 0.95);
uniform float face_alpha : hint_range(0.0, 0.2) = 0.04;  // Deckkraft in der Flaeche
uniform float sheen : hint_range(0.0, 0.2) = 0.03;       // Aufhellung des Deckels

varying vec3 world_normal;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float fres = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), edge_power);
	float top = clamp(world_normal.y, 0.0, 1.0);
	ALBEDO = glass_tint * (sheen * top) + edge_color * fres * edge_gain;
	ALPHA = clamp(face_alpha + fres * edge_alpha + top * sheen, 0.0, 1.0);
}
