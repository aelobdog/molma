// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package model

Bond :: struct {
	a, b: i32,
}

compute_bonds :: proc(atoms: []Atom, lattice: Lattice, tolerance: f32 = 0.2) -> [dynamic]Bond {
	bonds := make([dynamic]Bond)
	// TODO: spatial hash for cells above ~10^4 atoms
	for i in 0 ..< len(atoms) {
		ei, _ := lookup_by_number(atoms[i].atomic_number)
		for j in i + 1 ..< len(atoms) {
			ej, _ := lookup_by_number(atoms[j].atomic_number)
			cutoff := ei.cov_radius_ang + ej.cov_radius_ang + tolerance
			if distance_pbc(lattice, atoms[i].position, atoms[j].position) <= cutoff {
				append(&bonds, Bond{a = i32(i), b = i32(j)})
			}
		}
	}
	return bonds
}
