package game

import "core:math/linalg"
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
