// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

// Package backend is the only place the app touches raylib (or any
// future platform). It owns the window, the input snapshot, and the
// execution of draw command lists produced by the ui package.
package backend

import rl "vendor:raylib"

Color :: struct {
	r, g, b, a: u8,
}

Window :: struct {
	width:  i32,
	height: i32,
}

init :: proc(width, height: i32, title: cstring) -> Window {
	rl.SetConfigFlags({rl.ConfigFlag.WINDOW_RESIZABLE, rl.ConfigFlag.WINDOW_ALWAYS_RUN})
	rl.InitWindow(width, height, title)
	rl.SetTargetFPS(60)
	return Window{width = rl.GetScreenWidth(), height = rl.GetScreenHeight()}
}

shutdown :: proc() {
	rl.CloseWindow()
}

should_close :: proc(window: ^Window) -> bool {
	return rl.WindowShouldClose()
}

begin_frame :: proc(window: ^Window) {
	window.width = rl.GetScreenWidth()
	window.height = rl.GetScreenHeight()
	rl.BeginDrawing()
}

end_frame :: proc(window: ^Window) {
	rl.EndDrawing()
}

clear :: proc(window: ^Window, color: Color) {
	rl.ClearBackground(rl.Color{color.r, color.g, color.b, color.a})
}
