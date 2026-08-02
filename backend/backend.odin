// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

// Package backend is the only place the app touches raylib (or any
// future platform). It owns the window, the input snapshot, and the
// execution of draw command lists produced by the ui layer.
package backend

import "core:path/slashpath"
import "core:strings"
import rl "vendor:raylib"

Color :: struct {
	r, g, b, a: u8,
}

FontMetrics :: struct {
	advance:   f32,
	base_size: f32,
}

font_metrics :: proc(window: ^Window) -> FontMetrics {
	advance := f32(10)
	if window.font.glyphCount > 0 {
		advance = f32(window.font.glyphs[0].advanceX)
	}
	return FontMetrics{advance = advance, base_size = f32(window.font.baseSize)}
}

Window :: struct {
	width:  i32,
	height: i32,
	input:  Input,
	font:   rl.Font,
}

init :: proc(width, height: i32, title: cstring) -> Window {
	rl.SetConfigFlags({rl.ConfigFlag.WINDOW_RESIZABLE, rl.ConfigFlag.WINDOW_ALWAYS_RUN})
	rl.InitWindow(width, height, title)
	rl.SetTargetFPS(60)

	font_path := slashpath.join(
		{string(rl.GetApplicationDirectory()), "fonts", "JetBrainsMono-2.304", "JetBrainsMono-Regular.ttf"},
	)
	font := rl.LoadFont(strings.clone_to_cstring(font_path))

	return Window {
		width  = rl.GetScreenWidth(),
		height = rl.GetScreenHeight(),
		font   = font,
	}
}

shutdown :: proc(window: ^Window) {
	rl.UnloadFont(window.font)
	rl.CloseWindow()
}

should_close :: proc(window: ^Window) -> bool {
	return rl.WindowShouldClose()
}

begin_frame :: proc(window: ^Window) {
	window.width = rl.GetScreenWidth()
	window.height = rl.GetScreenHeight()
	refresh_input(window)
	rl.BeginDrawing()
}

end_frame :: proc(window: ^Window) {
	rl.EndDrawing()
}

clear :: proc(window: ^Window, color: Color) {
	rl.ClearBackground(rl.Color{color.r, color.g, color.b, color.a})
}
