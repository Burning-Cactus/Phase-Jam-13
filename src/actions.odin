package game


Action_Type :: enum {
	NONE,
	ATTACK,
}

Action_Definition :: struct {
	name: string,
	has_animation: bool,
	start: proc(),
	update: proc(actor: ^Entity, target_id: i32),
	end: proc(),
}

actions := [Action_Type]Action_Definition {
	.NONE = {
		name = "None",
		update = no_action,
	},
	.ATTACK = {
		name = "Attack",
		update = attack_action,
	},
}

no_action :: proc(actor: ^Entity, target_id: i32) {

}

attack_action :: proc(actor: ^Entity, target_id: i32) {

}

heal_action :: proc() {

}

use_item_action :: proc() {

}
