shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never;

// Fresnel-Schimmer der Würfel: additive Hülle knapp über dem Körper, deren
// Glühen mit flacherem Blickwinkel zunimmt - das Licht wirkt so, als käme es
// aus dem Glasvolumen statt von der Oberfläche. DAS ist die Farbabstrahlung
// des Würfels: sie hängt an ihm selbst, wirkt also in Grube, Tray, Werkstatt
// und Inspektor gleichermaßen (anders als die Lache, die einen Boden braucht).

uniform vec3 glow_color = vec3(0.55, 0.91, 0.99);
uniform float strength : hint_range(0.0, 3.0) = 0.5;
uniform float falloff : hint_range(1.0, 5.0) = 2.1;

void fragment() {
	float grazing = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	// Flacherer Exponent = der Saum greift weiter in die Fläche hinein: der
	// Würfel strahlt, statt nur eine Kontur zu haben.
	float fresnel = pow(grazing, falloff);
	// unshaded verwirft EMISSION - die Farbe muss über ALBEDO raus. ALPHA
	// bleibt 1, sonst steckte der Fresnel-Abfall bei blend_add zweimal drin.
	ALBEDO = glow_color * fresnel * strength;
	ALPHA = 1.0;
}
