shader_type spatial;
render_mode blend_mix, cull_disabled, shadows_disabled;

// TIEFEN-NEBEL und MILCHGLAS fuer den PATERNOSTER: je tiefer eine Stapel-Ebene in
// der Grube liegt, desto DUNKLER und MILCHIGER liest sie. Er traegt zwei Flaechen,
// die heute StandardMaterial3D waren - die Tablett-Platte (getoent, geschattet) und
// die Netz-Backung der Karte (unschattiert, aus einer Textur). Was sie trennt, sind
// Uniforms: cull_back verwirft die Rueckseiten (die Platte), use_tex liest das Netz.
// Die ALPHA bleibt exakt die des Bestands - der Nebel dimmt nur Farbe und Emission.

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec3 emission : source_color = vec3(0.0);
uniform float emission_energy = 1.0;
// Die Bestands-Alpha, unveraendert; bei Textur mischt ihr Alpha mit (wie albedo_color).
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 1.0;
uniform float specular : hint_range(0.0, 1.0) = 0.5;
// Die Platte ist ein Kasten und will ihre Rueckseiten los; das Netz-Quad liest
// beidseitig (von hinten dieselbe Backung, gespiegelt).
uniform bool cull_back = false;

// 0 = Lese-Tiefe (voll hell, scharf), 1 = unterste Park-Ebene.
uniform float depth_fade : hint_range(0.0, 1.0) = 0.0;
uniform float fog_strength : hint_range(0.0, 1.0) = 0.8;
// Die erste Stufe soll HART abfallen, die letzten sich sammeln - darum eine Kurve.
uniform float fog_gamma = 0.45;
uniform float frost_strength : hint_range(0.0, 1.0) = 0.9;
// Das Milchglas steigt SANFTER als der Nebel faellt - sonst waere die erste
// geparkte Ebene schon fast so milchig wie die unterste.
uniform float frost_gamma = 0.7;
uniform vec3 frost_tint : source_color = vec3(0.60, 0.62, 0.70);
// Wie hell das Milchglas gegen den Nebel anleuchten darf (es hellt nie ueber ihn auf).
uniform float frost_gain : hint_range(0.0, 1.0) = 0.35;
uniform float frost_grain = 90.0;

uniform sampler2D net_tex : source_color, filter_linear_mipmap, hint_default_white;
uniform bool use_tex = false;
// Tap-Streuung bei vollem Frost, in UV: tiefe Netze lesen UNSCHARF.
uniform float blur_span = 0.02;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(41.317, 289.043))) * 43758.5453);
}

void fragment() {
	if (cull_back && !FRONT_FACING) {
		discard;
	}
	float fog = 1.0 - fog_strength * pow(depth_fade, fog_gamma);
	float frost = frost_strength * pow(depth_fade, frost_gamma);
	vec4 tex = vec4(1.0);
	if (use_tex) {
		tex = texture(net_tex, UV);
		float off = blur_span * frost;
		if (off > 0.0001) {
			// Vier Nachbar-Taps: die Backung verliert ihre Kanten, statt scharf
			// aus der Tiefe zu stanzen.
			tex += texture(net_tex, UV + vec2(off, 0.0));
			tex += texture(net_tex, UV - vec2(off, 0.0));
			tex += texture(net_tex, UV + vec2(0.0, off));
			tex += texture(net_tex, UV - vec2(0.0, off));
			tex *= 0.2;
		}
	}
	float grain = hash21(floor(UV * frost_grain)) * 0.6
		+ hash21(floor(UV * frost_grain * 2.7) + 13.0) * 0.4;
	// Das Milchglas liegt IM Nebel: es zieht die Farbe ins Grau, hellt aber nie
	// ueber die gedaempfte Helligkeit dieser Ebene hinaus auf.
	vec3 milk = frost_tint * fog * frost_gain * (0.75 + 0.5 * grain);
	vec3 base = mix(albedo.rgb * tex.rgb * fog, milk, frost);
	vec3 glow = mix(emission * tex.rgb * emission_energy * fog, milk, frost);
	ALBEDO = base;
	EMISSION = glow;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	ALPHA = alpha * tex.a;
}
