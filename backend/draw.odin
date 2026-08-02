// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package backend

import "../draw"
import rl "vendor:raylib"

execute_commands :: proc(window: ^Window, commands: []draw.DrawCommand) {
	for command in commands {
		switch c in command {
		case draw.FillRect:
			rl.DrawRectangleRec(
				rl.Rectangle{c.rect.x, c.rect.y, c.rect.w, c.rect.h},
				to_rl_color(c.color),
			)
		case draw.Line:
			rl.DrawLineEx(
				rl.Vector2{c.p0[0], c.p0[1]},
				rl.Vector2{c.p1[0], c.p1[1]},
				c.width,
				to_rl_color(c.color),
			)
		case draw.Text:
			if len(c.text) > 0 {
				rl.DrawTextEx(
					window.font,
					cstring(raw_data(c.text)),
					rl.Vector2{c.position[0], c.position[1]},
					c.size,
					c.spacing,
					to_rl_color(c.color),
				)
			}
		case draw.Clip:
			if c.push {
				rl.BeginScissorMode(i32(c.rect.x), i32(c.rect.y), i32(c.rect.w), i32(c.rect.h))
			} else {
				rl.EndScissorMode()
			}
		}
	}
}

to_rl_color :: proc(c: draw.Color) -> rl.Color {
	return rl.Color{c.r, c.g, c.b, c.a}
}
