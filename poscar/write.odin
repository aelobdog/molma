// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package poscar

import "core:os"
import "core:strings"
import "../model"

SpeciesCount :: struct {
	atomic_number: u16,
	count:         int,
}

write :: proc(filename: string, mol: model.Molecule) -> bool {
	sb := strings.builder_make()
	defer strings.builder_destroy(&sb)

	strings.write_string(&sb, "fixme\n")
	strings.write_string(&sb, "1.0\n")

	vecs := [3]model.CartVec3{mol.lattice.a, mol.lattice.b, mol.lattice.c}
	for vec in vecs {
		for component in vec {
			strings.write_f32(&sb, component, 'f')
			strings.write_byte(&sb, ' ')
		}
		strings.write_byte(&sb, '\n')
	}

	species := make([dynamic]SpeciesCount)
	defer delete(species)

	for atom in mol.atoms {
		if _, ok := model.lookup_by_number(atom.atomic_number); !ok {
			return false
		}
		idx := -1
		for entry, i in species {
			if entry.atomic_number == atom.atomic_number {
				idx = i
				break
			}
		}
		if idx == -1 {
			append(&species, SpeciesCount{atomic_number = atom.atomic_number, count = 1})
		} else {
			species[idx].count += 1
		}
	}

	for entry in species {
		e, _ := model.lookup_by_number(entry.atomic_number)
		strings.write_string(&sb, e.symbol)
		strings.write_byte(&sb, '\t')
	}
	strings.write_byte(&sb, '\n')

	for entry in species {
		strings.write_int(&sb, entry.count)
		strings.write_byte(&sb, '\t')
	}
	strings.write_byte(&sb, '\n')

	strings.write_string(&sb, "Direct\n")

	for atom in mol.atoms {
		position := model.wrap_fractional(atom.position)
		for component in position {
			strings.write_f32(&sb, component, 'f')
			strings.write_byte(&sb, ' ')
		}
		strings.write_byte(&sb, '\n')
	}

	err := os.write_entire_file(filename, strings.to_string(sb))
	return err == nil
}
