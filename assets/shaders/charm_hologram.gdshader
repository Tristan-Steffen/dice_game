// Hologramm-Look für die Charm-Modelle (siehe CharmRowView): der Charm wird zur
// projizierten Lichtgestalt im Star-Wars-Stil - durchscheinend, mit Fresnel-
// Kante, nach oben wandernden Scanlines und leichtem Flackern. Die ECHTEN
// Modellfarben bleiben erhalten: CharmRowView._apply_hologram reicht je Fläche
// Originaltextur + -farbe herein. Additiv gemischt -> die Farbe leuchtet,
// Überlappungen werden heller, der Farbton bleibt aber erhalten.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform sampler2D albedo_tex : source_color, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool use_texture = false;
uniform vec3 holo_tint : source_color = vec3(0.45, 0.8, 1.0);
uniform float tint_mix : hint_range(0.0, 1.0) = 0.15;  // 0 = reine Modellfarbe, höher = einheitlicher Blaustich
uniform float brightness = 1.4;
uniform float base_alpha : hint_range(0.0, 1.0) = 0.78;
uniform float fresnel_gain : hint_range(0.0, 2.0) = 0.55;
uniform float fresnel_power = 2.2;
uniform float scan_freq = 22.0;     // Scanlines je Welteinheit Höhe
uniform float scan_speed = 5.0;     // Wandergeschwindigkeit nach oben
uniform float scan_min : hint_range(0.0, 1.0) = 0.78;  // Restdeckkraft zwischen den Linien
uniform float flicker_speed = 11.0;
uniform float flicker_amount : hint_range(0.0, 1.0) = 0.1;
// Kurzes Aufblitzen, wenn der Charm in der Zähl-Animation feuert (siehe
// CharmRowView.flash_charm): hebt Helligkeit und Deckkraft gemeinsam an.
uniform float flash : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = albedo_color.rgb;
	if (use_texture) {
		base *= texture(albedo_tex, UV).rgb;
	}
	base = mix(base, base * holo_tint, tint_mix);  // dezenter, einheitlicher Blaustich über allen Charms
	float fres = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), fresnel_power);
	float scan = 0.5 + 0.5 * sin(world_pos.y * scan_freq - TIME * scan_speed);
	float flick = 1.0 - flicker_amount * (0.5 + 0.5 * sin(TIME * flicker_speed) * sin(TIME * flicker_speed * 2.3));
	float intensity = (base_alpha + fres * fresnel_gain) * mix(scan_min, 1.0, scan) * flick;
	ALBEDO = base * brightness * (1.0 + flash * 2.2);
	ALPHA = clamp(intensity * (1.0 + flash * 0.6), 0.0, 1.0);
}
