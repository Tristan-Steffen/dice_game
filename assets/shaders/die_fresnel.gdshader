shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;

// Fresnel-Schimmer der Würfel: additive Hülle knapp über dem Körper, deren
// Glühen mit flacherem Blickwinkel zunimmt - das Licht wirkt so, als käme es
// aus dem Glasvolumen statt von der Oberfläche.

uniform vec3 glow_color = vec3(0.55, 0.91, 0.99);
uniform float strength : hint_range(0.0, 2.0) = 0.5;

void fragment() {
	float grazing = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fresnel = pow(grazing, 3.0);
	ALBEDO = vec3(0.0);
	EMISSION = glow_color * fresnel * strength;
	ALPHA = fresnel;
}
