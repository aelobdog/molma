// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package main

import "model"

MAX_UNDO :: 100

snapshot :: proc(mol: ^model.Molecule) -> model.Molecule {
	s := model.Molecule {lattice = mol.lattice}
	s.atoms = make([dynamic]model.Atom, len(mol.atoms))
	copy(s.atoms[:], mol.atoms[:])
	return s
}

record_undo :: proc(app: ^App) {
	append(&app.undo_stack, snapshot(&app.mol))
	if len(app.undo_stack) > MAX_UNDO {
		delete(app.undo_stack[0].atoms)
		ordered_remove(&app.undo_stack, 0)
	}
	clear(&app.redo_stack)
}

undo :: proc(app: ^App) {
	if len(app.undo_stack) == 0 {
		return
	}
	append(&app.redo_stack, snapshot(&app.mol))
	restore_snapshot(&app.mol, &app.undo_stack[len(app.undo_stack) - 1])
	pop(&app.undo_stack)
	finish_undo_redo(app)
}

redo :: proc(app: ^App) {
	if len(app.redo_stack) == 0 {
		return
	}
	append(&app.undo_stack, snapshot(&app.mol))
	restore_snapshot(&app.mol, &app.redo_stack[len(app.redo_stack) - 1])
	pop(&app.redo_stack)
	finish_undo_redo(app)
}

restore_snapshot :: proc(mol: ^model.Molecule, from: ^model.Molecule) {
	delete(mol.atoms)
	mol.lattice = from.lattice
	mol.atoms = from.atoms
	from.atoms = nil
}

finish_undo_redo :: proc(app: ^App) {
	app.mol.version += 1
	clear(&app.selection)
	app.last_edited = -1
	app.sel_epoch += 1
}

clear_history :: proc(app: ^App) {
	for entry in app.undo_stack {
		delete(entry.atoms)
	}
	clear(&app.undo_stack)
	for entry in app.redo_stack {
		delete(entry.atoms)
	}
	clear(&app.redo_stack)
}
