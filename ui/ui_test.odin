// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package ui

import "../backend"
import "core:testing"
import "../draw"

test_frame :: proc(commands: ^[dynamic]draw.DrawCommand) -> Frame {
	return Frame {
		theme = default_theme(),
		font  = backend.FontMetrics{advance = 10, base_size = 10},
	}
}

@test click_survives_across_frames_test :: proc(t: ^testing.T) {
	commands := make([dynamic]draw.DrawCommand)
	defer delete(commands)
	frame := test_frame(&commands)
	rect := draw.Rect{0, 0, 100, 40}

	begin_frame(&frame, &commands, backend.Input{mouse_pos = {50, 20}, mouse_pressed = {.LEFT}})
	testing.expect(t, !button(&frame, rect, "Test"), "no click on press")

	begin_frame(&frame, &commands, backend.Input{mouse_pos = {50, 20}, mouse_released = {.LEFT}})
	testing.expect(t, button(&frame, rect, "Test"), "click on release, same persistent frame")
}

@test second_button_clicked_after_first_processed_test :: proc(t: ^testing.T) {
	commands := make([dynamic]draw.DrawCommand)
	defer delete(commands)
	frame := test_frame(&commands)

	add_rect := draw.Rect{0, 0, 100, 40}
	reset_rect := draw.Rect{0, 80, 100, 40}

	begin_frame(&frame, &commands, backend.Input{mouse_pos = {50, 100}, mouse_pressed = {.LEFT}})
	button(&frame, add_rect, "Add")
	testing.expect(t, !button(&frame, reset_rect, "Reset"), "no click on press")

	begin_frame(&frame, &commands, backend.Input{mouse_pos = {50, 100}, mouse_released = {.LEFT}})
	button(&frame, add_rect, "Add")
	testing.expect(t, button(&frame, reset_rect, "Reset"), "first button must not steal active")
}

@test button_drag_off_cancels_test :: proc(t: ^testing.T) {
	commands := make([dynamic]draw.DrawCommand)
	defer delete(commands)
	frame := test_frame(&commands)
	rect := draw.Rect{0, 0, 100, 40}

	begin_frame(&frame, &commands, backend.Input{mouse_pos = {50, 20}, mouse_pressed = {.LEFT}})
	button(&frame, rect, "Test")

	begin_frame(&frame, &commands, backend.Input{mouse_pos = {500, 500}, mouse_released = {.LEFT}})
	testing.expect(t, !button(&frame, rect, "Test"), "release away from the button cancels")
}

@test button_not_hovered_not_clicked_test :: proc(t: ^testing.T) {
	commands := make([dynamic]draw.DrawCommand)
	defer delete(commands)
	frame := test_frame(&commands)
	rect := draw.Rect{0, 0, 100, 40}

	begin_frame(&frame, &commands, backend.Input{mouse_pos = {500, 500}, mouse_pressed = {.LEFT}})
	testing.expect(t, !button(&frame, rect, "Test"))
}

@test button_hover_uses_theme_color_test :: proc(t: ^testing.T) {
	commands := make([dynamic]draw.DrawCommand)
	defer delete(commands)
	frame := test_frame(&commands)

	begin_frame(&frame, &commands, backend.Input{mouse_pos = {50, 20}})
	button(&frame, draw.Rect{0, 0, 100, 40}, "Test")

	fill, ok := commands[0].(draw.FillRect)
	testing.expect(t, ok)
	testing.expect_value(t, fill.color, frame.theme.button_hover)
}

@test floating_panel_drags_by_title_test :: proc(t: ^testing.T) {
	commands := make([dynamic]draw.DrawCommand)
	defer delete(commands)
	frame := test_frame(&commands)
	rect := draw.Rect{100, 100, 200, 200}

	begin_frame(&frame, &commands, backend.Input{mouse_pos = {150, 105}, mouse_pressed = {.LEFT}})
	open := begin_floating_panel(&frame, &rect, "Atom")
	end_floating_panel(&frame)
	testing.expect(t, open)

	begin_frame(
		&frame,
		&commands,
		backend.Input{mouse_pos = {160, 115}, mouse_down = {.LEFT}, mouse_delta = {10, 10}},
	)
	begin_floating_panel(&frame, &rect, "Atom")
	end_floating_panel(&frame)
	testing.expect_value(t, rect, draw.Rect{110, 110, 200, 200})

	begin_frame(&frame, &commands, backend.Input{mouse_pos = {160, 115}, mouse_released = {.LEFT}})
	begin_floating_panel(&frame, &rect, "Atom")
	end_floating_panel(&frame)
	testing.expect_value(t, rect, draw.Rect{110, 110, 200, 200})
}

@test floating_panel_close_button_test :: proc(t: ^testing.T) {
	commands := make([dynamic]draw.DrawCommand)
	defer delete(commands)
	frame := test_frame(&commands)
	rect := draw.Rect{100, 100, 200, 200}
	close_center := [2]f32{100 + 200 - 12, 100 + 12}

	begin_frame(&frame, &commands, backend.Input{mouse_pos = close_center, mouse_pressed = {.LEFT}})
	open := begin_floating_panel(&frame, &rect, "Atom")
	end_floating_panel(&frame)
	testing.expect(t, open, "no close on press")

	begin_frame(&frame, &commands, backend.Input{mouse_pos = close_center, mouse_released = {.LEFT}})
	open = begin_floating_panel(&frame, &rect, "Atom")
	end_floating_panel(&frame)
	testing.expect(t, !open, "close on release")
}

@test panel_emits_fill_and_clip_test :: proc(t: ^testing.T) {
	commands := make([dynamic]draw.DrawCommand)
	defer delete(commands)
	frame := test_frame(&commands)

	begin_frame(&frame, &commands, backend.Input{})
	begin_panel(&frame, draw.Rect{0, 0, 100, 100})
	end_panel(&frame)

	testing.expect_value(t, len(commands), 3)

	_, is_fill := commands[0].(draw.FillRect)
	clip1, is_clip1 := commands[1].(draw.Clip)
	clip2, is_clip2 := commands[2].(draw.Clip)
	testing.expect(t, is_fill && is_clip1 && clip1.push)
	testing.expect(t, is_clip2 && !clip2.push)
}

@test layout_below_advances_test :: proc(t: ^testing.T) {
	commands := make([dynamic]draw.DrawCommand)
	defer delete(commands)
	frame := test_frame(&commands)
	begin_frame(&frame, &commands, backend.Input{})

	layout := make_layout(&frame, draw.Rect{20, 20, 200, 300})
	r1 := below(&layout, 40)
	r2 := below(&layout, 40)

	testing.expect_value(t, r1, draw.Rect{28, 28, 184, 40})
	testing.expect_value(t, r2.y, f32(76))
}

@test layout_right_advances_test :: proc(t: ^testing.T) {
	commands := make([dynamic]draw.DrawCommand)
	defer delete(commands)
	frame := test_frame(&commands)
	begin_frame(&frame, &commands, backend.Input{})

	layout := make_layout(&frame, draw.Rect{20, 20, 200, 300})
	r1 := right(&layout, 100, 40)
	r2 := right(&layout, 100, 40)

	testing.expect_value(t, r1, draw.Rect{28, 28, 100, 40})
	testing.expect_value(t, r2.x, f32(136))
}

@test text_input_accepts_typed_chars_when_focused_test :: proc(t: ^testing.T) {
	commands := make([dynamic]draw.DrawCommand)
	defer delete(commands)
	frame := test_frame(&commands)
	buffer := make([dynamic]u8)
	append(&buffer, 0)
	defer delete(buffer)
	rect := draw.Rect{0, 0, 200, 40}

	begin_frame(&frame, &commands, backend.Input{mouse_pos = {50, 20}, mouse_pressed = {.LEFT}})
	text_input(&frame, rect, &buffer)

	input := backend.Input{mouse_pos = {50, 20}}
	input.typed[0], input.typed[1], input.typed[2] = 'a', 'b', 'c'
	input.typed_count = 3
	begin_frame(&frame, &commands, input)
	changed := text_input(&frame, rect, &buffer)
	testing.expect(t, changed)
	testing.expect_value(t, string(buffer[:len(buffer) - 1]), "abc")
}

@test text_input_ignores_typing_when_unfocused_test :: proc(t: ^testing.T) {
	commands := make([dynamic]draw.DrawCommand)
	defer delete(commands)
	frame := test_frame(&commands)
	buffer := make([dynamic]u8)
	append(&buffer, 0)
	defer delete(buffer)
	rect := draw.Rect{0, 0, 200, 40}

	input := backend.Input{mouse_pos = {500, 500}}
	input.typed[0] = 'a'
	input.typed_count = 1
	begin_frame(&frame, &commands, input)
	changed := text_input(&frame, rect, &buffer)
	testing.expect(t, !changed)
	testing.expect_value(t, string(buffer[:len(buffer) - 1]), "")
}

@test text_input_backspace_test :: proc(t: ^testing.T) {
	commands := make([dynamic]draw.DrawCommand)
	defer delete(commands)
	frame := test_frame(&commands)
	buffer := make([dynamic]u8)
	append(&buffer, 'a')
	append(&buffer, 'b')
	append(&buffer, 0)
	defer delete(buffer)
	rect := draw.Rect{0, 0, 200, 40}

	begin_frame(&frame, &commands, backend.Input{mouse_pos = {50, 20}, mouse_pressed = {.LEFT}})
	text_input(&frame, rect, &buffer)

	begin_frame(&frame, &commands, backend.Input{mouse_pos = {50, 20}, keys_pressed = {.BACKSPACE}})
	changed := text_input(&frame, rect, &buffer)
	testing.expect(t, changed)
	testing.expect_value(t, string(buffer[:len(buffer) - 1]), "a")
}

@test text_input_unfocus_on_click_elsewhere_test :: proc(t: ^testing.T) {
	commands := make([dynamic]draw.DrawCommand)
	defer delete(commands)
	frame := test_frame(&commands)
	buffer := make([dynamic]u8)
	append(&buffer, 0)
	defer delete(buffer)
	rect := draw.Rect{0, 0, 200, 40}

	begin_frame(&frame, &commands, backend.Input{mouse_pos = {50, 20}, mouse_pressed = {.LEFT}})
	text_input(&frame, rect, &buffer)
	testing.expect_value(t, frame.focus, rect)

	begin_frame(&frame, &commands, backend.Input{mouse_pos = {500, 500}, mouse_pressed = {.LEFT}})
	text_input(&frame, rect, &buffer)
	testing.expect_value(t, frame.focus, draw.Rect{})
}

@test text_width_counts_spacing_test :: proc(t: ^testing.T) {
	commands := make([dynamic]draw.DrawCommand)
	defer delete(commands)
	frame := test_frame(&commands)
	begin_frame(&frame, &commands, backend.Input{})

	// advance 10, base 10, theme spacing 2: width = n*10*size/10 + (n-1)*2
	testing.expect_value(t, text_width(&frame, "abcd", 10), f32(46))
	testing.expect_value(t, text_width(&frame, "ab", 20), f32(42))
	testing.expect_value(t, text_width(&frame, "", 10), f32(0))
}

@test caret_drawn_when_focused_test :: proc(t: ^testing.T) {
	commands := make([dynamic]draw.DrawCommand)
	defer delete(commands)
	frame := test_frame(&commands)
	buffer := make([dynamic]u8)
	append(&buffer, 0)
	defer delete(buffer)
	rect := draw.Rect{0, 0, 200, 40}

	begin_frame(&frame, &commands, backend.Input{mouse_pos = {50, 20}, mouse_pressed = {.LEFT}})
	text_input(&frame, rect, &buffer)

	testing.expect_value(t, len(commands), 3)
	caret, is_fill := commands[2].(draw.FillRect)
	testing.expect(t, is_fill)
	testing.expect_value(t, caret.rect.w, f32(2))
}

@test caret_not_drawn_when_unfocused_test :: proc(t: ^testing.T) {
	commands := make([dynamic]draw.DrawCommand)
	defer delete(commands)
	frame := test_frame(&commands)
	buffer := make([dynamic]u8)
	append(&buffer, 0)
	defer delete(buffer)
	rect := draw.Rect{0, 0, 200, 40}

	begin_frame(&frame, &commands, backend.Input{})
	text_input(&frame, rect, &buffer)

	testing.expect_value(t, len(commands), 2)
}
