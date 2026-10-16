/*
 * It's expected that you've already begun drawing when calling these functions.
 */
package game

import rl "vendor:raylib"
import "core:fmt"
import "core:mem"
import "core:math/linalg"

// Use this to keep track of the menu hierarchy without any dangling pointers.
@(private) buf: [2048]u8
@(private) stack_alloc: mem.Stack
@(private) menu_allocator: mem.Allocator

current_menu: ^Menu

target_cursor: Target_Cursor
target_cursor_texture: rl.Texture2D

Target_Cursor :: struct {
	pos: Vec2,
	old_pos: Vec2,
	ticks_since_update: i32,
	target_idx: i32,
	visible: bool,
}

Menu_Item :: struct {
	name: cstring,
	value: i32,
}

Menu :: struct {
	prev: ^Menu,
	buttons: []Menu_Item,
	cursor_idx: i32,
	top_left: Vec2i,
	routine: proc(^Menu),
}


ui_init :: proc() {
	mem.stack_init(&stack_alloc, buf[:])
	menu_allocator = mem.stack_allocator(&stack_alloc)
	target_cursor_texture = rl.LoadTexture("assets/ui/selection_arrow.png")
}

ui_deinit :: proc() {
	rl.UnloadTexture(target_cursor_texture)
}

draw_ui :: proc() {
	player := entities[party_leader_idx]
	info := entity_definitions[player.type]

	top_left := Vec2{f32(RESOLUTION.x) - 90, 10}
	ui_size := Vec2{80, 40}
	neutral_color := rl.Color{0x80, 0x80, 0x80, 0x66}
	character_color := rl.Color{info.color_code.r, info.color_code.g, info.color_code.b, 0xcc}
	rl.DrawRectangleGradientEx({top_left.x, top_left.y, ui_size.x, ui_size.y},
		character_color, neutral_color,
		neutral_color, character_color)

	top_left = top_left + {10, 10}
	max_hp := player.max_health // TODO: Do this for the whole party
	hp := player.health
	hp_ratio := f32(hp) / f32(max_hp)
	draw_bar(hp_ratio, {top_left.x, top_left.y, 60, 5}, {0xc2, 0x00, 0x00, 0xff}, {0x42, 0x07, 0x07, 0xff})

	if player.current_action != .NONE {
		top_left = top_left + {0, 10}
		action_cost: f32 = 30
		action_time: f32 = player.action_charge
		action_ratio := action_time / action_cost
		draw_bar(action_ratio, {top_left.x, top_left.y, 40, 5}, rl.Color{0xa0, 0xa0, 0x22, 0xff}, rl.Color{0x4d, 0x4d, 0x00, 0xff})
	}

	if current_menu != nil {
		current_menu.routine(current_menu)
	} else if rl.IsKeyPressed(.SPACE) {
		open_battle_menu()
	}
}

draw_bar :: proc{draw_bar_values, draw_bar_ratio}

draw_bar_values :: proc(current_value: f32, max_value: f32, rect: rl.Rectangle, fill_color, bg_color: rl.Color) {
	draw_bar_ratio(current_value / max_value, rect, fill_color, bg_color)
}

draw_bar_ratio :: proc(fill_ratio: f32, rect: rl.Rectangle, fill_color, bg_color: rl.Color) {
	fill_size := fill_ratio * rect.width
	rl.DrawRectanglePro({rect.x, rect.y, fill_size, rect.height}, {}, 0, fill_color)
	rl.DrawRectanglePro({rect.x + fill_size, rect.y, rect.width - fill_size, rect.height}, {}, 0, bg_color)
}

pop_menu :: proc() {
	old_menu := current_menu
	current_menu = current_menu.prev
	target_cursor.visible = false
	delete(old_menu.buttons, menu_allocator)
	free(old_menu, menu_allocator)
}

close_all_menus :: proc() {
	current_menu = nil
	target_cursor.visible = false
	free_all(menu_allocator)
}

close_battle_menu :: proc() {
	pop_menu()
}

@(private) Battle_Options :: enum {
	ATTACK,
	// SKILLS,
	ITEMS,
	CANCEL,
}

open_battle_menu :: proc() {
	next_menu, err := new(Menu, menu_allocator)
	if err != nil {
		fmt.printf("ERROR: Failed to allocate new menu instance!\n")
	}
	next_menu.prev = current_menu
	current_menu = next_menu
	current_menu.buttons = make([]Menu_Item, 3, menu_allocator)
	current_menu.buttons[0] = {
		name = "Attack",
		value = 0,
	}
	current_menu.buttons[1] = {
		name = "Items",
		value = 1,
	}
	current_menu.buttons[2] = {
		name = "Cancel",
		value = 2,
	}
	current_menu.routine = update_battle_menu
	current_menu.top_left = Vec2i{20, RESOLUTION.y - 120}
}

update_battle_menu :: proc(menu: ^Menu) {
	if rl.IsKeyPressed(.BACKSPACE) {
		close_battle_menu()
	}
	if rl.IsKeyPressed(.SPACE) {
		switch Battle_Options(menu.cursor_idx) {
		case Battle_Options.ATTACK:
			open_attack_menu()
		case Battle_Options.ITEMS:
		case Battle_Options.CANCEL:
			close_battle_menu()
		case:
			fmt.printf("Unimplemented button!\n")
		}
	}
	if rl.IsKeyPressed(.DOWN) {
		menu.cursor_idx += 1
		if menu.cursor_idx >= i32(len(menu.buttons)) do menu.cursor_idx = 0
	} else if rl.IsKeyPressed(.UP) {
		menu.cursor_idx -= 1
		if menu.cursor_idx < 0 do menu.cursor_idx = cast(i32) (len(menu.buttons) - 1)
	}
	draw_battle_menu(menu)
}

open_attack_menu :: proc() {
	next_menu, err := new(Menu, menu_allocator)
	if err != nil {
		fmt.printf("ERROR: Failed to allocate new menu instance!\n")
	}
	next_menu.prev = current_menu
	current_menu = next_menu
	current_menu.routine = update_attack_menu
	current_menu.top_left = Vec2i{20, RESOLUTION.y - 120}
	party_leader := entities[party_leader_idx]
	available_targets := get_entities_in_range(party_leader.pos, 8, entities[:])
	current_menu.buttons = make([]Menu_Item, len(available_targets), menu_allocator)
	for i in i32(0)..<i32(len(available_targets)) {
		enemy_idx := available_targets[i]
		entity := entities[enemy_idx]
		current_menu.buttons[i] = {
			name = entity_definitions[entity.type].name,
			value = enemy_idx,
		}
	}
	delete(available_targets)
	if len(current_menu.buttons) > 0 {
		target := entities[current_menu.buttons[0].value]
		target_cursor.pos = target.pos
		target_cursor.old_pos = target.pos
		target_cursor.visible = true
	}
}

update_attack_menu :: proc(menu: ^Menu) {
	if rl.IsKeyPressed(.BACKSPACE) {
		pop_menu()
	}
	if rl.IsKeyPressed(.DOWN) {
		menu.cursor_idx += 1
		if menu.cursor_idx >= i32(len(menu.buttons)) do menu.cursor_idx = 0
		target_cursor.old_pos = target_cursor.pos
		target_cursor.target_idx = menu.buttons[menu.cursor_idx].value
		target_cursor.ticks_since_update = 0
	} else if rl.IsKeyPressed(.UP) {
		menu.cursor_idx -= 1
		if menu.cursor_idx < 0 do menu.cursor_idx = cast(i32) (len(menu.buttons) - 1)
		target_cursor.old_pos = target_cursor.pos
		target_cursor.target_idx = menu.buttons[menu.cursor_idx].value
		target_cursor.ticks_since_update = 0
	}
	if rl.IsKeyPressed(.SPACE) {
		set_action(&entities[party_leader_idx], menu.buttons[menu.cursor_idx].value)
		close_all_menus()
	}
	draw_battle_menu(menu)
	if target_cursor.ticks_since_update < 15 {
		target_idx := menu.buttons[menu.cursor_idx].value
		target := entities[target_idx]
		target_cursor.ticks_since_update += 1
		target_cursor.pos = linalg.lerp(target_cursor.old_pos, target.pos, f32(target_cursor.ticks_since_update) / 15)
	}
	CURSOR_HALF_SIZE :: [2]f32{16 / 2, 16 / 2}

	render_pos := render_pos_from_world_pos(target_cursor.pos) - CURSOR_HALF_SIZE
	render_pos.y -= 24

	rl.BeginMode2D(camera)
	rl.DrawTextureV(target_cursor_texture, render_pos, {0xff, 0xff, 0xff, 0xff})
	rl.EndMode2D()
}

draw_battle_menu :: proc(menu: ^Menu) {
	menu_size := Vec2{60, 100}
	rl.DrawTexturePro(menu_texture, {0, 0, 48, 48}, {f32(menu.top_left.x), f32(menu.top_left.y), menu_size.x, menu_size.y}, 0, 0, rl.WHITE)
	{
		for i in i32(0)..<i32(len(menu.buttons)) {
			if i == menu.cursor_idx {
				rl.DrawText(menu.buttons[i].name, i32(menu.top_left.x) + 5, i32(menu.top_left.y) + i * 20 + 10, 12, {0x6a, 0x1d, 0x13, 0xff})
			} else {
				rl.DrawText(menu.buttons[i].name, i32(menu.top_left.x) + 5, i32(menu.top_left.y) + i * 20 + 10, 12, {0x2a, 0x1b, 0x16, 0xff})
			}
		}
	}
}

main_menu_update :: proc(menu: ^Menu) {
	Menu_Button :: struct {
		name: cstring,
	}
	buttons := []Menu_Button {
		{"Start Game"},
		{"Continue"},
	}
	if rl.IsKeyPressed(.SPACE) {
		switch menu.cursor_idx {
		case 0:
			current_screen = .CHARACTER_SELECT
		case:
			fmt.printf("Unimplemented button!\n")

		}
	} else if rl.IsKeyPressed(.DOWN) {
		menu.cursor_idx += 1
		if menu.cursor_idx >= i32(len(buttons)) do menu.cursor_idx = 0
	} else if rl.IsKeyPressed(.UP) {
		menu.cursor_idx -= 1
		if menu.cursor_idx < 0 do menu.cursor_idx = cast(i32) (len(buttons) - 1)
	}
	rl.BeginDrawing()
	rl.BeginTextureMode(canvas)
	{
		rl.ClearBackground({0xad, 0x96, 0x74, 0xff})
		top_left := Vec2i{100, 100}
		for i in i32(0)..<i32(len(buttons)) {
			button := buttons[i]
			if menu.cursor_idx == i {
				rl.DrawText(button.name, top_left.x + 5, top_left.y + i * 20, 12, {0x6a, 0x1d, 0x13, 0xff})
			} else {
				rl.DrawText(button.name, top_left.x, top_left.y + i * 20, 12, {0x2a, 0x1b, 0x16, 0xff})
			}
		}
	}
	rl.EndTextureMode()
	rl.DrawTexturePro(canvas.texture, {0, 0, f32(RESOLUTION.x), f32(-RESOLUTION.y)}, {0, 0, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}, {0, 0}, 0, rl.WHITE)
	rl.EndDrawing()
}

// TODO: Should this be a menu?
character_select_update :: proc() {
	cursor_idx: i32
	Character_Panel :: struct {
		name: cstring,
		color: rl.Color,
	}
	panels := []Character_Panel {
		{"Wilhelmina Frost", {0x98, 0xcb, 0xd6, 0xff}},
		{"Sinon Sinfonia", {0x3e, 0xd0, 0xf2, 0xff}},
		{"Bibi Biscuit", {0xbd, 0x2d, 0x4e, 0xff}},
		{"Malice Evermore", {0x8f, 0x25, 0x55, 0xff}},
		{"Nitya Nil", {0x5d, 0x80, 0x00, 0xff}},
	}
	if rl.IsKeyPressed(.SPACE) {
		current_screen = .LEVEL
	} else if rl.IsKeyPressed(.RIGHT) {
		cursor_idx += 1
		if cursor_idx >= i32(len(panels)) do cursor_idx = 0
	} else if rl.IsKeyPressed(.LEFT) {
		cursor_idx -= 1
		if cursor_idx < 0 do cursor_idx = cast(i32) (len(panels) - 1)
	}

	rl.BeginDrawing()
	rl.BeginTextureMode(canvas)
		rl.ClearBackground({0x2a, 0x17, 0x24, 0xff})
		button_width :: 90
		button_height :: 200
		offset_size :: RESOLUTION.x / 5
		for i: i32 = 0; i < i32(len(panels)); i += 1 {
			panel := panels[i]
			middle_x := offset_size * i + offset_size / 2
			x := middle_x - button_width / 2
			top_left := Vec2i{x, 6}
			rl.DrawRectangle(top_left.x, top_left.y, button_width, button_height, panel.color)
			rl.DrawText(panel.name, middle_x - 30, button_height - 30, 12, rl.WHITE)
			if cursor_idx == i {
				rl.DrawRectangleLinesEx({f32(top_left.x), f32(top_left.y), button_width, button_height}, 4.0, rl.WHITE)
			}
		}
	rl.EndTextureMode()
	rl.DrawTexturePro(canvas.texture, {0, 0, f32(RESOLUTION.x), f32(-RESOLUTION.y)}, {0, 0, f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())}, {0, 0}, 0, rl.WHITE)
	rl.EndDrawing()
}
