shader_type spatial;
// Die HOLO-SCHEIBE im Fenster der Charm-Diskette: das Charm-Bild liegt auf einer runden Scheibe
// um die Nabe; außerhalb ihres Rands dunkles Gehäuse, am Rand ein schmaler Saum.
render_mode unshaded, cull_back;

uniform sampler2D picture : source_color, filter_linear_mipmap;
// Fenster in Flächen-Koordinaten (x0, y0, x1, y1) - UV.x läuft mit x, UV.y gegen y.
uniform vec4 rect;
uniform vec2 hub;
uniform float radius;
uniform float rim_width = 0.012;
// Das geteilte Charm-Bild läßt viel Rand um das Modell - die Scheibe zeigt es vergrößert.
uniform float zoom = 1.6;
uniform vec3 bg_inner : source_color;
uniform vec3 bg_outer : source_color = vec3(0.01, 0.008, 0.02);
uniform vec3 rim_color : source_color = vec3(0.3, 0.29, 0.28);
uniform vec3 housing : source_color = vec3(0.006, 0.006, 0.008);

void fragment() {
	vec2 p = vec2(mix(rect.x, rect.z, UV.x), mix(rect.w, rect.y, UV.y));
	float aspect = (rect.z - rect.x) / (rect.w - rect.y);
	// Das quadratische Bild steht vergrößert mittig, links und rechts der Verlauf.
	vec2 tuv = vec2(0.5 + (UV.x - 0.5) * aspect / zoom, 0.5 + (UV.y - 0.5) / zoom);
	vec4 art = texture(picture, tuv);
	float in_tex = step(0.0, tuv.x) * step(tuv.x, 1.0);
	float glow = 1.0 - clamp(length((UV - 0.5) * vec2(aspect, 1.0)) / (0.5 * aspect), 0.0, 1.0);
	vec3 col = mix(bg_outer, bg_inner, glow);
	col = mix(col, art.rgb, art.a * in_tex);
	float d = distance(p, hub);
	col = mix(col, rim_color, smoothstep(radius - rim_width, radius - rim_width * 0.5, d));
	col = mix(col, housing, step(radius, d));
	ALBEDO = col;
}
