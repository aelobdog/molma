package model

import "core:testing"

@test vec3_is_plain_array_test :: proc(t: ^testing.T) {
	v := Vec3{1, 2, 3}
	testing.expect_value(t, v, Vec3{1, 2, 3})

	// array arithmetic works out of the box
	testing.expect_value(t, v + Vec3{1, 1, 1}, Vec3{2, 3, 4})
	testing.expect_value(t, v * 2, Vec3{2, 4, 6})
	testing.expect_value(t, v / 2, Vec3{0.5, 1, 1.5})
}

@test atom_creation_test :: proc(t: ^testing.T) {
	atom := Atom{position = Vec3{0.25, 0.5, 0.75}, atomic_number = 6}
	testing.expect_value(t, atom.atomic_number, u16(6))
	testing.expect_value(t, atom.position, Vec3{0.25, 0.5, 0.75})
}

@test lattice_creation_test :: proc(t: ^testing.T) {
	lat := Lattice{a = Vec3{5.67, 0, 0}, b = Vec3{0, 5.67, 0}, c = Vec3{0, 0, 5.67}}
	testing.expect_value(t, lat.a[0], f32(5.67))
	testing.expect_value(t, lat.c[2], f32(5.67))
}

@test molecule_creation_test :: proc(t: ^testing.T) {
	mol := Molecule {
		lattice = Lattice{a = Vec3{1, 0, 0}, b = Vec3{0, 1, 0}, c = Vec3{0, 0, 1}},
	}
	append(&mol.atoms, Atom{position = Vec3{0, 0, 0}, atomic_number = 1})
	append(&mol.atoms, Atom{position = Vec3{0.5, 0.5, 0.5}, atomic_number = 8})
	defer delete(mol.atoms)

	testing.expect_value(t, len(mol.atoms), 2)
	testing.expect_value(t, mol.atoms[0].atomic_number, u16(1))
	testing.expect_value(t, mol.atoms[1].atomic_number, u16(8))
}
