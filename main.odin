#+feature dynamic-literals

package main

import "core:log"
import "core:math"
import "core:fmt"
import "core:strconv"
import rl "vendor:raylib"
import nfd "nativefiledialog-odin"

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
    font                     : rl.Font,
    mode                     : Mode,
    select                   : Select,
    rotate                   : Rotate,
    hovering_over_sphere     : i32,
    toolbar                  : toolbar,
    poscar                   : Poscar,
    bonds                    : Bonds,
    lattice_normalized       : Lattice,
    origin                   : rl.Vector3,
    max_distance             : f32,
    aspect_ratio             : f32,
    camera_original_position : rl.Vector3,
    camera                   : rl.Camera3D,


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

toolbar_default_position :: rl.Vector2 {toolbar_padding, 100}

init_state :: proc(state: ^State, font: rl.Font) {
    state.font = font
    measure_text := rl.MeasureTextEx(font, "-0.000000", ui_font_size, ui_font_spacing)
    state.mode = .NONE
    state.hovering_over_sphere = -1
    state.select = Select {
        last_selected = -1,
        curr_selected = -1,
        xpos = 0,
        ypos = 0,
        zpos = 0,
        font_size = ui_font_size,
        ui_rect_1tb_w = 2 * ui_padding + i32(math.ceil(measure_text.x)),
        ui_rect_1tb_h = i32(math.ceil(measure_text.y)),
        ui_edit_mode = false,
    }
    state.rotate = Rotate {
        pitch = 0,
        yaw = 0,
        roll = 0,
        molecule_rotation = quaternion_from_xyzw(0, 0, 0, 1)
    }
    state.toolbar = toolbar_create(toolbar_default_position)
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
    rl.SetTraceLogLevel(.WARNING)
    context.logger = log.create_console_logger()
    rl.SetConfigFlags({ rl.ConfigFlag.WINDOW_RESIZABLE, rl.ConfigFlag.WINDOW_ALWAYS_RUN })

    open_path: cstring
    save_path: cstring
    nfd.Init()
    defer nfd.Quit()

    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Molma v0.1")
    defer rl.CloseWindow()

    executable_dir := rl.GetApplicationDirectory()
    font_path := fmt.ctprintf("%s/%s", executable_dir, "fonts/JetBrainsMono-2.304/JetBrainsMono-Regular.ttf")
    font := rl.LoadFont(font_path)
    defer rl.UnloadFont(font)

    // GUI Styling
    // rl.GuiSetFont(font)
    // rl.GuiSetStyle(.DEFAULT, i32(rl.GuiDefaultProperty.TEXT_SIZE), 32)
    // TB_BG_COLOR := i32(rl.ColorToInt(rl.ORANGE))
    // rl.GuiSetStyle(.DEFAULT, i32(rl.GuiControlProperty.TEXT_COLOR_NORMAL), TB_BG_COLOR)
    // rl.GuiSetStyle(.DEFAULT, i32(rl.GuiControlProperty.BASE_COLOR_NORMAL), TB_BG_COLOR)

    rl.SetTargetFPS(60)

    state: State
    poscar_filename := "test-files/Ge.vasp"
    poscar_ok: bool
    state.poscar, poscar_ok = poscar_parse(poscar_filename)
    if !poscar_ok {
        fmt.println("Could not parse {}", poscar_filename)
    }

    load_poscar_data_and_refresh(&state, state.poscar)

    for ! rl.WindowShouldClose() {
        if rl.IsFileDropped() {
            dropped_files := rl.LoadDroppedFiles()
            defer rl.UnloadDroppedFiles(dropped_files)

            // note: we only take the last dropped file for now
            dropped_file := dropped_files.paths[dropped_files.count - 1]

            fmt.println(dropped_file)

            poscar_dropped, poscar_dropped_ok := poscar_parse(string(dropped_file))

            if !poscar_dropped_ok {
                fmt.println("WARNING: Unable to parse dropped file's data")
            }
            else {
                if state.poscar.atoms != nil do delete(state.poscar.atoms)
                    if state.bonds != nil do delete(state.bonds)
                        load_poscar_data_and_refresh(&state, poscar_dropped)
            }
        }

        winw := rl.GetScreenWidth()
        winh := rl.GetScreenHeight()
        state.select.edit_ui_x = winw - (state.select.ui_rect_1tb_w + ui_padding)
        state.select.edit_ui_y = ui_padding

        ZOOM_SCALE :: 5.0
        zoom := rl.GetMouseWheelMove()
        fovy := state.camera.fovy
        fovy -= (zoom * ZOOM_SCALE)
        fovy = clamp(fovy, 1.0, 1000.0)
        state.camera.fovy = rl.Lerp(state.camera.fovy, fovy, 0.15)

        /*
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

   // note(aelobdog): temporary
   if rl.IsKeyPressed(.O) {
   result := nfd.OpenDialogU8(&open_path, nil, 0, nil)
   switch result {
   case .Okay: {
   fmt.println("Success!")
   fmt.println(open_path)
   nfd.FreePathU8(open_path)
   }
   case .Cancel: fmt.println("User pressed cancel.")
   case .Error: fmt.println("Error:", nfd.GetError())
   }
        }

        // note(aelobdog): temporary
        if rl.IsKeyPressed(.S) {
        result := nfd.SaveDialogU8(&save_path, nil, 0, nil, nil)
        switch result {
        case .Okay: {
        fmt.println("Success!")
        fmt.println(save_path)
        _ = poscar_write(string(save_path), poscar)
        nfd.FreePathU8(save_path)
        }
        case .Cancel: fmt.println("User pressed cancel.")
        case .Error: fmt.println("Error:", nfd.GetError())
        }
    }
    */

        rot_matrix := rl.QuaternionToMatrix(state.rotate.molecule_rotation)

        switch (state.mode) {
        case .ROTATE:
            {
                if rl.IsMouseButtonDown(.LEFT) {
                    SENSITIVITY :: 0.005
                    delta := rl.GetMouseDelta()
                    forward := rl.Vector3Normalize(state.camera.target - state.camera.position)
                    right   := rl.Vector3Normalize(rl.Vector3CrossProduct(forward, state.camera.up))
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

                for i in 0..<len(state.poscar.atoms) {
                    ray := rl.GetScreenToWorldRay(rl.GetMousePosition(), state.camera)
                    collision := rl.GetRayCollisionSphere(ray, state.poscar.atoms[i].position.xyz, f32(state.poscar.atoms[i].radius) * RADIUS_PCT)
                    if collision.hit && !state.poscar.atoms[i].is_a_ghost{
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

        offset := rl.Vector3Transform(state.camera_original_position, rot_matrix)
        state.camera.position = state.origin + offset
        state.camera.up = rl.Vector3Transform({0, 1, 0}, rot_matrix)
        state.camera.target = state.origin

        rl.BeginDrawing(); defer rl.EndDrawing()

        rl.ClearBackground(rl.GetColor(0x444444ff))
        rl.DrawFPS(10, 30);

        rl.BeginMode3D(state.camera)

        draw_lattice(state.poscar.lattice)

        draw_bonds(state.bonds, state.poscar.atoms[:])

        draw_atoms(state.poscar.atoms[:])

        if state.hovering_over_sphere != -1 {
            draw_highlighted_atom(state.hovering_over_sphere, state.poscar.atoms[:], rl.BLACK)
        }

        if state.select.curr_selected != -1 {
            draw_highlighted_atom(state.select.curr_selected, state.poscar.atoms[:], rl.GREEN)
        }

        rl.EndMode3D()

        draw_gizmo(state.lattice_normalized, state.rotate.molecule_rotation)

        toolbar_draw(&state)

        if state.mode == .SELECT {
            draw_edit_ui(font, &state, state.poscar.atoms[:], &state.bonds)
        }
    }
}

load_poscar_data_and_refresh :: proc(state: ^State, poscar: Poscar) {
    state.poscar = poscar
    state.lattice_normalized = Lattice {
        rl.Vector3Normalize(state.poscar.lattice[0]),
        rl.Vector3Normalize(state.poscar.lattice[1]),
        rl.Vector3Normalize(state.poscar.lattice[2]),
    }

    state.bonds = make(Bonds)
    populate_bonds(&state.bonds, state.poscar.atoms[:])
    state.origin = get_molecule_center(state.poscar.atoms[:])
    state.max_distance = get_farthest_atom_from_center(state.poscar.atoms[:], state.origin)
    state.aspect_ratio = f32(rl.GetScreenWidth()) / f32(rl.GetScreenHeight())

    vertical_size   := 5 * state.max_distance
    horizontal_size := 5 * state.max_distance
    required_fovy_from_width := horizontal_size / state.aspect_ratio

    state.camera_original_position = rl.Vector3{0, 0, 5 * state.max_distance}
    state.camera = rl.Camera3D {
        position = state.origin + state.camera_original_position,
        target = state.origin,
        up = rl.Vector3{0.0, 1.0, 0.0},
        fovy =  max(vertical_size, required_fovy_from_width),
        projection = rl.CameraProjection.ORTHOGRAPHIC,
    }

    init_state(state, state.font)
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
    if state.select.curr_selected != -1 && state.select.curr_selected != state.select.last_selected {
        edit_atom_pos := atoms[state.select.curr_selected].position
        fmt.bprintf(state.select.xpos[:], "%.6f", edit_atom_pos.x)
        fmt.bprintf(state.select.ypos[:], "%.6f", edit_atom_pos.y)
        fmt.bprintf(state.select.zpos[:], "%.6f", edit_atom_pos.z)
        state.select.last_selected = state.select.curr_selected
    }

    if state.select.curr_selected != -1 && state.select.curr_selected == state.select.last_selected {
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
