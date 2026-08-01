// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package poscar

import "core:fmt"
import "core:math"
import "core:testing"
import "../model"

expect_close :: proc(t: ^testing.T, got, want: f32, eps: f32 = 1e-4) {
	if math.abs(got - want) > eps {
		testing.expect(t, false, fmt.tprintf("got %v, want %v ± %v", got, want, eps))
	}
}

expect_vec_close :: proc(
	t: ^testing.T,
	got, want: $V,
	eps: f32 = 1e-5,
) where V == model.Vec3 || V == model.CartVec3 || V == model.FracVec3 {
	for i in 0 ..< 3 {
		expect_close(t, got[i], want[i], eps)
	}
}

count_atoms_of_number :: proc(atoms: []model.Atom, number: u16) -> int {
	count := 0
	for atom in atoms do if atom.atomic_number == number do count += 1
	return count
}

@test parse_ge_cartesian_test :: proc(t: ^testing.T) {
	mol, ok := parse("test-files/Ge.vasp")
	testing.expect(t, ok)
	defer delete(mol.atoms)

	testing.expect_value(t, len(mol.atoms), 8)
	testing.expect_value(t, count_atoms_of_number(mol.atoms[:], 32), 8)
	testing.expect_value(t, mol.version, u64(0))

	expect_vec_close(t, mol.lattice.a, model.CartVec3{5.6748542786, 0, 0}, 1e-6)

	expect_vec_close(t, mol.atoms[0].position, model.FracVec3{0, 0, 0.5})
	expect_vec_close(t, mol.atoms[7].position, model.FracVec3{0.75, 0.75, 0.75})
}

@test parse_h2o_direct_test :: proc(t: ^testing.T) {
	mol, ok := parse("test-files/H2O.vasp")
	testing.expect(t, ok)
	defer delete(mol.atoms)

	testing.expect_value(t, len(mol.atoms), 36)
	testing.expect_value(t, count_atoms_of_number(mol.atoms[:], 1), 24)
	testing.expect_value(t, count_atoms_of_number(mol.atoms[:], 8), 12)

	expect_vec_close(t, mol.lattice.a, model.CartVec3{3.7521103059553962, -6.4988456855175496, 0}, 1e-6)

	expect_vec_close(t, mol.atoms[0].position, model.FracVec3{0.33601722, 0.33601722, 0.69603087})
}

@test parse_ge7fecl_sorted_test :: proc(t: ^testing.T) {
	mol, ok := parse("test-files/Ge7FeCl.vasp")
	testing.expect(t, ok)
	defer delete(mol.atoms)

	testing.expect_value(t, len(mol.atoms), 9)
	testing.expect_value(t, count_atoms_of_number(mol.atoms[:], 17), 1) // cl
	testing.expect_value(t, count_atoms_of_number(mol.atoms[:], 26), 1) // fe
	testing.expect_value(t, count_atoms_of_number(mol.atoms[:], 32), 7) // ge

	testing.expect_value(t, mol.atoms[0].atomic_number, u16(17))
	testing.expect_value(t, mol.atoms[1].atomic_number, u16(26))
	testing.expect_value(t, mol.atoms[2].atomic_number, u16(32))

	// cartesian (1,1,1) in a 5.67485428 cell
	expect_vec_close(t, mol.atoms[0].position, model.FracVec3{0.1762, 0.1762, 0.1762}, 1e-3)
	expect_vec_close(t, mol.atoms[1].position, model.FracVec3{0.75, 0.75, 0.75})
	expect_vec_close(t, mol.atoms[2].position, model.FracVec3{0.25, 0.25, 0.75})
}

@test parse_b324_test :: proc(t: ^testing.T) {
	mol, ok := parse("test-files/B324.poscar")
	testing.expect(t, ok)
	defer delete(mol.atoms)

	testing.expect_value(t, len(mol.atoms), 324)
	testing.expect_value(t, count_atoms_of_number(mol.atoms[:], 5), 324)

	expect_vec_close(t, mol.atoms[0].position, model.FracVec3{0.1739849333333330, 0.6686303166666661, 0.8012408566666661})
}

@test parse_vasp4_fails_gracefully_test :: proc(t: ^testing.T) {
	_, ok := parse("test-files/Li2FeSiO4.vasp")
	testing.expect(t, !ok)
}

@test parse_missing_file_fails_test :: proc(t: ^testing.T) {
	_, ok := parse("test-files/does_not_exist.vasp")
	testing.expect(t, !ok)
}
