// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package main

import "backend"
import "core:fmt"
import "core:strconv"
import "core:strings"
import "draw"
import "model"
import "poscar"
import "render"
import "ui"

App :: struct {
	mol:          model.Molecule,
	selection:    [dynamic]model.AtomIndex,
	hover:        i32,
	view:         render.View,
	renderer:     render.Renderer,
	frame:        ui.Frame,
	edit_rect:    draw.Rect,
	last_edited:  i32,
	edit_x:       [dynamic]u8,
	edit_y:       [dynamic]u8,
	edit_z:       [dynamic]u8,
	edit_species: [dynamic]u8,
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

set_buffer :: proc(buffer: ^[dynamic]u8, s: string) {
	clear(buffer)
	append(buffer, s)
	append(buffer, 0)
}

refill_edit_buffers :: proc(app: ^App, primary: i32) {
	atom := app.mol.atoms[primary]
	position := model.Vec3(model.cartesian(app.mol.lattice, atom.position))
	e, _ := model.lookup_by_number(atom.atomic_number)

	set_buffer(&app.edit_x, fmt.tprintf("%.4f", position[0]))
	set_buffer(&app.edit_y, fmt.tprintf("%.4f", position[1]))
	set_buffer(&app.edit_z, fmt.tprintf("%.4f", position[2]))
	set_buffer(&app.edit_species, e.symbol)
}

commit_position :: proc(app: ^App, primary: i32) {
	cart: model.CartVec3
	okx, oky, okz: bool
	cart[0], okx = strconv.parse_f32(string(app.edit_x[:len(app.edit_x) - 1]))
	cart[1], oky = strconv.parse_f32(string(app.edit_y[:len(app.edit_y) - 1]))
	cart[2], okz = strconv.parse_f32(string(app.edit_z[:len(app.edit_z) - 1]))
	if !(okx && oky && okz) {
		return
	}
	if frac, ok := model.fractional(app.mol.lattice, cart); ok {
		model.set_atom_position(&app.mol, model.AtomIndex(primary), frac)
	}
}

commit_species :: proc(app: ^App, primary: i32) {
	symbol := strings.to_lower(string(app.edit_species[:len(app.edit_species) - 1]))
	if _, n := model.lookup_by_symbol(symbol); n != 0 {
		model.set_atom_species(&app.mol, model.AtomIndex(primary), n)
	}
}

delete_selected :: proc(app: ^App) {
	for i := len(app.selection) - 1; i >= 0; i -= 1 {
		model.remove_atom(&app.mol, app.selection[i])
	}
	clear(&app.selection)
	app.last_edited = -1
}

draw_edit_panel :: proc(app: ^App) {
	if len(app.selection) == 0 {
		app.last_edited = -1
		return
	}

	primary := i32(app.selection[0])
	if app.last_edited != primary {
		refill_edit_buffers(app, primary)
		app.last_edited = primary
	}

	if !ui.begin_floating_panel(&app.frame, &app.edit_rect, "Atom") {
		return
	}
	defer ui.end_floating_panel(&app.frame)

	content := draw.Rect {
		app.edit_rect.x,
		app.edit_rect.y + app.frame.theme.title_height,
		app.edit_rect.w,
		app.edit_rect.h - app.frame.theme.title_height,
	}
	layout := ui.make_layout(&app.frame, content)

	if ui.text_input(&app.frame, ui.below(&layout, 32), &app.edit_x) ||
	   ui.text_input(&app.frame, ui.below(&layout, 32), &app.edit_y) ||
	   ui.text_input(&app.frame, ui.below(&layout, 32), &app.edit_z) {
		commit_position(app, primary)
	}
	if ui.text_input(&app.frame, ui.below(&layout, 32), &app.edit_species) {
		commit_species(app, primary)
	}
	if ui.button(&app.frame, ui.below(&layout, 36), "Delete") {
		delete_selected(app)
	}
}

main :: proc() {
	window := backend.init(1280, 800, "Molma")
	defer backend.shutdown(&window)

	app: App
	app.edit_rect = draw.Rect{980, 40, 260, 300}
	app.last_edited = -1
	app.edit_x = make([dynamic]u8)
	app.edit_y = make([dynamic]u8)
	app.edit_z = make([dynamic]u8)
	app.edit_species = make([dynamic]u8)
	append(&app.edit_x, 0)
	append(&app.edit_y, 0)
	append(&app.edit_z, 0)
	append(&app.edit_species, 0)
	defer delete(app.edit_x)
	defer delete(app.edit_y)
	defer delete(app.edit_z)
	defer delete(app.edit_species)

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

		commands := make([dynamic]draw.DrawCommand, context.temp_allocator)
		ui.begin_frame(&app.frame, &commands, window.input)
		draw_edit_panel(&app)

		if !app.frame.ui_hover {
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
		}

		render.draw(&app.renderer, &app.view, &app.mol, app.hover, app.selection[:])

		backend.execute_commands(&window, commands[:])
		backend.end_frame(&window)

		free_all(context.temp_allocator)
	}
}
