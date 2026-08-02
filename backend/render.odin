// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package backend

import rl "vendor:raylib"

Matrix4 :: #row_major matrix[4, 4]f32

Camera :: struct {
	position: [3]f32,
	target:   [3]f32,
	up:       [3]f32,
	fovy:     f32,
}

Mesh :: struct {
	handle: rl.Mesh,
}

Material :: struct {
	handle: rl.Material,
}

begin_3d :: proc(camera: Camera) {
	rl.BeginMode3D(
		rl.Camera3D {
			position   = rl.Vector3{camera.position[0], camera.position[1], camera.position[2]},
			target     = rl.Vector3{camera.target[0], camera.target[1], camera.target[2]},
			up         = rl.Vector3{camera.up[0], camera.up[1], camera.up[2]},
			fovy       = camera.fovy,
			projection = .ORTHOGRAPHIC,
		},
	)
}

end_3d :: proc() {
	rl.EndMode3D()
}

create_sphere :: proc(radius: f32, rings, slices: i32) -> Mesh {
	return Mesh{handle = rl.GenMeshSphere(radius, rings, slices)}
}

create_cylinder :: proc(radius, height: f32, slices: i32) -> Mesh {
	return Mesh{handle = rl.GenMeshCylinder(radius, height, slices)}
}

destroy_mesh :: proc(mesh: Mesh) {
	rl.UnloadMesh(mesh.handle)
}

create_material :: proc(window: ^Window, color: Color) -> Material {
	material := rl.LoadMaterialDefault()
	material.shader = window.shader
	material.maps[rl.MaterialMapIndex.ALBEDO].color = rl.Color{color.r, color.g, color.b, color.a}
	return Material{handle = material}
}

destroy_material :: proc(material: Material) {
	rl.UnloadMaterial(material.handle)
}

make_transform :: proc(position, scale: [3]f32) -> Matrix4 {
	return rl.MatrixTranslate(position[0], position[1], position[2]) *
	       rl.MatrixScale(scale[0], scale[1], scale[2])
}

make_cylinder_transform :: proc(p1, p2: [3]f32, radius: f32) -> Matrix4 {
	up := rl.Vector3{0, 1, 0}
	a := rl.Vector3{p1[0], p1[1], p1[2]}
	b := rl.Vector3{p2[0], p2[1], p2[2]}
	delta := rl.Vector3Subtract(b, a)
	distance := rl.Vector3Length(delta)
	dir := rl.Vector3Normalize(delta)

	scale := rl.MatrixScale(radius, distance, radius)
	rotation := rl.QuaternionToMatrix(rl.QuaternionFromVector3ToVector3(up, dir))
	translation := rl.MatrixTranslate(p1[0], p1[1], p1[2])
	return translation * rotation * scale
}

draw_line_3d :: proc(p0, p1: [3]f32, color: Color) {
	rl.DrawLine3D(
		rl.Vector3{p0[0], p0[1], p0[2]},
		rl.Vector3{p1[0], p1[1], p1[2]},
		rl.Color{color.r, color.g, color.b, color.a},
	)
}

draw_instanced :: proc(mesh: Mesh, material: Material, transforms: []Matrix4) {
	rl.DrawMeshInstanced(mesh.handle, material.handle, raw_data(transforms), i32(len(transforms)))
}
