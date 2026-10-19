package game

import rl "vendor:raylib"

inventory: [dynamic; 20]Item_Type

field_items: [100]Field_Item

item_textures := [Item_Type]rl.Texture{}

Item_Type :: enum {
	NONE,
	COFFEE,
	// TEA,
	// HOT_CHOCOLATE,
	ORANGE,
	BISCUIT,
	// ANTIDOTE,
	// DAKI,
	RUBBER_DUCK,
	// SPELL_CARD,
	// HOURGLASS,
	BROCCOLI_EGGS,
	// UMBRELLA,
	// MICROPHONE,
	// PENLIGHT,
	// MAP,
	// CROWBAR,
	// MICROWAVE,
}

@(rodata) item_names := [Item_Type]cstring {
	.NONE = "NONE",
	.COFFEE = "Phase Connect Coffee",
	.ORANGE = "Orange",
	.BISCUIT = "Biscuit",
	.RUBBER_DUCK = "Rubber Duck",
	.BROCCOLI_EGGS = "Broccoli & Eggs",
	// .MICROPHONE = "Microphone",
}

Field_Item :: struct {
	in_use: bool,
	type: Item_Type,
	pos: Vec2,
}

spawn_item :: proc(type: Item_Type, pos: Vec2) {
	for i in 0..<len(field_items) {
		item := &field_items[i]
		if !item.in_use {
			item^ = {
				in_use = true,
				type = type,
				pos = pos,
			}
		}
		break
	}
}

use_item :: proc(item: Item_Type, target_id: i32) -> bool {
	switch item {
	case .NONE:
	case .COFFEE: heal_entity(target_id, 40)
	case .ORANGE: heal_entity(target_id, 40)
	case .BISCUIT: heal_entity(target_id, 80)
	case .BROCCOLI_EGGS: heal_entity(target_id, 60)
	// case .TEA: regen_entity
	// case .HOT_CHOCOLATE:
	// case .ANTIDOTE:
	// case .DAKI:
	case .RUBBER_DUCK: spawn_entity(.SAMMY, entities[target_id].pos, .ALLY)
	// case .SPELL_CARD:
	// case .HOURGLASS:
	// case .UMBRELLA:
	// case .MICROPHONE:
	}

	return true
}

load_items :: proc() {
	item_textures[.COFFEE] = rl.LoadTexture("assets/items/coffee.png")
	item_textures[.ORANGE] = rl.LoadTexture("assets/items/orange.png")
	item_textures[.BISCUIT] = rl.LoadTexture("assets/items/biscuit.png")
	item_textures[.RUBBER_DUCK] = rl.LoadTexture("assets/items/rubber_duck.png")
	item_textures[.BROCCOLI_EGGS] = rl.LoadTexture("assets/item/broccoli_eggs.png")
}

unload_items :: proc() {
	for texture in item_textures {
		rl.UnloadTexture(texture)
	}
}

Status_Effect :: enum {
	LIGMA,
	SLOW,
	SLEEP,
}
