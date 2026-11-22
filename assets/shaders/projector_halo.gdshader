shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// Lichthof eines Projektors auf dem Filz: fällt vom Gehäuserand nach außen ab.
uniform vec4 tint : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform vec2 body = vec2(0.7, 0.7);  // Anteil des Gehäuses am Quad
uniform float corner = 0.12;

void fragment() {
	vec2 p = abs(UV - 0.5) * 2.0;
	vec2 d = p - (body - corner);
	float dist = length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - corner;
	float reach = 1.0 - max(body.x, body.y);
	float fall = clamp(1.0 - dist / reach, 0.0, 1.0);
	ALBEDO = tint.rgb * fall * fall * step(0.0, dist + 0.02);
}
