// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package model

import "core:math"
import "core:math/linalg"

volume :: proc(lattice: Lattice) -> f32 {
	return linalg.dot(lattice.a, linalg.cross(lattice.b, lattice.c))
}

cartesian :: proc(lattice: Lattice, frac: Vec3) -> Vec3 {
	return frac.x * lattice.a + frac.y * lattice.b + frac.z * lattice.c
}

fractional :: proc(lattice: Lattice, cart: Vec3) -> (Vec3, bool) {
	v := volume(lattice)
	if v == 0 {
		return Vec3{}, false
	}
	// TODO: near-zero cell volumes are well-defined but numerically ill-conditioned.
	bc := linalg.cross(lattice.b, lattice.c)
	ca := linalg.cross(lattice.c, lattice.a)
	ab := linalg.cross(lattice.a, lattice.b)
	return Vec3 {
		linalg.dot(cart, bc) / v,
		linalg.dot(cart, ca) / v,
		linalg.dot(cart, ab) / v,
	}, true
}

wrap_fractional :: proc(frac: Vec3) -> Vec3 {
	return Vec3 {
		frac.x - math.floor(frac.x),
		frac.y - math.floor(frac.y),
		frac.z - math.floor(frac.z),
	}
}
