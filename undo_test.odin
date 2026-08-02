// Copyright 2026 Ashwin K. Godbole (aelobdog)
// SPDX-License-Identifier: Apache-2.0

package main

import "core:testing"
import "model"

test_app :: proc() -> App {
	app: App
	app.mol = model.Molecule {
		lattice = model.Lattice {
			a = model.CartVec3{10, 0, 0},
			b = model.CartVec3{0, 10, 0},
			c = model.CartVec3{0, 0, 10},
		},
	}
	model.add_atom(&app.mol, model.Atom{position = model.FracVec3{0.5, 0.5, 0.5}, atomic_number = 1})
	app.selection = make([dynamic]model.AtomIndex)
	app.undo_stack = make([dynamic]model.Molecule)
	app.redo_stack = make([dynamic]model.Molecule)
	return app
}

@test undo_restores_and_redo_reapplies_test :: proc(t: ^testing.T) {
	app := test_app()
	defer clear_history(&app)
	defer delete(app.selection)
	defer delete(app.undo_stack)
	defer delete(app.redo_stack)
	defer delete(app.mol.atoms)

	record_undo(&app)
	model.set_atom_position(&app.mol, 0, model.FracVec3{0.25, 0.5, 0.5})
	testing.expect_value(t, app.mol.atoms[0].position, model.FracVec3{0.25, 0.5, 0.5})

	undo(&app)
	testing.expect_value(t, app.mol.atoms[0].position, model.FracVec3{0.5, 0.5, 0.5})

	redo(&app)
	testing.expect_value(t, app.mol.atoms[0].position, model.FracVec3{0.25, 0.5, 0.5})
}

@test undo_restores_species_test :: proc(t: ^testing.T) {
	app := test_app()
	defer clear_history(&app)
	defer delete(app.selection)
	defer delete(app.undo_stack)
	defer delete(app.redo_stack)
	defer delete(app.mol.atoms)

	record_undo(&app)
	model.set_atom_species(&app.mol, 0, 8)
	testing.expect_value(t, app.mol.atoms[0].atomic_number, u16(8))

	undo(&app)
	testing.expect_value(t, app.mol.atoms[0].atomic_number, u16(1))
}

@test new_action_clears_redo_test :: proc(t: ^testing.T) {
	app := test_app()
	defer clear_history(&app)
	defer delete(app.selection)
	defer delete(app.undo_stack)
	defer delete(app.redo_stack)
	defer delete(app.mol.atoms)

	record_undo(&app)
	model.set_atom_position(&app.mol, 0, model.FracVec3{0.25, 0.5, 0.5})
	undo(&app)
	testing.expect_value(t, len(app.redo_stack), 1)

	record_undo(&app)
	model.set_atom_species(&app.mol, 0, 8)
	testing.expect_value(t, len(app.redo_stack), 0)
	testing.expect_value(t, len(app.undo_stack), 1)
}

@test undo_cap_test :: proc(t: ^testing.T) {
	app := test_app()
	defer clear_history(&app)
	defer delete(app.selection)
	defer delete(app.undo_stack)
	defer delete(app.redo_stack)
	defer delete(app.mol.atoms)

	for i in 0 ..< MAX_UNDO + 10 {
		record_undo(&app)
		model.set_atom_position(&app.mol, 0, model.FracVec3{0.1, 0.2, 0.3})
	}
	testing.expect_value(t, len(app.undo_stack), MAX_UNDO)
}

@test snapshot_is_independent_copy_test :: proc(t: ^testing.T) {
	app := test_app()
	defer delete(app.selection)
	defer delete(app.undo_stack)
	defer delete(app.redo_stack)

	s := snapshot(&app.mol)
	defer delete(s.atoms)

	model.set_atom_position(&app.mol, 0, model.FracVec3{0.25, 0.5, 0.5})
	testing.expect_value(t, s.atoms[0].position, model.FracVec3{0.5, 0.5, 0.5})
}
