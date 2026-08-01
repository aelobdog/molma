// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package model

import "core:math"
import "core:math/linalg"

minimum_image_vector :: proc(lattice: Lattice, from, to: Vec3) -> Vec3 {
	d := to - from
	for i in 0 ..< 3 {
		d[i] -= math.round(d[i])
	}
	return cartesian(lattice, d)
}

distance_pbc :: proc(lattice: Lattice, from, to: Vec3) -> f32 {
	return linalg.length(minimum_image_vector(lattice, from, to))
}
