package game

import "core:math"
import "core:math/rand"
import "core:math/noise"

TILE_SIZE :: [2]i32{64, 32}
TILE_WIDTH :: 64
TILE_HEIGHT :: 32

current_floor: Floor
floor_number: i32

Stairs :: struct {
	pos: Vec2i,
}

dungeon_tile_set: Tile_Set

entities := [100]Entity{}

Floor :: struct {
	tile_map: Tile_Map,
	stairs: Stairs,
}

init_dungeon :: proc() {
	dungeon_tile_set, _ = load_tile_set("swamp.json")
	floor_number = 1
	seed := rand.uint64()
	generate_floor(cast(i64) seed)
}

unload_dungeon :: proc() {
	unload_tile_set(dungeon_tile_set)
}

advance_to_next_floor :: proc() {
	floor_number += 1
	seed := rand.uint64()
	for i in 0..<len(entities) {
		entities[i].in_use = false
	}
	for i in 0..<len(field_items) {
		field_items[i].in_use = false
	}
	generate_floor(cast(i64) seed)
}

@(private)
generate_floor :: proc(seed: i64) {
	delete(current_floor.tile_map.tiles)
	width: i32 : 32
	height: i32 : 32
	tiles := make([]u8, width * height)
	current_floor.tile_map = {
		tile_set = dungeon_tile_set,
		width = width,
		height = height,
		tiles = tiles,
	}

	for y in 0..<height {
		for x in 0..<width {
			idx := y * width + x
			value := noise.noise_2d(seed, {f64(x) * 0.1, f64(y) * 0.1})
			if value > -0.6 {
				tiles[idx] = 1
			} else {
				tiles[idx] = 150
			}
		}
	}

	// Return adjacent tiles in clockwise order, starting with the top left
	get_adjacent_tiles :: proc(center: Vec2i, tile_map: Tile_Map) -> (adjacent: [4]u8) {
		adjacent[0], _ = get_tile(center + {-1, 0}, tile_map)
		adjacent[1], _ = get_tile(center + {0, -1}, tile_map)
		adjacent[2], _ = get_tile(center + {1, 0}, tile_map)
		adjacent[3], _ = get_tile(center + {0, 1}, tile_map)
		return
	}

	// Second pass
	for y in 0..<height {
		for x in 0..<width {
			idx := y * width + x
			tile := tiles[idx]
			adjacent := get_adjacent_tiles({x, y}, current_floor.tile_map)
			if tile >= 150 {
				top_left_land := adjacent[0] < 150 && adjacent[0] != 0
				top_right_land := adjacent[1] < 150 && adjacent[1] != 0
				if top_left_land && top_right_land do tile = 156
				else if top_left_land do tile = 154
				else if top_right_land do tile = 152
			} else {
				top_left_water := adjacent[0] >= 150
				top_right_water := adjacent[1] >= 150
				bottom_right_water := adjacent[2] >= 150
				bottom_left_water := adjacent[3] >= 150
				if top_left_water && top_right_water do tile = 2
				else if top_right_water && bottom_right_water do tile = 3
				else if bottom_right_water && bottom_left_water do tile = 4
				else if bottom_left_water && top_left_water do tile = 5
				else if top_right_water do tile = 6
				else if bottom_right_water do tile = 7
				else if bottom_left_water do tile = 8
				else if top_left_water do tile = 9
			}
			tiles[idx] = tile
		}
	}

	// Third pass for water details
	for y in 0..<height {
		for x in 0..<width {
			idx := y * width + x
			tile := tiles[idx]
			if tiles[idx] < 150 {

			} else if tiles[idx] == 150 {
				value := noise.noise_2d(seed, {f64(x) * 0.3, f64(y) * 0.3})
				if value > 0 {
					value = (value)
					decoration_idx := math.clamp(u8(math.floor(value * 20)), 0, 20)
					tile = 180 + decoration_idx
				}
			}
			tiles[idx] = tile
		}
	}

	item_count := rand.uint32_max(5) + 10 // Not deterministic based on seed argument
	for _ in 0..<item_count {
		type := cast(Item_Type) rand.uint32_range(1, len(Item_Type))
		if type != .NONE do spawn_item(type, cast(Vec2) select_random_pos_not_obstructed(current_floor.tile_map))
	}

	party_leader_idx = spawn_entity(main_character, cast(Vec2) select_random_pos_not_obstructed(current_floor.tile_map), .PLAYER)

	enemy_count := rand.uint32_max(10) + 10 // Not deterministic based on seed argument
	for _ in 0..<enemy_count {
		type := cast(Entity_Type) rand.uint32_range(2, len(Entity_Type))
		spawn_entity(type, cast(Vec2) select_random_pos_not_obstructed(current_floor.tile_map), .ENEMY)
	}

	current_floor.stairs.pos = select_random_pos_not_obstructed(current_floor.tile_map)
}

select_random_pos_not_obstructed :: proc(tile_map: Tile_Map) -> Vec2i {
	tile: u8 = 0
	x: i32
	y: i32
	for tile == 0 || tile >= 150 {
		x = rand.int31_max(tile_map.width)
		y = rand.int31_max(tile_map.height)
		tile, _ = get_tile({x, y}, tile_map)
	}
	return tile_map.pos + {x, y}
}

update_world :: proc() {
	if is_inside_rec(entities[party_leader_idx].pos, {f32(current_floor.stairs.pos.x), f32(current_floor.stairs.pos.y), 1, 1}) {
		advance_to_next_floor()
	} else {

	}
}
