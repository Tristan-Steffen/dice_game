// Das Charm-HOLOGRAMM (siehe CharmRowView): ein MASSIVES, beleuchtetes Modell in
// kräftigen Farben, über das ein Hologramm-Effekt läuft - welcher, sagt das
// PRESET der Reihe (CharmRowView.HOLO_PRESETS): Fresnel-Saum, breite Bänder,
// feine Scanlines, Blaustich und/oder Halbtransparenz. Kein Flackern (clean,
// nicht CRT). Nie additiv: der additive Ersatz war viel zu hell.
shader_type spatial;
render_mode cull_back, depth_draw_always;

uniform sampler2D albedo_tex : source_color, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool use_texture = false;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.0;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.6;

// SÄTTIGUNG um die Leuchtdichte: der Tisch ist dunkel und blau-ambient, roh
// lasen die Modellfarben ausgegraut. Eigenlicht auf der GESÄTTIGTEN Farbe.
uniform float saturation : hint_range(0.0, 3.0) = 1.6;
uniform float self_glow : hint_range(0.0, 1.0) = 0.45;

uniform vec3 holo_color : source_color = vec3(0.45, 0.8, 1.0);
// Kühlstich über der Modellfarbe (0 = reine Modellfarbe).
uniform float tint_mix : hint_range(0.0, 1.0) = 0.0;
uniform float rim_gain : hint_range(0.0, 2.0) = 0.5;   // Fresnel-Saum
uniform float rim_power = 2.6;
uniform float band_gain : hint_range(0.0, 1.0) = 0.14; // breite steigende Bänder
uniform float band_freq = 2.5;
uniform float band_speed = 1.2;
uniform float scan_gain : hint_range(0.0, 1.0) = 0.0;  // feine Scanlines (Dunkelung)
uniform float scan_freq = 40.0;
uniform float scan_speed = 0.8;
// Deckkraft des Modells; unter 1 wird es zur durchscheinenden Gestalt.
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
// Kurzes Aufblitzen, wenn der Charm feuert (CharmRowView.flash_charm).
uniform float flash : hint_range(0.0, 1.0) = 0.0;

varying vec3 world_pos;

vec3 saturate_rgb(vec3 color, float amount) {
	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	return max(mix(vec3(luma), color, amount), vec3(0.0));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 base = albedo_color;
	if (use_texture) {
		base *= texture(albedo_tex, UV);
	}
	vec3 color = saturate_rgb(base.rgb, saturation);
	color = mix(color, holo_color * dot(color, vec3(0.333)) * 1.6, tint_mix);
	// Scanlines dunkeln die Fläche in feinen Zeilen ab, statt Licht zu addieren.
	float scan = 1.0 - scan_gain * (0.5 + 0.5 * sin(world_pos.y * scan_freq - TIME * scan_speed));
	ALBEDO = color * scan;
	METALLIC = metallic_value;
	ROUGHNESS = roughness_value;
	float fres = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), rim_power);
	float band = 0.5 + 0.5 * sin(world_pos.y * band_freq - TIME * band_speed);
	float sheen = fres * rim_gain + band * band_gain;
	EMISSION = (color * self_glow * scan * (1.0 + flash)
		+ holo_color * sheen * (1.0 + flash * 3.0));
	ALPHA = clamp(alpha + fres * (1.0 - alpha) * 0.6 + flash * 0.3, 0.0, 1.0);
}
