// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package main

import "core:fmt"
import "core:log"
import "core:math"
import "core:path/slashpath"
import "core:strconv"
import "core:strings"
import "model"
import nfd "nativefiledialog-odin"
import "poscar"
import rl "vendor:raylib"

WINDOW_HEIGHT :: 600
WINDOW_WIDTH :: 800

GIZMO_SIZE :: 40.0
GIZMO_MARGIN :: 50.0
X_COLOR :: rl.RED
Y_COLOR :: rl.GREEN
Z_COLOR :: rl.BLUE
RADIUS_PCT :: 0.6
BOND_RADIUS_PCT :: 0.3

Mode :: enum {
	NONE,
	ROTATE,
	SELECT,
	ADD,
	DELETE,
}

hover_color :: rl.Color{244, 244, 10, 50}
select_for_edit_color :: rl.Color{30, 244, 30, 50}
select_for_delete_color :: rl.Color{255, 30, 10, 50}

Select :: struct {
	// temporary buffers to read in user defined atom positions
	x_pos:               [8]u8,
	y_pos:               [8]u8,
	z_pos:               [8]u8,
	atom_symbol:         [3]u8,

	// trackers for the ui elements
	x_pos_updated:       bool,
	y_pos_updated:       bool,
	z_pos_updated:       bool,
	atom_symbol_updated: bool,

	// ui settings
	font_size:           i32,
	ui_rect_w:           i32,
	ui_rect_h:           i32,
	ui_rect_x:           i32,
	ui_rect_y:           i32,

	// note(aelobdog): Not sure if this is better than just making a dynamic
	//                 array for this. Might be something to look into.
	selected_atoms:      [dynamic]model.AtomIndex,
}

Rotate :: struct {
	pitch:             f32,
	yaw:               f32,
	roll:              f32,
	molecule_rotation: rl.Quaternion,
}

State :: struct {
	font:                      rl.Font,
	mode:                      Mode,
	select:                    Select,
	rotate:                    Rotate,
	hovering_over_sphere:      i32,
	potentially_delete_sphere: i32,
	toolbar:                   toolbar,
	mol:                       model.Molecule,
	synced_version:            u64,
	lattice_normalized:        [3]rl.Vector3,
	origin:                    rl.Vector3,
	max_distance:              f32,
	aspect_ratio:              f32,
	camera_original_position:  rl.Vector3,
	camera:                    rl.Camera3D,
	window_size:               [2]i32,
	button_states:             [MAX_BUTTON_STATES]bool,
	unique_atom_locations:     [dynamic]i32,
	atom_transformation_list:  [dynamic][]rl.Matrix,
	bond_transformation_list:  [dynamic]rl.Matrix,
}

quaternion_from_xyzw :: proc(x, y, z, w: f32) -> rl.Quaternion {
	q: rl.Quaternion
	q.x = x
	q.y = y
	q.z = z
	q.w = w
	return q
}

ui_font_size :: 32
ui_font_spacing :: 2
ui_padding :: 3

init_state :: proc(state: ^State) {
	measure_text := rl.MeasureTextEx(state.font, "-0.000000", ui_font_size, ui_font_spacing)
	state.mode = .NONE
	state.hovering_over_sphere = -1
	state.potentially_delete_sphere = -1
	state.select = Select {
		x_pos               = 0,
		y_pos               = 0,
		z_pos               = 0,
		atom_symbol         = 0,
		x_pos_updated       = false,
		y_pos_updated       = false,
		z_pos_updated       = false,
		atom_symbol_updated = false,
		font_size           = ui_font_size,
		ui_rect_w           = 2 * ui_padding + i32(math.ceil(measure_text.x)),
		ui_rect_h           = i32(math.ceil(measure_text.y)),
		ui_rect_x           = 0,
		ui_rect_y           = 0,
		selected_atoms      = make([dynamic]model.AtomIndex),
	}
	state.rotate = Rotate {
		pitch             = 0,
		yaw               = 0,
		roll              = 0,
		molecule_rotation = quaternion_from_xyzw(0, 0, 0, 1),
	}
	state.window_size = [2]i32{rl.GetScreenWidth(), rl.GetScreenHeight()}
	state.toolbar = toolbar_create()
	state.button_states = false
	state.synced_version = 0
	state.atom_transformation_list = make([dynamic][]rl.Matrix)
	state.bond_transformation_list = make([dynamic]rl.Matrix)
}

change_mode_to :: proc(state: ^State, mode: Mode) {
	switch state.mode {
	case .NONE:
	case .SELECT:
	case .ROTATE:
	case .ADD:
	case .DELETE:
	}

	state.mode = mode
}

selection_list_process_atom :: proc(id: i32, state: ^State) {
	location := -1

	for v, k in state.select.selected_atoms {
		if v == model.AtomIndex(id) {
			location = k
			break
		}
	}

	if location >= 0 {
		ordered_remove(&state.select.selected_atoms, location)
	} else {
		append(&state.select.selected_atoms, model.AtomIndex(id))
	}
}

cleanup_state :: proc(state: ^State) {
	delete(state.select.selected_atoms)
	delete(state.unique_atom_locations)
	for group in state.atom_transformation_list {
		delete(group)
	}
	delete(state.atom_transformation_list)
	delete(state.bond_transformation_list)
	delete(state.toolbar.items)
	delete(state.mol.atoms)
}

main :: proc() {
	rl.SetTraceLogLevel(.WARNING)
	context.logger = log.create_console_logger()
	rl.SetConfigFlags({rl.ConfigFlag.WINDOW_RESIZABLE, rl.ConfigFlag.WINDOW_ALWAYS_RUN})

	open_path: cstring
	save_path: cstring
	nfd.Init()
	defer nfd.Quit()

	rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Molma v0.1")
	defer rl.CloseWindow()

	state: State
	executable_dir := string(rl.GetApplicationDirectory())
	font_path := slashpath.join(
		{executable_dir, "fonts", "JetBrainsMono-2.304", "JetBrainsMono-Regular.ttf"},
	)
	state.font = rl.LoadFont(strings.clone_to_cstring(font_path))
	defer rl.UnloadFont(state.font)

	init_state(&state)
	defer cleanup_state(&state)

	rl.GuiSetFont(state.font)
	rl.GuiSetStyle(.DEFAULT, i32(rl.GuiDefaultProperty.TEXT_SIZE), 32)
	rl.SetTargetFPS(60)

	sphere_mesh := rl.GenMeshSphere(1, 32, 32)
	defer rl.UnloadMesh(sphere_mesh)

	cylinder_mesh := rl.GenMeshCylinder(1, 1, 32)
	defer rl.UnloadMesh(cylinder_mesh)

	vs := cstring(#load("shaders/lighting_instancing.vs"))
	fs := cstring(#load("shaders/lighting.fs"))
	shader := rl.LoadShaderFromMemory(vs, fs)
	defer rl.UnloadShader(shader)

	shader.locs[rl.ShaderLocationIndex.MATRIX_MVP] = rl.GetShaderLocation(shader, "mvp")
	shader.locs[rl.ShaderLocationIndex.VECTOR_VIEW] = rl.GetShaderLocation(shader, "viewPos")
	shader.locs[rl.ShaderLocationIndex.MATRIX_MODEL] = rl.GetShaderLocationAttrib(
		shader,
		"instanceTransform",
	)
	ambient_loc := rl.GetShaderLocation(shader, "ambient")
	ambient_value := [4]f32{0.2, 0.2, 0.2, 1.0}
	rl.SetShaderValue(shader, ambient_loc, &ambient_value, .VEC4)
	create_light(.DIRECTIONAL, rl.Vector3{50.0, 50.0, 0.0}, rl.Vector3{}, rl.WHITE, shader)

	init_materials(shader)

	bond_material := rl.LoadMaterialDefault()
	bond_material.shader = shader
	bond_material.maps[rl.MaterialMapIndex.ALBEDO].color = rl.LIGHTGRAY

	for !rl.WindowShouldClose() {

		state.window_size.x = rl.GetScreenWidth()
		state.window_size.y = rl.GetScreenHeight()

		if rl.IsFileDropped() {
			dropped_files := rl.LoadDroppedFiles()
			defer rl.UnloadDroppedFiles(dropped_files)

			dropped_file := dropped_files.paths[dropped_files.count - 1]
			if mol, ok := poscar.parse(string(dropped_file)); ok {
				load_molecule(&state, mol)
			} else {
				fmt.println("WARNING: Unable to parse dropped file's data")
			}
		}
		winw := rl.GetScreenWidth()
		winh := rl.GetScreenHeight()
		state.select.ui_rect_x = winw - (state.select.ui_rect_w + ui_padding)
		state.select.ui_rect_y = ui_padding

		ZOOM_SCALE :: 5.0
		zoom := rl.GetMouseWheelMove()
		fovy := state.camera.fovy
		fovy -= (zoom * ZOOM_SCALE)
		fovy = clamp(fovy, 1.0, 1000.0)
		state.camera.fovy = rl.Lerp(state.camera.fovy, fovy, 0.15)

		rot_matrix := rl.QuaternionToMatrix(state.rotate.molecule_rotation)

		switch (state.mode) {
		case .ROTATE:
			{
				if rl.IsMouseButtonDown(.LEFT) {
					SENSITIVITY :: 0.005
					delta := rl.GetMouseDelta()
					forward := rl.Vector3Normalize(state.camera.target - state.camera.position)
					right := rl.Vector3Normalize(rl.Vector3CrossProduct(forward, state.camera.up))
					up := rl.Vector3Normalize(rl.Vector3CrossProduct(right, forward))
					q_pitch := rl.QuaternionFromAxisAngle(right, -delta.y * SENSITIVITY)
					q_yaw := rl.QuaternionFromAxisAngle(up, -delta.x * SENSITIVITY)
					state.rotate.molecule_rotation =
						q_pitch * q_yaw * state.rotate.molecule_rotation
					state.rotate.molecule_rotation = rl.QuaternionNormalize(
						state.rotate.molecule_rotation,
					)
				}

			}
		case .SELECT:
			{
				state.hovering_over_sphere = -1

				ray := rl.GetScreenToWorldRay(rl.GetMousePosition(), state.camera)
				for atom, i in state.mol.atoms {
					e, _ := model.lookup_by_number(atom.atomic_number)
					collision := rl.GetRayCollisionSphere(
						ray,
						atom_cartesian(&state, i),
						e.cov_radius_ang * RADIUS_PCT,
					)
					if collision.hit {
						state.hovering_over_sphere = i32(i)
					}
				}

				if rl.IsMouseButtonPressed(.LEFT) {
					if state.hovering_over_sphere >= 0 {
						mouse_position := rl.GetMousePosition()

						ui_box_rect := rl.Rectangle {
							f32(state.select.ui_rect_x),
							f32(state.select.ui_rect_y),
							f32(ui_padding + state.select.ui_rect_w),
							f32(4 * (ui_padding + state.select.ui_rect_h)),
						}

						if !rl.CheckCollisionPointRec(mouse_position, ui_box_rect) {
							selection_list_process_atom(state.hovering_over_sphere, &state)
						}
					}
				}
			}
		case .ADD: // do nothing
		case .DELETE:
			{
				state.potentially_delete_sphere = -1

				ray := rl.GetScreenToWorldRay(rl.GetMousePosition(), state.camera)
				for atom, i in state.mol.atoms {
					e, _ := model.lookup_by_number(atom.atomic_number)
					collision := rl.GetRayCollisionSphere(
						ray,
						atom_cartesian(&state, i),
						e.cov_radius_ang * RADIUS_PCT,
					)
					if collision.hit {
						state.potentially_delete_sphere = i32(i)
					}
				}

				if rl.IsMouseButtonPressed(.LEFT) {
					if state.potentially_delete_sphere != -1 {
						model.remove_atom(
							&state.mol,
							model.AtomIndex(state.potentially_delete_sphere),
						)
						state.potentially_delete_sphere = -1
					}
				}
			}
		case .NONE: // do nothing
		}

		offset := rl.Vector3Transform(state.camera_original_position, rot_matrix)
		state.camera.position = state.origin + offset
		state.camera.up = rl.Vector3Transform({0, 1, 0}, rot_matrix)
		state.camera.target = state.origin

		camera_pos := [3]f32 {
			state.camera.position.x,
			state.camera.position.y,
			state.camera.position.z,
		}
		rl.SetShaderValue(
			shader,
			shader.locs[rl.ShaderLocationIndex.VECTOR_VIEW],
			&camera_pos,
			.VEC3,
		)

		ensure_synced(&state)

		rl.BeginDrawing(); defer rl.EndDrawing()

		rl.ClearBackground(rl.GetColor(0x444444ff))
		rl.DrawFPS(10, 30)

		rl.BeginMode3D(state.camera)

		draw_lattice(state.mol.lattice)

		if state.button_states[toolbar_button_states.ButtonRenderBonds] {
			draw_bonds(&state, cylinder_mesh, bond_material)
		}

		if len(state.mol.atoms) > 0 {
			draw_atoms(
				state.unique_atom_locations[:],
				state.mol.atoms[:],
				sphere_mesh,
				state.atom_transformation_list[:],
			)
		}

		if state.mode == .SELECT {
			if state.hovering_over_sphere != -1 {
				draw_highlighted_atom(
					&state,
					model.AtomIndex(state.hovering_over_sphere),
					hover_color,
				)
			}

			for k in state.select.selected_atoms {
				draw_highlighted_atom(&state, k, select_for_edit_color)
			}
		} else if state.mode == .DELETE {
			if state.potentially_delete_sphere != -1 {
				draw_highlighted_atom(
					&state,
					model.AtomIndex(state.potentially_delete_sphere),
					select_for_delete_color,
				)
			}
		}

		rl.EndMode3D()

		draw_gizmo(state.lattice_normalized, state.rotate.molecule_rotation)

		toolbar_y := (f32(state.window_size.y) - state.toolbar.height) / 2.0
		toolbar_draw(&state, toolbar_padding, toolbar_y)
		toolbar_draw_active_buttons(&state, toolbar_padding, toolbar_y)

		if state.mode == .SELECT {
			draw_edit_ui(&state)
		}

		free_all(context.temp_allocator)
	}
}

ensure_synced :: proc(state: ^State) {
	if state.synced_version == state.mol.version {
		return
	}
	rebuild_species_groups(state)
	rebuild_atom_instances(state)
	rebuild_bonds(state)
	state.synced_version = state.mol.version
}

rebuild_species_groups :: proc(state: ^State) {
	clear(&state.unique_atom_locations)
	if len(state.mol.atoms) == 0 {
		return
	}
	append(&state.unique_atom_locations, 0)
	last := state.mol.atoms[0].atomic_number
	for atom, i in state.mol.atoms[1:] {
		if atom.atomic_number != last {
			append(&state.unique_atom_locations, i32(i + 1))
			last = atom.atomic_number
		}
	}
}

count_in_group :: proc(state: ^State, group_index: int) -> int {
	start := state.unique_atom_locations[group_index]
	if group_index + 1 < len(state.unique_atom_locations) {
		return int(state.unique_atom_locations[group_index + 1] - start)
	}
	return len(state.mol.atoms) - int(start)
}

vec3_to_rl :: proc(v: model.CartVec3) -> rl.Vector3 {
	return rl.Vector3{v[0], v[1], v[2]}
}

atom_cartesian :: proc(state: ^State, index: int) -> rl.Vector3 {
	return vec3_to_rl(model.cartesian(state.mol.lattice, state.mol.atoms[index].position))
}

rebuild_atom_instances :: proc(state: ^State) {
	for group in state.atom_transformation_list {
		delete(group)
	}
	clear(&state.atom_transformation_list)
	resize(&state.atom_transformation_list, len(state.unique_atom_locations))

	for i in 0 ..< len(state.unique_atom_locations) {
		start := int(state.unique_atom_locations[i])
		count := count_in_group(state, i)
		group := make([]rl.Matrix, count)
		for j in 0 ..< count {
			atom := state.mol.atoms[start + j]
			position := atom_cartesian(state, start + j)
			e, _ := model.lookup_by_number(atom.atomic_number)
			radius := e.cov_radius_ang * RADIUS_PCT
			scale := rl.MatrixScale(radius, radius, radius)
			translation := rl.MatrixTranslate(position.x, position.y, position.z)
			group[j] = translation * scale
		}
		state.atom_transformation_list[i] = group
	}
}

rebuild_bonds :: proc(state: ^State) {
	clear(&state.bond_transformation_list)

	bonds := model.compute_bonds(state.mol.atoms[:], state.mol.lattice)
	defer delete(bonds)

	rad := f32(0.1)
	up := rl.Vector3{0, 1, 0}
	for bond in bonds {
		p1 := atom_cartesian(state, int(bond.a))
		shift := model.FracVec3{f32(bond.shift[0]), f32(bond.shift[1]), f32(bond.shift[2])}
		p2 := vec3_to_rl(model.cartesian(state.mol.lattice, state.mol.atoms[bond.b].position + shift))

		delta := p2 - p1
		distance := rl.Vector3Distance(p2, p1)
		if distance < 0.001 {
			continue
		}
		dir := rl.Vector3Normalize(delta)

		scale := rl.MatrixScale(rad, distance, rad)
		rotation := rl.QuaternionToMatrix(rl.QuaternionFromVector3ToVector3(up, dir))
		translation := rl.MatrixTranslate(p1.x, p1.y, p1.z)

		append(&state.bond_transformation_list, translation * rotation * scale)
	}
}

load_molecule :: proc(state: ^State, mol: model.Molecule) {
	delete(state.mol.atoms)
	state.mol = mol
	reframe_camera(state)
	rebuild_species_groups(state)
	rebuild_atom_instances(state)
	rebuild_bonds(state)
	state.synced_version = state.mol.version
}

reframe_camera :: proc(state: ^State) {
	n := len(state.mol.atoms)
	if n == 0 {
		state.origin = rl.Vector3{0, 0, 0}
		state.max_distance = 1.0
	} else {
		sum: rl.Vector3
		for atom in state.mol.atoms {
			sum += vec3_to_rl(model.cartesian(state.mol.lattice, atom.position))
		}
		state.origin = sum / f32(n)

		max_distance := f32(0)
		for atom in state.mol.atoms {
			position := vec3_to_rl(model.cartesian(state.mol.lattice, atom.position))
			e, _ := model.lookup_by_number(atom.atomic_number)
			distance := rl.Vector3Distance(position, state.origin) + e.cov_radius_ang
			max_distance = max(max_distance, distance)
		}
		state.max_distance = max_distance
	}

	state.aspect_ratio = f32(rl.GetScreenWidth()) / f32(rl.GetScreenHeight())

	vertical_size := 5 * state.max_distance
	required_fovy_from_width := vertical_size / state.aspect_ratio

	state.camera_original_position = rl.Vector3{0, 0, 5 * state.max_distance}
	state.camera = rl.Camera3D {
		position   = state.origin + state.camera_original_position,
		target     = state.origin,
		up         = rl.Vector3{0.0, 1.0, 0.0},
		fovy       = max(vertical_size, required_fovy_from_width),
		projection = rl.CameraProjection.ORTHOGRAPHIC,
	}

	state.lattice_normalized = [3]rl.Vector3 {
		rl.Vector3Normalize(vec3_to_rl(state.mol.lattice.a)),
		rl.Vector3Normalize(vec3_to_rl(state.mol.lattice.b)),
		rl.Vector3Normalize(vec3_to_rl(state.mol.lattice.c)),
	}
}

draw_bonds :: proc(state: ^State, cylinder: rl.Mesh, material: rl.Material) {
	rl.DrawMeshInstanced(
		cylinder,
		material,
		raw_data(state.bond_transformation_list),
		i32(len(state.bond_transformation_list)),
	)
}

draw_lattice :: proc(lattice: model.Lattice) {
	a := vec3_to_rl(lattice.a)
	b := vec3_to_rl(lattice.b)
	c := vec3_to_rl(lattice.c)
	_1 := a + b
	_2 := a + c
	_3 := b + c
	_4 := a + b + c
	o := rl.Vector3{0, 0, 0}

	rl.DrawLine3D(o, a, rl.GREEN)
	rl.DrawLine3D(o, b, rl.GREEN)
	rl.DrawLine3D(o, c, rl.GREEN)

	rl.DrawLine3D(b, _1, rl.GREEN)
	rl.DrawLine3D(_1, a, rl.GREEN)
	rl.DrawLine3D(c, _2, rl.GREEN)
	rl.DrawLine3D(_2, a, rl.GREEN)
	rl.DrawLine3D(b, _3, rl.GREEN)
	rl.DrawLine3D(_3, c, rl.GREEN)

	rl.DrawLine3D(_1, _4, rl.GREEN)
	rl.DrawLine3D(_2, _4, rl.GREEN)
	rl.DrawLine3D(_3, _4, rl.GREEN)
}

draw_atoms :: proc(
	unique_atom_locations: []i32,
	atoms: []model.Atom,
	sphere: rl.Mesh,
	transformation_list: [][]rl.Matrix,
) {
	for i in 0 ..< len(unique_atom_locations) {
		material := periodic_table[atoms[unique_atom_locations[i]].atomic_number].material
		rl.DrawMeshInstanced(
			sphere,
			material,
			raw_data(transformation_list[i]),
			i32(len(transformation_list[i])),
		)
	}
}

draw_highlighted_atom :: proc(state: ^State, id: model.AtomIndex, color: rl.Color) {
	atom := state.mol.atoms[id]
	e, _ := model.lookup_by_number(atom.atomic_number)
	rl.DrawSphere(atom_cartesian(state, int(id)), e.cov_radius_ang * RADIUS_PCT * 1.03, color)
}

draw_gizmo :: proc(lattice: [3]rl.Vector3, rotation_quaternion: rl.Quaternion) {
	gizmo_center := rl.Vector2{GIZMO_MARGIN, f32(rl.GetScreenHeight()) - GIZMO_MARGIN}

	rot_mat := rl.QuaternionToMatrix(rotation_quaternion)
	colors := [3]rl.Color{X_COLOR, Y_COLOR, Z_COLOR}
	labels := [3]string{"X", "Y", "Z"}

	for i in 0 ..< 3 {
		rotated_axis := rl.Vector3Transform(lattice[i], rot_mat)
		end_point := gizmo_center + rl.Vector2{rotated_axis.x, -rotated_axis.y} * GIZMO_SIZE
		rl.DrawLineEx(gizmo_center, end_point, 3.0, colors[i])
		label_cstr := rl.TextFormat("%s", labels[i])
		rl.DrawText(label_cstr, i32(end_point.x + 5), i32(end_point.y - 5), 10, colors[i])
	}
}

parse_edit_position :: proc(state: ^State) -> (model.FracVec3, bool) {
	cart: model.CartVec3
	okx, oky, okz: bool
	cart[0], okx = strconv.parse_f32(string(cstring(&state.select.x_pos[0])))
	cart[1], oky = strconv.parse_f32(string(cstring(&state.select.y_pos[0])))
	cart[2], okz = strconv.parse_f32(string(cstring(&state.select.z_pos[0])))
	if !(okx && oky && okz) {
		return model.FracVec3{}, false
	}
	return model.fractional(state.mol.lattice, cart)
}

commit_position :: proc(state: ^State, key: model.AtomIndex) {
	if frac, ok := parse_edit_position(state); ok {
		model.set_atom_position(&state.mol, key, frac)
	}
}

draw_edit_ui :: proc(state: ^State) {
	if len(state.select.selected_atoms) == 1 {
		key: model.AtomIndex
		for k in state.select.selected_atoms {
			key = k
			break
		}

		edit_atom := state.mol.atoms[key]
		edit_pos := model.cartesian(state.mol.lattice, edit_atom.position)
		e, _ := model.lookup_by_number(edit_atom.atomic_number)

		state.select.x_pos = 0
		state.select.y_pos = 0
		state.select.z_pos = 0
		state.select.atom_symbol = 0

		fmt.bprintf(state.select.x_pos[:], "%.6f", edit_pos[0])
		fmt.bprintf(state.select.y_pos[:], "%.6f", edit_pos[1])
		fmt.bprintf(state.select.z_pos[:], "%.6f", edit_pos[2])
		fmt.bprintf(state.select.atom_symbol[:], "%s", e.symbol)

		y1 := state.select.ui_rect_y
		height := state.select.ui_rect_h
		y2 := y1 + (ui_padding + height)
		y3 := y2 + (ui_padding + height)
		y4 := y3 + (ui_padding + height)

		tb1 := rl.GuiTextBox(
			rl.Rectangle {
				f32(state.select.ui_rect_x),
				f32(y1),
				f32(state.select.ui_rect_w),
				f32(state.select.ui_rect_h),
			},
			cstring(&state.select.x_pos[0]),
			32,
			state.select.x_pos_updated,
		)

		tb2 := rl.GuiTextBox(
			rl.Rectangle {
				f32(state.select.ui_rect_x),
				f32(y2),
				f32(state.select.ui_rect_w),
				f32(state.select.ui_rect_h),
			},
			cstring(&state.select.y_pos[0]),
			32,
			state.select.y_pos_updated,
		)

		tb3 := rl.GuiTextBox(
			rl.Rectangle {
				f32(state.select.ui_rect_x),
				f32(y3),
				f32(state.select.ui_rect_w),
				f32(state.select.ui_rect_h),
			},
			cstring(&state.select.z_pos[0]),
			32,
			state.select.z_pos_updated,
		)

		tb4 := rl.GuiTextBox(
			rl.Rectangle {
				f32(state.select.ui_rect_x),
				f32(y4),
				f32(state.select.ui_rect_w),
				f32(state.select.ui_rect_h),
			},
			cstring(&state.select.atom_symbol[0]),
			32,
			state.select.atom_symbol_updated,
		)

		if tb1 {
			state.select.x_pos_updated = !state.select.x_pos_updated
			commit_position(state, key)
		}
		if tb2 {
			state.select.y_pos_updated = !state.select.y_pos_updated
			commit_position(state, key)
		}
		if tb3 {
			state.select.z_pos_updated = !state.select.z_pos_updated
			commit_position(state, key)
		}
		if tb4 {
			state.select.atom_symbol_updated = !state.select.atom_symbol_updated
			symbol := strings.to_lower(string(cstring(&state.select.atom_symbol[0])))
			if _, atomic_number := model.lookup_by_symbol(symbol); atomic_number != 0 {
				model.set_atom_species(&state.mol, key, atomic_number)
			}
		}
	}
}
