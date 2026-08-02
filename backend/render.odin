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

create_material :: proc(color: Color) -> Material {
	material := rl.LoadMaterialDefault()
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

draw_instanced :: proc(mesh: Mesh, material: Material, transforms: []Matrix4) {
	rl.DrawMeshInstanced(mesh.handle, material.handle, raw_data(transforms), i32(len(transforms)))
}
