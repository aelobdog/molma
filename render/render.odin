// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

// Package render turns a model.Molecule into a 3D scene. It talks
// only to backend; the model stays pure.
package render

import "../backend"
import "core:math/linalg"
import "../model"

RADIUS_PCT :: 0.6
BOND_RADIUS :: 0.1

LATTICE_COLOR :: backend.Color{0x4a, 0xb0, 0x4a, 0xff}
BOND_COLOR :: backend.Color{0xc8, 0xc8, 0xc8, 0xff}

View :: struct {
	origin:       [3]f32,
	max_distance: f32,
	camera:       backend.Camera,
}

reframe :: proc(view: ^View, mol: ^model.Molecule, window_w, window_h: i32) {
	n := len(mol.atoms)
	if n == 0 {
		view.origin = {0, 0, 0}
		view.max_distance = 1
	} else {
		sum: model.CartVec3
		for atom in mol.atoms {
			sum += model.cartesian(mol.lattice, atom.position)
		}
		view.origin = model.Vec3(sum) / f32(n)

		max_dist := f32(0)
		for atom in mol.atoms {
			c := model.Vec3(model.cartesian(mol.lattice, atom.position))
			e, _ := model.lookup_by_number(atom.atomic_number)
			d := linalg.length(c - view.origin) + e.cov_radius_ang
			max_dist = max(max_dist, d)
		}
		view.max_distance = max_dist
	}
	update_view(view, window_w, window_h)
}

update_view :: proc(view: ^View, window_w, window_h: i32) {
	aspect := f32(window_w) / max(f32(window_h), 1)
	vertical := 5 * view.max_distance
	view.camera = backend.Camera {
		position = {view.origin[0], view.origin[1], view.origin[2] + 5 * view.max_distance},
		target   = view.origin,
		up       = {0, 1, 0},
		fovy     = max(vertical, vertical / aspect),
	}
}

Renderer :: struct {
	window:          ^backend.Window,
	synced_version:  u64,
	sphere:          backend.Mesh,
	cylinder:        backend.Mesh,
	bond_material:   backend.Material,
	groups:          [dynamic]i32,
	species:         [dynamic]u16,
	transforms:      [dynamic][]backend.Matrix4,
	bond_transforms: [dynamic]backend.Matrix4,
	lattice_lines:   [12][2][3]f32,
	materials:       [119]backend.Material,
	created:         [119]bool,
}

init :: proc(window: ^backend.Window) -> Renderer {
	return Renderer {
		window         = window,
		synced_version = max(u64),
		sphere         = backend.create_sphere(1, 16, 16),
		cylinder       = backend.create_cylinder(1, 1, 12),
		bond_material  = backend.create_material(window, BOND_COLOR),
		groups         = make([dynamic]i32),
		species        = make([dynamic]u16),
		transforms     = make([dynamic][]backend.Matrix4),
		bond_transforms = make([dynamic]backend.Matrix4),
	}
}

destroy :: proc(r: ^Renderer) {
	backend.destroy_mesh(r.sphere)
	backend.destroy_mesh(r.cylinder)
	backend.destroy_material(r.bond_material)
	for i in 0 ..< 119 {
		if r.created[i] {
			backend.destroy_material(r.materials[i])
		}
	}
	delete(r.groups)
	delete(r.species)
	for group in r.transforms {
		delete(group)
	}
	delete(r.transforms)
	delete(r.bond_transforms)
}

reset :: proc(r: ^Renderer) {
	r.synced_version = max(u64)
}

sync :: proc(r: ^Renderer, mol: ^model.Molecule) {
	if r.synced_version == mol.version {
		return
	}

	clear(&r.groups)
	clear(&r.species)
	for group in r.transforms {
		delete(group)
	}
	clear(&r.transforms)

	groups, species := compute_groups(mol.atoms[:])
	defer delete(groups)
	defer delete(species)
	for g in 0 ..< len(groups) {
		start := int(groups[g])
		end := len(mol.atoms)
		if g + 1 < len(groups) {
			end = int(groups[g + 1])
		}
		append(&r.groups, groups[g])
		append(&r.species, species[g])
		append(&r.transforms, build_group_transforms(mol.atoms[:], mol.lattice, start, end - start))
		ensure_material(r, species[g])
	}

	delete(r.bond_transforms)
	r.bond_transforms = build_bond_transforms(mol.atoms[:], mol.lattice)

	o := [3]f32{0, 0, 0}
	a := model.Vec3(mol.lattice.a)
	b := model.Vec3(mol.lattice.b)
	c := model.Vec3(mol.lattice.c)
	r.lattice_lines = [12][2][3]f32 {
		{o, a}, {o, b}, {o, c},
		{b, a + b}, {a + b, a},
		{c, a + c}, {a + c, a},
		{b, b + c}, {b + c, c},
		{a + b, a + b + c}, {a + c, a + b + c}, {b + c, a + b + c},
	}

	r.synced_version = mol.version
}

build_bond_transforms :: proc(atoms: []model.Atom, lattice: model.Lattice) -> [dynamic]backend.Matrix4 {
	transforms := make([dynamic]backend.Matrix4)
	zero_shift := [3]i8{0, 0, 0}
	bonds := model.compute_bonds(atoms, lattice)
	defer delete(bonds)
	for bond in bonds {
		if bond.shift != zero_shift {
			continue
		}
		p1 := model.Vec3(model.cartesian(lattice, atoms[bond.a].position))
		shift := model.FracVec3{f32(bond.shift[0]), f32(bond.shift[1]), f32(bond.shift[2])}
		p2 := model.Vec3(model.cartesian(lattice, atoms[bond.b].position + shift))
		if linalg.length(p2 - p1) < 0.001 {
			continue
		}
		append(&transforms, backend.make_cylinder_transform(p1, p2, BOND_RADIUS))
	}
	return transforms
}

build_group_transforms :: proc(
	atoms: []model.Atom,
	lattice: model.Lattice,
	start, count: int,
) -> []backend.Matrix4 {
	group := make([]backend.Matrix4, count)
	for j in 0 ..< count {
		atom := atoms[start + j]
		position := model.Vec3(model.cartesian(lattice, atom.position))
		e, _ := model.lookup_by_number(atom.atomic_number)
		radius := e.cov_radius_ang * RADIUS_PCT
		group[j] = backend.make_transform(position, {radius, radius, radius})
	}
	return group
}

compute_groups :: proc(atoms: []model.Atom) -> (groups: [dynamic]i32, species: [dynamic]u16) {
	groups = make([dynamic]i32)
	species = make([dynamic]u16)
	if len(atoms) == 0 {
		return
	}
	append(&groups, 0)
	append(&species, atoms[0].atomic_number)
	last := atoms[0].atomic_number
	for atom, i in atoms[1:] {
		if atom.atomic_number != last {
			append(&groups, i32(i + 1))
			append(&species, atom.atomic_number)
			last = atom.atomic_number
		}
	}
	return
}

ensure_material :: proc(r: ^Renderer, atomic_number: u16) {
	if r.created[atomic_number] {
		return
	}
	e, _ := model.lookup_by_number(atomic_number)
	r.materials[atomic_number] = backend.create_material(r.window, element_color(e))
	r.created[atomic_number] = true
}

element_color :: proc(e: model.Element) -> backend.Color {
	return backend.Color {
		r = u8(e.color >> 24),
		g = u8(e.color >> 16),
		b = u8(e.color >> 8),
		a = u8(e.color),
	}
}

draw :: proc(r: ^Renderer, view: ^View) {
	backend.begin_3d(view.camera)
	for line in r.lattice_lines {
		backend.draw_line_3d(line[0], line[1], LATTICE_COLOR)
	}
	if len(r.bond_transforms) > 0 {
		backend.draw_instanced(r.cylinder, r.bond_material, r.bond_transforms[:])
	}
	for g in 0 ..< len(r.groups) {
		backend.draw_instanced(r.sphere, r.materials[r.species[g]], r.transforms[g])
	}
	backend.end_3d()
}
