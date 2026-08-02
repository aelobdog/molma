// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package main

import "backend"
import "core:fmt"
import "draw"
import "poscar"
import "render"
import "ui"

main :: proc() {
	window := backend.init(1280, 800, "Molma")
	defer backend.shutdown(&window)

	mol, ok := poscar.parse("test-files/Ge.vasp")
	if !ok {
		fmt.println("WARNING: failed to load test-files/Ge.vasp")
		return
	}
	defer delete(mol.atoms)

	renderer := render.init(&window)
	defer render.destroy(&renderer)

	view: render.View
	render.reframe(&view, &mol, window.width, window.height)

	theme := ui.default_theme()
	font := backend.font_metrics(&window)
	count := 0
	name := make([dynamic]u8)
	append(&name, 0)
	defer delete(name)
	frame: ui.Frame
	frame.theme = theme
	frame.font = font

	for !backend.should_close(&window) {
		backend.begin_frame(&window)
		backend.clear(&window, backend.Color{0x33, 0x33, 0x33, 0xff})

		render.sync(&renderer, &mol)
		render.update_view(&view, window.width, window.height)
		render.draw(&renderer, &view)

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
