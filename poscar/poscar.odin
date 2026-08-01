// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package poscar

import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"
import "../model"

Species :: struct {
	symbol: string,
	count:  int,
}

is_ascii_char :: proc(ch: byte) -> bool {
	return (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z')
}

line_at :: proc(lines: []string, n: int) -> (string, bool) {
	if n < 0 || n >= len(lines) {
		return "", false
	}
	return lines[n], true
}

parse :: proc(filename: string) -> (model.Molecule, bool) {
	mol: model.Molecule

	data, read_err := os.read_entire_file(filename, context.temp_allocator)
	if read_err != nil {
		return mol, false
	}

	lines := strings.split_lines(string(data), context.temp_allocator)

	line_number := 1 // skip the comment line

	scaling_factor, ok := strconv.parse_f32(strings.trim_space(lines[line_number]))
	if !ok {
		return mol, false
	}
	line_number += 1

	lattice_vecs: [3]model.CartVec3
	for i in 0 ..< 3 {
		values, lattice_err := strings.fields(lines[line_number + i], context.temp_allocator)
		if lattice_err != nil {
			return mol, false
		}
		for j in 0 ..< 3 {
			component, ok := strconv.parse_f32(values[j])
			if !ok {
				return mol, false
			}
			lattice_vecs[i][j] = component * scaling_factor
		}
	}
	mol.lattice = model.Lattice{a = lattice_vecs[0], b = lattice_vecs[1], c = lattice_vecs[2]}
	line_number += 3

	species := make([dynamic]Species, context.temp_allocator)

	line: string
	line, ok = line_at(lines, line_number)
	if !ok {
		return mol, false
	}
	line = strings.trim_left_space(line)
	if len(line) == 0 || !is_ascii_char(line[0]) {
		return mol, false
	}
	symbols, _ := strings.fields(line, context.temp_allocator)
	for symbol in symbols {
		append(&species, Species{symbol = strings.to_lower(symbol, context.temp_allocator)})
	}
	line_number += 1

	atoms_len := 0
	values, cnt_err := strings.fields(lines[line_number], context.temp_allocator)
	if cnt_err != nil {
		return mol, false
	}
	for v, k in values {
		if k >= len(species) {
			return mol, false
		}
		count, ok := strconv.parse_int(v, 10)
		if !ok {
			return mol, false
		}
		species[k].count = count
		atoms_len += count
	}
	line_number += 1

	line, ok = line_at(lines, line_number)
	if !ok {
		return mol, false
	}
	line = strings.trim_left_space(line)
	if len(line) == 0 {
		return mol, false
	}
	if line[0] == 's' || line[0] == 'S' {
		line_number += 1
		line, ok = line_at(lines, line_number)
		if !ok {
			return mol, false
		}
		line = strings.trim_left_space(line)
		if len(line) == 0 {
			return mol, false
		}
	}

	coord_mode_cartesian := line[0] == 'c' || line[0] == 'C' || line[0] == 'k' || line[0] == 'K'
	line_number += 1

	atoms := make([dynamic]model.Atom, atoms_len)

	parse_ok := true
	atom_it := 0
	for s in species {
		_, atomic_number := model.lookup_by_symbol(s.symbol)
		if atomic_number == 0 {
			parse_ok = false
			break
		}
		for i in 0 ..< s.count {
			values, pos_err := strings.fields(lines[line_number + i], context.temp_allocator)
			if pos_err != nil || len(values) < 3 {
				parse_ok = false
				break
			}

			frac: model.FracVec3
			if coord_mode_cartesian {
				cart: model.CartVec3
				okx, oky, okz: bool
				cart[0], okx = strconv.parse_f32(values[0])
				cart[1], oky = strconv.parse_f32(values[1])
				cart[2], okz = strconv.parse_f32(values[2])
				if !(okx && oky && okz) {
					parse_ok = false
					break
				}
				frac, ok = model.fractional(mol.lattice, cart)
				if !ok {
					parse_ok = false
					break
				}
			} else {
				okx, oky, okz: bool
				frac[0], okx = strconv.parse_f32(values[0])
				frac[1], oky = strconv.parse_f32(values[1])
				frac[2], okz = strconv.parse_f32(values[2])
				if !(okx && oky && okz) {
					parse_ok = false
					break
				}
			}

			atoms[atom_it] = model.Atom{position = frac, atomic_number = atomic_number}
			atom_it += 1
		}
		if !parse_ok {
			break
		}
		line_number += s.count
	}
	if !parse_ok {
		delete(atoms)
		return mol, false
	}

	slice.sort_by(atoms[:], proc(a, b: model.Atom) -> bool {
		return a.atomic_number < b.atomic_number
	})

	mol.atoms = atoms
	return mol, true
}
