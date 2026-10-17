package game

import rl "vendor:raylib"
import "core:math/linalg"

WINDOW_SIZE :: Vec2i{1920, 1080}
RESOLUTION :: Vec2i{480, 270}
TILE_SIZE :: [2]i32{64, 32}
TILE_WIDTH :: 64
TILE_HEIGHT :: 32
MAX_PARTY_SIZE :: 4
MAX_ENEMIES :: 100
PLAYER_SPEED :: 0.02

UPDATE_SPEED :: f32(1) / 120

root_dir: string = ""

run: bool = true
time_since_update: f32 = 0

current_screen: Screen = .LEVEL

entities := [100]Entity{}
party_member_ids := [MAX_PARTY_SIZE]i32{}
party_leader_idx: i32 = 0

menu_texture: rl.Texture2D
canvas: rl.RenderTexture2D
camera: rl.Camera2D

// Use this for placing enemies and such when testing
test_mode := false

Screen :: enum {
	TITLE_SCREEN,
	CHARACTER_SELECT,
	LEVEL,
}

Vec2 :: [2]f32
Vec2i :: [2]i32

@(export)
game_update :: proc() {
	switch current_screen {
	case .TITLE_SCREEN:
		// main_menu_update()
	case .CHARACTER_SELECT:
		// character_select_update()
	case .LEVEL:
		time_since_update += rl.GetFrameTime()
		for time_since_update > UPDATE_SPEED {
			if current_menu == nil {
				update_entities(entities[:])
			}
			time_since_update -= UPDATE_SPEED
		}

		if rl.IsKeyPressed(.F3) {
			test_mode = !test_mode
		}

		rl.BeginDrawing()
		rl.BeginTextureMode(canvas)
		{
			rl.ClearBackground(rl.BLACK)

			camera.target = linalg.floor(render_pos_from_world_pos(entities[party_leader_idx].pos))
			rl.BeginMode2D(camera)

			// TODO: Will need to hide entities behind terrain. Probably will just have to sort each array and do it row-by-row.
			draw_tile_map(tile_map)
			draw_scene()
			rl.EndMode2D()
			draw_ui()
		}
		rl.EndTextureMode()
		rl.DrawTexturePro(canvas.texture, {0, 0, f32(RESOLUTION.x), f32(-RESOLUTION.y)}, {0, 0, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}, {0, 0}, 0, rl.WHITE)
		rl.EndDrawing()
	}

	// Everything on tracking allocator is valid until end-of-frame.
	free_all(context.temp_allocator)
}

@(export)
game_init_window :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(WINDOW_SIZE.x, WINDOW_SIZE.y, "Saga Mystery Dungeon")
	rl.SetWindowPosition(200, 200)
	rl.SetTargetFPS(120)
	rl.SetExitKey(nil)
}

@(export)
game_init :: proc() {
	menu_texture = rl.LoadTexture("assets/Map-Ui-Palette.png")
	create_tile_map(&tile_map)
	register_entities()
	ui_init()
	load_shaders()

	canvas = rl.LoadRenderTexture(RESOLUTION.x, RESOLUTION.y)
	camera = {
		target = {0, 0},
		zoom = 1.0,
		offset = {f32(RESOLUTION.x) / 2, f32(RESOLUTION.y) / 2},
	}

	spawn_entity(.NITYA, {2, 2}, .PLAYER)

	party_leader_idx = 0
	spawn_entity(.BISCUITEER, {3, 3}, .ALLY)

	spawn_entity(.SAMMY, {4, 1}, .ENEMY)
	spawn_entity(.SAMMY, {8, 1}, .ENEMY)
	spawn_entity(.MALISTOCRAT, {14, 1}, .ENEMY)

	spawn_item(.COFFEE, {5, 5})
	spawn_item(.BROCCOLI_EGGS, {5, 7})

	append(&inventory, .COFFEE)
}

@(export)
game_should_run :: proc() -> bool {
	when ODIN_OS != .JS {
		// Never run this proc in browser. It contains a 16 ms sleep on web!
		if rl.WindowShouldClose() {
			return false
		}
	}

	return run
}

@(export)
game_shutdown :: proc() {
	unload_tile_map(tile_map)
	unregister_entities()
	ui_deinit()
	unload_shaders()
	rl.UnloadTexture(menu_texture)
	rl.UnloadRenderTexture(canvas)
}

@(export)
game_shutdown_window :: proc() {
	rl.CloseWindow()
}

@(export)
game_force_reload :: proc() -> bool {
	return rl.IsKeyPressed(.F5)
}

@(export)
game_force_restart :: proc() -> bool {
	return rl.IsKeyPressed(.F6)
}

// In a web build, this is called when browser changes size. Remove the
// `rl.SetWindowSize` call if you don't want a resizable game.
game_parent_window_size_changed :: proc(w, h: int) {
	rl.SetWindowSize(i32(w), i32(h))
}
