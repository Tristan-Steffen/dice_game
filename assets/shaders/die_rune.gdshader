// Runen der Würfelschale: EIN Shader für alle sechs Zeichen und die Vakuum-
// Umkehrung. Die Maske ist FARBLOS (R Kern, G Bogenlänge, B Abstand zur
// Mittellinie, A Deckung) und in SEITEN-Koordinaten gebacken, liegt also
// deckungsgleich auf der Seite; die Tönung kommt als Uniform, der Runen-Platz als
// glyph_flip - darum gibt es sechs Texturen im Spiel und nicht dreißig.
//
// unshaded verwirft EMISSION - die Helligkeit muss über ALBEDO raus. Genau daran
// ist die alte Auflage gescheitert: sie animierte emission_energy_multiplier auf
// einem unschattierten Material, also passierte sichtbar nie etwas.
//
// Zwei Regeln formen jede Bewegung. In Ruhe darf nichts die Bloom-Schwelle (0.95)
// erreichen - das hält sechs beschriftete Würfel in der Grube mechanisch davon ab,
// eine Disco zu werden. Und ein Ausbruch liest auf Übersichts-Distanz über
// BREITE: eine Naht ist dort ~1 px, Helligkeit allein bliebe ein Subpixel-Punkt.

shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;

// Datentextur, KEIN source_color: die sRGB-Kurve zöge Bogenlänge und Abstand
// krumm. repeat_disable, weil die Bias-Probe über den Rand greifen darf.
uniform sampler2D glyph_map : filter_linear_mipmap, repeat_disable;
uniform vec3 seam_color = vec3(1.0);   // normiert: hellste Komponente == 1
uniform vec3 core_color = vec3(1.0);
uniform int motion = 0;                // 0 ECHO 1 SCATTER 2 EMBER 3 SPARK 4 INTAKE
uniform float idle_low = 0.22;
uniform float idle_high = 0.62;        // MUSS unter 0.95 bleiben
uniform float idle_speed = 0.238;      // 1 / Ruhe-Periode
uniform float phase = 0.0;             // je Würfel versetzt: 30 Tray-Würfel atmen nie im Gleichschritt
uniform float flare = 0.0;             // 1 -> 0 über RUNE_FLARE_TIME
uniform float flare_peak = 3.0;
uniform float core_share = 0.55;       // Kern gegen Hof - unser Gegenstück zur Pulverkörnung
uniform float halo_width = 0.35;
uniform float halo_flare = 2.8;
uniform vec2 halo_bias = vec2(0.0);    // gerichtetes Ausbluten (Streulicht: nach unten)
uniform vec2 digit_half = vec2(0.26, 0.38);
// Runen-Platz als Spiegelung (Rune.SLOT_FLIPS): eine negative Komponente klappt
// die Figur an dieser Achse um. Mehrere Runen einer Seite sind Spiegelungen
// derselben Maske - die Sperr-Ellipse ist symmetrisch, also hält jede den
// Ziffern-Abstand exakt ein.
uniform vec2 glyph_flip = vec2(1.0, 1.0);
uniform bool block_flare = false;      // Einbrand: Schutz-Blitz statt Wertungswelle

// Länge der wandernden Bande als Anteil der Naht (TAU ist eingebaut).
const float BAND = 0.12;

// DISTANZ-AUSGLEICH (2026-09-11). Auf Grubendistanz ist eine Seite ~25 px breit,
// die Naht also gut EIN Pixel - und ein Subpixel-Strich verschwindet, gleich wie
// hell er ist. Darum weitet sich mit der Entfernung das angenommene Hof-Band, bis
// das ganze gebackene Feld trägt: aus dem Strich wird eine Marke. Gemessen wird an
// den Texeln je Pixel, nicht an einer Kameradistanz - so gilt dieselbe Regel für
// Grube, Vorrat, Podest und Netz.
const float FAR_REF = 1.5;    // darunter ist der Strich dick genug
const float FAR_MAX = 7.0;    // weiter aufgeweitet wird nicht
const float FAR_GAIN = 2.2;   // und so viel heller wird die Marke dabei

// Bande hinter einem Kopf auf der Bogenlänge, umlaufend.
float trail(float s, float head, float width) {
	return 1.0 - smoothstep(0.0, width, fract(head - s));
}

// Alles hinter einem Kopf, der die Naht EINMAL überquert (kein Umlauf).
float swept(float s, float head, float soft) {
	return 1.0 - smoothstep(head - soft, head, s);
}

void fragment() {
	vec2 face_uv = UV;
	// Der Platz ist eine Spiegelung, keine Verschiebung - ohne if-Zweig.
	vec2 mirror = step(glyph_flip, vec2(0.0));
	vec2 uv = mix(face_uv, 1.0 - face_uv, mirror);
	vec4 mask = texture(glyph_map, uv);
	float core = mask.r;
	float s = mask.g;
	float radial = mask.b;
	float cover = mask.a;

	float ts = TIME + phase * 7.3;   // absolute Sekunden, je Würfel versetzt
	float t = ts * idle_speed;       // ein Durchlauf je Ruhe-Periode
	float u = 1.0 - clamp(flare, 0.0, 1.0);   // Ausbruch-Uhr: 0 -> 1
	float amp = idle_high - idle_low;

	float energy = idle_low;
	vec3 tint = seam_color;
	float widen = 1.0;
	float ring = 0.0;

	if (motion == 0) {
		// ECHO - die Seite feuert, dann noch einmal, schwächer. Der Ring leuchtet,
		// wird still und leuchtet erneut: die Animation ist ein Diagramm der Wirkung.
		energy = idle_low + amp * trail(s, fract(t), BAND);
		float h1 = clamp(u / 0.40, 0.0, 1.0);
		float h2 = clamp((u - 0.55) / 0.45, 0.0, 1.0);
		// Erst die LÜCKE zwischen den Läufen macht daraus eine Wiederholung
		// statt eines Wackelns.
		float b1 = trail(s, h1, BAND) * (1.0 - smoothstep(0.40, 0.55, u));
		float b2 = trail(s, h2, BAND) * (1.0 - smoothstep(0.90, 1.00, u));
		energy += flare_peak * b1 + flare_peak * 0.45 * b2;
		widen = 1.0 + (halo_flare - 1.0) * max(b1, b2 * 0.66);
	} else if (motion == 1) {
		// SCATTER - kein Lauf, nur Glitzern an Ort und Stelle. Der einzige Rune,
		// dessen Ruhe seine Hauptvorstellung ist: er bezahlt fürs Nichtstun.
		float crawl = 0.5 + 0.5 * sin(ts * 0.65 + s * 11.0);
		float glint = pow(max(0.0, sin(ts * 0.43 + s * 23.0)), 8.0);
		// max statt Summe: so IST idle_high die Obergrenze und nicht nur der
		// Regelfall - sonst könnten beide Terme zusammen darüber hinausschießen.
		energy = idle_low + amp * max(0.44 * crawl, glint);
		// Ausbruch: eine weiche Kaskade, nach Bogenlänge versetzt - ein Lauf von
		// Münzen, kein Schlag. Der Nenner sorgt dafür, dass JEDE Haarlinie bei
		// u = 1 fertig ist; sonst bliebe am Ende eine stehen und ruckt aus.
		float local = clamp((u - 0.25 * s) / (1.0 - 0.25 * s), 0.0, 1.0);
		float env = local < 0.222 ? local / 0.222 : 1.0 - (local - 0.222) / 0.778;
		env = clamp(env, 0.0, 1.0);
		energy += flare_peak * env;
		widen = 1.0 + (halo_flare - 1.0) * env;
	} else if (motion == 2) {
		// EMBER - die Glut kriecht die Strahlen hoch und zieht sich zurück. Der
		// einzige Rune mit einem Farbverlauf ENTLANG der Naht: weißglühend am
		// Einschlag, orange auf halbem Weg, tiefrot an den Spitzen.
		float k = 3.2 + 1.4 * sin(ts * 0.60);
		float heat = exp(-s * k);
		energy = idle_low + amp * heat;
		tint = mix(seam_color, core_color, heat * heat);
		if (block_flare) {
			// Der Schutz-Blitz: der einzige Moment, in dem die Wirkung überhaupt
			// sichtbar wird - hart weiß, plus ein Ring über die ganze Seite.
			float env = clamp(u / 0.111, 0.0, 1.0) * (1.0 - clamp((u - 0.111) / 0.889, 0.0, 1.0));
			// Der Ring geht von der SEITENMITTE aus: er ist die Schutz-Geste des
			// Würfels, nicht die des Zeichens.
			ring = (1.0 - smoothstep(0.0, 0.10, abs(length(face_uv - vec2(0.5)) - u * 0.9))) * env;
			energy += flare_peak * 1.21 * env;
			tint = mix(tint, core_color, env);
			widen = 1.0 + (halo_flare - 1.0) * env;
		} else {
			// Wertungs-Welle: langsamster Anschlag UND langsamster Abfall im Satz.
			// Einbrand ist der einzige Rune, der nicht schnappt.
			float env = swept(s, u * 2.0, 0.25) * (1.0 - clamp((u - 0.5) / 0.5, 0.0, 1.0));
			energy += flare_peak * env;
			tint = mix(tint, core_color, env);
			widen = 1.0 + (halo_flare - 1.0) * env;
		}
	} else {
		// SPARK - ein dunkler Körper und ein laufender Kopf. Hier ist nicht die
		// Naht die Erkennungsmarke, sondern der Punkt; nur ~4 % der Naht leuchten
		// je Moment, also lesen sechs davon als verstreute Funken, nicht als Blitze.
		energy = idle_low + amp * exp(-fract(s - fract(t)) * 30.0);
		// Ausbruch: der Kopf beschleunigt, überquert die Bahn und VERLÄSST sie.
		float head = clamp(u / 0.22, 0.0, 1.0);
		float env = mix(swept(s, head, 0.30), 1.0 - clamp((u - 0.22) / 0.78, 0.0, 1.0), step(0.22, u));
		energy += flare_peak * env;
		tint = mix(seam_color, core_color, env);
		widen = 1.0 + (halo_flare - 1.0) * env;
	}

	// Ziffern-Wächter: das Zeichen DIMMT, wo es hinter einer breiten Zahl liegt.
	// Es ändert nie seine Form - Knochen lässt Werte wachsen, und eine Rune, die
	// sich dabei neu zeichnet, liest als Fehler.
	// Gelockert am 2026-09-11: die FIGUR hält den Abstand seit dem KRANZ selbst ein
	// (ein Test bewacht ihn), also dimmt der Wächter nur noch, was wirklich
	// hereinragt - sonst kostete er jede Rune ein Fünftel ihrer Helligkeit.
	energy *= smoothstep(0.70, 1.00, length((face_uv - 0.5) / digit_half));

	float texels = max(fwidth(uv).x, fwidth(uv).y) * float(textureSize(glyph_map, 0).x);
	float far = clamp(texels / FAR_REF, 1.0, FAR_MAX);
	widen *= far;
	energy *= mix(1.0, FAR_GAIN, clamp((far - 1.0) / (FAR_MAX - 1.0), 0.0, 1.0));

	float band = halo_width * widen;
	float halo = clamp(1.0 - radial / max(band, 0.001), 0.0, 1.0);
	halo *= halo;
	// Gerichtetes Ausbluten: eine zweite Probe gegen die Bias-Richtung schiebt den
	// Hof zur Bias-Seite - bei Streulicht fällt das Licht so vom Würfel aufs Filz.
	float spill = 0.05 * (widen - 1.0) / max(halo_flare - 1.0, 0.001);
	// Die Bias-Richtung ist in SEITEN-Koordinaten gemeint, also klappt sie mit.
	float shifted = clamp(1.0 - texture(glyph_map, uv - halo_bias * glyph_flip * spill).b
		/ max(band, 0.001), 0.0, 1.0);
	halo = max(halo, shifted * shifted);

	float bright = clamp(energy, 0.0, 1.0);
	vec3 out_albedo = (core_color * core * core_share + tint * halo * (1.0 - core_share)) * energy
		+ core_color * ring * flare_peak;
	// Der Kern ist immer da - der Spalt bleibt, auch wenn kein Licht durchfällt.
	// Der Hof dagegen kommt und geht mit der Helligkeit.
	float out_alpha = clamp(max(core, max(halo * bright, ring)), 0.0, 1.0) * max(cover, ring);

	// --- Vakuum: die Umkehrung. Licht fällt HINEIN, statt heraus -------------------
	if (motion == 4) {
		// Die einzige Bewegung ist die BREITE, und sie geht nach innen: die Naht
		// zieht sich zu, während ihre Deckkraft steigt. Ein Vakuum führt sich nicht auf.
		float breath = 0.5 + 0.5 * sin(t * TAU);
		float intake = idle_low + amp * breath;
		float vac_band = halo_width * mix(1.0, 0.55, breath);
		float edge = radial / max(vac_band, 0.001);
		// Der Saum IST das Ereignishorizont-Signal: eine schwarze Naht auf einer
		// schwarzen Seite existiert ohne ihn schlicht nicht. Kein Zierrat, sondern
		// die Lesbarkeit der ganzen Essenz.
		float rim = smoothstep(0.70, 0.95, edge) - smoothstep(0.95, 1.25, edge);
		// Ausbruch: die Seite verdunkelt sich von den Nähten nach außen - die
		// Umkehr-Geste zu jedem anderen Ausbruch auf diesem Tisch.
		float bleed = 1.0 - smoothstep(0.0, 0.45 + 0.55 * flare, radial);
		float swallow = max(core, clamp(1.0 - edge, 0.0, 1.0));
		out_albedo = core_color * rim * mix(0.45, flare_peak, flare);
		out_alpha = clamp(max(swallow * intake, bleed * 0.70 * flare) + rim * 0.5, 0.0, 1.0)
			* max(cover, bleed);
	}

	ALBEDO = out_albedo;
	ALPHA = out_alpha;
}
