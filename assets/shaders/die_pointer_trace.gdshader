shader_type spatial;
render_mode unshaded, cull_disabled;

// Leiterbahn eines Würfels: ein kurzes, überall gleich breites Band über die
// gequerte Kante. Die RICHTUNG trägt allein die Strömung: diskrete Chevrons
// (Spitze voraus) wandern stetig zur Zielseite - das Boost-Feld-Prinzip.
// ENTSCHEIDEND ist der Kontrast NACH UNTEN: die Rille zwischen den Chevrons
// bleibt dunkel (unter der Bloom-Schwelle), nur der Kamm blüht. Ein heller
// Grund + hellerer Kamm klemmt beides auf Weiß und die Bewegung verschwindet.
// UV.y ist die BOGENLÄNGE (0 = Quellende, 1 = Zielende), UV.x die Bandbreite;
// TIME treibt die Wellen, phase versetzt sie je Würfel (kein Tray-Gleichtakt).

uniform vec3 trace_color : source_color = vec3(0.0, 0.85, 1.0);
uniform float base_energy = 0.3;   // Rille: sichtbar Cyan, aber deutlich dunkel
uniform float crest_energy = 1.08; // Chevron-Kamm: blüht (Schwelle 0.95)
uniform float phase = 0.0;
uniform float flow_speed = 0.8;    // Takte je Sekunde
uniform float repeats = 4.0;       // Chevrons auf der Bogenlänge
uniform float slant = 1.1;         // V-Tiefe: 0 = gerade Bänder
uniform float duty = 0.45;         // Anteil Chevron am Takt (Rest = Rille)

void fragment() {
	// + abs(...): die Bandmitte läuft voraus - die Chevron-Spitze zeigt zum Ziel.
	float w = UV.y * repeats + abs(UV.x - 0.5) * slant;
	float k = fract(w - TIME * flow_speed - phase);
	// Schnelle, aber weiche Flanken: klare Chevron-FORMEN statt Sinusnebel.
	float chevron = smoothstep(0.0, 0.1, k) * (1.0 - smoothstep(duty, duty + 0.1, k));
	// Zu den Bandrändern leicht abdunkeln - das flache Band wirkt wie ein
	// runder Leiter, nicht wie ein Klebestreifen.
	float body = 1.0 - 0.35 * smoothstep(0.28, 0.5, abs(UV.x - 0.5));
	// unshaded verwirft EMISSION - die Farbe muss über ALBEDO raus.
	ALBEDO = trace_color * mix(base_energy, crest_energy, chevron) * body;
	ALPHA = 1.0;
}
