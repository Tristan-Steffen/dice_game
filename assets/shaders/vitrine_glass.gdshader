shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

// Die SCHEIBE über einer Vitrine, untere Lage (VitrineGlassView): sie zeigt
// dasselbe Bild, das der Tisch-Bildschirm unter ihr zeigte - denselben
// Textur-Ausschnitt, aus demselben Viewport - und fährt ihn per Vorhang von
// DECKEND auf einen Glas-Grundton herunter. Der Übergang IST diese Deckkraft:
// das Loch im Haupt-Mesh ist binär, die Scheibe trägt das Auf- und Zublenden
// allein (ein Rausch-Dissolve stand vorher hier und las sich als Bildstörung
// statt als Glas).
// Ganz offen muss man SEHEN, dass Glas darüber liegt: ein Ton, zwei wandernde
// Schimmerbänder, ein heller Rahmenstrich und - über der hinteren Buchtkante -
// eine Reihe Glanzpunkte, die die Birnen der Auskleidung spiegelt. Die Grenze ist
// die Ware: sie und die Beschriftung darüber bleiben klar lesbar.

uniform sampler2D display_texture : source_color, filter_linear_mipmap;
// Der Ausschnitt der Bucht im Display, in UV: xy = Ecke, zw = Größe.
uniform vec4 field = vec4(0.0, 0.0, 1.0, 1.0);
uniform float open : hint_range(0.0, 1.0) = 0.0;
// Anzeigeton des Displays (screen_glass.emission_energy) - sonst läse die Kopie
// dunkler als der Tisch daneben.
uniform float energy = 1.2;
uniform vec3 tint : source_color = vec3(0.55, 0.62, 0.86);
// Rest-Deckkraft der ganz offenen Scheibe: gerade genug für "da liegt Glas".
uniform float base_alpha : hint_range(0.0, 0.4) = 0.18;
uniform float sheen : hint_range(0.0, 1.0) = 0.46;
uniform float edge_shade : hint_range(0.0, 1.0) = 0.55;
// Der helle Strich knapp innerhalb der Kante: die geschliffene Fassung.
uniform float frame_light : hint_range(0.0, 2.0) = 0.85;
// Die gespiegelten Birnen über der hinteren Buchtkante (UV-y = 0 ist hinten).
uniform float glint_pitch = 0.055;
uniform float glint_energy : hint_range(0.0, 2.0) = 0.75;
// Wanderung der Schimmerbänder - SEHR langsam, sie soll man nur bemerken, wenn
// man hinsieht.
uniform float drift_speed = 0.05;

void fragment() {
	vec3 display = texture(display_texture, field.xy + UV * field.zw).rgb * energy;

	// Zwei Bänder quer über die Scheibe statt eines Verlaufs: ein bloßer Verlauf
	// las sich als "die Grube ist einseitig heller", erst die Bänder sagen "hier
	// liegt eine Platte". Sie wandern langsam gegeneinander.
	float diagonal = clamp(0.5 + 0.6 * (UV.x - UV.y), 0.0, 1.0);
	float drift = sin(TIME * drift_speed) * 0.07;
	float shimmer = (1.0 - smoothstep(0.0, 0.14, abs(diagonal - (0.66 + drift)))) * sheen;
	shimmer += (1.0 - smoothstep(0.0, 0.05, abs(diagonal - (0.33 - drift)))) * sheen * 0.6;

	vec2 middle = abs(UV - vec2(0.5));
	float rim = smoothstep(0.34, 0.5, max(middle.x, middle.y));
	// Der Fassungsstrich: eine schmale helle Linie dicht an der Kante.
	float frame = 1.0 - smoothstep(0.008, 0.020, abs(max(middle.x, middle.y) - 0.478));

	// Glanzpunkte über der hinteren Kante - die Marquee-Birnen der Wand, in der
	// Scheibe gespiegelt.
	float row = 1.0 - smoothstep(0.0, 0.05, abs(UV.y - 0.055));
	float glint = row * (1.0 - smoothstep(0.13, 0.30,
		abs(fract(UV.x / max(glint_pitch, 0.005)) - 0.5)));

	vec3 glass = tint * (0.30 + shimmer * 0.80 + frame * frame_light
		+ glint * glint_energy) * (1.0 - edge_shade * rim * 0.55);
	float glass_alpha = base_alpha * (0.85 + shimmer * 1.5 + rim * 1.0
		+ frame * 2.0 + glint * 1.4);

	float curtain = smoothstep(0.0, 1.0, open);
	ALBEDO = mix(display, glass, curtain);
	ALPHA = mix(1.0, glass_alpha, curtain);
}
