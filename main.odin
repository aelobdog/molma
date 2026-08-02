// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package main

import "backend"

main :: proc() {
	window := backend.init(1280, 800, "Molma")
	defer backend.shutdown()

	for !backend.should_close(&window) {
		backend.begin_frame(&window)
		backend.clear(&window, backend.Color{0x33, 0x33, 0x33, 0xff})
		backend.end_frame(&window)
	}
}
