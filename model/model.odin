// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package model

Vec3 :: [3]f32

Atom :: struct {
	position:      Vec3,
	atomic_number: u16,
}

Lattice :: struct {
	a, b, c: Vec3,
}

Molecule :: struct {
	lattice: Lattice,
	atoms:   [dynamic]Atom,
}
