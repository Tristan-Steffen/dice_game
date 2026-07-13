// Energiefeld der Würfelgrube: durchscheinende, additiv leuchtende Wand über
// dem goldenen Emitter-Ring (siehe dice_tray.gd). Nach oben wandernde helle
// Bänder plus Fresnel-Kante. Sichtbar ist nur der untere Teil (bis top_y,
// dort Ausblendung auf top_fade) - die Kollisionswand dahinter ist höher,
// das Feld "verdichtet" sich fiktional nur nahe am Ring.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec3 field_color : source_color = vec3(0.15, 0.75, 1.0);
uniform float base_alpha : hint_range(0.0, 1.0) = 0.04;
uniform float stripe_alpha : hint_range(0.0, 1.0) = 0.12;
uniform float fresnel_alpha : hint_range(0.0, 1.0) = 0.2;
uniform float stripe_density = 0.35; // Streifen je Welteinheit Höhe
uniform float stripe_speed = 0.6;    // Streifen-Wanderung nach oben (Einheiten/s)
uniform float bottom_y = -3.4;       // Filz-Oberkante (Feld-Unterkante)
uniform float top_y = 1.9;           // sichtbare Feldhöhe (nicht die Kollisionshöhe)
uniform float top_fade : hint_range(0.0, 1.0) = 0.0; // Restdeckkraft an der Oberkante

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float h = clamp((world_pos.y - bottom_y) / (top_y - bottom_y), 0.0, 1.0);
	float fade = mix(1.0, top_fade, h);
	float stripes = 0.5 + 0.5 * sin((world_pos.y - TIME * stripe_speed) * stripe_density * TAU);
	stripes = pow(stripes, 3.0);
	float fresnel = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	ALBEDO = field_color;
	ALPHA = clamp((base_alpha + stripe_alpha * stripes + fresnel_alpha * fresnel) * fade, 0.0, 1.0);
}
