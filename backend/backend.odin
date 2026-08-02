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

FONT_LOAD_SIZE :: 64

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
	width:       i32,
	height:      i32,
	input:       Input,
	font:        rl.Font,
	shader:      rl.Shader,
	dropped:     [1024]u8,
	dropped_len: int,
}

init :: proc(width, height: i32, title: cstring) -> Window {
	rl.SetConfigFlags({rl.ConfigFlag.WINDOW_RESIZABLE, rl.ConfigFlag.WINDOW_ALWAYS_RUN})
	rl.InitWindow(width, height, title)
	rl.SetTargetFPS(60)

	font_path := slashpath.join(
		{string(rl.GetApplicationDirectory()), "fonts", "JetBrainsMono-2.304", "JetBrainsMono-Regular.ttf"},
	)
	font := rl.LoadFontEx(strings.clone_to_cstring(font_path), FONT_LOAD_SIZE, nil, 0)
	rl.SetTextureFilter(font.texture, .BILINEAR)

	vs := cstring(#load("../shaders/instancing.vs"))
	fs := cstring(#load("../shaders/flat.fs"))
	shader := rl.LoadShaderFromMemory(vs, fs)
	shader.locs[rl.ShaderLocationIndex.MATRIX_MODEL] = rl.GetShaderLocationAttrib(
		shader,
		"instanceTransform",
	)

	return Window {
		width  = rl.GetScreenWidth(),
		height = rl.GetScreenHeight(),
		font   = font,
		shader = shader,
	}
}

shutdown :: proc(window: ^Window) {
	rl.UnloadShader(window.shader)
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
