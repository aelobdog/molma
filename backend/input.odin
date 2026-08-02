// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package backend

import rl "vendor:raylib"

MouseButton :: enum u8 {
	LEFT,
	RIGHT,
	MIDDLE,
}

Modifier :: enum u8 {
	SHIFT,
	CTRL,
	ALT,
	SUPER,
}

Key :: enum u8 {
	BACKSPACE,
	ENTER,
	ESCAPE,
	TAB,
	LEFT,
	RIGHT,
	HOME,
	END,
	DELETE,
}

Input :: struct {
	mouse_pos:      [2]f32,
	mouse_delta:    [2]f32,
	mouse_wheel:    f32,
	mouse_down:     bit_set[MouseButton],
	mouse_pressed:  bit_set[MouseButton],
	mouse_released: bit_set[MouseButton],
	mods:           bit_set[Modifier],
	keys_pressed:   bit_set[Key],
	typed:          [16]rune,
	typed_count:    int,
}

// poll_dropped_file copies the last dropped path into the window
// buffer and returns it; valid until the next poll.
poll_dropped_file :: proc(window: ^Window) -> string {
	window.dropped_len = 0
	if rl.IsFileDropped() {
		dropped := rl.LoadDroppedFiles()
		defer rl.UnloadDroppedFiles(dropped)
		if dropped.count > 0 {
			path := dropped.paths[dropped.count - 1]
			window.dropped_len = copy(window.dropped[:], string(path))
		}
	}
	return string(window.dropped[:window.dropped_len])
}

refresh_input :: proc(window: ^Window) {
	input := &window.input
	input.typed_count = 0

	pos := rl.GetMousePosition()
	input.mouse_pos = [2]f32{pos.x, pos.y}
	input.mouse_delta = input.mouse_pos - window.prev_mouse
	window.prev_mouse = input.mouse_pos
	input.mouse_wheel = rl.GetMouseWheelMove()

	input.mouse_down = {}
	input.mouse_pressed = {}
	input.mouse_released = {}
	for button in MouseButton {
		rb := rl.MouseButton(button)
		if rl.IsMouseButtonDown(rb) {
			input.mouse_down += {button}
		}
		if rl.IsMouseButtonPressed(rb) {
			input.mouse_pressed += {button}
		}
		if rl.IsMouseButtonReleased(rb) {
			input.mouse_released += {button}
		}
	}

	input.mods = {}
	if rl.IsKeyDown(.LEFT_SHIFT) || rl.IsKeyDown(.RIGHT_SHIFT) {
		input.mods += {.SHIFT}
	}
	if rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL) {
		input.mods += {.CTRL}
	}
	if rl.IsKeyDown(.LEFT_ALT) || rl.IsKeyDown(.RIGHT_ALT) {
		input.mods += {.ALT}
	}
	if rl.IsKeyDown(.LEFT_SUPER) || rl.IsKeyDown(.RIGHT_SUPER) {
		input.mods += {.SUPER}
	}

	input.keys_pressed = {}
	key_map := [9]rl.KeyboardKey {
		.BACKSPACE,
		.ENTER,
		.ESCAPE,
		.TAB,
		.LEFT,
		.RIGHT,
		.HOME,
		.END,
		.DELETE,
	}
	for key, i in Key {
		if rl.IsKeyPressed(key_map[i]) {
			input.keys_pressed += {key}
		}
	}

	for {
		ch := rl.GetCharPressed()
		if ch == 0 {
			break
		}
		if input.typed_count < len(input.typed) {
			input.typed[input.typed_count] = rune(ch)
			input.typed_count += 1
		}
	}
}
