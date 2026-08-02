// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package render

import "core:math"
import "core:testing"
import "../model"

@test compute_groups_finds_species_boundaries_test :: proc(t: ^testing.T) {
	atoms := []model.Atom {
		{atomic_number = 1},
		{atomic_number = 1},
		{atomic_number = 6},
		{atomic_number = 8},
		{atomic_number = 8},
		{atomic_number = 8},
	}
	groups, species := compute_groups(atoms)
	defer delete(groups)
	defer delete(species)

	testing.expect_value(t, len(groups), 3)
	testing.expect_value(t, groups[0], i32(0))
	testing.expect_value(t, groups[1], i32(2))
	testing.expect_value(t, groups[2], i32(3))
	testing.expect_value(t, len(species), 3)
	testing.expect_value(t, species[0], u16(1))
	testing.expect_value(t, species[1], u16(6))
	testing.expect_value(t, species[2], u16(8))
}

@test compute_groups_empty_test :: proc(t: ^testing.T) {
	groups, species := compute_groups(nil)
	defer delete(groups)
	defer delete(species)

	testing.expect_value(t, len(groups), 0)
	testing.expect_value(t, len(species), 0)
}

@test build_group_transforms_places_and_scales_test :: proc(t: ^testing.T) {
	atoms := []model.Atom {
		{position = model.FracVec3{0.5, 0.5, 0.5}, atomic_number = 1},
		{position = model.FracVec3{0.25, 0.5, 0.5}, atomic_number = 1},
	}
	lattice := model.Lattice {
		a = model.CartVec3{10, 0, 0},
		b = model.CartVec3{0, 10, 0},
		c = model.CartVec3{0, 0, 10},
	}

	group := build_group_transforms(atoms, lattice, 0, 2)
	defer delete(group)

	testing.expect_value(t, len(group), 2)
	// hydrogen radius 0.31 * RADIUS_PCT -> uniform scale
	radius := f32(0.31) * RADIUS_PCT
	testing.expect_value(t, group[0][0][0], radius)
	testing.expect_value(t, group[0][1][1], radius)
	testing.expect_value(t, group[0][2][2], radius)
	// atom 0 at cell center -> (5, 5, 5); raylib translation at row 3
	testing.expect_value(t, group[0][0][3], f32(5))
	testing.expect_value(t, group[0][1][3], f32(5))
	testing.expect_value(t, group[0][2][3], f32(5))
	// atom 1 at x = 2.5
	testing.expect_value(t, group[1][0][3], f32(2.5))
}

@test build_bond_transforms_along_y_test :: proc(t: ^testing.T) {
	atoms := []model.Atom {
		{position = model.FracVec3{0, 0, 0}, atomic_number = 1},
		{position = model.FracVec3{0, 0.08, 0}, atomic_number = 1},
	}
	lattice := model.Lattice {
		a = model.CartVec3{10, 0, 0},
		b = model.CartVec3{0, 10, 0},
		c = model.CartVec3{0, 0, 10},
	}

	transforms := build_bond_transforms(atoms, lattice)
	defer delete(transforms)

	testing.expect_value(t, len(transforms), 1)
	// bond along +Y: length encoded on the Y diagonal
	if math.abs(transforms[0][1][1] - 0.8) > 1e-5 {
		testing.expect(t, false, "bond length should be 0.8")
	}
	// cylinder base at p1
	testing.expect_value(t, transforms[0][0][3], f32(0))
	testing.expect_value(t, transforms[0][1][3], f32(0))
	testing.expect_value(t, transforms[0][2][3], f32(0))
}

@test cross_boundary_bonds_are_skipped_test :: proc(t: ^testing.T) {
	atoms := []model.Atom {
		{position = model.FracVec3{0.92, 0.5, 0.5}, atomic_number = 1},
		{position = model.FracVec3{0, 0.5, 0.5}, atomic_number = 1},
	}
	lattice := model.Lattice {
		a = model.CartVec3{10, 0, 0},
		b = model.CartVec3{0, 10, 0},
		c = model.CartVec3{0, 0, 10},
	}

	transforms := build_bond_transforms(atoms, lattice)
	defer delete(transforms)

	testing.expect_value(t, len(transforms), 0)
}

@test orbit_and_zoom_affect_camera_test :: proc(t: ^testing.T) {
	view: View
	mol := model.Molecule{}
	reframe(&view, &mol, 800, 600)
	view.origin = {1, 2, 3}
	view.max_distance = 2

	// default: camera above the origin along +z
	update_view(&view, 800, 600)
	testing.expect_value(t, view.camera.position, [3]f32{1, 2, 13})
	testing.expect_value(t, view.camera.fovy, f32(10))

	orbit(&view, 0, 0) // no-op drag
	testing.expect_value(t, view.yaw, f32(0))

	zoom(&view, 2)
	testing.expect_value(t, view.zoom, f32(0.8))
	update_view(&view, 800, 600)
	testing.expect_value(t, view.camera.fovy, f32(8))
}

@test orbit_rotates_camera_position_test :: proc(t: ^testing.T) {
	view: View
	view.origin = {0, 0, 0}
	view.max_distance = 2
	view.zoom = 1
	view.yaw = math.PI / 2
	update_view(&view, 800, 600)

	// yaw 90 degrees: camera swings to +x
	if math.abs(view.camera.position[0] - 10) > 1e-4 {
		testing.expect(t, false, "camera should orbit to +x")
	}
	if math.abs(view.camera.position[2]) > 1e-4 {
		testing.expect(t, false, "z should be zero after 90 degree yaw")
	}
}

@test reframe_empty_molecule_test :: proc(t: ^testing.T) {
	view: View
	mol := model.Molecule{}
	reframe(&view, &mol, 800, 600)

	testing.expect_value(t, view.origin, [3]f32{0, 0, 0})
	testing.expect_value(t, view.max_distance, f32(1))
	testing.expect_value(t, view.camera.fovy, f32(5))
}

@test reframe_single_atom_test :: proc(t: ^testing.T) {
	view: View
	mol := model.Molecule {
		lattice = model.Lattice {
			a = model.CartVec3{10, 0, 0},
			b = model.CartVec3{0, 10, 0},
			c = model.CartVec3{0, 0, 10},
		},
	}
	defer delete(mol.atoms)
	model.add_atom(&mol, model.Atom{position = model.FracVec3{0.5, 0.5, 0.5}, atomic_number = 1})

	reframe(&view, &mol, 800, 600)

	// hydrogen at the cell center: origin (5,5,5), max = cov radius (0.31)
	testing.expect_value(t, view.origin, [3]f32{5, 5, 5})
	if view.max_distance < 0.3 || view.max_distance > 0.32 {
		testing.expect(t, false, "max_distance should be the hydrogen covalent radius")
	}
}
