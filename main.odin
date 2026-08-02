// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package main

import "backend"
import "core:fmt"
import "draw"
import "model"
import "poscar"
import "render"
import "ui"

App :: struct {
	mol:       model.Molecule,
	selection: [dynamic]model.AtomIndex,
	hover:     i32,
	view:      render.View,
	renderer:  render.Renderer,
	frame:     ui.Frame,
}

toggle_selection :: proc(app: ^App, index: model.AtomIndex) {
	location := -1
	for v, k in app.selection {
		if v == index {
			location = k
			break
		}
	}
	if location >= 0 {
		ordered_remove(&app.selection, location)
	} else {
		append(&app.selection, index)
	}
}

main :: proc() {
	window := backend.init(1280, 800, "Molma")
	defer backend.shutdown(&window)

	app: App
	mol, ok := poscar.parse("test-files/Ge.vasp")
	if !ok {
		fmt.println("WARNING: failed to load test-files/Ge.vasp")
		return
	}
	app.mol = mol
	defer delete(app.mol.atoms)
	defer delete(app.selection)

	app.renderer = render.init(&window)
	defer render.destroy(&app.renderer)

	render.reframe(&app.view, &app.mol, window.width, window.height)

	app.frame.theme = ui.default_theme()
	app.frame.font = backend.font_metrics(&window)

	for !backend.should_close(&window) {
		backend.begin_frame(&window)
		backend.clear(&window, backend.Color{0x33, 0x33, 0x33, 0xff})

		if dropped := backend.poll_dropped_file(&window); len(dropped) > 0 {
			if new_mol, ok := poscar.parse(dropped); ok {
				delete(app.mol.atoms)
				app.mol = new_mol
				clear(&app.selection)
				render.reset(&app.renderer)
				render.reframe(&app.view, &app.mol, window.width, window.height)
			} else {
				fmt.println("WARNING: failed to parse:", dropped)
			}
		}

		render.sync(&app.renderer, &app.mol)
		if .RIGHT in window.input.mouse_down {
			render.orbit(&app.view, window.input.mouse_delta[0], window.input.mouse_delta[1])
		}
		if window.input.mouse_wheel != 0 {
			render.zoom(&app.view, window.input.mouse_wheel)
		}
		render.update_view(&app.view, window.width, window.height)

		app.hover = -1
		if idx, picked := render.pick_atom(
			&app.mol,
			app.view.camera,
			window.width,
			window.height,
			window.input.mouse_pos,
		); picked {
			app.hover = i32(idx)
		}

		if .LEFT in window.input.mouse_pressed {
			if app.hover >= 0 {
				if .SHIFT in window.input.mods {
					toggle_selection(&app, model.AtomIndex(app.hover))
				} else {
					clear(&app.selection)
					append(&app.selection, model.AtomIndex(app.hover))
				}
			} else if !(.SHIFT in window.input.mods) {
				clear(&app.selection)
			}
		}

		render.draw(&app.renderer, &app.view, &app.mol, app.hover, app.selection[:])

		commands := make([dynamic]draw.DrawCommand, context.temp_allocator)
		ui.begin_frame(&app.frame, &commands, window.input)

		backend.execute_commands(&window, commands[:])
		backend.end_frame(&window)

		free_all(context.temp_allocator)
	}
}
