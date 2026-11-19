shader_type spatial;

// Veredelte Seite, DECKEND. Die durchscheinende Spielart (Glas) steht in
// die_dope_mount_sheer - zwei Dateien, weil ein geschriebenes ALPHA die ganze
// Seite in den Transparenz-Durchgang zieht.

#include "res://assets/shaders/die_dope_mount.gdshaderinc"

void vertex() {
	// Blickrichtung im Tangentenraum: der Lichtstreif wandert beim Drehen.
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
}
