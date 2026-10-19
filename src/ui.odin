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
menu_texture: rl.Texture2D

@(private) target_cursor: Target_Cursor
@(private) target_cursor_texture: rl.Texture2D

@(private) healthbar_bg_texture: rl.Texture2D
@(private) healthbar_texture: rl.Texture2D
@(private) actionbar_texture: rl.Texture2D

@(private) character_select_panels: [5]Character_Panel

@(private)
Character_Panel :: struct {
	name: cstring,
	color: rl.Color,
	texture: rl.Texture2D,
	character_type: Entity_Type,
}

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
	disabled: bool,
}

Menu :: struct {
	prev: ^Menu,
	buttons: []Menu_Item,
	cursor_idx: i32,
	top_left: Vec2i,
	routine: proc(^Menu),
}

Menu_Action :: enum {
	None,
	Move,
	Select,
	Cancel,
}

ui_init :: proc() {
	mem.stack_init(&stack_alloc, buf[:])
	menu_allocator = mem.stack_allocator(&stack_alloc)

	target_cursor_texture = rl.LoadTexture("assets/ui/selection_arrow.png")

	character_select_panels = {
		{"Wilhelmina Frost", {0x98, 0xcb, 0xd6, 0xff}, {}, .NITYA},
		{"Sinon Sinfonia", {0x3e, 0xd0, 0xf2, 0xff}, {}, .NITYA},
		{"Bibi Biscuit", {0xbd, 0x2d, 0x4e, 0xff}, {}, .BIBI},
		{"Malice Evermore", {0x8f, 0x25, 0x55, 0xff}, {}, .NITYA},
		{"Nitya Nil", {0x5d, 0x80, 0x00, 0xff}, {}, .NITYA},
	}
	// character_select_panels[1].texture = rl.LoadTexture("assets/ui/character_select_sinon.png")
	character_select_panels[2].texture = rl.LoadTexture("assets/ui/character_select_bibi.png")
	character_select_panels[4].texture = rl.LoadTexture("assets/ui/character_select_nitya.png")

	healthbar_bg_texture = rl.LoadTexture("assets/ui/healthbar_bg.png")
	healthbar_texture = rl.LoadTexture("assets/ui/healthbar.png")
	actionbar_texture = rl.LoadTexture("assets/ui/actionbar.png")
}

ui_deinit :: proc() {
	rl.UnloadTexture(target_cursor_texture)
	rl.UnloadTexture(character_select_panels[2].texture)
	rl.UnloadTexture(character_select_panels[4].texture)
	rl.UnloadTexture(healthbar_bg_texture)
	rl.UnloadTexture(healthbar_texture)
	rl.UnloadTexture(actionbar_texture)
}

draw_ui :: proc() {
	player := entities[party_leader_idx]
	// info := entity_definitions[player.type]

	top_left := Vec2{f32(RESOLUTION.x) - 90, 10}
	// ui_size := Vec2{80, 40}
	// neutral_color := rl.Color{0x80, 0x80, 0x80, 0x66}
	// character_color := rl.Color{info.color_code.r, info.color_code.g, info.color_code.b, 0xcc}
	// rl.DrawRectangleGradientEx({top_left.x, top_left.y, ui_size.x, ui_size.y},
	// 	character_color, neutral_color,
	// 	neutral_color, character_color)

	top_left = top_left + {10, 10}
	max_hp := player.max_health // TODO: Do this for the whole party
	hp := player.health
	hp_ratio := f32(hp) / f32(max_hp)

	draw_bar(hp_ratio, {top_left.x + 3, top_left.y - 6, 57, 11}, {0xc2, 0x00, 0x00, 0xff}, {0x42, 0x07, 0x07, 0xff})

	if player.current_action != .NONE {
		action_cost: f32 = 30
		action_time: f32 = player.action_charge
		action_ratio := action_time / action_cost
		draw_bar(action_ratio, {top_left.x + 20, top_left.y + 6, 35, 6}, rl.Color{0xff, 0xff, 0x55, 0xff}, rl.Color{0x66, 0x66, 0x00, 0xff})
	}

	rl.DrawTexture(healthbar_bg_texture, i32(top_left.x), i32(top_left.y - 30), rl.WHITE)
	rl.DrawTexture(healthbar_texture, i32(top_left.x), i32(top_left.y - 30), rl.WHITE)
	rl.DrawTexture(actionbar_texture, i32(top_left.x), i32(top_left.y - 30), rl.WHITE)

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

@(private) Battle_Options :: enum {
	ATTACK,
	// SKILLS,
	ITEMS,
	CANCEL,
}

update_vertical_menu :: proc(menu: ^Menu) -> (action: Menu_Action) {
	if rl.IsKeyPressed(.BACKSPACE) {
		pop_menu()
		action = .Cancel
		rl.PlaySound(select_sound)
	} else if rl.IsKeyPressed(.DOWN) {
		menu.cursor_idx += 1
		if menu.cursor_idx >= i32(len(menu.buttons)) do menu.cursor_idx = 0
		action = .Move
		rl.PlaySound(navigate_sound)
	} else if rl.IsKeyPressed(.UP) {
		menu.cursor_idx -= 1
		if menu.cursor_idx < 0 do menu.cursor_idx = cast(i32) (len(menu.buttons) - 1)
		action = .Move
		rl.PlaySound(navigate_sound)
	} else if rl.IsKeyPressed(.SPACE) {
		action = .Select
		rl.PlaySound(select_sound)
	}
	return action
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
	current_menu.top_left = Vec2i{20, RESOLUTION.y - 130}
}

update_battle_menu :: proc(menu: ^Menu) {
	action := update_vertical_menu(menu)
	if action == .Cancel do return
	if action == .Select {
		switch Battle_Options(menu.cursor_idx) {
		case Battle_Options.ATTACK:
			open_target_menu()
		case Battle_Options.ITEMS:
			open_item_menu()
		case Battle_Options.CANCEL:
			pop_menu()
		case:
			fmt.printf("Unimplemented button!\n")
		}
	}
	draw_battle_menu(menu)
}

open_target_menu :: proc() {
	
	target := &entities[party_leader_idx]
	if target.type == .NITYA{
		rl.PlaySound(nitya_eh_sound)
	} else if target.type == .BIBI{
		rl.PlaySound(bibi_eh_sound)
	}

	next_menu, err := new(Menu, menu_allocator)
	if err != nil {
		fmt.printf("ERROR: Failed to allocate new menu instance!\n")
	}
	next_menu.prev = current_menu
	current_menu = next_menu
	current_menu.routine = update_target_menu
	current_menu.top_left = Vec2i{20, RESOLUTION.y - 130}
	screen_space := rl.Rectangle{camera.target.x - f32(RESOLUTION.x) / 2, camera.target.y - f32(RESOLUTION.y) / 2, f32(RESOLUTION.x), f32(RESOLUTION.y)}
	available_targets := get_entities_on_screen(screen_space)
	defer delete(available_targets)
	current_menu.buttons = make([]Menu_Item, len(available_targets), menu_allocator)
	for i in i32(0)..<i32(len(available_targets)) {
		enemy_idx := available_targets[i]
		entity := entities[enemy_idx]
		current_menu.buttons[i] = {
			name = entity_definitions[entity.type].name,
			value = enemy_idx,
		}
	}
	if len(current_menu.buttons) > 0 {
		target := entities[current_menu.buttons[0].value]
		target_cursor.pos = target.pos
		target_cursor.old_pos = target.pos
		target_cursor.visible = true
	}
}

update_target_menu :: proc(menu: ^Menu) {
	action := update_vertical_menu(menu)
	if action == .Cancel do return
	if action == .Move {
		target_cursor.old_pos = target_cursor.pos
		target_cursor.target_idx = menu.buttons[menu.cursor_idx].value
		target_cursor.ticks_since_update = 0
	}
	if action == .Select {
		set_action(&entities[party_leader_idx], menu.buttons[menu.cursor_idx].value, .ATTACK)
		close_all_menus()
	}

	// Handle target cursor
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
	draw_battle_menu(menu)
}

open_item_menu :: proc() {
	next_menu, err := new(Menu, menu_allocator)
	if err != nil {
		fmt.printf("ERROR: Failed to allocate new menu instance!\n")
	}
	next_menu.prev = current_menu
	current_menu = next_menu
	item_count := i32(len(inventory))
	current_menu.buttons = make([]Menu_Item, item_count, menu_allocator)
	for i in 0..<item_count {
		type := inventory[i]
		name := item_names[type]
		current_menu.buttons[i] = {
			name = name,
			value = i,
		}
	}
	current_menu.routine = update_item_menu
	current_menu.top_left = Vec2i{20, RESOLUTION.y - 130}
}

update_item_menu :: proc(menu: ^Menu) {
	action := update_vertical_menu(menu)
	if action == .Cancel do return
	if action == .Select {
		item_type := inventory[menu.cursor_idx]
		use_item(item_type, party_leader_idx)
		ordered_remove(&inventory, menu.cursor_idx)
		close_all_menus()
	}
	draw_battle_menu(menu)
}

draw_battle_menu :: proc(menu: ^Menu) {
	menu_size := Vec2{80, 120}
	rl.DrawTexturePro(menu_texture, {0, 0, 48, 48}, {f32(menu.top_left.x), f32(menu.top_left.y), menu_size.x, menu_size.y}, 0, 0, rl.WHITE)

	for i in 0..<i32(len(menu.buttons)) {
		if i == menu.cursor_idx {
			rl.DrawText(menu.buttons[i].name, i32(menu.top_left.x) + 5, i32(menu.top_left.y) + i * 20 + 10, 12, {0x6a, 0x1d, 0x13, 0xff})
		} else {
			rl.DrawText(menu.buttons[i].name, i32(menu.top_left.x) + 5, i32(menu.top_left.y) + i * 20 + 10, 12, {0x2a, 0x1b, 0x16, 0xff})
		}
	}
}

open_main_menu :: proc() {
	next_menu, err := new(Menu, menu_allocator)
	if err != nil {
		fmt.printf("ERROR: Failed to allocate new menu instance!\n")
	}
	next_menu.prev = current_menu
	current_menu = next_menu
	current_menu.buttons = make([]Menu_Item, 3, menu_allocator)
	current_menu.buttons[0] = {
		name = "Start Game",
	}
	current_menu.buttons[1] = {
		name = "Continue",
		disabled = true,
	}
	current_menu.buttons[2] = {
		name = "Options",
	}
	current_menu.routine = update_main_menu
}

// TODO TODO
update_main_menu :: proc(menu: ^Menu) {
	action := update_vertical_menu(menu)
	if action == .Select {
		switch menu.cursor_idx {
		case 0:
			open_character_select()
		case 2:
			open_options_menu()
		case:
			fmt.printf("Unimplemented button!\n")
		}
	}

	rl.ClearBackground({0xad, 0x96, 0x74, 0xff})
	top_left := Vec2i{100, 100}
	for i in i32(0)..<i32(len(menu.buttons)) {
		button := menu.buttons[i]
		if menu.cursor_idx == i {
			rl.DrawText(button.name, top_left.x + 5, top_left.y + i * 20, 12, {0x6a, 0x1d, 0x13, 0xff})
		} else {
			rl.DrawText(button.name, top_left.x, top_left.y + i * 20, 12, {0x2a, 0x1b, 0x16, 0xff})
		}
	}
}

open_character_select :: proc() {
	next_menu, err := new(Menu, menu_allocator)
	if err != nil {
		fmt.printf("ERROR: Failed to allocate new menu instance!\n")
	}
	next_menu.prev = current_menu
	current_menu = next_menu
	current_menu.buttons = make([]Menu_Item, 5, menu_allocator)
	current_menu.buttons[0].disabled = true
	current_menu.buttons[1].disabled = true
	current_menu.buttons[3].disabled = true
	current_menu.cursor_idx = 2

	current_menu.routine = update_character_select
}

update_character_select :: proc(menu: ^Menu) {
	action := update_horizontal_menu(menu)
	if action == .Cancel do return
	if action == .Select {
		close_all_menus()
		if character_select_panels[menu.cursor_idx].character_type == .NITYA {
			rl.PlaySound(nitya_intro_sound)
		} else if character_select_panels[menu.cursor_idx].character_type == .BIBI {
			rl.PlaySound(bibi_intro_sound)
		}

		start_game(character_select_panels[menu.cursor_idx].character_type)
		return
	}

	rl.ClearBackground({0x2a, 0x17, 0x24, 0xff})
	button_width :: 90
	button_height :: 200
	offset_size :: RESOLUTION.x / 5

	for i in 0..<i32(len(menu.buttons)) {
		panel := character_select_panels[i]
		middle_x := offset_size * i + offset_size / 2
		x := middle_x - button_width / 2
		top_left := Vec2i{x, 6}
		rl.DrawRectangle(top_left.x, top_left.y, button_width, button_height, {0x70, 0x70, 0x70, 0x80})
		if panel.texture.id > 0 {
			rl.DrawTexture(panel.texture, top_left.x, top_left.y, rl.WHITE if !menu.buttons[i].disabled else {0xff, 0xff, 0xff, 0x80})
		}
		if menu.cursor_idx == i {
			rl.DrawRectangleLinesEx({f32(top_left.x), f32(top_left.y), button_width, button_height}, 2.0, rl.WHITE)
		}
	}
}

update_horizontal_menu :: proc(menu: ^Menu) -> (action: Menu_Action) {
	if rl.IsKeyPressed(.BACKSPACE) {
		pop_menu()
		action = .Cancel
	} else if rl.IsKeyPressed(.RIGHT) {
		for _ in 0..<len(menu.buttons) {
			menu.cursor_idx += 1
			if menu.cursor_idx >= i32(len(menu.buttons)) do menu.cursor_idx = 0
			if !menu.buttons[menu.cursor_idx].disabled do break
		}
		action = .Move
	} else if rl.IsKeyPressed(.LEFT) {
		for _ in 0..<len(menu.buttons) {
			menu.cursor_idx -= 1
			if menu.cursor_idx < 0 do menu.cursor_idx = cast(i32) (len(menu.buttons) - 1)
			if !menu.buttons[menu.cursor_idx].disabled do break
		}
		action = .Move
	} else if rl.IsKeyPressed(.SPACE) {
		action = .Select
	}
	return action
}

@(private)
Audio_Slider :: struct {
	name: cstring,
	type: Audio_Type,
}

audio_sliders := [4]Audio_Slider {
	{"Master", .Master},
	{"SFX", .Sfx},
	{"UI", .Ui},
	{"Music", .Music},
}

open_options_menu :: proc() {
	next_menu, err := new(Menu, menu_allocator)
	if err != nil {
		fmt.printf("ERROR: Failed to allocate new menu instance!\n")
	}
	next_menu.prev = current_menu
	current_menu = next_menu
	current_menu.buttons = make([]Menu_Item, 5, menu_allocator)
	current_menu.buttons[4] = {name = "Back"}
	current_menu.routine = update_options_menu
}

update_options_menu :: proc(menu: ^Menu) {
	action := update_vertical_menu(menu)
	if action == .Cancel do return
	if action == .Select && menu.cursor_idx == 4 {
		pop_menu()
		return
	}
	if menu.cursor_idx >= 0 && menu.cursor_idx < 4 {
		adjustment_value: i32 = 0
		if rl.IsKeyDown(.LEFT) {
			adjustment_value -= 1
		}
		if rl.IsKeyDown(.RIGHT) {
			adjustment_value += 1
		}
		if adjustment_value != 0 {
			adjust_sound_volume(audio_sliders[menu.cursor_idx].type, adjustment_value)
		}
	}

	top_left := Vec2i{100, 40}

	for i in 0..<i32(4) {
		slider := audio_sliders[i]
		current_value: i32
		switch slider.type {
		case .Master:
			current_value = master_volume
		case .Sfx:
			current_value = sfx_volume
		case .Ui:
			current_value = ui_volume
		case .Music:
			current_value = music_volume
		}
		rl.DrawText(slider.name, top_left.x, top_left.y, 12, rl.WHITE)
		top_left.y += 15
		bar_size := rl.Rectangle{f32(top_left.x), f32(top_left.y), 80, 6}
		draw_bar(f32(current_value), 100, bar_size, {0xd0, 0xd0, 0xd0, 0xcc}, {0x80, 0x80, 0x80, 0xa8})
		if i == menu.cursor_idx {
			rl.DrawRectangleLinesEx(bar_size, 1, rl.WHITE)
		}
		top_left.y += 15
	}

	top_left.y += 20
	if menu.cursor_idx == 4 {
		rl.DrawText(menu.buttons[4].name, top_left.x + 5, top_left.y, 12, {0x6a, 0x1d, 0x13, 0xff})
	} else {
		rl.DrawText(menu.buttons[4].name, top_left.x, top_left.y, 12, {0x2a, 0x1b, 0x16, 0xff})
	}
}
