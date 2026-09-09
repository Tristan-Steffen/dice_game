// Das Charm-HOLOGRAMM (siehe CharmRowView, zweite Fassung 2026-09-09): eine
// projizierte Lichtgestalt, die frei über ihrem Emitter-Ring schwebt -
// durchscheinend, additiv, mit Fresnel-Saum und breiten, langsam steigenden
// Bändern. Die ECHTEN Modellfarben bleiben und werden gesättigt (der Tisch ist
// dunkel und blau-ambient, ungesättigt lasen sie ausgegraut); nur der Saum trägt
// das kühle Hologramm-Blau. Kein Flackern (clean, nicht CRT). depth_draw_never:
// Rückseiten addieren durch das Modell hindurch - das IST der Hologramm-Look.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform sampler2D albedo_tex : source_color, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool use_texture = false;

uniform float saturation : hint_range(0.0, 3.0) = 1.6;
uniform float brightness : hint_range(0.0, 4.0) = 1.25;
uniform vec3 holo_color : source_color = vec3(0.45, 0.8, 1.0);
// Leichter, einheitlicher Kühlstich über der Modellfarbe - klein, sonst grau.
uniform float tint_mix : hint_range(0.0, 1.0) = 0.12;
// Grund-Deckkraft der Fläche; der Saum legt seine eigene obendrauf.
uniform float base_alpha : hint_range(0.0, 1.0) = 0.6;
uniform float rim_gain : hint_range(0.0, 2.0) = 0.9;
uniform float rim_power = 2.2;
uniform float band_freq = 2.5;    // Bänder je Welteinheit Höhe
uniform float band_speed = 1.2;   // Wandergeschwindigkeit nach oben
uniform float band_min : hint_range(0.0, 1.0) = 0.7;  // Restdeckkraft zwischen den Bändern
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
	vec3 base = albedo_color.rgb;
	if (use_texture) {
		base *= texture(albedo_tex, UV).rgb;
	}
	vec3 color = saturate_rgb(base, saturation);
	color = mix(color, color * holo_color, tint_mix);
	float fres = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), rim_power);
	float band = 0.5 + 0.5 * sin(world_pos.y * band_freq - TIME * band_speed);
	float bands = mix(band_min, 1.0, band);
	ALBEDO = (color * brightness + holo_color * fres * rim_gain) * (1.0 + flash * 0.9);
	ALPHA = clamp((base_alpha + fres * rim_gain * 0.5) * bands * (1.0 + flash * 0.5), 0.0, 1.0);
}
