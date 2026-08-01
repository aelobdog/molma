// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package model

import "core:testing"

@test fresh_molecule_version_test :: proc(t: ^testing.T) {
	mol := Molecule{}
	defer delete(mol.atoms)
	testing.expect_value(t, mol.version, u64(0))
}

@test add_atom_bumps_version_test :: proc(t: ^testing.T) {
	mol := Molecule{}
	defer delete(mol.atoms)

	idx := add_atom(&mol, Atom{position = FracVec3{0.5, 0.5, 0.5}, atomic_number = 8})
	testing.expect_value(t, idx, AtomIndex(0))
	testing.expect_value(t, mol.version, u64(1))
	testing.expect_value(t, len(mol.atoms), 1)

	idx = add_atom(&mol, Atom{position = FracVec3{0, 0, 0}, atomic_number = 1})
	testing.expect_value(t, idx, AtomIndex(1))
	testing.expect_value(t, mol.version, u64(2))
	testing.expect_value(t, mol.atoms[1].atomic_number, u16(1))
}

@test set_atom_position_bumps_version_test :: proc(t: ^testing.T) {
	mol := Molecule{}
	defer delete(mol.atoms)
	idx := add_atom(&mol, Atom{position = FracVec3{0.5, 0.5, 0.5}, atomic_number = 8})

	set_atom_position(&mol, idx, FracVec3{0.25, 0.25, 0.25})
	testing.expect_value(t, mol.version, u64(2))
	testing.expect_value(t, mol.atoms[0].position, FracVec3{0.25, 0.25, 0.25})
}

@test remove_atom_bumps_version_test :: proc(t: ^testing.T) {
	mol := Molecule{}
	defer delete(mol.atoms)
	add_atom(&mol, Atom{position = FracVec3{0, 0, 0}, atomic_number = 1})
	add_atom(&mol, Atom{position = FracVec3{0.5, 0.5, 0.5}, atomic_number = 8})
	add_atom(&mol, Atom{position = FracVec3{0.25, 0.25, 0.25}, atomic_number = 6})
	testing.expect_value(t, mol.version, u64(3))

	remove_atom(&mol, 1)
	testing.expect_value(t, mol.version, u64(4))
	testing.expect_value(t, len(mol.atoms), 2)
	testing.expect_value(t, mol.atoms[1].atomic_number, u16(6))
}

@test set_lattice_bumps_version_test :: proc(t: ^testing.T) {
	mol := Molecule{lattice = cubic(10)}
	defer delete(mol.atoms)
	testing.expect_value(t, mol.version, u64(0))

	set_lattice(&mol, cubic(20))
	testing.expect_value(t, mol.version, u64(1))
	testing.expect_value(t, mol.lattice.a[0], f32(20))
}
