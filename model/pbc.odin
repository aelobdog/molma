// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package model

import "core:math"
import "core:math/linalg"

nearest_image_delta :: proc(from, to: FracVec3) -> (delta: FracVec3, shift: [3]i8) {
	delta = to - from
	for k in 0 ..< 3 {
		r := math.round(delta[k])
		shift[k] = i8(-r)
		delta[k] -= r
	}
	return
}

nearest_image_vector :: proc(lattice: Lattice, from, to: FracVec3) -> CartVec3 {
	delta, _ := nearest_image_delta(from, to)
	return cartesian(lattice, delta)
}

distance_pbc :: proc(lattice: Lattice, from, to: FracVec3) -> f32 {
	return linalg.length(nearest_image_vector(lattice, from, to))
}
