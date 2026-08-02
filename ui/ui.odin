// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

// Package ui is an immediate-mode widget layer. It never touches a
// platform: it reads a backend.Input snapshot, applies a Theme, and
// appends draw commands for the backend to execute.
package ui

import "../backend"
import "../draw"

Theme :: struct {
	panel:        draw.Color,
	button:       draw.Color,
	button_hover: draw.Color,
	text:         draw.Color,
	text_size:    f32,
	padding:      f32,
}

default_theme :: proc() -> Theme {
	return Theme {
		panel        = draw.Color{0x28, 0x28, 0x28, 0xff},
		button       = draw.Color{0x3a, 0x3a, 0x3a, 0xff},
		button_hover = draw.Color{0x4a, 0x4a, 0x4a, 0xff},
		text         = draw.Color{0xee, 0xee, 0xee, 0xff},
		text_size    = 18,
		padding      = 8,
	}
}

Frame :: struct {
	commands:    ^[dynamic]draw.DrawCommand,
	input:       backend.Input,
	theme:       Theme,
	font:        backend.FontMetrics,
	active:      bool,
	active_rect: draw.Rect,
}

point_in_rect :: proc(p: [2]f32, rect: draw.Rect) -> bool {
	return p.x >= rect.x && p.x <= rect.x + rect.w && p.y >= rect.y && p.y <= rect.y + rect.h
}

fill_rect :: proc(frame: ^Frame, rect: draw.Rect, color: draw.Color) {
	append(frame.commands, draw.FillRect{rect = rect, color = color})
}

text :: proc(frame: ^Frame, position: [2]f32, s: string, size: f32, color: draw.Color) {
	append(frame.commands, draw.Text{position = position, text = s, size = size, color = color})
}

text_width :: proc(frame: ^Frame, s: string, size: f32) -> f32 {
	return f32(len(s)) * frame.font.advance * size / frame.font.base_size
}

begin_panel :: proc(frame: ^Frame, rect: draw.Rect) -> bool {
	fill_rect(frame, rect, frame.theme.panel)
	append(frame.commands, draw.Clip{rect = rect, push = true})
	return true
}

end_panel :: proc(frame: ^Frame) {
	append(frame.commands, draw.Clip{push = false})
}

button :: proc(frame: ^Frame, rect: draw.Rect, label: string) -> bool {
	hovered := point_in_rect(frame.input.mouse_pos, rect)
	if .LEFT in frame.input.mouse_pressed && hovered {
		frame.active = true
		frame.active_rect = rect
	}

	clicked := false
	if .LEFT in frame.input.mouse_released {
		clicked = frame.active && rect == frame.active_rect && hovered
		frame.active = false
	}

	color := frame.theme.button
	if hovered {
		color = frame.theme.button_hover
	}
	fill_rect(frame, rect, color)

	label_pos := [2]f32 {
		rect.x + (rect.w - text_width(frame, label, frame.theme.text_size)) / 2,
		rect.y + (rect.h - frame.theme.text_size) / 2,
	}
	text(frame, label_pos, label, frame.theme.text_size, frame.theme.text)

	return clicked
}
