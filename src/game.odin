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

current_screen: Screen = .TITLE_SCREEN

entities := [100]Entity{}
party_member_ids := [MAX_PARTY_SIZE]i32{}
party_leader_idx: i32 = 0

main_character: Entity_Type

canvas: rl.RenderTexture2D
camera: rl.Camera2D

title_screen_texture: rl.Texture2D

// Use this for placing enemies and such when testing
test_mode := false

Screen :: enum {
	TITLE_SCREEN,
	LEVEL,
}

Vec2 :: [2]f32
Vec2i :: [2]i32

@(export)
game_update :: proc() {
	switch current_screen {
	case .TITLE_SCREEN:
		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		rl.BeginTextureMode(canvas)
		rl.DrawTexture(title_screen_texture, 0, 0, rl.WHITE)
		if current_menu != nil {
			current_menu.routine(current_menu)
		} else if rl.IsKeyPressed(.SPACE) {
			open_main_menu()
		}
		rl.EndTextureMode()
		rl.DrawTexturePro(canvas.texture, {0, 0, f32(RESOLUTION.x), f32(-RESOLUTION.y)}, {0, 0, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}, {0, 0}, 0, rl.WHITE)
		rl.EndDrawing()
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
		rl.UpdateMusicStream(swamp_music)
	}

	// Everything on tracking allocator is valid until end-of-frame.
	free_all(context.temp_allocator)
}

start_game :: proc(character: Entity_Type) {
	main_character = character
	current_screen = .LEVEL

	spawn_entity(character, {2, 2}, .PLAYER)

	party_leader_idx = 0
	spawn_entity(.BISCUITEER, {3, 3}, .ALLY)

	spawn_entity(.SAMMY, {4, 1}, .ENEMY)
	spawn_entity(.SAMMY, {8, 1}, .ENEMY)
	spawn_entity(.MALISTOCRAT, {14, 1}, .ENEMY)

	spawn_item(.COFFEE, {5, 5})
	spawn_item(.BROCCOLI_EGGS, {5, 7})

	append(&inventory, .COFFEE)

	rl.PlayMusicStream(swamp_music)
}

@(export)
game_init_window :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(WINDOW_SIZE.x, WINDOW_SIZE.y, "Saga Mystery Dungeon")
	rl.InitAudioDevice()
	rl.SetWindowPosition(200, 200)
	rl.SetTargetFPS(120)
	rl.SetExitKey(nil)
}

@(export)
game_init :: proc() {
	menu_texture = rl.LoadTexture("assets/Map-Ui-Palette.png")
	title_screen_texture = rl.LoadTexture("assets/ui/title_screen.png")
	create_tile_map(&tile_map)
	register_entities()
	ui_init()
	load_shaders()
	load_audio()

	canvas = rl.LoadRenderTexture(RESOLUTION.x, RESOLUTION.y)
	camera = {
		target = {0, 0},
		zoom = 1.0,
		offset = {f32(RESOLUTION.x) / 2, f32(RESOLUTION.y) / 2},
	}
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
	unload_audio()
	rl.UnloadTexture(menu_texture)
	rl.UnloadRenderTexture(canvas)
	rl.UnloadTexture(title_screen_texture)
}

@(export)
game_shutdown_window :: proc() {
	rl.CloseAudioDevice()
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
