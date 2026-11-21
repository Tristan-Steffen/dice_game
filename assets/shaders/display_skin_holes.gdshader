shader_type spatial;
render_mode unshaded;
// Die Haut des VERSENKTEN Grubenbodens: das Bild der Anzeige an ihrer Stelle (wie
// display_skin), aber mit den Löchern der Schächte - eine Sektion, die im Grubenboden
// öffnet, muß auch ihn durchbrechen. Das eigene Dauer-Loch der Grube (skip_slot) zählt nicht.

uniform sampler2D screen_texture : source_color, filter_linear_mipmap;
uniform vec4 display_map = vec4(0.0, 1.0, 0.0, 1.0);
uniform float emission_energy = 1.2;
uniform vec2 screen_px = vec2(1.0, 1.0);

const int MAX_PITS = 49;
uniform int pit_count = 0;
uniform int skip_slot = -1;
uniform vec4 pit_rects[MAX_PITS];
uniform float pit_radii[MAX_PITS];

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hole_distance(vec2 p, vec4 rect, float radius) {
	vec2 center = (rect.xy + rect.zw) * 0.5;
	vec2 half_size = (rect.zw - rect.xy) * 0.5 - vec2(radius);
	vec2 d = abs(p - center) - half_size;
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0) - radius;
}

void fragment() {
	vec2 uv = vec2((world_position.z - display_map.x) / display_map.y,
		(display_map.z - world_position.x) / display_map.w);
	vec2 pixel = uv * screen_px;
	for (int i = 0; i < pit_count; i++) {
		if (i != skip_slot && pit_rects[i].z > pit_rects[i].x
				&& hole_distance(pixel, pit_rects[i], pit_radii[i]) < 0.0) {
			discard;
		}
	}
	ALBEDO = texture(screen_texture, clamp(uv, vec2(0.0), vec2(1.0))).rgb * emission_energy;
}
