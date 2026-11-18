shader_type spatial;
render_mode unshaded;
// Die DECKHAUT einer Hebebühnen-Plattform (siehe LiftShaftView): sie zeigt das
// ECHTE Bild der Tisch-Anzeige an IHRER Stelle. Gerechnet wird aus der
// WELTPOSITION, nicht aus einer UV - die Platte ist ein Quader, seine UV läuft je
// Seite anders, und sie FÄHRT: sinkt sie, trägt sie ihr Stück Anzeige sichtbar mit
// hinunter (der Mahjong-Deckel), statt ihr Bild zu verschieben.
//
// Die Abbildung ist Zeile für Zeile die von TableScreen.world_to_pixel:
//   u = (world.z - z_min) / z_span
//   v = (x_max - world.x) / x_span
// display_map trägt genau diese vier Zahlen (z_min, z_span, x_max, x_span);
// TableScreen meldet sie samt Textur herein (display_skin).
//
// unshaded wie das Glas: die Anzeige ist SELBSTLEUCHTEND, kein Szenenlicht darf
// auf ihr einen Fleck malen - sonst verriete sich die Platte im bündigen Stand.

uniform sampler2D screen_texture : source_color, filter_linear_mipmap;
uniform vec4 display_map = vec4(0.0, 1.0, 0.0, 1.0);
uniform float emission_energy = 1.2;  // dieselbe Zahl wie das Glas

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = vec2((world_position.z - display_map.x) / display_map.y,
		(display_map.z - world_position.x) / display_map.w);
	ALBEDO = texture(screen_texture, clamp(uv, vec2(0.0), vec2(1.0))).rgb * emission_energy;
}
