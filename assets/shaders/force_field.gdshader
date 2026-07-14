// Energiefeld der Würfelgrube: In RUHE nahezu unsichtbar (nur ein Hauch
// Fresnel-Kante), erst beim Aufprall eines Würfels blitzt das getroffene
// Segment auf - nach oben wandernde helle Bänder plus Fresnel-Kante (siehe
// dice_tray.gd: flash_segment steuert den impact-Parameter). Sichtbar ist nur
// der untere Teil (bis top_y, dort Ausblendung auf top_fade) - die
// Kollisionswand dahinter ist höher.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec3 field_color : source_color = vec3(0.15, 0.75, 1.0);
uniform float base_alpha : hint_range(0.0, 1.0) = 0.04;
uniform float stripe_alpha : hint_range(0.0, 1.0) = 0.12;
uniform float fresnel_alpha : hint_range(0.0, 1.0) = 0.2;
uniform float idle_alpha : hint_range(0.0, 1.0) = 0.02;  // Grund-Deckkraft in Ruhe (× Fresnel) - fast unsichtbar
uniform float impact : hint_range(0.0, 1.0) = 0.0;       // 0 = ruhig, 1 = frischer Aufprall (siehe DicePit.flash_segment)
uniform float impact_alpha : hint_range(0.0, 1.0) = 0.5; // zusätzlicher Deckkraft-Blitz beim Aufprall
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
	// In Ruhe nur ein Hauch Fresnel; beim Aufprall die volle Feld-Optik plus Blitz.
	float energy = base_alpha + stripe_alpha * stripes + fresnel_alpha * fresnel;
	float a = idle_alpha * fresnel + impact * (energy + impact_alpha);
	ALBEDO = field_color;
	ALPHA = clamp(a * fade, 0.0, 1.0);
}
