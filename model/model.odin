// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package model

Vec3 :: [3]f32
CartVec3 :: distinct Vec3
FracVec3 :: distinct Vec3
AtomIndex :: distinct i32

Atom :: struct {
	position:      FracVec3,
	atomic_number: u16,
}

Lattice :: struct {
	a, b, c: CartVec3,
}

Molecule :: struct {
	lattice: Lattice,
	atoms:   [dynamic]Atom,
	version: u64,
}

add_atom :: proc(mol: ^Molecule, atom: Atom) -> AtomIndex {
	append(&mol.atoms, atom)
	mol.version += 1
	return AtomIndex(len(mol.atoms) - 1)
}

remove_atom :: proc(mol: ^Molecule, index: AtomIndex) {
	ordered_remove(&mol.atoms, int(index))
	mol.version += 1
}

set_atom_position :: proc(mol: ^Molecule, index: AtomIndex, position: FracVec3) {
	mol.atoms[int(index)].position = position
	mol.version += 1
}

set_lattice :: proc(mol: ^Molecule, lattice: Lattice) {
	mol.lattice = lattice
	mol.version += 1
}
