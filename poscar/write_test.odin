// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package poscar

import "core:os"
import "core:strings"
import "core:testing"
import "../model"

roundtrip :: proc(t: ^testing.T, src, tmp: string, eps: f32 = 1e-4) {
	mol, ok := parse(src)
	testing.expect(t, ok, src)
	if !ok {
		return
	}
	defer delete(mol.atoms)

	ok = write(tmp, mol)
	testing.expect(t, ok, tmp)
	if !ok {
		return
	}
	defer os.remove(tmp)

	reparsed, ok2 := parse(tmp)
	testing.expect(t, ok2, tmp)
	if !ok2 {
		return
	}
	defer delete(reparsed.atoms)

	testing.expect_value(t, len(reparsed.atoms), len(mol.atoms))
	for i in 0 ..< len(mol.atoms) {
		testing.expect_value(t, reparsed.atoms[i].atomic_number, mol.atoms[i].atomic_number)
		expect_vec_close(t, reparsed.atoms[i].position, mol.atoms[i].position, eps)
	}
	expect_vec_close(t, reparsed.lattice.a, mol.lattice.a, eps)
	expect_vec_close(t, reparsed.lattice.b, mol.lattice.b, eps)
	expect_vec_close(t, reparsed.lattice.c, mol.lattice.c, eps)
}

@test roundtrip_ge_test :: proc(t: ^testing.T) {
	roundtrip(t, "test-files/Ge.vasp", "rt_ge_tmp.vasp")
}

@test roundtrip_h2o_test :: proc(t: ^testing.T) {
	roundtrip(t, "test-files/H2O.vasp", "rt_h2o_tmp.vasp")
}

@test roundtrip_ge7fecl_test :: proc(t: ^testing.T) {
	roundtrip(t, "test-files/Ge7FeCl.vasp", "rt_fecl_tmp.vasp")
}

@test roundtrip_b324_test :: proc(t: ^testing.T) {
	roundtrip(t, "test-files/B324.poscar", "rt_b324_tmp.vasp")
}

@test write_emits_direct_and_species_test :: proc(t: ^testing.T) {
	mol := model.Molecule {
		lattice = model.Lattice {
			a = model.CartVec3{10, 0, 0},
			b = model.CartVec3{0, 10, 0},
			c = model.CartVec3{0, 0, 10},
		},
	}
	defer delete(mol.atoms)
	model.add_atom(&mol, model.Atom{position = model.FracVec3{0.25, 0.5, 0.5}, atomic_number = 1})
	model.add_atom(&mol, model.Atom{position = model.FracVec3{0.75, 0.75, 0.75}, atomic_number = 8})

	ok := write("fmt_tmp.vasp", mol)
	testing.expect(t, ok)
	defer os.remove("fmt_tmp.vasp")

	data, _ := os.read_entire_file("fmt_tmp.vasp", context.temp_allocator)
	text := string(data)
	testing.expect(t, strings.contains(text, "h\t"))
	testing.expect(t, strings.contains(text, "o\t"))
	testing.expect(t, strings.contains(text, "1\t1\t"))
	testing.expect(t, strings.contains(text, "Direct"))
}

@test write_wraps_fractional_test :: proc(t: ^testing.T) {
	mol := model.Molecule {
		lattice = model.Lattice {
			a = model.CartVec3{10, 0, 0},
			b = model.CartVec3{0, 10, 0},
			c = model.CartVec3{0, 0, 10},
		},
	}
	defer delete(mol.atoms)
	model.add_atom(&mol, model.Atom{position = model.FracVec3{1.25, 0.5, 0.5}, atomic_number = 1})

	ok := write("wrap_tmp.vasp", mol)
	testing.expect(t, ok)
	defer os.remove("wrap_tmp.vasp")

	reparsed, ok2 := parse("wrap_tmp.vasp")
	testing.expect(t, ok2)
	defer delete(reparsed.atoms)
	expect_vec_close(t, reparsed.atoms[0].position, model.FracVec3{0.25, 0.5, 0.5})
}

@test write_rejects_invalid_atom_test :: proc(t: ^testing.T) {
	mol := model.Molecule {
		lattice = model.Lattice {
			a = model.CartVec3{10, 0, 0},
			b = model.CartVec3{0, 10, 0},
			c = model.CartVec3{0, 0, 10},
		},
	}
	defer delete(mol.atoms)
	model.add_atom(&mol, model.Atom{position = model.FracVec3{0, 0, 0}, atomic_number = 0})

	ok := write("invalid_tmp.vasp", mol)
	testing.expect(t, !ok)
	defer os.remove("invalid_tmp.vasp")
}
