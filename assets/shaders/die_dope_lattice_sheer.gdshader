shader_type spatial;
render_mode blend_mix, depth_prepass_alpha;

// Veredelte Seite, DURCHSICHTIG (nur Glas): dasselbe Gitter, aber die Seite
// bleibt durchscheinend - der Stufenschliff liegt auf dem Wuerfelinneren.
// Der Tiefen-Vorpass haelt Ziffer und Runen vor der Scheibe.

#include "res://assets/shaders/die_dope_lattice.gdshaderinc"

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
	dope_lattice(UV, tview, albedo, emission, metal, rough, alpha);
	ALBEDO = albedo;
	EMISSION = emission;
	METALLIC = metal;
	ROUGHNESS = rough;
	ALPHA = alpha;
}
