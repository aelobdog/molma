// Adapted from raylib.lights (examples/shaders/rlights.h)
//
// Original work by:
//   Copyright (c) 2017-2024 Victor Fisac (@victorfisac) and Ramon Santamaria (@raysan5)
//
// Original license: zlib/libpng
// This file is a derivative work used under the terms of the zlib/libpng license.
//
// See original source:
// https://github.com/raysan5/raylib/blob/master/examples/shaders/rlights.h
//
// This adaptation is part of molma, which is licensed under Apache License 2.0.

package main

import rl "vendor:raylib"

LightType :: enum i32 {
	DIRECTIONAL = 0,
	POINT,
}

Light :: struct {
	type:           LightType,
	enabled:        b32,
	position:       rl.Vector3,
	target:         rl.Vector3,
	color:          rl.Color,
	attenuation:    f32,

	// Shader locations
	enabledLoc:     i32,
	typeLoc:        i32,
	positionLoc:    i32,
	targetLoc:      i32,
	colorLoc:       i32,
	attenuationLoc: i32,
}

create_light :: proc(
	type: LightType,
	position, target: rl.Vector3,
	color: rl.Color,
	shader: rl.Shader,
) -> Light {
	light := Light{}

	light.enabled = true
	light.type = type
	light.position = position
	light.target = target
	light.color = color

	light.enabledLoc = rl.GetShaderLocation(shader, "lights[0].enabled")
	light.typeLoc = rl.GetShaderLocation(shader, "lights[0].type")
	light.positionLoc = rl.GetShaderLocation(shader, "lights[0].position")
	light.targetLoc = rl.GetShaderLocation(shader, "lights[0].target")
	light.colorLoc = rl.GetShaderLocation(shader, "lights[0].color")
	update_light_values(shader, light)

	return light
}

update_light_values :: proc(shader: rl.Shader, light: Light) {
	enabled_val := light.enabled
	type_val := i32(light.type)

	rl.SetShaderValue(shader, light.enabledLoc, &enabled_val, .INT)
	rl.SetShaderValue(shader, light.typeLoc, &type_val, .INT)

	position := [3]f32{light.position.x, light.position.y, light.position.z}
	target := [3]f32{light.target.x, light.target.y, light.target.z}
	color := [4]f32 {
		f32(light.color.r) / 255.0,
		f32(light.color.g) / 255.0,
		f32(light.color.b) / 255.0,
		f32(light.color.a) / 255.0,
	}

	rl.SetShaderValue(shader, light.positionLoc, &position, .VEC3)
	rl.SetShaderValue(shader, light.targetLoc, &target, .VEC3)
	rl.SetShaderValue(shader, light.colorLoc, &color, .VEC4)
}
