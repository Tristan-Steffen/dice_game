// Das Charm-HOLOGRAMM (siehe CharmRowView): ein MASSIVES, beleuchtetes Modell in
// kräftigen Farben, darüber die LICHTKANTE - ein blauer Fresnel-Saum und breite,
// langsam steigende Bänder. Kein Flackern, keine Scanlines, kein Blaustich,
// keine Alpha (clean, nicht CRT; Spieler-Wahl 2026-09-09 aus fünf Varianten).
// Nie additiv: der additive Ersatz war viel zu hell.
shader_type spatial;
render_mode cull_back;

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
uniform float rim_gain : hint_range(0.0, 2.0) = 1.0;   // Fresnel-Saum
uniform float rim_power = 2.6;
uniform float band_gain : hint_range(0.0, 1.0) = 0.18; // breite steigende Bänder
uniform float band_freq = 2.5;
uniform float band_speed = 1.2;
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
	ALBEDO = color;
	METALLIC = metallic_value;
	ROUGHNESS = roughness_value;
	float fres = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), rim_power);
	float band = 0.5 + 0.5 * sin(world_pos.y * band_freq - TIME * band_speed);
	float sheen = fres * rim_gain + band * band_gain;
	EMISSION = color * self_glow * (1.0 + flash) + holo_color * sheen * (1.0 + flash * 3.0);
}
