// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

// Round-trip regression tests: parse -> write -> parse must be stable.
// The writer is lossy by design (6 decimal places, always cartesian),
// so comparisons use a small epsilon.

package main

import "core:os"
import "core:testing"
import rl "vendor:raylib"

roundtrip_file :: proc(t: ^testing.T, src, tmp: string, eps: f32 = 1e-4) {
	poscar, ok := poscar_parse(src)
	testing.expect(t, ok, src)
	if !ok do return
	defer delete(poscar.atoms)

	ok = poscar_write(tmp, poscar)
	testing.expect(t, ok, tmp)
	if !ok do return
	defer os.remove(tmp)

	reparsed, ok2 := poscar_parse(tmp)
	testing.expect(t, ok2, tmp)
	if !ok2 do return
	defer delete(reparsed.atoms)

	testing.expect_value(t, len(reparsed.atoms), len(poscar.atoms))

	for i in 0 ..< len(poscar.atoms) {
		testing.expect_value(t, reparsed.atoms[i].atomic_number, poscar.atoms[i].atomic_number)
		expect_v3_close(t, reparsed.atoms[i].position.xyz, poscar.atoms[i].position.xyz, eps)
	}
	for j in 0 ..< 3 {
		expect_v3_close(t, reparsed.lattice[j], poscar.lattice[j], eps)
	}
}

@test roundtrip_ge_test :: proc(t: ^testing.T) {
	roundtrip_file(t, "test-files/Ge.vasp", "roundtrip_ge_tmp.vasp")
}

@test roundtrip_ge7fecl_test :: proc(t: ^testing.T) {
	roundtrip_file(t, "test-files/Ge7FeCl.vasp", "roundtrip_fecl_tmp.vasp")
}

@test roundtrip_h2o_test :: proc(t: ^testing.T) {
	roundtrip_file(t, "test-files/H2O.vasp", "roundtrip_h2o_tmp.vasp")
}

@test roundtrip_b324_test :: proc(t: ^testing.T) {
	roundtrip_file(t, "test-files/B324.poscar", "roundtrip_b324_tmp.vasp")
}
