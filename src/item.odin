package game


inventory: [20]Item

Item :: enum {
	NONE,
	COFFEE,
	TEA,
	HOT_CHOCOLATE,
	ORANGE,
	BISCUIT,
	COOKIE,
	ANTIDOTE,
	DAKI,
	RUBBER_DUCK,
	SPELL_CARD,
	HOURGLASS,
	BROCCOLI_EGGS,
	UMBRELLA,
	MICROPHONE,
	PENLIGHT,
	// MAP,
	// CROWBAR,
	// MICROWAVE,
}

use_item :: proc(item: Item, target_id: i32) -> bool {
	target := entities[target_id]
	_ = target
	_ = item

	return true
}



Status_Effect :: enum {
	LIGMA,
	SLOW,
	SLEEP,
}
