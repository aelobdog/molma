// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package model

Vec3 :: [3]f32
CartVec3 :: distinct Vec3
FracVec3 :: distinct Vec3

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
}
