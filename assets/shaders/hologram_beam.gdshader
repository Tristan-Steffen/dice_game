// Projektions-Zylinder der Charm-Hologramme (siehe CharmRowView): der "Lichtkegel"
// im Star-Wars-Stil, aus dem der Charm zu schweben scheint. Für JEDEN Charm
// identisch - ein durchscheinender, additiv leuchtender Zylinder, unten am
// Emitter hell und nach oben ausblendend, mit Fresnel-Wänden (die Tube-Kanten
// leuchten), aufsteigenden Lichtbändern und Flackern.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec3 beam_color : source_color = vec3(0.3, 0.68, 1.0);
uniform float bottom_y = -3.1;   // Emitter (Untersetzer-Oberkante), Welt-Y
uniform float top_y = 5.9;       // Oberkante des Lichtkegels, Welt-Y
uniform float base_alpha : hint_range(0.0, 1.0) = 0.04;
uniform float edge_alpha : hint_range(0.0, 1.0) = 0.32;
uniform float scan_freq = 6.0;
uniform float scan_speed = 3.0;
uniform float flicker_speed = 15.0;
uniform float flicker_amount : hint_range(0.0, 1.0) = 0.22;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float h = clamp((world_pos.y - bottom_y) / (top_y - bottom_y), 0.0, 1.0);
	float fade = 1.0 - h;  // unten hell (Emitter), oben aus
	float fres = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	float scan = 0.5 + 0.5 * sin(world_pos.y * scan_freq - TIME * scan_speed);
	float flick = 1.0 - flicker_amount * (0.5 + 0.5 * sin(TIME * flicker_speed) * sin(TIME * flicker_speed * 1.7));
	float intensity = (base_alpha + fres * edge_alpha) * fade * mix(0.6, 1.0, scan) * flick;
	ALBEDO = beam_color;
	ALPHA = clamp(intensity, 0.0, 1.0);
}
