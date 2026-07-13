// Hologramm-Look für die Charm-Modelle (siehe CharmRowView): der Charm wird zur
// projizierten Lichtgestalt im Star-Wars-Stil - durchscheinend, einfarbig blau,
// mit Fresnel-Kante, nach oben wandernden Scanlines und leichtem Flackern. Wird
// als material_override auf jedes MeshInstance3D des Modells gelegt und ersetzt
// damit dessen ursprüngliche Textur/Farbe.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec3 holo_color : source_color = vec3(0.35, 0.72, 1.0);
uniform float brightness = 1.7;
uniform float base_alpha : hint_range(0.0, 1.0) = 0.4;
uniform float fresnel_gain : hint_range(0.0, 2.0) = 0.7;
uniform float fresnel_power = 2.2;
uniform float scan_freq = 22.0;     // Scanlines je Welteinheit Höhe
uniform float scan_speed = 5.0;     // Wandergeschwindigkeit nach oben
uniform float scan_min : hint_range(0.0, 1.0) = 0.55;  // Restdeckkraft zwischen den Linien
uniform float flicker_speed = 11.0;
uniform float flicker_amount : hint_range(0.0, 1.0) = 0.12;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float fres = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), fresnel_power);
	float scan = 0.5 + 0.5 * sin(world_pos.y * scan_freq - TIME * scan_speed);
	float flick = 1.0 - flicker_amount * (0.5 + 0.5 * sin(TIME * flicker_speed) * sin(TIME * flicker_speed * 2.3));
	float intensity = (base_alpha + fres * fresnel_gain) * mix(scan_min, 1.0, scan) * flick;
	ALBEDO = holo_color * brightness;
	ALPHA = clamp(intensity, 0.0, 1.0);
}
