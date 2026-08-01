// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package model

import "core:math"
import "core:math/linalg"

volume :: proc(lattice: Lattice) -> f32 {
	return linalg.dot(lattice.a, linalg.cross(lattice.b, lattice.c))
}

cartesian :: proc(lattice: Lattice, frac: FracVec3) -> CartVec3 {
	return frac[0] * lattice.a + frac[1] * lattice.b + frac[2] * lattice.c
}

fractional :: proc(lattice: Lattice, cart: CartVec3) -> (FracVec3, bool) {
	v := volume(lattice)
	if v == 0 {
		return FracVec3{}, false
	}
	// TODO: near-zero cell volumes are well-defined but numerically ill-conditioned.
	bc := linalg.cross(lattice.b, lattice.c)
	ca := linalg.cross(lattice.c, lattice.a)
	ab := linalg.cross(lattice.a, lattice.b)
	return FracVec3 {
		linalg.dot(cart, bc) / v,
		linalg.dot(cart, ca) / v,
		linalg.dot(cart, ab) / v,
	}, true
}

wrap_fractional :: proc(frac: FracVec3) -> FracVec3 {
	return FracVec3 {
		frac[0] - math.floor(frac[0]),
		frac[1] - math.floor(frac[1]),
		frac[2] - math.floor(frac[2]),
	}
}
