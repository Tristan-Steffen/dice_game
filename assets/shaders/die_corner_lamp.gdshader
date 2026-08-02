shader_type spatial;
render_mode cull_back;

// Eck-Kappen des Würfels: die Fassungen des Rahmens. Sie tragen das
// Silhouetten-Signal "hat eine Seele" (nur mit Essenz sichtbar) und atmen im
// Takt des Kantenneons - mehr nicht. Das Eck-Lauflicht ab Episch ist wieder
// ausgebaut: es las sich nicht als Reklame, sondern als Fehler.
//
// BESCHATTET wie der Rahmen, an dem die Kappen sitzen (dunkles Albedo × Muster,
// Emission × Muster, gleiches Metallic/Roughness) - unbeschattet verlor der
// Eckwürfel jede Form. Alle 8 Kappen liegen in EINEM Mesh: ein Draw-Call.

uniform sampler2D surface_tex : source_color, hint_default_white;
uniform vec3 lamp_color = vec3(0.8, 0.8, 0.83);
uniform vec3 body_color = vec3(0.05, 0.05, 0.08);
uniform float metallic_amount = 0.35;
uniform float roughness_amount = 0.25;
// Je Würfel eigene Phase - 30 Tray-Würfel atmen nie im Gleichschritt.
uniform float phase = 0.0;
// Auswahl-Farbe der Gravur-Station (a > 0 = aktiv): die Kappen gehören zum
// Rahmen, also färbt set_edge_tint sie mit - flach und exakt wie die Balken.
uniform vec4 flat_tint = vec4(0.0);

// Atem wie am Kantenneon: die Kappen gehören optisch zum Rahmen.
const float BREATH_SPEED = 1.4;
const float BREATH_AMOUNT = 0.16;

void fragment() {
	if (flat_tint.a > 0.0) {
		ALBEDO = vec3(0.0);
		METALLIC = 0.0;
		ROUGHNESS = 1.0;
		EMISSION = flat_tint.rgb;
	} else {
		vec3 pattern = texture(surface_tex, UV).rgb;
		ALBEDO = body_color * pattern;
		METALLIC = metallic_amount;
		ROUGHNESS = roughness_amount;
		float breath = 1.0 + sin(TIME * BREATH_SPEED + phase) * BREATH_AMOUNT;
		EMISSION = lamp_color * pattern * breath;
	}
}
