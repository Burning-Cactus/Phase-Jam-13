package game

import "core:math/linalg"
import rl "vendor:raylib"
// These matrices make up the axes of the game's coordinate system.

iso_rotation_matrix := matrix[2, 2]f32 {
	1, 1,
	-1, 1,
}

iso_transform_matrix := matrix[2, 2]f32 {
	TILE_WIDTH / 2, TILE_HEIGHT / 2,
	-TILE_WIDTH / 2, TILE_HEIGHT / 2,
}

// Calculate where to draw on the screen in an isometric world.
render_pos_from_world_pos :: proc(world_pos: Vec2) -> Vec2 {
	return world_pos * iso_transform_matrix
}

world_pos_from_render_pos :: proc(render_pos: Vec2) -> Vec2 {
	return render_pos * linalg.inverse(iso_transform_matrix)
}

is_inside_rec :: proc{is_inside_rec_rl_rectangle, is_inside_rec_i32_array}

is_inside_rec_rl_rectangle :: proc(pos: Vec2, rec: rl.Rectangle) -> bool {
	return pos.x >= rec.x &&
		pos.x <= rec.x + rec.width &&
		pos.y >= rec.y &&
		pos.y <= rec.y + rec.height
}

is_inside_rec_i32_array :: proc(pos: Vec2i, rec: [4]i32) -> bool {
	return pos.x >= rec.x &&
		pos.x <= rec.x + rec[2] &&
		pos.y >= rec.y &&
		pos.y <= rec.y + rec[3]
}
