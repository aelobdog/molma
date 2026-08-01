// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package model

import "core:testing"

@test lookup_by_number_hydrogen_test :: proc(t: ^testing.T) {
	e, ok := lookup_by_number(1)
	testing.expect(t, ok)
	testing.expect_value(t, e.symbol, "h")
	testing.expect_value(t, e.name, "Hydrogen")
	testing.expect_value(t, e.cov_radius_ang, f32(0.31))
	testing.expect_value(t, e.vdw_radius_ang, f32(1.20))
}

@test lookup_by_number_iron_test :: proc(t: ^testing.T) {
	e, ok := lookup_by_number(26)
	testing.expect(t, ok)
	testing.expect_value(t, e.symbol, "fe")
	testing.expect_value(t, e.cov_radius_ang, f32(1.32))
	testing.expect_value(t, e.color, u32(0xE06633FF))
}

@test lookup_by_number_last_element_test :: proc(t: ^testing.T) {
	e, ok := lookup_by_number(118)
	testing.expect(t, ok)
	testing.expect_value(t, e.symbol, "og")
}

@test lookup_by_number_invalid_test :: proc(t: ^testing.T) {
	_, ok := lookup_by_number(0)
	testing.expect(t, !ok)
	_, ok = lookup_by_number(119)
	testing.expect(t, !ok)
	_, ok = lookup_by_number(500)
	testing.expect(t, !ok)
}

@test lookup_by_symbol_test :: proc(t: ^testing.T) {
	e, n := lookup_by_symbol("c")
	testing.expect_value(t, n, u16(6))
	testing.expect_value(t, e.name, "Carbon")

	e, n = lookup_by_symbol("ge")
	testing.expect_value(t, n, u16(32))
	testing.expect_value(t, e.symbol, "ge")
}

@test lookup_by_symbol_miss_test :: proc(t: ^testing.T) {
	_, n := lookup_by_symbol("C")
	testing.expect_value(t, n, u16(0))

	_, n = lookup_by_symbol("zz")
	testing.expect_value(t, n, u16(0))

	_, n = lookup_by_symbol("")
	testing.expect_value(t, n, u16(0))
}

@test is_valid_symbol_test :: proc(t: ^testing.T) {
	testing.expect(t, is_valid_symbol("h"))
	testing.expect(t, is_valid_symbol("og"))
	testing.expect(t, !is_valid_symbol("H"))
	testing.expect(t, !is_valid_symbol("xx"))
}
