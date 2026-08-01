// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package model

import "core:fmt"
import "core:testing"

cubic :: proc(size: f32) -> Lattice {
	return Lattice {
		a = CartVec3{size, 0, 0},
		b = CartVec3{0, size, 0},
		c = CartVec3{0, 0, size},
	}
}

make_atom :: proc(n: u16, pos: FracVec3) -> Atom {
	return Atom{position = pos, atomic_number = n}
}

expect_bond :: proc(t: ^testing.T, bonds: []Bond, a, b: AtomIndex, shift: [3]i8) {
	for bond in bonds {
		if bond.a == a && bond.b == b && bond.shift == shift {
			return
		}
	}
	testing.expect(
		t,
		false,
		fmt.tprintf("expected bond (%d, %d) shift %v not found", i32(a), i32(b), shift),
	)
}

@test h2_bonds_test :: proc(t: ^testing.T) {
	atoms := []Atom{make_atom(1, FracVec3{0, 0, 0}), make_atom(1, FracVec3{0.074, 0, 0})}
	bonds := compute_bonds(atoms, cubic(10))
	defer delete(bonds)

	testing.expect_value(t, len(bonds), 1)
	expect_bond(t, bonds[:], 0, 1, [3]i8{0, 0, 0})
}

@test h2_too_far_test :: proc(t: ^testing.T) {
	atoms := []Atom{make_atom(1, FracVec3{0, 0, 0}), make_atom(1, FracVec3{0.2, 0, 0})}
	bonds := compute_bonds(atoms, cubic(10))
	defer delete(bonds)

	testing.expect_value(t, len(bonds), 0)
}

@test pbc_cross_boundary_bond_test :: proc(t: ^testing.T) {
	atoms := []Atom{make_atom(1, FracVec3{0.92, 0.5, 0.5}), make_atom(1, FracVec3{0, 0.5, 0.5})}
	bonds := compute_bonds(atoms, cubic(10))
	defer delete(bonds)

	testing.expect_value(t, len(bonds), 1)
	expect_bond(t, bonds[:], 0, 1, [3]i8{1, 0, 0})
}

@test pbc_cross_boundary_negative_shift_test :: proc(t: ^testing.T) {
	atoms := []Atom{make_atom(1, FracVec3{0.05, 0.5, 0.5}), make_atom(1, FracVec3{0.97, 0.5, 0.5})}
	bonds := compute_bonds(atoms, cubic(10))
	defer delete(bonds)

	testing.expect_value(t, len(bonds), 1)
	expect_bond(t, bonds[:], 0, 1, [3]i8{-1, 0, 0})
}

@test fe_cutoff_test :: proc(t: ^testing.T) {
	bonded := []Atom{make_atom(26, FracVec3{0, 0, 0}), make_atom(26, FracVec3{0.25, 0, 0})}
	b1 := compute_bonds(bonded, cubic(10))
	defer delete(b1)
	testing.expect_value(t, len(b1), 1)
	expect_bond(t, b1[:], 0, 1, [3]i8{0, 0, 0})

	apart := []Atom{make_atom(26, FracVec3{0, 0, 0}), make_atom(26, FracVec3{0.5, 0, 0})}
	b2 := compute_bonds(apart, cubic(10))
	defer delete(b2)
	testing.expect_value(t, len(b2), 0)
}

@test ch_cutoff_test :: proc(t: ^testing.T) {
	bonded := []Atom{make_atom(6, FracVec3{0, 0, 0}), make_atom(1, FracVec3{0.11, 0, 0})}
	b1 := compute_bonds(bonded, cubic(10))
	defer delete(b1)
	testing.expect_value(t, len(b1), 1)
	expect_bond(t, b1[:], 0, 1, [3]i8{0, 0, 0})

	apart := []Atom{make_atom(6, FracVec3{0, 0, 0}), make_atom(1, FracVec3{0.15, 0, 0})}
	b2 := compute_bonds(apart, cubic(10))
	defer delete(b2)
	testing.expect_value(t, len(b2), 0)
}

@test bond_indices_sorted_test :: proc(t: ^testing.T) {
	atoms := []Atom {
		make_atom(1, FracVec3{0, 0, 0}),
		make_atom(1, FracVec3{0.074, 0, 0}),
		make_atom(1, FracVec3{0.148, 0, 0}),
		make_atom(1, FracVec3{0.222, 0, 0}),
	}
	bonds := compute_bonds(atoms, cubic(10))
	defer delete(bonds)

	testing.expect_value(t, len(bonds), 3)
	for bond in bonds {
		testing.expect(t, bond.a < bond.b)
	}
	expect_bond(t, bonds[:], 1, 2, [3]i8{0, 0, 0})
}

@test empty_atoms_no_bonds_test :: proc(t: ^testing.T) {
	bonds := compute_bonds(nil, cubic(10))
	defer delete(bonds)
	testing.expect_value(t, len(bonds), 0)
}
