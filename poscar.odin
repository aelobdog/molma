// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package main

import "core:os"
import "core:fmt"
import "core:strings"
import "core:strconv"
import rl "vendor:raylib"

Poscar :: struct {
    lattice: Lattice,
    atoms: [dynamic]Atom,
}

Species :: struct {
    symbol: string,
    count: int,
}

poscar_parse :: proc(filename: string) -> (Poscar, bool) {
    poscar : Poscar

    data, read_err := os.read_entire_file(filename, context.allocator)
    if read_err != nil {
        return poscar, false
    }
    defer delete(data, context.allocator)

    // temporary data
    ok := true
    scaling_factor := f32(0)
    atoms_len := 0
    coord_mode_cartesian := false
    species: [dynamic]Species
    defer delete(species)

    line_number := 0
    lines := strings.split_lines(string(data))

    // note(aelobdog): process the comment later
    line_number += 1

    // scaling factor
    // note(aelobdog): handle the case with 3 positive scaling factors
    // note(aelobdog): handle the case with 1 negative scaling factor
    scaling_factor, ok = strconv.parse_f32(strings.trim_space(lines[line_number]))
    if !ok {
        return poscar, false
    }
    line_number += 1

    // lattice vectors
    for i in 0..<3 {
        values, lattice_err := strings.fields(lines[line_number + i])
        defer delete(values)
        if lattice_err != nil {
            return poscar, false
        }

        for j in 0..<3 {
            poscar.lattice[i][j], ok = strconv.parse_f32(values[j])
            if !ok {
                return poscar, false
            }
            poscar.lattice[i][j] *= scaling_factor
        }
    }
    line_number += 3

    // species names
    if is_ascii_char(strings.trim_left_space(lines[line_number])[0]) {
        symbols, symbol_err := strings.fields(lines[line_number])
        defer delete(symbols)

        for symbol in symbols {
            append(&species, Species { symbol = strings.to_lower(symbol) })
        }
        line_number += 1
    }
    else {
        return poscar, false
    }

    // species count
    values, cnt_err := strings.fields(lines[line_number])
    defer delete(values)
    if cnt_err != nil {
        return poscar, false
    }
    for v, k in values {
        vint := 0
        vint, ok = strconv.parse_int(v, 10)
        if !ok {
            return poscar, false
        }
        species[k].count = vint
        atoms_len += vint
    }
    line_number += 1

    // selective dynamics (always ignore)
    first_letter := strings.trim_left_space(lines[line_number])[0]
    if first_letter == 's' || first_letter == 'S' {
        line_number += 1
    }

    first_letter = strings.trim_left_space(lines[line_number])[0]
    if first_letter == 'c' || first_letter == 'k' || first_letter == 'C' || first_letter == 'K' {
        coord_mode_cartesian = true
    }
    line_number += 1

    // atom positions
    poscar.atoms = make([dynamic]Atom, atoms_len)
    atom_it := 0
    for s in species {
        e, atomic_number := periodic_table_lookup_by_symbol(s.symbol)
        if atomic_number == 0 {
            return poscar, false
        }

        for i in 0..<s.count {
            values, pos_err := strings.fields(lines[line_number + i])
            defer delete(values)

            if pos_err != nil || len(values) < 3 {
                return poscar, false
            }

            okx := false
            oky := false
            okz := false
            poscar.atoms[atom_it].atomic_number = atomic_number
            poscar.atoms[atom_it].radius = e.cov_radius_ang
            poscar.atoms[atom_it].symbol = e.symbol
            poscar.atoms[atom_it].is_a_ghost = false

            position: rl.Vector3
            if (coord_mode_cartesian) {
                position.x, okx = strconv.parse_f32(values[0])
                position.y, oky = strconv.parse_f32(values[1])
                position.z, okz = strconv.parse_f32(values[2])

                if ! (okx && oky && okz) {
                    return poscar, false
                }
            }
            else {
                position.x, okx = strconv.parse_f32(values[0])
                position.y, oky = strconv.parse_f32(values[1])
                position.z, okz = strconv.parse_f32(values[2])

                if ! (okx && oky && okz) {
                    return poscar, false
                }

                cartesian_position := position.x * poscar.lattice[0] + 
                                      position.y * poscar.lattice[1] +
                                      position.z * poscar.lattice[2]

                position = cartesian_position
            }

            poscar.atoms[atom_it].position.x = position.x
            poscar.atoms[atom_it].position.y = position.y
            poscar.atoms[atom_it].position.z = position.z
            poscar.atoms[atom_it].position.w = 0.0

            atom_it += 1
        }
        line_number += s.count
    }

    return poscar, true
}

is_ascii_char :: proc(ch : byte) -> bool {
    return (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')
}

poscar_write :: proc(filename: string, poscar: Poscar) -> bool {
    output_sb := strings.builder_make()

    atoms := poscar.atoms
    lattice := poscar.lattice
    comment := "fixme"

    strings.write_string(&output_sb, comment)
    strings.write_byte(&output_sb, '\n')
    strings.write_f32(&output_sb, 1.0, 'f')
    strings.write_byte(&output_sb, '\n')

    for vec in lattice {
        for component in vec {
            strings.write_f32(&output_sb, component, 'f')
            strings.write_byte(&output_sb, ' ')
        }
        strings.write_byte(&output_sb, '\n')
    }

    species := make(map[string]int)
    for atom in atoms {
        if atom.symbol in species {
            species[atom.symbol] += 1
        }
        else {
            species[atom.symbol] = 1
        }
    }

    for s, _ in species {
        strings.write_string(&output_sb, s)
        strings.write_byte(&output_sb, '\t') 
    }
    strings.write_byte(&output_sb, '\n')

    for _, c in species {
        strings.write_int(&output_sb, c)
        strings.write_byte(&output_sb, '\t') 
    }
    strings.write_byte(&output_sb, '\n')
    strings.write_string(&output_sb, "Cartesian")
    strings.write_byte(&output_sb, '\n')

    for atom in atoms {
        for component in atom.position {
            strings.write_f32(&output_sb, component, 'f')
            strings.write_byte(&output_sb, ' ')
        }
        strings.write_byte(&output_sb, '\n')
    }

    fmt.println(strings.to_string(output_sb))
    ok := os.write_entire_file(filename, strings.to_string(output_sb))
    return true if ok == nil else false
}
