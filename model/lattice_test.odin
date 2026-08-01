// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package model

import "core:fmt"
import "core:math"
import "core:testing"

expect_vec3_close :: proc(
	t: ^testing.T,
	got, want: $V,
	eps: f32 = 1e-5,
) where V == Vec3 || V == CartVec3 || V == FracVec3 {
	for i in 0 ..< 3 {
		if math.abs(f32(got[i]) - f32(want[i])) > eps {
			testing.expect(
				t,
				false,
				fmt.tprintf("component %d: got %v, want %v ± %v", i, got[i], want[i], eps),
			)
		}
	}
}

@test volume_cubic_test :: proc(t: ^testing.T) {
	lattice := Lattice{a = CartVec3{5.67, 0, 0}, b = CartVec3{0, 5.67, 0}, c = CartVec3{0, 0, 5.67}}
	want := f32(5.67 * 5.67 * 5.67)
	if math.abs(volume(lattice) - want) > 1e-3 {
		testing.expect(t, false, fmt.tprintf("got %v, want %v", volume(lattice), want))
	}
}

@test cartesian_cubic_test :: proc(t: ^testing.T) {
	lattice := Lattice{a = CartVec3{5.67, 0, 0}, b = CartVec3{0, 5.67, 0}, c = CartVec3{0, 0, 5.67}}
	frac := FracVec3{0.25, 0.5, 0.75}
	want := CartVec3{5.67 * 0.25, 5.67 * 0.5, 5.67 * 0.75}
	expect_vec3_close(t, cartesian(lattice, frac), want)
}

@test fractional_cubic_test :: proc(t: ^testing.T) {
	lattice := Lattice{a = CartVec3{5.67, 0, 0}, b = CartVec3{0, 5.67, 0}, c = CartVec3{0, 0, 5.67}}
	cart := CartVec3{1.4175, 2.835, 4.2525}
	want := FracVec3{0.25, 0.5, 0.75}
	got, ok := fractional(lattice, cart)
	testing.expect(t, ok)
	expect_vec3_close(t, got, want)
}

@test cartesian_h2o_test :: proc(t: ^testing.T) {
	lattice := Lattice {
		a = CartVec3{3.7521103059553962, -6.4988456855175496, 0},
		b = CartVec3{3.7521103059553962, 6.4988456855175496, 0},
		c = CartVec3{0, 0, 7.0626434800000002},
	}
	frac := FracVec3{0.33601722, 0.33601722, 0.69603087}
	want := CartVec3{2.521547306, 0, 4.915817919}
	expect_vec3_close(t, cartesian(lattice, frac), want, 1e-4)
}

@test roundtrip_test :: proc(t: ^testing.T) {
	cubic := Lattice{a = CartVec3{5.67, 0, 0}, b = CartVec3{0, 5.67, 0}, c = CartVec3{0, 0, 5.67}}
	h2o := Lattice {
		a = CartVec3{3.7521103059553962, -6.4988456855175496, 0},
		b = CartVec3{3.7521103059553962, 6.4988456855175496, 0},
		c = CartVec3{0, 0, 7.0626434800000002},
	}
	frac := FracVec3{0.1739849333333330, 0.6686303166666661, 0.8012408566666661}
	lattices := [2]Lattice{cubic, h2o}
	for lattice in lattices {
		back, ok := fractional(lattice, cartesian(lattice, frac))
		testing.expect(t, ok)
		expect_vec3_close(t, back, frac)
	}
}

@test fractional_degenerate_cell_test :: proc(t: ^testing.T) {
	flat := Lattice{a = CartVec3{1, 0, 0}, b = CartVec3{0, 1, 0}, c = CartVec3{0, 0, 0}}
	_, ok := fractional(flat, CartVec3{1, 1, 1})
	testing.expect(t, !ok, "degenerate cells must not produce a fractional coordinate")
}

@test wrap_fractional_test :: proc(t: ^testing.T) {
	expect_vec3_close(t, wrap_fractional(FracVec3{1.25, -0.5, 2.0}), FracVec3{0.25, 0.5, 0})
	expect_vec3_close(t, wrap_fractional(FracVec3{0.5, 0.0, -1.0}), FracVec3{0.5, 0, 0})
}
