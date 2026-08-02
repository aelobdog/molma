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
	name := make([dynamic]u8)
	append(&name, 0)
	defer delete(name)
	frame: ui.Frame
	frame.theme = theme
	frame.font = font

	sphere := backend.create_sphere(1, 16, 16)
	defer backend.destroy_mesh(sphere)
	material := backend.create_material(backend.Color{60, 120, 200, 255})
	defer backend.destroy_material(material)

	camera := backend.Camera {
		position = {0, 0, 10},
		target   = {0, 0, 0},
		up       = {0, 1, 0},
		fovy     = 8,
	}

	transforms := [3]backend.Matrix4 {
		backend.make_transform({-3, 0, 0}, {1, 1, 1}),
		backend.make_transform({0, 0, 0}, {1.5, 1.5, 1.5}),
		backend.make_transform({3, 0, 0}, {1, 1, 1}),
	}

	for !backend.should_close(&window) {
		backend.begin_frame(&window)
		backend.clear(&window, backend.Color{0x33, 0x33, 0x33, 0xff})

		backend.begin_3d(camera)
		backend.draw_instanced(sphere, material, transforms[:])
		backend.end_3d()

		commands := make([dynamic]draw.DrawCommand, context.temp_allocator)
		ui.begin_frame(&frame, &commands, window.input)

		if ui.begin_panel(&frame, draw.Rect{20, 20, 240, 300}) {
			layout := ui.make_layout(&frame, draw.Rect{20, 20, 240, 300})
			if ui.button(&frame, ui.below(&layout, 40), "Add") {
				count += 1
			}
			if ui.button(&frame, ui.below(&layout, 40), "Reset") {
				count = 0
			}
			ui.text_input(&frame, ui.below(&layout, 40), &name)
			ui.end_panel(&frame)
		}

		buf: [32]u8
		s := fmt.bprintf(buf[:], "count: %d | name: %s", count, string(name[:len(name) - 1]))
		ui.text(&frame, {280, 30}, s, 24, theme.text)

		backend.execute_commands(&window, commands[:])
		backend.end_frame(&window)

		free_all(context.temp_allocator)
	}
}
