package game

import "core:math"
import "core:c"
import "core:slice"
import rl "vendor:raylib"

// Shaders
damage_shader: rl.Shader
damage_frames_loc: c.int
damage_duration_loc: c.int

heal_shader: rl.Shader
heal_frames_loc: c.int
heal_duration_loc: c.int

spell_charge_shader: rl.Shader
spell_current_frame: c.int
spell_color_loc: c.int


// Mutable state

damage_markers: [dynamic; 30]Damage_Marker

@(private) DAMAGE_MARKER_LIFETIME :: 100

@(private)
Damage_Marker :: struct {
	target_idx: i32,
	amount: i32,
	lifetime: i16,
	is_healing: bool,
}

@(private)
Object_Type :: enum {
	ENTITY,
	TILE,
	ITEM,
}

@(private)
Render_Info :: struct {
	screen_y: f32,
	type: Object_Type,
	id: i32,
}

load_shaders :: proc() {
	when ODIN_OS == .JS {
		load_shaders_web()
	} else {
		load_shaders_desktop()
	}
}

load_shaders_desktop :: proc() {
	damage_shader = rl.LoadShader(nil, "assets/shaders/desktop/damage.fs")
	damage_frames_loc = rl.GetShaderLocation(damage_shader, "damageFrames")
	damage_duration_loc = rl.GetShaderLocation(damage_shader, "damageDuration")

	heal_shader = rl.LoadShader(nil, "assets/shaders/desktop/heal.fs")
	heal_frames_loc = rl.GetShaderLocation(heal_shader, "healFrames")
	heal_duration_loc = rl.GetShaderLocation(heal_shader, "healDuration")

	spell_charge_shader = rl.LoadShader(nil, "assets/shaders/desktop/spell_charge.fs")
	spell_current_frame = rl.GetShaderLocation(spell_charge_shader, "currentFrame")
	spell_color_loc = rl.GetShaderLocation(spell_charge_shader, "skillColor")
}

load_shaders_web :: proc() {
	damage_shader = rl.LoadShader(nil, "assets/shaders/web/damage.fs")
	damage_frames_loc = rl.GetShaderLocation(damage_shader, "damageFrames")
	damage_duration_loc = rl.GetShaderLocation(damage_shader, "damageDuration")

	heal_shader = rl.LoadShader(nil, "assets/shaders/web/heal.fs")
	heal_frames_loc = rl.GetShaderLocation(heal_shader, "healFrames")
	heal_duration_loc = rl.GetShaderLocation(heal_shader, "healDuration")

	spell_charge_shader = rl.LoadShader(nil, "assets/shaders/web/spell_charge.fs")
	spell_current_frame = rl.GetShaderLocation(spell_charge_shader, "currentFrame")
	spell_color_loc = rl.GetShaderLocation(spell_charge_shader, "skillColor")
}

unload_shaders :: proc() {
	rl.UnloadShader(damage_shader)
	rl.UnloadShader(heal_shader)
	rl.UnloadShader(spell_charge_shader)
}

add_damage_marker :: proc(target_entity_idx, amount: i32, is_healing: bool) {
	append(&damage_markers, {
		target_idx = target_entity_idx,
		amount = amount,
		is_healing = is_healing,
		lifetime = 0,
	})
}

// Draw everything from top to bottom, so objects near the top do not appear in front of lower objects.
draw_scene :: proc() {
	resolution_with_padding :: Vec2{f32(RESOLUTION.x + 50), f32(RESOLUTION.y + 50)}
	screen_space_with_padding := rl.Rectangle{
		camera.target.x - resolution_with_padding.x / 2,
		camera.target.y - resolution_with_padding.y / 2,
		resolution_with_padding.x,
		resolution_with_padding.y,
	}
	render_list_size := size_of(Render_Info) * len(entities) * cap(field_items)
	render_list := make([dynamic]Render_Info, 0, render_list_size)
	defer delete(render_list)
	for i in 0..<i32(len(entities)) {
		entity := entities[i]
		if !entity.in_use {
			continue
		}
		render_pos := render_pos_from_world_pos(entity.pos)
		if is_inside_rec(render_pos, screen_space_with_padding) {
			append(&render_list, {
				screen_y = render_pos.y,
				type = .ENTITY,
				id = i,
			})
		}
	}
	sorting_callback :: proc(i, j: Render_Info) -> bool {
		return i.screen_y < j.screen_y
	}
	slice.sort_by(render_list[:], sorting_callback)
	for i in 0..<len(render_list) {
		delta := rl.GetFrameTime()
		idx := render_list[i].id
		#partial switch render_list[i].type {
		case .ENTITY: draw_entity(&entities[idx], delta)
		}
	}

	for i := len(damage_markers) - 1; i >= 0; i -= 1 {
		marker := &damage_markers[i]
		marker.lifetime += 1
		if marker.lifetime > DAMAGE_MARKER_LIFETIME {
			unordered_remove(&damage_markers, i)
		} else {
			target_pos := render_pos_from_world_pos(entities[marker.target_idx].pos)
			target_pos.y -= f32(marker.lifetime) * 0.5
			target_pos.x += 2 * math.sin(0.05 * f32(marker.lifetime))
			col := rl.Color{0x4c, 0xb9, 0x3d, 0xff} if marker.is_healing else rl.Color{0xb0, 0xd7, 0xf1, 0xff}
			rl.DrawText(rl.TextFormat("%i", marker.amount), i32(target_pos.x), i32(target_pos.y), 12, col)
		}
	}
}

draw_entity :: proc(entity: ^Entity, delta: f32) {
	renderer := entity_renderers[entity.type]
	mapping := renderer.animation_mappings[entity.animation_state]
	animation := renderer.animation_rows[mapping]
	current_frame := animation.frames[entity.animation_frame]

	// Animation calculations
	if current_menu == nil {
		entity.frame_time += delta
		if entity.frame_time >= current_frame.duration {
			entity.frame_time = 0
			entity.animation_frame += 1
			if entity.animation_frame >= i32(len(animation.frames)) {
				entity.animation_frame = 0
				entity.is_swinging = false // Hack to account for different entity swing animations. This is not ideal.
			}
			current_frame = animation.frames[entity.animation_frame]
		}
	}

	// Draw the actual sprite
	render_pos := cast(Vec2i) render_pos_from_world_pos(entity.pos)
	sprite_offset := Vec2i{current_frame.width / 2, current_frame.height / 2}
	source_texture_rec: rl.Rectangle
	if entity.facing_left {
		source_texture_rec = {f32(current_frame.x), f32(current_frame.y), -f32(current_frame.width), f32(current_frame.height)}
	} else {
		source_texture_rec = {f32(current_frame.x), f32(current_frame.y), f32(current_frame.width), f32(current_frame.height)}
	}
	if entity.damage_timer > 0 {
		damage_frames := cast(f32) entity.damage_timer
		damage_duration := cast(f32) DAMAGE_FLASH_DURATION
		rl.SetShaderValue(damage_shader, damage_frames_loc, &damage_frames, .FLOAT)
		rl.SetShaderValue(damage_shader, damage_duration_loc, &damage_duration, .FLOAT)
		rl.BeginShaderMode(damage_shader)
		rl.DrawTextureRec(renderer.texture, source_texture_rec, cast(Vec2) (render_pos - sprite_offset), rl.WHITE)
		rl.EndShaderMode()
	} else if entity.heal_timer > 0 {
		heal_frames := cast(f32) entity.heal_timer
		heal_duration := cast(f32) DAMAGE_FLASH_DURATION * 4
		rl.SetShaderValue(heal_shader, heal_frames_loc, &heal_frames, .FLOAT)
		rl.SetShaderValue(heal_shader, heal_duration_loc, &heal_duration, .FLOAT)
		rl.BeginShaderMode(heal_shader)
		rl.DrawTextureRec(renderer.texture, source_texture_rec, cast(Vec2) (render_pos - sprite_offset), rl.WHITE)
		rl.EndShaderMode()
	} else {
		current_frame := f32(entity.living_ticks - entity.action_selected_tick)
		col := entity_definitions[entity.type].color_code.rgb
		spell_color := rl.Vector3{f32(col.r) / 255, f32(col.g) / 255, f32(col.b) / 255}
		rl.SetShaderValue(spell_charge_shader, spell_current_frame, &current_frame, .FLOAT)
		rl.SetShaderValue(spell_charge_shader, spell_color_loc, &spell_color, .VEC3)
		rl.BeginShaderMode(spell_charge_shader)
		rl.DrawTextureRec(renderer.texture, source_texture_rec,	cast(Vec2) (render_pos - sprite_offset), {0xff, 0xff, 0xff, 0xff})
		rl.EndShaderMode()
	}

	// Health bar
	health_render_pos := render_pos
	health_render_pos.y -= sprite_offset.y
	health_bar_rect := rl.Rectangle{f32(health_render_pos.x) - 16, f32(health_render_pos.y) + 6, 32, 4}
	fill_color, bg_color: rl.Color
	#partial switch entity.team {
	case .ALLY:
		fill_color = {0x6c, 0xc7, 0x44, 0xff}
		bg_color = {0x34, 0x4f, 0x28, 0xff}
		draw_bar(f32(entity.health), f32(entity.max_health), health_bar_rect, fill_color, bg_color)
	case .ENEMY:
		fill_color = {0xac, 0x20, 0x32, 0xff}
		bg_color = {0x74, 0x2b, 0x2b, 0xff}
		draw_bar(f32(entity.health), f32(entity.max_health), health_bar_rect, fill_color, bg_color)
	}
}
