package editor

import "core:c"
import "core:encoding/json"
import "core:fmt"
import "core:path/filepath"
import "core:math"
import "core:math/linalg"
import "core:mem"
import "core:os"
import "core:strings"
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

pre_existing_file: bool

canvas: rl.RenderTexture2D
main :: proc() {
	exec_dir, err := os.get_executable_directory(context.allocator)
	game.root_dir = filepath.dir(exec_dir)
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
			json_filters := [1]nfd.Filter_Item {{"JSON object", "json"}}
			png_filters := [1]nfd.Filter_Item {{"Sprite/Image", "png"}}
			rl.BeginDrawing()
			rl.ClearBackground(BACKGROUND_COLOR)
			if rl.GuiButton({120, 45, 800, 300}, "New tile map") {
				default_path, path_err := filepath.join({game.root_dir, "assets/data/tile_sets"}, context.temp_allocator)
				cstr_default_path := strings.clone_to_cstring(default_path, context.temp_allocator)
				args := nfd.Open_Dialog_Args {
					filter_list = raw_data(json_filters[:]),
					filter_count = 1,
					default_path = cstr_default_path,
				}
				result := nfd.OpenDialogU8_With(&file_path, &args)
				switch result {
				case .Okay:
					success: bool
					mode = .TILE_MAP
				case .Error:
				case .Cancel:
				}
			}
			if rl.GuiButton({1000, 45, 800, 300}, "Edit tile map") {
				default_path, path_err := filepath.join({game.root_dir, "assets/data/tile_maps"}, context.temp_allocator)
				cstr_default_path := strings.clone_to_cstring(default_path, context.temp_allocator)
				args := nfd.Open_Dialog_Args {
					filter_list = raw_data(json_filters[:]),
					filter_count = 1,
					default_path = cstr_default_path,
				}
				result := nfd.OpenDialogU8_With(&file_path, &args)
				switch result {
				case .Okay:
					pre_existing_file = true
					mode = .TILE_MAP
				case .Error:
				case .Cancel:
				}
			}
			if rl.GuiButton({120, 390, 800, 300}, "New tile set") {
				default_path, path_err := filepath.join({game.root_dir, "assets/tile_sets"}, context.temp_allocator)
				cstr_default_path := strings.clone_to_cstring(default_path, context.temp_allocator)
				args := nfd.Open_Dialog_Args {
					filter_list = raw_data(png_filters[:]),
					filter_count = 1,
					default_path = cstr_default_path,
				}
				result := nfd.OpenDialogU8_With(&file_path, &args)
				switch result {
				case .Okay:
					success: bool
					mode = .TILE_SET
				case .Error:
				case .Cancel:
				}
			}
			if rl.GuiButton({1000, 390, 800, 300}, "Edit tile set") {
				default_path, path_err := filepath.join({game.root_dir, "assets/data/tile_sets"}, context.temp_allocator)
				cstr_default_path := strings.clone_to_cstring(default_path, context.temp_allocator)
				args := nfd.Open_Dialog_Args {
					filter_list = raw_data(json_filters[:]),
					filter_count = 1,
					default_path = cstr_default_path,
				}
				result := nfd.OpenDialogU8_With(&file_path, &args)
				switch result {
				case .Okay:
					success: bool
					mode = .TILE_SET
					pre_existing_file = true
				case .Error:
				case .Cancel:
				}
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
			run_tile_set_editor(string(file_path), !pre_existing_file)
		case .ENTITY:
		}
		free_all(context.temp_allocator)
	}
	rl.UnloadRenderTexture(canvas)
	rl.UnloadTexture(tile_cursor_texture)
	rl.CloseWindow()
}

create_tile_map :: proc(tile_set_name: string) -> (tile_map: game.Tile_Map, success: bool) {
	tile_set, ok := game.load_tile_set(tile_set_name)
	if !ok {
		success = false
		return
	}
	tile_map.tile_set = tile_set
	tile_map.tile_set_name = tile_set_name
	map_width :: 16
	map_height :: 16
	tile_map.tiles = make([]u8, map_width * map_height)
	tile_map.width = map_width
	tile_map.height = map_height
	success = true
	return
}

run_tile_map_editor :: proc(file_path: string) {
	tile_map: game.Tile_Map
	ok: bool
	if pre_existing_file {
		_, tile_map_name := filepath.split(file_path)
		tile_map, ok = game.load_tile_map(tile_map_name)
	} else {
		_, tile_set_name := filepath.split(file_path)
		tile_map, ok = create_tile_map(tile_set_name)
	}
	if !ok do return
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

		in_grid_bounds := is_inside_rec(cast(game.Vec2i) tile_pos, {i32(tile_map.pos.x), i32(tile_map.pos.y), tile_map.width, tile_map.height})

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
			} else if rl.IsMouseButtonDown(.LEFT) && in_grid_bounds {
				tile_idx: i32 = i32(tile_pos.y) * tile_map.width + i32(tile_pos.x)
				tile_map.tiles[tile_idx] = paint_tile
			} else if rl.IsMouseButtonDown(.RIGHT) && in_grid_bounds {
				tile_idx: i32 = i32(tile_pos.y) * tile_map.width + i32(tile_pos.x)
				tile_map.tiles[tile_idx] = 0
			}
		}

		rl.BeginDrawing()
		rl.BeginTextureMode(canvas)
		{
			rl.ClearBackground({0xbb, 0xbb, 0xbb, 0xff})
			rl.BeginMode2D(camera)
			adjusted_pos := cast(game.Vec2) tile_map.pos
			top_corner := game.render_pos_from_world_pos(adjusted_pos)
			right_corner := game.render_pos_from_world_pos(adjusted_pos + {f32(tile_map.width), 0})
			bottom_corner := game.render_pos_from_world_pos(adjusted_pos + {f32(tile_map.width), f32(tile_map.height)})
			left_corner := game.render_pos_from_world_pos(adjusted_pos + {0, f32(tile_map.height)})
			border_color :: rl.Color{0x22, 0x22, 0x22, 0xFF}
			rl.DrawLineEx(top_corner, right_corner, 3, border_color)
			rl.DrawLineEx(right_corner, bottom_corner, 3, border_color)
			rl.DrawLineEx(bottom_corner, left_corner, 3, border_color)
			rl.DrawLineEx(left_corner, top_corner, 3, border_color)

			game.draw_tile_map(tile_map)

			selector_color: rl.Color
			if in_grid_bounds {
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

run_tile_set_editor :: proc(file_path: string, new_tile_set: bool) {
	tile_set: game.Tile_Set
	ok: bool = true
	if new_tile_set {
		DEFAULT_TILE_SIZE :: game.Vec2i{64, 32}
		texture_path := strings.clone_to_cstring(file_path, context.temp_allocator)
		tile_set.texture = rl.LoadTexture(texture_path)
		_, texture_name := filepath.split(file_path)
		cstr_texture_name := strings.clone_to_cstring(texture_name)
		tile_set.texture_name = cstr_texture_name
		tile_set.tile_width = DEFAULT_TILE_SIZE.x
		tile_set.tile_height = DEFAULT_TILE_SIZE.y
		tile_set.atlas_width = tile_set.texture.width / tile_set.tile_width
		tile_set.atlas_height = tile_set.texture.height / tile_set.tile_height
	} else {
		_, tile_set_name := filepath.split(file_path)
		tile_set, ok = game.load_tile_set(tile_set_name)
	}
	if !ok do return
	defer rl.UnloadTexture(tile_set.texture)
	defer delete(tile_set.texture_name)
	defer game.unload_tile_set(tile_set)

	cell_width: f32 = f32(tile_set.tile_width)
	cell_height: f32 = f32(tile_set.tile_height)
	atlas_width: f32 = f32(tile_set.atlas_width)
	atlas_height: f32 = f32(tile_set.atlas_height)

	for !rl.WindowShouldClose() {
		gui_pressed: bool

		mouse_pos := rl.GetMousePosition()
		scale := [2]f32{f32(game.RESOLUTION.x) / 1920, f32(game.RESOLUTION.y) / 1080}
		scaled_mouse_pos := mouse_pos * scale

		translated_mouse_pos := scaled_mouse_pos + camera.target

		tile_pos := game.world_pos_from_render_pos(translated_mouse_pos)
		tile_pos += {0, 1}
		tile_pos = linalg.floor(tile_pos)

		selector_pos := game.render_pos_from_world_pos(tile_pos) - {32, 0}

		if rl.IsMouseButtonReleased(.LEFT) do gui_pressed = false

		window_width := rl.GetScreenWidth()
		window_height := rl.GetScreenHeight()
		tool_bar := rl.Rectangle{0, 0, f32(window_width), 128}
		save_button := rl.Rectangle{16, 32, 128, 64}
		if is_inside_rec(mouse_pos, tool_bar) {
			gui_pressed = true
			if is_inside_rec(mouse_pos, save_button) {
				if rl.IsMouseButtonPressed(.LEFT) {
					save_tile_set(tile_set)
				}
			}
		}
		else {
			if rl.IsMouseButtonDown(.MIDDLE) {
				camera.target -= linalg.floor(rl.GetMouseDelta() * scale)
			}
		}

		rl.BeginDrawing()
		rl.BeginTextureMode(canvas)
		{
			rl.ClearBackground({0xbb, 0xbb, 0xbb, 0xff})
			rl.BeginMode2D(camera)
			rl.DrawTexture(tile_set.texture, 0, 0, rl.WHITE)
			grid_color :: rl.Color{0x22, 0x22, 0x22, 0xaa}
			for i in 0..=tile_set.atlas_width {
				rl.DrawLine(i * tile_set.tile_width, 0, i * tile_set.tile_width, tile_set.texture.height, grid_color)
			}
			for j in 0..=tile_set.atlas_height {
				rl.DrawLine(0, j * tile_set.tile_height, tile_set.texture.width, j * tile_set.tile_height, grid_color)
			}
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

		// Tile set adjustment buttons
		current_pos := game.Vec2{save_button.x + save_button.width + 20, save_button.y}

		slider_width :: 240
		slider_height :: 40

		current_pos.x += slider_width + 80
		draw_slider(&cell_width, 0, 128, {current_pos.x, current_pos.y + 40, slider_width, slider_height})
		tile_set.tile_width = i32(math.floor(cell_width))
		cell_width_label := fmt.ctprintf("Cell Width: %d:", tile_set.tile_width)
		rl.DrawText(cell_width_label, i32(current_pos.x), i32(current_pos.y), 24, rl.WHITE)

		current_pos.x += slider_width + 80
		draw_slider(&cell_height, 0, 128, {current_pos.x, current_pos.y + 40, slider_width, slider_height})
		tile_set.tile_height = i32(math.floor(cell_height))
		cell_height_label := fmt.ctprintf("Cell Height: %d:", tile_set.tile_height)
		rl.DrawText(cell_height_label, i32(current_pos.x), i32(current_pos.y), 24, rl.WHITE)

		current_pos.x += slider_width + 80
		draw_slider(&atlas_width, 0, 128, {current_pos.x, current_pos.y + 40, slider_width, slider_height})
		tile_set.atlas_width = i32(math.floor(atlas_width))
		atlas_width_label := fmt.ctprintf("Columns: %d:", tile_set.atlas_width)
		rl.DrawText(atlas_width_label, i32(current_pos.x), i32(current_pos.y), 24, rl.WHITE)

		current_pos.x += slider_width + 80
		draw_slider(&atlas_height, 0, 128, {current_pos.x, current_pos.y + 40, slider_width, slider_height})
		tile_set.atlas_height = i32(math.floor(atlas_height))
		atlas_height_label := fmt.ctprintf("Rows: %d:", tile_set.atlas_height)
		rl.DrawText(atlas_height_label, i32(current_pos.x), i32(current_pos.y), 24, rl.WHITE)

		rl.EndDrawing()

		free_all(context.temp_allocator)
	}
}

draw_slider :: proc(value: ^f32, floor: f32, ceil: f32, rect: rl.Rectangle) {
	rl.GuiSlider(rect, "", "", value, floor, ceil)
}


save_tile_map :: proc(tile_map: game.Tile_Map) {
	arena: mem.Dynamic_Arena
	mem.dynamic_arena_init(&arena)
	defer mem.dynamic_arena_destroy(&arena)
	arena_allocator := mem.dynamic_arena_allocator(&arena)
	default_path, path_err := filepath.join({game.root_dir, "assets/data/tile_maps"}, arena_allocator)
	cstr_default_path := strings.clone_to_cstring(default_path, arena_allocator)
	if path_err != nil do return
	file_path: cstring
	filters := [1]nfd.Filter_Item {{"JSON object", "json"}}
	args := nfd.Save_Dialog_Args {
		filter_list = raw_data(filters[:]),
		filter_count = 1,
		default_path = cstr_default_path,
	}
	result := nfd.SaveDialogU8_With(&file_path, &args)
	bytes, err := json.marshal(tile_map, json.Marshal_Options {
		pretty = true,
	}, arena_allocator)
	json_data := string(bytes)
	file_handle, file_err := os.open(string(file_path), {.Create, .Write})
	if file_err == nil {
		defer os.close(file_handle)
		fmt.fprint(file_handle, json_data)
	} else {
		fmt.eprintln("Error: ", file_err)
	}
}

save_tile_set :: proc(tile_set: game.Tile_Set) {
	arena: mem.Dynamic_Arena
	mem.dynamic_arena_init(&arena)
	defer mem.dynamic_arena_destroy(&arena)
	arena_allocator := mem.dynamic_arena_allocator(&arena)
	default_path, path_err := filepath.join({game.root_dir, "assets/data/tile_sets"}, arena_allocator)
	cstr_default_path := strings.clone_to_cstring(default_path, arena_allocator)
	if path_err != nil do return
	file_path: cstring
	filters := [1]nfd.Filter_Item {{"JSON object", "json"}}
	args := nfd.Save_Dialog_Args {
		filter_list = raw_data(filters[:]),
		filter_count = 1,
		default_path = cstr_default_path
	}
	result := nfd.SaveDialogU8_With(&file_path, &args)
	bytes, err := json.marshal(tile_set, json.Marshal_Options {
		pretty = true,
	}, arena_allocator)
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
	return pos.x >= rec.x &&
		pos.x < rec.x + rec.width &&
		pos.y >= rec.y &&
		pos.y < rec.y + rec.height
}

is_inside_rec_i32_array :: proc(pos: game.Vec2i, rec: [4]i32) -> bool {
	return pos.x >= rec.x &&
		pos.x < rec.x + rec[2] &&
		pos.y >= rec.y &&
		pos.y < rec.y + rec[3]
}
