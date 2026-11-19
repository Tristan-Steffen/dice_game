shader_type spatial;
render_mode blend_mix, depth_prepass_alpha;

// Veredelte Seite, DURCHSCHEINEND (nur Glas): dieselbe Glut und Kante, aber das
// Wuerfelinnere scheint durch. Der Tiefen-Vorpass haelt Ziffer und Runen davor.

#include "res://assets/shaders/die_dope_mount.gdshaderinc"

void vertex() {
	vec3 vpos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 v = normalize(-vpos);
	tview = vec3(dot(v, TANGENT), dot(v, BINORMAL), dot(v, NORMAL));
}

void fragment() {
	vec3 albedo;
	vec3 emission;
	float metal;
	float rough;
	float alpha;
	dope_mount(UV, tview, albedo, emission, metal, rough, alpha);
	ALBEDO = albedo;
	EMISSION = emission;
	METALLIC = metal;
	ROUGHNESS = rough;
	ALPHA = alpha;
}
