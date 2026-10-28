shader_type spatial;
// Die WAENDE einer Karten-Mulde im Tablett (Spieler-Wunsch 2026-10-28): mit dem
// Material der Oberflaeche las die Vertiefung flach. Ein Verlauf nach unten ins
// Dunkel und eine helle Kante oben machen die Tiefe lesbar. Gerechnet in der Hoehe
// der Wand selbst - rollt das Tablett, faehrt der Verlauf mit.

uniform vec3 top_color : source_color = vec3(0.13, 0.13, 0.19);
uniform vec3 bottom_color : source_color = vec3(0.025, 0.025, 0.04);
uniform vec3 rim_color : source_color = vec3(0.46, 0.48, 0.64);
uniform float height = 0.5;          // Hoehe der Wand (Welt) - der Kasten ist mittig
uniform float rim_share = 0.07;      // Anteil der Hoehe, den die Kante oben nimmt
uniform float energy = 0.55;

varying float rise;

void vertex() {
	rise = VERTEX.y / max(height, 0.001) + 0.5;
}

void fragment() {
	float t = clamp(rise, 0.0, 1.0);
	vec3 color = mix(bottom_color, top_color, t * t);
	color = mix(color, rim_color, smoothstep(1.0 - rim_share, 1.0, t));
	ALBEDO = color;
	EMISSION = color * energy;
	ROUGHNESS = 0.6;
	METALLIC = 0.25;
}
