package editor

import "core:c"
import "core:encoding/json"
import "core:fmt"
import "core:math/linalg"
import "core:os"
import rl "vendor:raylib"

import game "../src"
import nfd "lib/nfd"

// Use this package to make the level editor and the UI editor.]

Editor_Mode :: enum {
	NONE,
	TILE_MAP,
	TILE_SET,
	ENTITY,
}

Editor_Stage :: enum {
	NONE,
	SELECT_FILE,
	EDITING,
}

BACKGROUND_COLOR :: rl.Color{0xbb, 0xbb, 0xbb, 0xff}

camera := rl.Camera2D {
	zoom = 1
}
mode: Editor_Mode
tile_cursor_texture: rl.Texture2D

canvas: rl.RenderTexture2D
main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(1920, 1080, "Tile Editor")
	rl.SetTargetFPS(120)
	rl.SetExitKey(nil)
	rl.SetMouseCursor(.ARROW)

	canvas = rl.LoadRenderTexture(480, 270)
	tile_cursor_texture = rl.LoadTexture("../assets/ui/tile_selector.png")
	nfd.Init()
	defer nfd.Quit()

	file_path: cstring


	for !rl.WindowShouldClose() {
		switch mode {
		case .NONE:
			file_path: cstring
			args := nfd.Open_Dialog_Args {
				filter_count = 0
			}
			rl.BeginDrawing()
			rl.ClearBackground(BACKGROUND_COLOR)
			if rl.GuiButton({120, 45, 800, 300}, "New tile map") {
				mode = .TILE_MAP
			}
			if rl.GuiButton({1000, 45, 800, 300}, "Edit tile map") {
				args := nfd.Open_Dialog_Args {
					filter_count = 0
				}
				result := nfd.OpenDialogMultipleU8_With(1, &file_path, &args)
				switch result {
				case .Okay:
					success: bool
					mode = .TILE_MAP
				case .Error:
				case .Cancel:
				}
				_ = result
			}
			if rl.GuiButton({120, 390, 800, 300}, "New tile set") {

			}
			if rl.GuiButton({1000, 390, 800, 300}, "Edit tile set") {

			}
// 			if rl.GuiButton({120, 735, 800, 300}, "New entity") {
//
// 			}
// 			if rl.GuiButton({1000, 735, 800, 300}, "Edit entity") {
//
// 			}
			rl.EndDrawing()
		case .TILE_MAP:
			run_tile_map_editor(string(file_path))
		case .TILE_SET:
		case .ENTITY:
		}
	}
	rl.UnloadRenderTexture(canvas)
	rl.UnloadTexture(tile_cursor_texture)
	rl.CloseWindow()
}

create_tile_map :: proc(tile_map: ^game.Tile_Map) {
	path :: "../assets/tile_sets/warehouse_floor.png"
	texture_name: cstring = "warehouse_floor.png"
	texture := rl.LoadTexture(path)
	tile_set := game.Tile_Set{
		texture = texture,
		texture_name = texture_name,
		atlas_width = texture.width / game.TILE_SIZE.x,
		atlas_height = texture.height / game.TILE_SIZE.y,
		tile_width = game.TILE_SIZE.x,
		tile_height = game.TILE_SIZE.y,
	}
	tile_map.tile_set = tile_set
	tile_map.tile_set_name = "warehouse_floor"

	map_width :: 8
	map_height :: 8

	tile_map.tiles = make([]u8, map_width * map_height)
	tile_map.width = map_width
	tile_map.height = map_height
}

save_tile_map :: proc(tile_map: game.Tile_Map) {
	file_path: cstring
	filters := [1]nfd.Filter_Item {{"JSON object", "json"}}
	args := nfd.Save_Dialog_Args {
		filter_list = raw_data(filters[:]),
		filter_count = 1,
	}
	result := nfd.SaveDialogU8_With(&file_path, &args)
	bytes, err := json.marshal(tile_map, json.Marshal_Options {
		pretty = true,
	})
	defer delete(bytes)
	json_data := string(bytes)
	file_handle, file_err := os.open(string(file_path), {.Create, .Write})
	if file_err == nil {
		defer os.close(file_handle)
		fmt.fprint(file_handle, json_data)
	} else {
		fmt.eprintln("Error: ", file_err)
	}
}

is_inside_rec :: proc{is_inside_rec_rl_rectangle, is_inside_rec_i32_array}

is_inside_rec_rl_rectangle :: proc(pos: game.Vec2, rec: rl.Rectangle) -> bool {
	return pos.x > rec.x &&
		pos.x < rec.x + rec.width &&
		pos.y > rec.y &&
		pos.y < rec.y + rec.height
}

is_inside_rec_i32_array :: proc(pos: game.Vec2i, rec: [4]i32) -> bool {
	return pos.x > rec.x &&
		pos.x < rec.x + rec[2] &&
		pos.y > rec.y &&
		pos.y < rec.y + rec[3]
}

run_tile_map_editor :: proc(file_path: string) {
	tile_map: game.Tile_Map
	ok: bool
	if len(file_path) == 0 {
		create_tile_map(&tile_map)
	} else {
		tile_map, ok = game.load_tile_map(file_path)
		if !ok do return
	}
	defer game.unload_tile_map(tile_map)
	tile_set_size: i32 = tile_map.tile_set.atlas_height * tile_map.tile_set.atlas_width
	paint_tile: u8 = 1
	for !rl.WindowShouldClose() {
		gui_pressed: bool

		mouse_pos := rl.GetMousePosition()
		scale := [2]f32{f32(game.RESOLUTION.x) / 1920, f32(game.RESOLUTION.y) / 1080}
		scaled_mouse_pos := mouse_pos * scale

		translated_mouse_pos := scaled_mouse_pos + camera.target

		tile_pos := game.world_pos_from_render_pos(translated_mouse_pos)
		tile_pos += {0, 1}
		tile_pos = linalg.floor(tile_pos)

		in_bounds := is_inside_rec(cast(game.Vec2i) tile_pos, {i32(tile_map.pos.x), i32(tile_map.pos.y), tile_map.width, tile_map.height})

		selector_pos := game.render_pos_from_world_pos(tile_pos)

		if rl.IsMouseButtonReleased(.LEFT) do gui_pressed = false

		window_width := rl.GetScreenWidth()
		window_height := rl.GetScreenHeight()
		tool_bar := rl.Rectangle{0, 0, f32(window_width), 128}
		save_button := rl.Rectangle{16, 32, 128, 64}
		if is_inside_rec(mouse_pos, tool_bar) {

			if is_inside_rec(mouse_pos, save_button) {
				if rl.IsMouseButtonPressed(.LEFT) {
					save_tile_map(tile_map)
					gui_pressed = true
				}
			}
		}
		else {
			if rl.IsMouseButtonDown(.MIDDLE) {
				camera.target -= linalg.floor(rl.GetMouseDelta() * scale)
			} else if rl.IsMouseButtonDown(.LEFT) && in_bounds {
				tile_idx: i32 = i32(tile_pos.y) * tile_map.width + i32(tile_pos.x)
				tile_map.tiles[tile_idx] = paint_tile
			} else if rl.IsMouseButtonDown(.RIGHT) && in_bounds {
				tile_idx: i32 = i32(tile_pos.y) * tile_map.width + i32(tile_pos.x)
				tile_map.tiles[tile_idx] = 0
			}
		}

		rl.BeginDrawing()
		rl.BeginTextureMode(canvas)
		{
			rl.ClearBackground({0xbb, 0xbb, 0xbb, 0xff})
			rl.BeginMode2D(camera)
			game.draw_tile_map(tile_map)
			selector_color: rl.Color
			if in_bounds {
				selector_color = {0xff, 0xff, 0xff, 0xff}
			} else {
				selector_color = {0xff, 0x88, 0x88, 0xff}
			}
			rl.DrawTexture(tile_cursor_texture, i32(selector_pos.x), i32(selector_pos.y), selector_color)
			rl.EndMode2D()

		}
		rl.EndTextureMode()
		rl.DrawTexturePro(canvas.texture, {0, 0, f32(game.RESOLUTION.x), f32(-game.RESOLUTION.y)}, {0, 0, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}, {0, 0}, 0, rl.WHITE)

		// Gui
		rl.DrawRectangleRec(tool_bar, {0x44, 0x44, 0x44, 0xff})

		button_color := rl.Color{0x44, 0x44, 0x44, 0xff}
		hover_color := rl.Color{0xaa, 0xaa, 0xaa, 0xff}

		save_button_color := hover_color if is_inside_rec(mouse_pos, save_button) else button_color
		rl.DrawRectangleRec(save_button, save_button_color)
		rl.DrawRectangleLinesEx(save_button, 2, rl.WHITE)
		rl.DrawText("Save", i32(save_button.x + 5), i32(save_button.y + save_button.height / 2), 36, rl.WHITE)

		for i in 0..<tile_set_size {
			x_offset: i32 = 160
			y_offset: i32 = 16
			x := (i / 2) * 72
			y := (i %% 2) * 40
			tile_button_rec := rl.Rectangle{f32(x + x_offset), f32(y + y_offset), 64, 32}
			hovered := is_inside_rec(mouse_pos, tile_button_rec)
			tile_button_color := hover_color if hovered else button_color
			rl.DrawRectangleRec(tile_button_rec, tile_button_color)
			rl.DrawRectangleLinesEx(tile_button_rec, 2, rl.WHITE)
			tile_set := tile_map.tile_set
			tile_x := i %% tile_set.atlas_width
			tile_y := i / tile_set.atlas_height
			rl.DrawTexturePro(tile_set.texture,
				{
					f32(tile_x * tile_set.tile_width), f32(tile_y * tile_set.tile_height),
					f32(tile_set.tile_width), f32(tile_set.tile_height),
				},
				tile_button_rec,
				0, 0, rl.WHITE
			)
			if hovered && rl.IsMouseButtonPressed(.LEFT) {
				paint_tile = u8(i)
			}
		}
		rl.EndDrawing()
	}

}
