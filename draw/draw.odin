// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

// Package draw is the data contract between the ui layer and the
// backend: the ui appends commands, the backend executes them.
package draw

Color :: struct {
	r, g, b, a: u8,
}

Rect :: struct {
	x, y, w, h: f32,
}

FillRect :: struct {
	rect:  Rect,
	color: Color,
}

Line :: struct {
	p0, p1: [2]f32,
	width:  f32,
	color:  Color,
}

Text :: struct {
	position: [2]f32,
	text:     string,
	size:     f32,
	color:    Color,
}

Clip :: struct {
	rect: Rect,
	push: bool,
}

DrawCommand :: union {
	FillRect,
	Line,
	Text,
	Clip,
}
