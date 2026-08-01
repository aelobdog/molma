// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package model

import "core:fmt"
import "core:math"
import "core:testing"

expect_vec3_close :: proc(t: ^testing.T, got, want: Vec3, eps: f32 = 1e-5) {
	for i in 0 ..< 3 {
		if math.abs(got[i] - want[i]) > eps {
			testing.expect(
				t,
				false,
				fmt.tprintf("component %d: got %v, want %v ± %v", i, got[i], want[i], eps),
			)
		}
	}
}

@test volume_cubic_test :: proc(t: ^testing.T) {
	lattice := Lattice{a = Vec3{5.67, 0, 0}, b = Vec3{0, 5.67, 0}, c = Vec3{0, 0, 5.67}}
	want := f32(5.67 * 5.67 * 5.67)
	if math.abs(volume(lattice) - want) > 1e-3 {
		testing.expect(t, false, fmt.tprintf("got %v, want %v", volume(lattice), want))
	}
}

@test cartesian_cubic_test :: proc(t: ^testing.T) {
	lattice := Lattice{a = Vec3{5.67, 0, 0}, b = Vec3{0, 5.67, 0}, c = Vec3{0, 0, 5.67}}
	frac := Vec3{0.25, 0.5, 0.75}
	want := Vec3{5.67 * 0.25, 5.67 * 0.5, 5.67 * 0.75}
	expect_vec3_close(t, cartesian(lattice, frac), want)
}

@test fractional_cubic_test :: proc(t: ^testing.T) {
	lattice := Lattice{a = Vec3{5.67, 0, 0}, b = Vec3{0, 5.67, 0}, c = Vec3{0, 0, 5.67}}
	cart := Vec3{1.4175, 2.835, 4.2525}
	want := Vec3{0.25, 0.5, 0.75}
	got, ok := fractional(lattice, cart)
	testing.expect(t, ok)
	expect_vec3_close(t, got, want)
}

@test cartesian_h2o_test :: proc(t: ^testing.T) {
	lattice := Lattice {
		a = Vec3{3.7521103059553962, -6.4988456855175496, 0},
		b = Vec3{3.7521103059553962, 6.4988456855175496, 0},
		c = Vec3{0, 0, 7.0626434800000002},
	}
	frac := Vec3{0.33601722, 0.33601722, 0.69603087}
	// cross-checked against H2O.POSCAR.vasp, the same system in cartesian
	want := Vec3{2.521547306, 0, 4.915817919}
	expect_vec3_close(t, cartesian(lattice, frac), want, 1e-4)
}

@test roundtrip_test :: proc(t: ^testing.T) {
	cubic := Lattice{a = Vec3{5.67, 0, 0}, b = Vec3{0, 5.67, 0}, c = Vec3{0, 0, 5.67}}
	h2o := Lattice {
		a = Vec3{3.7521103059553962, -6.4988456855175496, 0},
		b = Vec3{3.7521103059553962, 6.4988456855175496, 0},
		c = Vec3{0, 0, 7.0626434800000002},
	}
	frac := Vec3{0.1739849333333330, 0.6686303166666661, 0.8012408566666661}
	lattices := [2]Lattice{cubic, h2o}
	for lattice in lattices {
		back, ok := fractional(lattice, cartesian(lattice, frac))
		testing.expect(t, ok)
		expect_vec3_close(t, back, frac)
	}
}

@test fractional_degenerate_cell_test :: proc(t: ^testing.T) {
	flat := Lattice{a = Vec3{1, 0, 0}, b = Vec3{0, 1, 0}, c = Vec3{0, 0, 0}}
	_, ok := fractional(flat, Vec3{1, 1, 1})
	testing.expect(t, !ok, "degenerate cells must not produce a fractional coordinate")
}

@test wrap_fractional_test :: proc(t: ^testing.T) {
	expect_vec3_close(t, wrap_fractional(Vec3{1.25, -0.5, 2.0}), Vec3{0.25, 0.5, 0})
	expect_vec3_close(t, wrap_fractional(Vec3{0.5, 0.0, -1.0}), Vec3{0.5, 0, 0})
}
