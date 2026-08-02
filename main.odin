// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package main

import "backend"
import "draw"

main :: proc() {
	window := backend.init(1280, 800, "Molma")
	defer backend.shutdown(&window)

	for !backend.should_close(&window) {
		backend.begin_frame(&window)
		backend.clear(&window, backend.Color{0x33, 0x33, 0x33, 0xff})

		commands := make([dynamic]draw.DrawCommand, context.temp_allocator)
		append(&commands, draw.FillRect{rect = {0, 0, 200, 100}, color = {60, 120, 200, 255}})
		append(&commands, draw.Line{p0 = {0, 0}, p1 = {200, 100}, width = 2, color = {255, 255, 255, 255}})
		append(&commands, draw.Text{position = {10, 10}, text = "Molma", size = 32, color = {255, 255, 255, 255}})

		backend.execute_commands(&window, commands[:])
		backend.end_frame(&window)

		free_all(context.temp_allocator)
	}
}
