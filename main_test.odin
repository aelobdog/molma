// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

// Regression tests pinning current poscar_parse behavior.
// These document expected behavior so the refactor can be verified step by step.

package main

import "core:fmt"
import "core:math"
import "core:testing"
import rl "vendor:raylib"

expect_close :: proc(t: ^testing.T, got, want: f32, eps: f32 = 1e-4) {
	delta := math.abs(got - want)
	if delta > eps {
		testing.expect(t, false, fmt.tprintf("expected %v ± %v, got %v", want, eps, got))
	}
}

expect_v3_close :: proc(t: ^testing.T, got, want: rl.Vector3, eps: f32 = 1e-4) {
	expect_close(t, got.x, want.x, eps)
	expect_close(t, got.y, want.y, eps)
	expect_close(t, got.z, want.z, eps)
}

expect_parse_ok :: proc(t: ^testing.T, path: string) -> Poscar {
	poscar, ok := poscar_parse(path)
	if !ok {
		testing.expect(t, false, fmt.tprintf("poscar_parse(%q) failed", path))
	}
	return poscar
}

count_atoms_of_number :: proc(atoms: []Atom, number: i32) -> int {
	count := 0
	for atom in atoms do if atom.atomic_number == number do count += 1
	return count
}

@test parse_ge_cartesian_test :: proc(t: ^testing.T) {
	poscar := expect_parse_ok(t, "test-files/Ge.vasp")
	defer delete(poscar.atoms)

	testing.expect_value(t, len(poscar.atoms), 8)
	testing.expect_value(t, count_atoms_of_number(poscar.atoms[:], 32), 8)

	expect_v3_close(t, poscar.lattice[0], rl.Vector3{5.6748542786, 0, 0})
	expect_v3_close(t, poscar.lattice[1], rl.Vector3{0, 5.6748542786, 0})
	expect_v3_close(t, poscar.lattice[2], rl.Vector3{0, 0, 5.6748542786})

	expect_v3_close(t, poscar.atoms[0].position.xyz, rl.Vector3{0, 0, 2.837427139})
	expect_v3_close(t, poscar.atoms[7].position.xyz, rl.Vector3{4.256140709, 4.256140709, 4.256140709})
	testing.expect_value(t, poscar.atoms[0].symbol, "ge")
}

@test parse_ge7_tabs_test :: proc(t: ^testing.T) {
	poscar := expect_parse_ok(t, "test-files/Ge7.vasp")
	defer delete(poscar.atoms)

	testing.expect_value(t, len(poscar.atoms), 7)
	testing.expect_value(t, count_atoms_of_number(poscar.atoms[:], 32), 7)
	expect_v3_close(t, poscar.atoms[0].position.xyz, rl.Vector3{0, 0, 2.83742714})
}

@test parse_multispecies_sorted_test :: proc(t: ^testing.T) {
	poscar := expect_parse_ok(t, "test-files/Ge7FeCl.vasp")
	defer delete(poscar.atoms)

	testing.expect_value(t, len(poscar.atoms), 9)
	testing.expect_value(t, count_atoms_of_number(poscar.atoms[:], 17), 1) // cl
	testing.expect_value(t, count_atoms_of_number(poscar.atoms[:], 26), 1) // fe
	testing.expect_value(t, count_atoms_of_number(poscar.atoms[:], 32), 7) // ge

	// atoms are sorted by symbol: cl, fe, ge...
	testing.expect_value(t, poscar.atoms[0].atomic_number, 17)
	testing.expect_value(t, poscar.atoms[1].atomic_number, 26)
	testing.expect_value(t, poscar.atoms[2].atomic_number, 32)
	testing.expect_value(t, poscar.atoms[8].atomic_number, 32)
	expect_v3_close(t, poscar.atoms[0].position.xyz, rl.Vector3{1, 1, 1})
	expect_v3_close(t, poscar.atoms[1].position.xyz, rl.Vector3{4.25614071, 4.25614071, 4.25614071})
}

@test parse_h2o_direct_test :: proc(t: ^testing.T) {
	poscar := expect_parse_ok(t, "test-files/H2O.vasp")
	defer delete(poscar.atoms)

	testing.expect_value(t, len(poscar.atoms), 36)
	testing.expect_value(t, count_atoms_of_number(poscar.atoms[:], 1), 24) // h
	testing.expect_value(t, count_atoms_of_number(poscar.atoms[:], 8), 12) // o

	// sorted: 24 h then 12 o
	testing.expect_value(t, poscar.atoms[0].atomic_number, 1)
	testing.expect_value(t, poscar.atoms[23].atomic_number, 1)
	testing.expect_value(t, poscar.atoms[24].atomic_number, 8)

	expect_v3_close(t, poscar.lattice[0], rl.Vector3{3.7521103059553962, -6.4988456855175496, 0}, 1e-6)

	// direct -> cartesian conversion of the first H.
	// Cross-checked against H2O.POSCAR.vasp, the same system in cartesian.
	expect_v3_close(t, poscar.atoms[0].position.xyz, rl.Vector3{2.521547306, 0, 4.915817919}, 1e-4)
}

@test parse_b324_extra_columns_test :: proc(t: ^testing.T) {
	poscar := expect_parse_ok(t, "test-files/B324.poscar")
	defer delete(poscar.atoms)

	testing.expect_value(t, len(poscar.atoms), 324)
	testing.expect_value(t, count_atoms_of_number(poscar.atoms[:], 5), 324) // b

	// coordinate lines carry a 4th column (B0+); the parser must ignore it.
	frac := rl.Vector3{0.1739849333333330, 0.6686303166666661, 0.8012408566666661}
	want := frac.x * poscar.lattice[0] + frac.y * poscar.lattice[1] + frac.z * poscar.lattice[2]
	expect_v3_close(t, poscar.atoms[0].position.xyz, want, 1e-4)
}

@test parse_vasp4_no_species_names_fails_test :: proc(t: ^testing.T) {
	// VASP4 files carry counts without species names; parse must fail gracefully.
	_, ok := poscar_parse("test-files/Li2FeSiO4.vasp")
	testing.expect(t, !ok, "VASP4 files without a species-name line should fail, not panic")
}
