package game

import "core:encoding/json"
import "core:mem"
import "core:strings"
// import "core:math/linalg"
import rl "vendor:raylib"


TILE_MAP_SIZE :: Vec2i{64, 64}

tile_map: Tile_Map

Tile_Map :: struct {
	tile_set: Tile_Set `json:"-"`,
	tile_set_name: string,
	pos: Vec2 `json:"-"`,
	tiles: []u8,
	width: i32,
	height: i32,
}

Tile_Set :: struct {
	texture: rl.Texture2D `json:"-"`,
	texture_name: cstring,
	atlas_width: i32,
	atlas_height: i32,
	tile_width: i32,
	tile_height: i32,
}

create_tile_map :: proc(tile_map: ^Tile_Map) {
	path :: "assets/tile_sets/warehouse_floor.png"
	texture := rl.LoadTexture(path)
	tile_set := Tile_Set {
		texture = texture,
		atlas_width = texture.width / TILE_SIZE.x,
		atlas_height = texture.height / TILE_SIZE.y,
		tile_width = TILE_SIZE.x,
		tile_height = TILE_SIZE.y,
	}
	tile_map.tile_set = tile_set

	map_width :: 64
	map_height :: 64

	tile_map.tiles = make([]u8, map_width * map_height)
	tile_map.width = map_width
	tile_map.height = map_height
	for i in 0..<map_width*map_height {
		id := i %% 8
		tile_map.tiles[i] = cast(u8) id
	}
	tile_map.pos = {-32, -32}
}

load_tile_map :: proc(tile_map_file_name: string) -> (tile_map: Tile_Map, success: bool) {
	arena: mem.Dynamic_Arena
	mem.dynamic_arena_init(&arena)
	defer mem.dynamic_arena_destroy(&arena)
	arena_allocator := mem.dynamic_arena_allocator(&arena)
	// json_file_name := strings.concatenate({tile_map_name, ".json"}, arena_allocator)
	json_path, _ := join_file_path({root_dir, "assets/data/tile_maps", tile_map_file_name}, arena_allocator)
	bytes, ok := read_entire_file(json_path, arena_allocator)
	if !ok {
		return
	}
	unmarshal_err := json.unmarshal(bytes, &tile_map, allocator = context.allocator)
	if unmarshal_err != nil {
		return
	}

	tile_set, tile_set_ok := load_tile_set(tile_map.tile_set_name)
	if !tile_set_ok {
		return
	}
	tile_map.tile_set = tile_set
	success = true
	return
}

unload_tile_map :: proc(tile_map: Tile_Map) {
	delete(tile_map.tiles)
	unload_tile_set(tile_map.tile_set)
}

draw_tile_map :: proc(tile_map_in: Tile_Map) {
	for j in 0..<tile_map_in.height {
		for i in 0..<tile_map_in.width {
			tile_idx := tile_map_in.tiles[j * tile_map_in.width + i]
			tile_x := i32(tile_idx) %% tile_map_in.tile_set.atlas_width
			tile_y := i32(tile_idx) / tile_map_in.tile_set.atlas_width

			render_pos := render_pos_from_world_pos({f32(i), f32(j)} + tile_map.pos)

			// What? Make sure you're properly calculating the row and height.
			rl.DrawTextureRec(tile_map_in.tile_set.texture, {f32(tile_x * TILE_SIZE.x), f32(tile_y * TILE_SIZE.y),
				f32(TILE_SIZE.x), f32(TILE_SIZE.y)},
				render_pos,
				{0xff, 0xff, 0xff, 0xff})
		}
	}
}

load_tile_set :: proc(tile_set_file_name: string) -> (tile_set: Tile_Set, success: bool) {
	arena: mem.Dynamic_Arena
	mem.dynamic_arena_init(&arena)
	defer mem.dynamic_arena_destroy(&arena)
	arena_allocator := mem.dynamic_arena_allocator(&arena)
	// json_file_name := strings.concatenate({tile_set_file_name, ".json"}, arena_allocator)
	json_path, path_err := join_file_path({root_dir, "assets/data/tile_sets", tile_set_file_name}, arena_allocator)
	if path_err != nil {
		success = false
		return
	}
	bytes, file_ok := read_entire_file(json_path, arena_allocator)
	if !file_ok {
		success = false
		return
	}
	json_err := json.unmarshal(bytes, &tile_set, allocator = context.allocator)
	if json_err != nil {
		success = false
		return
	}
	texture_file_path, texture_path_err := join_file_path({root_dir, "assets/tile_sets", string(tile_set.texture_name)}, arena_allocator)
	if texture_path_err != nil {
		success = false
		return
	}
	cstr_texture_path := strings.clone_to_cstring(texture_file_path, arena_allocator)
	tile_set.texture = rl.LoadTexture(cstr_texture_path)
	success = true
	return
}

unload_tile_set :: proc(tile_set: Tile_Set) {
	rl.UnloadTexture(tile_set.texture)
}
