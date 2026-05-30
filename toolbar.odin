// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package main

import "core:fmt"
import nfd "nativefiledialog-odin"
import rl "vendor:raylib"

MAX_BUTTON_STATES :: 5
highlight_color :: rl.Color{215, 124, 46, 150}

// note(aelobdog): The whole "-ve numbers for non-sticky buttons, and +ve numbers for
//                 sticky buttons" felt smart in the beginning. now it just feel stupid.
//                 REFACTOR THIS !

toolbar_button_states :: enum i8 {
	ButtonAdd         = -3,
	FileOpen          = -2,
	FileSave          = -1,
	ButtonRotate      = 0,
	ButtonSelect      = 1,
	ButtonDelete      = 3,
	ButtonRenderBonds = 4,
}

toolbar_item :: struct {
	is_stateful: b32,
	id:          toolbar_button_states,
	icon_name:   rl.GuiIconName,
}

toolbar :: struct {
	width:    f32,
	height:   f32,
	padding:  f32,
	columns:  i32,
	item_dim: f32,
	items:    [dynamic]toolbar_item,
}

toolbar_padding :: 2
toolbar_item_dim :: 32
toolbar_width :: 2 * toolbar_padding + toolbar_item_dim

toolbar_create :: proc() -> toolbar {
	tb := toolbar {
		width    = toolbar_width,
		padding  = toolbar_padding,
		columns  = 1,
		item_dim = toolbar_item_dim,
		items    = make([dynamic]toolbar_item),
	}
	append(
		&(tb.items),
		toolbar_item{is_stateful = false, id = .FileOpen, icon_name = .ICON_FILE_ADD},
	)
	append(
		&(tb.items),
		toolbar_item{is_stateful = false, id = .FileSave, icon_name = .ICON_FILE_SAVE_CLASSIC},
	)
	append(
		&(tb.items),
		toolbar_item{is_stateful = true, id = .ButtonRotate, icon_name = .ICON_RESTART},
	)
	append(
		&(tb.items),
		toolbar_item{is_stateful = true, id = .ButtonSelect, icon_name = .ICON_CURSOR_POINTER},
	)
	append(
		&(tb.items),
		toolbar_item{is_stateful = false, id = .ButtonAdd, icon_name = .ICON_TARGET_SMALL_FILL},
	)
	append(
		&(tb.items),
		toolbar_item{is_stateful = true, id = .ButtonDelete, icon_name = .ICON_CROSS},
	)
	append(
		&(tb.items),
		toolbar_item {
			is_stateful = true,
			id = .ButtonRenderBonds,
			icon_name = .ICON_TARGET_MOVE_FILL,
		},
	)
	tb.height = f32(len(tb.items) * (2 * toolbar_padding + toolbar_item_dim))
	return tb
}

toolbar_draw :: proc(state: ^State, x, y: f32) {
	rl.DrawRectangle(
		i32(x),
		i32(y),
		i32(state.toolbar.width),
		i32(state.toolbar.height),
		rl.Color{0, 0, 0, 100},
	)

	for item, index in state.toolbar.items {
		offset := i32(index * (2 * toolbar_padding + toolbar_item_dim))

		rect := rl.Rectangle {
			f32(x + toolbar_padding),
			y + f32(toolbar_padding + offset),
			toolbar_item_dim,
			toolbar_item_dim,
		}

		if item.is_stateful {
			if rl.GuiButton(rect, rl.GuiIconText(item.icon_name, "")) {
				switch item.id {
				case .ButtonRotate:
					{
						if state.button_states[item.id] == true {
							state.button_states[item.id] = false
							change_mode_to(state, .NONE)
						} else {
							state.button_states[item.id] = true
							change_mode_to(state, .ROTATE)
						}
					}
				case .ButtonSelect:
					{
						if state.button_states[item.id] == true {
							state.button_states[item.id] = false
							state.select.last_selected = -1
							state.select.curr_selected = -1
							state.hovering_over_sphere = -1
							change_mode_to(state, .NONE)
						} else {
							state.button_states[item.id] = true
							change_mode_to(state, .SELECT)
						}
					}
				case .ButtonAdd: // do nothing
				case .ButtonRenderBonds:
					{
						state.button_states[item.id] = !state.button_states[item.id]
					}
				case .ButtonDelete:
					{
						if state.button_states[item.id] == true {
							state.button_states[item.id] = false
							change_mode_to(state, .NONE)
						} else {
							state.button_states[item.id] = true
							change_mode_to(state, .DELETE)
						}
					}
				case .FileOpen: // do nothing
				case .FileSave: // do nothing
				}
			}
		} else {
			if rl.GuiButton(rect, rl.GuiIconText(item.icon_name, "")) {
				switch item.id {
				case .FileSave:
					{
						savepath: cstring
						result := nfd.SaveDialogU8(&savepath, nil, 0, nil, nil)
						switch result {
						case .Okay:
							{
								_ = poscar_write(string(savepath), state.poscar)
								nfd.FreePathU8(savepath)
							}
						case .Cancel: // note(aelobdog): handle with UI message
						case .Error: // note(aelobdog): handle with UI message
						}
						populate_bonds(&state.bonds, state.poscar.atoms[:])
					}
				case .FileOpen:
					{
						openpath: cstring
						result := nfd.OpenDialogU8(&openpath, nil, 0, nil)
						switch result {
						case .Okay:
							{
								poscar_opened, poscar_dropped_ok := poscar_parse(string(openpath))
								if !poscar_dropped_ok {
									fmt.println("WARNING: Unable to parse opened file's data")
								} else {
									if state.poscar.atoms != nil do delete(state.poscar.atoms)
									if state.bonds != nil do delete(state.bonds)
									load_poscar_data_and_refresh(state, poscar_opened)
								}
								nfd.FreePathU8(openpath)
							}
						case .Cancel: // note(aelobdog): handle with UI message
						case .Error:
							fmt.println(nfd.GetError()) // note(aelobdog): handle with UI message
						}
					}
				case .ButtonAdd:
					{
						unknown_element, unknown_atomic_number := periodic_table_lookup_by_symbol(
							"x",
						)
						append(
							&(state.poscar.atoms),
							Atom {
								atomic_number = unknown_atomic_number,
								radius = unknown_element.cov_radius_ang,
								symbol = unknown_element.symbol,
								position = {-5, -5, -5, 1.0},
							},
						)
					}
				case .ButtonDelete: // do nothing
				case .ButtonRotate: // do nothing
				case .ButtonSelect: // do nothing
				case .ButtonRenderBonds: // do nothing
				}
			}
		}
	}

	for item, index in state.toolbar.items {
		if item.is_stateful {
			offset := i32(index * (2 * toolbar_padding + toolbar_item_dim))
			rect := rl.Rectangle {
				f32(x + toolbar_padding),
				y + f32(toolbar_padding + offset),
				toolbar_item_dim,
				toolbar_item_dim,
			}
			// note(aelobdog): not sure how to correctly highlight a button if
			// its state is "active", so I'm defaulting to just drawing a semi-
			// tranparent overlay on top of the button
			if state.button_states[item.id] == true {
				rl.DrawRectangleRec(rect, highlight_color)
			}
		}
	}

}
