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
	input:        draw.Color,
	input_focus:  draw.Color,
	text:         draw.Color,
	text_size:    f32,
	padding:      f32,
}

default_theme :: proc() -> Theme {
	return Theme {
		panel        = draw.Color{0x28, 0x28, 0x28, 0xff},
		button       = draw.Color{0x3a, 0x3a, 0x3a, 0xff},
		button_hover = draw.Color{0x4a, 0x4a, 0x4a, 0xff},
		input        = draw.Color{0x1e, 0x1e, 0x1e, 0xff},
		input_focus  = draw.Color{0x24, 0x24, 0x24, 0xff},
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
	focus:       draw.Rect,
}

begin_frame :: proc(frame: ^Frame, commands: ^[dynamic]draw.DrawCommand, input: backend.Input) {
	frame.commands = commands
	frame.input = input
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

Layout :: struct {
	panel:   draw.Rect,
	pos:     [2]f32,
	padding: f32,
}

make_layout :: proc(frame: ^Frame, panel: draw.Rect) -> Layout {
	return Layout {
		panel   = panel,
		pos     = {panel.x + frame.theme.padding, panel.y + frame.theme.padding},
		padding = frame.theme.padding,
	}
}

below :: proc(layout: ^Layout, height: f32) -> draw.Rect {
	rect := draw.Rect {
		layout.pos.x,
		layout.pos.y,
		layout.panel.x + layout.panel.w - layout.padding - layout.pos.x,
		height,
	}
	layout.pos.y += height + layout.padding
	return rect
}

right :: proc(layout: ^Layout, width, height: f32) -> draw.Rect {
	rect := draw.Rect {layout.pos.x, layout.pos.y, width, height}
	layout.pos.x += width + layout.padding
	return rect
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
		if rect == frame.active_rect {
			frame.active = false
		}
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

// text_input edits buffer in place; buffer always ends with a null
// byte, so string(buffer[:len-1]) is the value. Returns true if the
// text changed this frame.
text_input :: proc(frame: ^Frame, rect: draw.Rect, buffer: ^[dynamic]u8) -> bool {
	hovered := point_in_rect(frame.input.mouse_pos, rect)
	if .LEFT in frame.input.mouse_pressed {
		if hovered {
			frame.focus = rect
		} else if frame.focus == rect {
			frame.focus = {}
		}
	}

	focused := frame.focus == rect
	changed := false
	if focused {
		if .BACKSPACE in frame.input.keys_pressed && len(buffer) > 1 {
			buffer[len(buffer) - 2] = 0
			resize(buffer, len(buffer) - 1)
			changed = true
		}
		for i in 0 ..< frame.input.typed_count {
			r := frame.input.typed[i]
			if r < 0x20 || r >= 0x100 || len(buffer) - 1 >= 64 {
				continue
			}
			append(buffer, 0)
			buffer[len(buffer) - 2] = u8(r)
			changed = true
		}
	}

	color := frame.theme.input
	if focused {
		color = frame.theme.input_focus
	}
	fill_rect(frame, rect, color)

	value := string(buffer[:len(buffer) - 1])
	text_pos := [2]f32 {rect.x + frame.theme.padding, rect.y + (rect.h - frame.theme.text_size) / 2}
	text(frame, text_pos, value, frame.theme.text_size, frame.theme.text)

	if focused {
		caret_x := text_pos.x + text_width(frame, value, frame.theme.text_size) + 1
		fill_rect(frame, draw.Rect{caret_x, rect.y + frame.theme.padding, 2, rect.h - 2 * frame.theme.padding}, frame.theme.text)
	}

	return changed
}
