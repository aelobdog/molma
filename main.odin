// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package main

import "backend"
import "core:fmt"
import "draw"
import "ui"

main :: proc() {
	window := backend.init(1280, 800, "Molma")
	defer backend.shutdown(&window)

	theme := ui.default_theme()
	font := backend.font_metrics(&window)
	count := 0
	frame: ui.Frame
	frame.theme = theme
	frame.font = font

	for !backend.should_close(&window) {
		backend.begin_frame(&window)
		backend.clear(&window, backend.Color{0x33, 0x33, 0x33, 0xff})

		commands := make([dynamic]draw.DrawCommand, context.temp_allocator)
		ui.begin_frame(&frame, &commands, window.input)

		if ui.begin_panel(&frame, draw.Rect{20, 20, 240, 300}) {
			if ui.button(&frame, draw.Rect{30, 30, 220, 40}, "Add") {
				count += 1
			}
			if ui.button(&frame, draw.Rect{30, 80, 220, 40}, "Reset") {
				count = 0
			}
			ui.end_panel(&frame)
		}

		buf: [32]u8
		s := fmt.bprintf(buf[:], "count: %d", count)
		ui.text(&frame, {280, 30}, s, 24, theme.text)

		backend.execute_commands(&window, commands[:])
		backend.end_frame(&window)

		free_all(context.temp_allocator)
	}
}
