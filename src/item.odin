package game


inventory: [dynamic; 20]Item_Type

field_items: [100]Field_Item

Item_Type :: enum {
	NONE,
	COFFEE,
	// TEA,
	// HOT_CHOCOLATE,
	ORANGE,
	BISCUIT,
	COOKIE,
	// ANTIDOTE,
	// DAKI,
	RUBBER_DUCK,
	// SPELL_CARD,
	// HOURGLASS,
	BROCCOLI_EGGS,
	// UMBRELLA,
	MICROPHONE,
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
	.COOKIE = "Cookie",
	.RUBBER_DUCK = "Rubber Duck",
	.BROCCOLI_EGGS = "Broccoli & Eggs",
	.MICROPHONE = "Microphone",
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
	target := &entities[target_id]

	#partial switch item {
	case .COFFEE: heal_entity(target, 20)
	case .ORANGE: heal_entity(target, 20)
	case .BISCUIT: heal_entity(target, 40)
	case .COOKIE: heal_entity(target, 40)
	case .BROCCOLI_EGGS: heal_entity(target, 30)
	// case .TEA: regen_entity
	// case .HOT_CHOCOLATE:
	// case .ANTIDOTE:
	// case .DAKI:
	case .RUBBER_DUCK:
	// case .SPELL_CARD:
	// case .HOURGLASS:
	// case .UMBRELLA:
	case .MICROPHONE:
	}

	return true
}



Status_Effect :: enum {
	LIGMA,
	SLOW,
	SLEEP,
}
