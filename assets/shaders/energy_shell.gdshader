// Energie-Hülle des Würfel-Ikosaeders (DiceShell): additive Dreiecks-Facette
// mit leuchtendem Rand (UV = baryzentrisch, siehe dice_shell.gd), Fresnel und
// wandernden Streifen wie das Gruben-Feld (force_field.gdshader). impact
// blitzt die getroffene Facette auf, dissolve löst die Hülle beim Auskippen auf.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec3 field_color : source_color = vec3(0.15, 0.75, 1.0);
uniform float base_alpha : hint_range(0.0, 1.0) = 0.03;
uniform float fresnel_alpha : hint_range(0.0, 1.0) = 0.10;
uniform float edge_alpha : hint_range(0.0, 1.0) = 0.55;   // Dreiecks-Rand ("Drahtgitter aus Energie")
uniform float edge_width : hint_range(0.0, 0.3) = 0.055;  // Randbreite in baryzentrischen Einheiten
uniform float stripe_alpha : hint_range(0.0, 1.0) = 0.06;
uniform float stripe_density = 0.5;  // Streifen je Welteinheit Höhe
uniform float stripe_speed = 0.6;    // Wanderung nach oben (Einheiten/s)
uniform float impact : hint_range(0.0, 1.0) = 0.0;        // Aufprall-Blitz der Facette (DiceShell.flash_face)
uniform float impact_alpha : hint_range(0.0, 1.0) = 0.55;
uniform float dissolve : hint_range(0.0, 1.0) = 0.0;      // 1 = Hülle geborsten/unsichtbar

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Abstand zum nächsten Dreiecksrand: min der drei baryzentrischen Koordinaten.
	float bary = min(min(UV.x, UV.y), 1.0 - UV.x - UV.y);
	float edge = smoothstep(edge_width, 0.0, bary);
	float stripes = 0.5 + 0.5 * sin((world_pos.y - TIME * stripe_speed) * stripe_density * TAU);
	stripes = pow(stripes, 3.0);
	float fresnel = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	float a = base_alpha + edge_alpha * edge + stripe_alpha * stripes
		+ fresnel_alpha * fresnel + impact * impact_alpha;
	// Kurz vor dem Bersten hell aufglühen, dann weg.
	float burst = 1.0 + 1.5 * sin(clamp(dissolve, 0.0, 1.0) * PI);
	ALBEDO = field_color * burst;
	ALPHA = clamp(a * (1.0 - dissolve), 0.0, 1.0);
}
