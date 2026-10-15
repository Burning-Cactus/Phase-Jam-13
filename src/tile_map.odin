package game

import rl "vendor:raylib"
// import "core:math/linalg"
import "core:encoding/json"


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

load_tile_map :: proc(file_path: string) -> (tile_map: Tile_Map, success: bool) {
	bytes, ok := read_entire_file(file_path)
	if !ok {
		return
	}
	defer delete(bytes)
	unmarshal_err := json.unmarshal(bytes, &tile_map)
	if unmarshal_err == nil do success = true
	return
}

create_tile_map :: proc(tile_map: ^Tile_Map) {
	path :: "assets/tile_sets/warehouse_floor.png"
	texture := rl.LoadTexture(path)
	tile_set := Tile_Set{
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

unload_tile_map :: proc(tile_map: Tile_Map) {
	rl.UnloadTexture(tile_map.tile_set.texture)
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
