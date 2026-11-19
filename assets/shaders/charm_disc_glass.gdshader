shader_type spatial;
// Das versiegelte GLAS über der Holo-Scheibe: fast klar, mit einem schmalen schrägen Lichtstreif.
render_mode unshaded, blend_mix, depth_draw_never, cull_back;

uniform float base_alpha = 0.03;
uniform float streak_alpha = 0.16;
uniform float streak_at = 0.4;
uniform float streak_width = 0.035;

void fragment() {
	float s = dot(UV, vec2(0.62, 0.45));
	float streak = smoothstep(streak_at - streak_width, streak_at, s)
		* (1.0 - smoothstep(streak_at + streak_width * 0.4, streak_at + streak_width * 1.4, s));
	ALBEDO = vec3(0.92, 0.96, 1.0);
	ALPHA = base_alpha + streak * streak_alpha;
}
