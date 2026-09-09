// Der Charm auf seinem Vitrinen-Sockel (siehe CharmRowView): ein MASSIVES,
// beleuchtetes Modell in kräftigen Farben, über das ein zurückgenommener
// HOLOGRAMM-Schimmer läuft - Fresnel-Saum und breite, langsam steigende Bänder.
// Kein Flackern, keine feinen Scanlines (die Kunstrichtung ist clean, nicht CRT).
// Das Modell bleibt undurchsichtig: ALPHA wird nie geschrieben, so bleibt es im
// Tiefenpuffer und stellt keine Sortierfrage.
shader_type spatial;
render_mode cull_back;

uniform sampler2D albedo_tex : source_color, hint_default_white;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform bool use_texture = false;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.0;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.6;

// SÄTTIGUNG um die Leuchtdichte: der Tisch ist dunkel und blau-ambient, darum
// lasen die echten Modellfarben ausgegraut. 1,0 = Originalfarbe.
uniform float saturation : hint_range(0.0, 3.0) = 1.45;
// Museums-Eigenlicht: jede Fläche strahlt ihre Farbe schwach zurück, sonst steht
// das PBR-Modell im dunklen Raum als schwarzer Klumpen. Zu hoch hebt es die
// Tiefen an und macht alles milchig - DAS war das Grau.
uniform float self_glow : hint_range(0.0, 1.0) = 0.22;

// Der Hologramm-Schimmer, beide Anteile bewußt schwach.
uniform vec3 holo_color : source_color = vec3(0.45, 0.8, 1.0);
uniform float holo_rim : hint_range(0.0, 2.0) = 0.35;   // Fresnel-Saum
uniform float holo_band : hint_range(0.0, 1.0) = 0.09;  // steigende Bänder
uniform float band_freq = 2.5;    // Bänder je Welteinheit Höhe
uniform float band_speed = 1.2;   // Wandergeschwindigkeit nach oben
uniform float rim_power = 2.6;
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
	float sheen = fres * holo_rim + band * holo_band;
	EMISSION = color * self_glow * (1.0 + flash)
		+ holo_color * sheen * (1.0 + flash * 3.0);
}
