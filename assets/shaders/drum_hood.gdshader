shader_type spatial;
render_mode unshaded;
// Die Abdeckhaube einer gesperrten Walzen-Scheibe: dunkler Stahl, ringsum ein Band
// aus Warnschraffur - nur die NÄCHSTE (hazard 1), die übrigen sind ruhig und dunkler.
uniform vec2 half_size = vec2(1.0, 1.0);
uniform float hazard = 1.0;
uniform float calm_dim = 0.7;
uniform float band = 0.25;
uniform float stripe = 0.3;
uniform vec3 steel : source_color = vec3(0.075, 0.08, 0.1);
uniform vec3 warn : source_color = vec3(1.0, 0.62, 0.08);
uniform float warn_energy = 0.85;
varying vec3 local;
varying float top;

void vertex() {
	local = VERTEX;
	top = step(0.5, NORMAL.y);
}

void fragment() {
	vec2 p = local.xz;
	vec2 edge = half_size - abs(p);
	float rim = min(edge.x, edge.y);
	float in_band = step(rim, band) * step(band * 0.18, rim);
	float line = step(0.5, fract((p.x + p.y) / stripe));
	float brushed = 0.85 + 0.15 * sin(p.y * 90.0) * sin(p.y * 37.0);
	float sheen = 1.0 + 0.5 * smoothstep(-half_size.x, half_size.x, p.x);
	vec3 base = steel * brushed * sheen * mix(calm_dim, 1.0, hazard);
	vec3 stripes = mix(vec3(0.02), warn * warn_energy, line);
	ALBEDO = mix(base, stripes, in_band * top * hazard);
}
