// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package model

import "core:math"
import "core:testing"

@test nearest_image_wraps_cross_boundary_test :: proc(t: ^testing.T) {
	lattice := Lattice{a = CartVec3{5.67, 0, 0}, b = CartVec3{0, 5.67, 0}, c = CartVec3{0, 0, 5.67}}
	from := FracVec3{0.9, 0.9, 0.9}
	to := FracVec3{0.1, 0.1, 0.1}
	want := CartVec3{0.2 * 5.67, 0.2 * 5.67, 0.2 * 5.67}
	expect_vec3_close(t, nearest_image_vector(lattice, from, to), want)
}

@test nearest_image_stays_put_test :: proc(t: ^testing.T) {
	lattice := Lattice{a = CartVec3{5.67, 0, 0}, b = CartVec3{0, 5.67, 0}, c = CartVec3{0, 0, 5.67}}
	from := FracVec3{0.25, 0.25, 0.25}
	to := FracVec3{0.4, 0.4, 0.4}
	want := CartVec3{0.15 * 5.67, 0.15 * 5.67, 0.15 * 5.67}
	expect_vec3_close(t, nearest_image_vector(lattice, from, to), want)
}

@test distance_pbc_periodic_identity_test :: proc(t: ^testing.T) {
	lattice := Lattice{a = CartVec3{5.67, 0, 0}, b = CartVec3{0, 5.67, 0}, c = CartVec3{0, 0, 5.67}}
	origin := FracVec3{0.3, 0.3, 0.3}

	expect_vec3_close(t, nearest_image_vector(lattice, origin, origin + FracVec3{1, 0, 0}), CartVec3{})
	expect_vec3_close(t, nearest_image_vector(lattice, origin, origin + FracVec3{0, 1, 0}), CartVec3{})
	expect_vec3_close(t, nearest_image_vector(lattice, origin, origin + FracVec3{0, 0, 1}), CartVec3{})

	shifted := nearest_image_vector(lattice, origin, origin + FracVec3{1.25, 0.5, -0.75})
	unshifted := nearest_image_vector(lattice, origin, origin + FracVec3{0.25, 0.5, 0.25})
	expect_vec3_close(t, shifted, unshifted)
}

@test distance_pbc_cubic_test :: proc(t: ^testing.T) {
	lattice := Lattice{a = CartVec3{5.67, 0, 0}, b = CartVec3{0, 5.67, 0}, c = CartVec3{0, 0, 5.67}}
	from := FracVec3{0.9, 0.9, 0.9}
	to := FracVec3{0.1, 0.1, 0.1}
	want := 0.2 * 5.67 * math.sqrt(f32(3))
	if math.abs(distance_pbc(lattice, from, to) - want) > 1e-4 {
		testing.expect(t, false, "distance_pbc mismatch")
	}
}

@test distance_pbc_symmetric_test :: proc(t: ^testing.T) {
	lattice := Lattice{a = CartVec3{3.75, -6.5, 0}, b = CartVec3{3.75, 6.5, 0}, c = CartVec3{0, 0, 7.06}}
	a := FracVec3{0.1, 0.9, 0.2}
	b := FracVec3{0.9, 0.1, 0.8}
	if math.abs(distance_pbc(lattice, a, b) - distance_pbc(lattice, b, a)) > 1e-5 {
		testing.expect(t, false, "distance_pbc must be symmetric")
	}
}
