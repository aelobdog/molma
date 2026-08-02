// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package ui

import "../backend"
import "core:testing"
import "../draw"

test_frame :: proc(commands: ^[dynamic]draw.DrawCommand) -> Frame {
	return Frame {
		commands = commands,
		theme    = default_theme(),
		font     = backend.FontMetrics{advance = 10, base_size = 10},
	}
}

@test button_clicks_on_press_then_release_test :: proc(t: ^testing.T) {
	commands := make([dynamic]draw.DrawCommand)
	defer delete(commands)
	frame := test_frame(&commands)

	rect := draw.Rect{0, 0, 100, 40}

	frame.input.mouse_pos = {50, 20}
	frame.input.mouse_pressed = {.LEFT}
	testing.expect(t, !button(&frame, rect, "Test"), "no click on press")

	frame.input.mouse_pressed = {}
	frame.input.mouse_released = {.LEFT}
	testing.expect(t, button(&frame, rect, "Test"), "click on release over the button")
}

@test button_drag_off_cancels_test :: proc(t: ^testing.T) {
	commands := make([dynamic]draw.DrawCommand)
	defer delete(commands)
	frame := test_frame(&commands)

	rect := draw.Rect{0, 0, 100, 40}

	frame.input.mouse_pos = {50, 20}
	frame.input.mouse_pressed = {.LEFT}
	button(&frame, rect, "Test")

	frame.input.mouse_pressed = {}
	frame.input.mouse_pos = {500, 500}
	frame.input.mouse_released = {.LEFT}
	testing.expect(t, !button(&frame, rect, "Test"), "release away from the button cancels")
}

@test button_not_hovered_not_clicked_test :: proc(t: ^testing.T) {
	commands := make([dynamic]draw.DrawCommand)
	defer delete(commands)
	frame := test_frame(&commands)

	rect := draw.Rect{0, 0, 100, 40}

	frame.input.mouse_pos = {500, 500}
	frame.input.mouse_pressed = {.LEFT}
	testing.expect(t, !button(&frame, rect, "Test"))
}

@test button_hover_uses_theme_color_test :: proc(t: ^testing.T) {
	commands := make([dynamic]draw.DrawCommand)
	defer delete(commands)
	frame := test_frame(&commands)

	frame.input.mouse_pos = {50, 20}
	button(&frame, draw.Rect{0, 0, 100, 40}, "Test")

	fill, ok := commands[0].(draw.FillRect)
	testing.expect(t, ok)
	testing.expect_value(t, fill.color, frame.theme.button_hover)
}

@test panel_emits_fill_and_clip_test :: proc(t: ^testing.T) {
	commands := make([dynamic]draw.DrawCommand)
	defer delete(commands)
	frame := test_frame(&commands)

	begin_panel(&frame, draw.Rect{0, 0, 100, 100})
	end_panel(&frame)

	testing.expect_value(t, len(commands), 3)

	_, is_fill := commands[0].(draw.FillRect)
	clip1, is_clip1 := commands[1].(draw.Clip)
	clip2, is_clip2 := commands[2].(draw.Clip)
	testing.expect(t, is_fill && is_clip1 && clip1.push)
	testing.expect(t, is_clip2 && !clip2.push)
}

@test text_width_scales_with_size_test :: proc(t: ^testing.T) {
	commands := make([dynamic]draw.DrawCommand)
	defer delete(commands)
	frame := test_frame(&commands)

	testing.expect_value(t, text_width(&frame, "abcd", 10), f32(40))
	testing.expect_value(t, text_width(&frame, "ab", 20), f32(40))
	testing.expect_value(t, text_width(&frame, "", 10), f32(0))
}
