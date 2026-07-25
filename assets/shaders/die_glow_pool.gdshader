shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;

// Licht-Lache eines Würfels: die weiche, farbige Fläche, die er auf den
// Grubenboden wirft. Sie trägt die REICHWEITE des Würfellichts - ein weiter
// OmniLight-Verlauf bandet in gl_compatibility sichtbar in Ringe (8-Bit-Ziel,
// Godots Debanding wirkt dort nicht). Hier wird der Abfall analytisch
// gerechnet: kein Verlaufsbild, keine Stufen.
//
// Zusätzlich klemmt die Lache auf den Grubeninnenraum (abgerundetes Rechteck
// in Weltkoordinaten). Ohne das legte sie sich als Schleier über Ziel-Leiste
// und Filz - Licht auf einem Tisch endet dort, wo der Tisch endet.

uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 0.4);
// Abfallkurve: > 1 = früh dunkel, weicher Ausklang; 1 = linear.
uniform float falloff : hint_range(0.5, 4.0) = 1.7;
uniform vec2 clip_center = vec2(0.0, 0.0);   // Grubenmitte (Welt-XZ)
uniform vec2 clip_half = vec2(1000.0, 1000.0); // halbe Grubenmaße
uniform float clip_radius = 0.0;             // Eckenradius der Grube
uniform float clip_fade = 1.6;               // weicher Auslauf an der Wand

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// Radialer Abfall aus der Quad-Mitte, analytisch statt aus einer Textur.
	float r = clamp(length(UV - vec2(0.5)) * 2.0, 0.0, 1.0);
	float glow = pow(1.0 - r, falloff);

	// Abgerundetes Rechteck (SDF) als Grubenmaske.
	vec2 d = abs(world_pos.xz - clip_center) - (clip_half - vec2(clip_radius));
	float dist = length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - clip_radius;
	glow *= 1.0 - smoothstep(-clip_fade, 0.0, dist);

	// unshaded verwirft EMISSION - die Farbe muss über ALBEDO raus. ALPHA
	// bleibt 1, sonst steckte der Abfall bei blend_add zweimal drin.
	ALBEDO = tint.rgb * glow * tint.a;
	ALPHA = 1.0;
}
