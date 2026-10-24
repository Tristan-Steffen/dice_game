extends GutTest

## Ein falsch geschriebener Schlüssel in project.godot schweigt: Godot legt ihn als
## eigene Einstellung ab, und die echte bleibt auf ihrem Standard (so lief MSAA
## einen Tag lang gar nicht).
func test_msaa_really_reaches_the_renderer() -> void:
	assert_eq(int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", 0)),
		Viewport.MSAA_4X, "MSAA 4x gegen die Treppen an den Würfelkanten")
	assert_false(ProjectSettings.has_setting("rendering/rendering/anti_aliasing/quality/msaa_3d"),
		"kein doppeltes rendering/ im Schlüssel")
