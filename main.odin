// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

#+feature dynamic-literals

package main

import "core:log"
import "core:math"
import "core:fmt"
import "core:strconv"
import rl "vendor:raylib"

WINDOW_HEIGHT :: 600
WINDOW_WIDTH :: 800

Atom :: struct {
    atomic_number : i32,
    radius        : f32,
    symbol        : string,
    position      : rl.Vector4,
    is_a_ghost    : bool,
}

BondData :: struct {
    destination : int,
    length      : f32,
}

Lattice :: [3]rl.Vector3
Bonds   :: map[int][dynamic]BondData

Lattice_extras :: struct {
    bxc: rl.Vector3,
    cxa: rl.Vector3,
    axb: rl.Vector3,
    V  : f32,
}

GIZMO_SIZE      :: 40.0
GIZMO_MARGIN    :: 50.0
X_COLOR         :: rl.RED
Y_COLOR         :: rl.GREEN
Z_COLOR         :: rl.BLUE
RADIUS_PCT      :: 0.6
BOND_RADIUS_PCT :: 0.3

Mode :: enum {
    NONE,
    ROTATE,
    SELECT,
}

Select :: struct {
    last_selected : i32,
    curr_selected : i32,
    xpos          : [32]u8,
    ypos          : [32]u8,
    zpos          : [32]u8,
    font_size     : i32,
    ui_rect_1tb_w : i32,
    ui_rect_1tb_h : i32,
    ui_edit_mode  : [3]bool,
    edit_ui_x     : i32,
    edit_ui_y     : i32,
}

Rotate :: struct {
    pitch             : f32,
    yaw               : f32,
    roll              : f32,
    molecule_rotation : rl.Quaternion,
    ui_is_rotate      : bool,
}

State :: struct {
    mode                 : Mode,
    select               : Select,
    rotate               : Rotate,
    hovering_over_sphere : i32,

    // note: expand this?
    //   - add camera to remember last camara state?
}

quaternion_from_xyzw :: proc (x, y, z, w : f32) -> rl.Quaternion {
    q : rl.Quaternion
    q.x = x
    q.y = y
    q.z = z
    q.w = w
    return q
}

ui_font_size    :: 32
ui_font_spacing :: 2
ui_padding      :: 3
eps             :: 1e-3

init_state :: proc(font: rl.Font) -> State {
    measure_text := rl.MeasureTextEx(font, "-0.000000", ui_font_size, ui_font_spacing)
    return State {
        mode = .NONE,
        hovering_over_sphere = -1,
        select = Select {
            last_selected = -1,
            curr_selected = -1,
            xpos = 0,
            ypos = 0,
            zpos = 0,
            font_size = ui_font_size,
            ui_rect_1tb_w = 2 * ui_padding + i32(math.ceil(measure_text.x)),
            ui_rect_1tb_h = i32(math.ceil(measure_text.y)),
            ui_edit_mode = false,
        },
        rotate = Rotate {
            pitch = 0,
            yaw = 0,
            roll = 0,
            molecule_rotation = quaternion_from_xyzw(0, 0, 0, 1)
        },
    }
}

change_mode_to :: proc(state: ^State, mode: Mode) {
    switch state.mode {
    case .NONE:
    case .SELECT:
    case .ROTATE:
    }

    state.mode = mode
}

update_selection_to_hovering_over :: proc(state: ^State) {
    state.select.last_selected = state.select.curr_selected
    state.select.curr_selected = state.hovering_over_sphere
}

main :: proc() {
    poscar_filename := "Ge.vasp"
    poscar, poscar_ok := poscar_parse(poscar_filename)
    if !poscar_ok {
        fmt.println("Could not parse {}", poscar_filename)
    }

    rl.SetTraceLogLevel(.WARNING)
    context.logger = log.create_console_logger()
    rl.SetConfigFlags({ rl.ConfigFlag.WINDOW_RESIZABLE, rl.ConfigFlag.WINDOW_ALWAYS_RUN })

    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Molma v0.1")
    defer rl.CloseWindow()

    font := rl.LoadFont("fonts/JetBrainsMono-2.304/JetBrainsMono-Regular.ttf")
    defer rl.UnloadFont(font)

    // GUI Styling
    rl.GuiSetFont(font)
    rl.GuiSetStyle(.DEFAULT, i32(rl.GuiDefaultProperty.TEXT_SIZE), 32)
    TB_BG_COLOR := i32(rl.ColorToInt(rl.ORANGE))
    rl.GuiSetStyle(.DEFAULT, i32(rl.GuiControlProperty.TEXT_COLOR_NORMAL), TB_BG_COLOR)
    rl.GuiSetStyle(.DEFAULT, i32(rl.GuiControlProperty.BASE_COLOR_NORMAL), TB_BG_COLOR)

    rl.SetTargetFPS(60)

    atoms, lattice, lattice_normalized,
    bonds, origin, max_distance, aspect_ratio,
    camera_original_position, camera, state := load_poscar_data_and_refresh(poscar, font)

    for ! rl.WindowShouldClose() {
        if rl.IsFileDropped() {
            dropped_files := rl.LoadDroppedFiles()
            defer rl.UnloadDroppedFiles(dropped_files)

            fmt.println("a file was dropped yo!")

            // note: we only take the last dropped file for now
            dropped_file := dropped_files.paths[dropped_files.count - 1]

            fmt.println(dropped_file)

            poscar_dropped, poscar_dropped_ok := poscar_parse(string(dropped_file))

            if !poscar_dropped_ok {
                fmt.println("WARNING: Unable to parse dropped file's data")
            }
            else {
                if atoms != nil do delete(atoms)
                    if bonds != nil do delete(bonds)

                        atoms, lattice, lattice_normalized,
                        bonds, origin, max_distance, aspect_ratio,
                        camera_original_position, camera, state =
                        load_poscar_data_and_refresh(poscar_dropped, font)
            }
        }

        winw := rl.GetScreenWidth()
        winh := rl.GetScreenHeight()
        state.select.edit_ui_x = winw - (state.select.ui_rect_1tb_w + ui_padding)
        state.select.edit_ui_y = ui_padding

        ZOOM_SCALE :: 5.0
        zoom := rl.GetMouseWheelMove()
        fovy := camera.fovy
        fovy -= (zoom * ZOOM_SCALE)
        fovy = clamp(fovy, 1.0, 1000.0)
        camera.fovy = rl.Lerp(camera.fovy, fovy, 0.15)

        if rl.IsKeyPressed(.E) {
            if state.mode == .SELECT {
                state.select.last_selected = -1
                state.select.curr_selected = -1
                state.hovering_over_sphere = -1
                change_mode_to(&state, .NONE)
            }
            else {
                change_mode_to(&state, .SELECT)
            }
        }

        if rl.IsKeyPressed(.R) {
            if state.mode == .ROTATE {
                state.mode = .NONE
            }
            else {
                change_mode_to(&state, .ROTATE)
            }
        }

        rot_matrix := rl.QuaternionToMatrix(state.rotate.molecule_rotation)

        switch (state.mode) {
        case .ROTATE:
            {
                if rl.IsMouseButtonDown(.LEFT) {
                    SENSITIVITY :: 0.005
                    delta := rl.GetMouseDelta()
                    forward := rl.Vector3Normalize(camera.target - camera.position)
                    right   := rl.Vector3Normalize(rl.Vector3CrossProduct(forward, camera.up))
                    up      := rl.Vector3Normalize(rl.Vector3CrossProduct(right, forward))
                    q_pitch := rl.QuaternionFromAxisAngle(right, -delta.y * SENSITIVITY)
                    q_yaw   := rl.QuaternionFromAxisAngle(up,    -delta.x * SENSITIVITY)
                    state.rotate.molecule_rotation = q_pitch * q_yaw * state.rotate.molecule_rotation
                    state.rotate.molecule_rotation = rl.QuaternionNormalize(state.rotate.molecule_rotation)
                }

            }
        case .SELECT:
            {
                state.hovering_over_sphere = -1

                for i in 0..<len(atoms) {
                    ray := rl.GetScreenToWorldRay(rl.GetMousePosition(), camera)
                    collision := rl.GetRayCollisionSphere(ray, atoms[i].position.xyz, f32(atoms[i].radius) * RADIUS_PCT)
                    if collision.hit && !atoms[i].is_a_ghost{
                        state.hovering_over_sphere = i32(i)
                    }
                }

                if rl.IsMouseButtonPressed(.LEFT) {
                    if state.select.curr_selected != -1 &&
                        state.select.curr_selected == state.select.last_selected
                        {
                            mouse_position := rl.GetMousePosition()
                            ui_box_rect := rl.Rectangle {
                                f32(state.select.edit_ui_x),
                                f32(state.select.edit_ui_y),
                                f32(ui_padding + state.select.ui_rect_1tb_w),
                                f32(3 * (ui_padding + state.select.ui_rect_1tb_h)),
                            }

                            if !rl.CheckCollisionPointRec(mouse_position, ui_box_rect) {
                                update_selection_to_hovering_over(&state)
                            }
                        }
                        else {
                            update_selection_to_hovering_over(&state)
                        }
                    }
                }
                case .NONE: // do nothing
        }

        offset := rl.Vector3Transform(camera_original_position, rot_matrix)
        camera.position = origin + offset
        camera.up = rl.Vector3Transform({0, 1, 0}, rot_matrix)
        camera.target = origin

        rl.BeginDrawing(); defer rl.EndDrawing()

        rl.ClearBackground(rl.GetColor(0x444444ff))
        rl.DrawFPS(10, 30);

        rl.BeginMode3D(camera)

        draw_lattice(lattice)

        draw_bonds(bonds, atoms[:])

        draw_atoms(atoms[:])

        if state.hovering_over_sphere != -1 {
            draw_highlighted_atom(state.hovering_over_sphere, atoms[:], rl.BLACK)
        }

        if state.select.curr_selected != -1 {
            draw_highlighted_atom(state.select.curr_selected, atoms[:], rl.GREEN)
        }

        rl.EndMode3D()

        draw_gizmo(lattice_normalized, state.rotate.molecule_rotation)

        draw_help(font, &state)

        if state.mode == .SELECT {
            draw_edit_ui(font, &state, atoms[:], &bonds)
        }
    }
}

load_poscar_data_and_refresh :: proc(poscar: Poscar, font: rl.Font) ->
(
 atoms: [dynamic]Atom,
 lattice: Lattice,
 lattice_normalized: Lattice,
 bonds: Bonds,
 origin: rl.Vector3,
 max_distance: f32,
 aspect_ratio: f32,
 camera_original_position: rl.Vector3,
 camera: rl.Camera3D,
 state: State,
)
{
    atoms = poscar.atoms
    lattice = poscar.lattice
    lattice_normalized = Lattice {
        rl.Vector3Normalize(lattice[0]),
        rl.Vector3Normalize(lattice[1]),
        rl.Vector3Normalize(lattice[2]),
    }

    bonds = make(Bonds)
    populate_bonds(&bonds, atoms[:])
    origin = get_molecule_center(atoms[:])
    max_distance = get_farthest_atom_from_center(atoms[:], origin)
    aspect_ratio = f32(rl.GetScreenWidth()) / f32(rl.GetScreenHeight())

    vertical_size   := 5 * max_distance
    horizontal_size := 5 * max_distance
    required_fovy_from_width := horizontal_size / aspect_ratio

    camera_original_position = rl.Vector3{0, 0, 5 * max_distance}
    camera = rl.Camera3D {
        position = origin + camera_original_position,
        target = origin,
        up = rl.Vector3{0.0, 1.0, 0.0},
        fovy =  max(vertical_size, required_fovy_from_width),
        projection = rl.CameraProjection.ORTHOGRAPHIC,
    }

    state = init_state(font)
    return
}

draw_bonds :: proc(bonds: Bonds, atoms : []Atom) {
    for k, v in bonds {
        for bond_data in v {
            target := bond_data.destination
            rad := min(atoms[k].radius, atoms[target].radius) * RADIUS_PCT * BOND_RADIUS_PCT
            rl.DrawCylinderEx(atoms[k].position.xyz, atoms[target].position.xyz, rad, rad, 20, rl.RAYWHITE)
        }
    }
}

zero3 :: rl.Vector3 {0, 0, 0}

draw_lattice :: proc(lattice: Lattice) {
    a := lattice[0]
    b := lattice[1]
    c := lattice[2]
    _1 := a + b
    _2 := a + c
    _3 := b + c
    _4 := a + b + c

    rl.DrawLine3D(zero3, lattice[0], rl.GREEN)
    rl.DrawLine3D(zero3, lattice[1], rl.GREEN)
    rl.DrawLine3D(zero3, lattice[2], rl.GREEN)

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

draw_atoms :: proc(atoms : []Atom) {
    for i in 0..<len(atoms) {
        element_info := periodic_table[atoms[i].atomic_number]
        color := rl.YELLOW if atoms[i].is_a_ghost else rl.GetColor(element_info.color)
        rl.DrawSphere(atoms[i].position.xyz, f32(atoms[i].radius) * RADIUS_PCT, color);
    }
}

draw_highlighted_atom :: proc(id: i32, atoms : []Atom, color: rl.Color) {
    atom := atoms[id]
    rl.DrawSphereWires(atom.position.xyz, f32(atom.radius) * RADIUS_PCT,
        10, 20, color)
}

draw_gizmo :: proc(lattice: Lattice, rotation_quaternion: rl.Quaternion) {
    gizmo_center := rl.Vector2 { GIZMO_MARGIN, f32(rl.GetScreenHeight()) - GIZMO_MARGIN }

    rot_mat := rl.QuaternionToMatrix(rotation_quaternion)
    colors := [3]rl.Color{ X_COLOR, Y_COLOR, Z_COLOR }
    labels := [3]string{ "X", "Y", "Z" }

    for i in 0..<3 {
        rotated_axis := rl.Vector3Transform(lattice[i], rot_mat)
        end_point := gizmo_center + rl.Vector2 { rotated_axis.x, -rotated_axis.y } * GIZMO_SIZE
        rl.DrawLineEx(gizmo_center, end_point, 3.0, colors[i])
        label_cstr := rl.TextFormat("%s", labels[i])
        rl.DrawText(label_cstr, i32(end_point.x + 5), i32(end_point.y - 5), 10, colors[i])
    }
}

draw_help :: proc(font: rl.Font, state: ^State) {
    // rl.GuiCheckBox(rl.Rectangle {0, 0, 10, 10}, "Edit", &(state.select.ui_is_select));
    rl.DrawTextEx(font, "E: edit"  , {10, 50}, 32.0, 2.0, rl.ORANGE)
    rl.DrawTextEx(font, "R: rotate", {10, 70}, 32.0, 2.0, rl.ORANGE)
}

draw_edit_ui :: proc(font: rl.Font, state: ^State, atoms: []Atom, bonds: ^Bonds) {
    if state.select.curr_selected != -1 && 
       state.select.curr_selected != state.select.last_selected
    {
        edit_atom_pos := atoms[state.select.curr_selected].position
        fmt.bprintf(state.select.xpos[:], "%.6f", edit_atom_pos.x)
        fmt.bprintf(state.select.ypos[:], "%.6f", edit_atom_pos.y)
        fmt.bprintf(state.select.zpos[:], "%.6f", edit_atom_pos.z)
        state.select.last_selected = state.select.curr_selected
    }

    if state.select.curr_selected != -1 &&
       state.select.curr_selected == state.select.last_selected
    {
        y1 := state.select.edit_ui_y
        height := state.select.ui_rect_1tb_h
        y2 := y1 + (ui_padding + height)
        y3 := y2 + (ui_padding + height)

        tb1 := rl.GuiTextBox(
            rl.Rectangle {
                f32(state.select.edit_ui_x),
                f32(y1),
                f32(state.select.ui_rect_1tb_w),
                f32(state.select.ui_rect_1tb_h),
            },
            cstring(&state.select.xpos[0]),
            32, state.select.ui_edit_mode[0],
        ) 

        tb2 := rl.GuiTextBox(
            rl.Rectangle {
                f32(state.select.edit_ui_x),
                f32(y2),
                f32(state.select.ui_rect_1tb_w),
                f32(state.select.ui_rect_1tb_h),
            },
            cstring(&state.select.ypos[0]),
            32, state.select.ui_edit_mode[1],
        ) 

        tb3 := rl.GuiTextBox(
            rl.Rectangle {
                f32(state.select.edit_ui_x),
                f32(y3),
                f32(state.select.ui_rect_1tb_w),
                f32(state.select.ui_rect_1tb_h),
            },
            cstring(&state.select.zpos[0]),
            32, state.select.ui_edit_mode[2],
        ) 

        // reconcile data between string position and real position
        selected_atom := &atoms[state.select.curr_selected]
        if tb1 {
            state.select.ui_edit_mode[0] = !state.select.ui_edit_mode[0]
            if value, ok := strconv.parse_f32(string(cstring(&state.select.xpos[0]))); ok {
                if value != selected_atom.position.x {
                    selected_atom.position.x = value
                    populate_bonds(bonds, atoms[:])
                }
            }
        }
        if tb2 {
            state.select.ui_edit_mode[1] = !state.select.ui_edit_mode[1]
            if value, ok := strconv.parse_f32(string(cstring(&state.select.ypos[0]))); ok {
                if value != selected_atom.position.y {
                    selected_atom.position.y = value 
                    populate_bonds(bonds, atoms[:])
                }
            }
        }
        if tb3 {
            state.select.ui_edit_mode[2] = !state.select.ui_edit_mode[2]
            if value, ok := strconv.parse_f32(string(cstring(&state.select.zpos[0]))); ok {
                if value != selected_atom.position.z {
                    selected_atom.position.z = value 
                    populate_bonds(bonds, atoms[:])
                }
            }
        }
    }
}

get_molecule_center :: proc(atoms: []Atom) -> rl.Vector3 {
    if len(atoms) == 0 do return {0, 0, 0}

    sum := rl.Vector3{0, 0, 0}
    for atom in atoms {
        sum += atom.position.xyz
    }

    return sum / f32(len(atoms))
}

get_farthest_atom_from_center :: proc(atoms: []Atom, center: rl.Vector3) -> f32 {
    max_distance := math.NEG_INF_F32
    for atom in atoms {
        distance := rl.Vector3Distance(atom.position.xyz, center) +
        periodic_table[atom.atomic_number].cov_radius_ang
        max_distance = max(max_distance, distance)
    }

    return max_distance
}

get_lattice_extras :: proc(lattice: Lattice) -> Lattice_extras {
    a, b, c := lattice[0], lattice[1], lattice[2]

    bxc := rl.Vector3CrossProduct(b, c)
    cxa := rl.Vector3CrossProduct(c, a)
    axb := rl.Vector3CrossProduct(a, b)

    return Lattice_extras {
        bxc = bxc,
        cxa = cxa,
        axb = axb,
        V   = rl.Vector3DotProduct(a, bxc),
    }
}

// V     = a . (b x c)
// alpha = P . (b x c) / V
// beta  = P . (c x a) / V
// gamma = P . (a x b) / V
get_alpha_beta_gamma :: proc(le: Lattice_extras, point: rl.Vector3) -> rl.Vector3 {
    return rl.Vector3{
        rl.Vector3DotProduct(point, le.bxc) / le.V,
        rl.Vector3DotProduct(point, le.cxa) / le.V,
        rl.Vector3DotProduct(point, le.axb) / le.V,
    }
}

is_near_boundary :: proc(val: f32, direction: int) -> bool {
    if direction == 1 {
        return val < eps           // Near 0, project to +1
    }
    if direction == -1 {
        return val > (1.0 - eps)   // Near 1, project to -1
    }
    return false
}

populate_bonds :: proc(bonds : ^Bonds, atoms: []Atom) {
    TOLERANCE :: 0.2
    clear_map(bonds)
    for i in 0..<len(atoms) {
        for j in (i+1)..<len(atoms) {
            distance := rl.Vector3Distance(atoms[i].position.xyz, atoms[j].position.xyz)
            sum_of_radii := atoms[i].radius + atoms[j].radius
            if distance <= sum_of_radii + TOLERANCE {
                if bonds[i] == nil {
                    bonds[i] = make([dynamic]BondData)
                }
                append(&bonds[i], BondData{j, distance})
            }
        }
    }
}
