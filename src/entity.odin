package game

import rl "vendor:raylib"
import "core:encoding/json"
import "core:fmt"
import "core:math/linalg"
import "core:strings"

DAMAGE_FLASH_DURATION :: 30

entity_definitions: [Entity_Type]Entity_Info
entity_renderers: [Entity_Type]Entity_Renderer

Entity_Team :: enum {
	PLAYER,
	ENEMY,
	ALLY,
}

// Spawn chances should be determined per dungeon.
Entity_Info :: struct {
	name: cstring,
	sprite_name: string,
	color_code: rl.Color,
	base_health: i32,
	base_attack: i32,
	base_magic_power: i32,
	base_speed: i32,
	entity_width: i32,
}

// These are all of the possible animations an entity can have.
Animation_State :: enum {
	IDLE_E,
	IDLE_S,
	IDLE_N,
	RUN_E,
	RUN_S,
	RUN_N,
	SWING_E,
	SWING_S,
	SWING_N,
	DEAD,
}

// These are created to work directly with aseprite's export.
// This animation system is pretty complex to handle certain edge cases. Best make sure it stays self-contained.
Animation_Frame :: struct {
	x, y, width, height: i32,
	duration: f32,
}

Animation_Row :: struct {
	name: string,
	frames: []Animation_Frame,
}

Entity_Renderer :: struct {
	texture: rl.Texture2D,
	animation_mappings: [Animation_State]i32,
	animation_rows: []Animation_Row,
}

// Instance of an entity. This should not be serialized except for in save data.
Entity :: struct {
	in_use: bool,
	type: Entity_Type,
	pos: Vec2,
	velocity: Vec2,
	max_health: i32,
	health: i32,
	attack_power: i32,
	damage_timer: i32,
	ko_timer: i32,
	current_action: Action_Type,
	action_charge: f32,
	is_acting: bool,
	target_id: i32,

	// Properties related to animation
	animation_state: Animation_State,
	direction: Animation_Direction,
	animation_frame: i32,
	frame_time: f32,
	facing_left: bool,
	is_swinging: bool,
}

Entity_Type :: enum {
	NITYA,
	// MALICE,
	// BIBI,
	// SINON,
	// WILHELMINA,
	SAMMY,
	MALISTOCRAT,
}

register_entities :: proc() {
	entity_definitions[.NITYA] = {
		name = "Nitya",
		sprite_name = "nitty",
		color_code = rl.GetColor(0x5d8000ff),
		base_health = 40,
		base_attack = 8,
		entity_width = 32,
	}
	entity_definitions[.SAMMY] = {
		name = "Sammy",
		sprite_name = "Sammie",
		base_health = 30,
		base_attack = 4,
		entity_width = 32,
	}
	entity_definitions[.MALISTOCRAT] = {
		name = "Malistocrat",
		sprite_name = "Malistocrat",
		base_health = 30,
		base_attack = 4,
		entity_width = 32,
	}

	register_renderers()
}

unregister_entities :: proc() {
	unregister_renderers()
}

register_renderers :: proc() {
	nitya_sprite_name := "nitty"

	nitya_rows, nitya_ok := parse_aseprite_json(nitya_sprite_name, "assets/sprites/nitty.json")
	if nitya_ok {
		nitya_mappings := map_animations(nitya_rows)
		entity_renderers[.NITYA] = {
			texture = rl.LoadTexture("assets/sprites/nitty.png"),
			animation_rows = nitya_rows,
			animation_mappings = nitya_mappings,
		}
	}
	sammy_sprite_name := "Sammie"
	sammy_rows, sammy_ok := parse_aseprite_json(sammy_sprite_name, "assets/sprites/Sammie.json")
	if sammy_ok {
		sammy_mappings := map_animations(sammy_rows)
		entity_renderers[.SAMMY] = {
			texture = rl.LoadTexture("assets/sprites/Sammie.png"),
			animation_rows = sammy_rows,
			animation_mappings = sammy_mappings,
		}
	}
	malistocrat_sprite_name := "Malistocrat"
	malistocrat_rows, malistocrat_ok := parse_aseprite_json(malistocrat_sprite_name, "assets/sprites/Malistocrat.json")
	if malistocrat_ok {
		malistocrat_mappings := map_animations(malistocrat_rows)
		entity_renderers[.MALISTOCRAT] = {
			texture = rl.LoadTexture("assets/sprites/Malistocrat.png"),
			animation_rows = malistocrat_rows,
			animation_mappings = malistocrat_mappings,
		}
	}

	free_all(context.temp_allocator)
}

unregister_renderers :: proc() {
	for &renderer in entity_renderers {
		rl.UnloadTexture(renderer.texture)
	}
}

parse_aseprite_json :: proc(sprite_name, path: string) -> (animation_rows: []Animation_Row, ok: bool = true) {
	bytes: []u8
	bytes, ok = read_entire_file(path, context.temp_allocator)
	if !ok {
		fmt.printf("Error: Couldn't read file. %s\n", path)
		return nil, false
	}

	json_data, err := json.parse(bytes, allocator = context.temp_allocator)
	if err != .None {
		fmt.printf("Error: \n", err)
		return nil, false
	}
	root := json_data.(json.Object)
	meta := root["meta"]
	frame_tags := meta.(json.Object)["frameTags"]
	tags_array := frame_tags.(json.Array)

	tag_count := len(tags_array)
	animations := make([]Animation_Row, tag_count, context.allocator)

	// Get metadata
	for i in 0..<tag_count {
		tag_object := tags_array[i].(json.Object)
		name := strings.clone(tag_object["name"].(json.String), context.allocator)
		from := tag_object["from"].(json.Float)
		to := tag_object["to"].(json.Float)
		frame_count := i32(to) - i32(from) + 1
		animation_slice := make([]Animation_Frame, frame_count, context.allocator)
		animations[i] = Animation_Row{
			name,
			animation_slice,
		}
	}

	frames := root["frames"].(json.Object)
	for row in animations {
		for i in 0..<len(row.frames) {
			frame_name: string
			if len(row.frames) > 1 {
				name_format := "%s #%s %d.aseprite"
				frame_name = fmt.tprintf(name_format, sprite_name, row.name, i)
			} else {
				name_format := "%s #%s.aseprite"
				frame_name = fmt.tprintf(name_format, sprite_name, row.name)
			}
			frame_object := frames[frame_name].(json.Object)
			frame := &(row.frames[i])
			dimensions_object := frame_object["frame"].(json.Object)
			x := dimensions_object["x"].(json.Float)
			y := dimensions_object["y"].(json.Float)
			w := dimensions_object["w"].(json.Float)
			h := dimensions_object["h"].(json.Float)
			frame.x = i32(x)
			frame.y = i32(y)
			frame.width = i32(w)
			frame.height = i32(h)
			duration := frame_object["duration"].(json.Float)
			frame.duration = f32(duration) * 0.001
		}
	}
	return animations, true
}


// TODO: If the game is to have add-ins later, this procedure MUST fail when there is no facing right animations.
map_animations :: proc(animation_rows: []Animation_Row) -> [Animation_State]i32 {
	mappings: [Animation_State]i32

	for state in Animation_State {
		state_name: string
		switch state {
		case .IDLE_E: state_name = "idle_E"
		case .IDLE_S: state_name = "idle_S"
		case .IDLE_N: state_name = "idle_N"
		case .RUN_E: state_name = "run_E"
		case .RUN_S: state_name = "run_S"
		case .RUN_N: state_name = "run_N"
		case .SWING_E: state_name = "swing_E"
		case .SWING_S: state_name = "swing_S"
		case .SWING_N: state_name = "swing_N"
		case .DEAD: state_name = "dead"
		}

		target_idx: i32 = -1
		for i in i32(0)..<i32(len(animation_rows)) {
			row := animation_rows[i]
			if row.name == state_name {
				target_idx = i
				break
			}
		}
		// If the animation doesn't exist, fill it with the equivalent east animation. Yes, this is a hack.
		if target_idx < 0 {
			#partial switch state {
			case .IDLE_N, .IDLE_S: state_name = "idle_E"
			case .RUN_N, .RUN_S: state_name = "run_E"
			case .SWING_N, .SWING_S: state_name = "swing_E"
			case .DEAD: state_name = "idle_E"
			}

			for i in i32(0)..<i32(len(animation_rows)) {
				row := animation_rows[i]
				if row.name == state_name {
					target_idx = i
					break
				}
			}
		}
		mappings[state] = target_idx
	}
	return mappings
}

// Tries to add an entity of input type to the input list. Returns false if failed.
spawn_entity :: proc(entities: []Entity, type: Entity_Type, pos: Vec2) -> bool {
	for i in 0..<len(entities) {
		if !entities[i].in_use {
			definition := entity_definitions[type]
			entities[i] = Entity {
				in_use = true,
				type = type,
				pos = pos,
				max_health = definition.base_health,
				health = definition.base_health,
				attack_power = definition.base_attack,
			}
			return true
		}
	}
	return false
}

// get_entities_on_screen()

// The returned result will need to live beyond the frame.
get_entities_in_range :: proc(origin: Vec2, radius: f32, entities: []Entity, allocator := context.allocator, loc := #caller_location) -> [dynamic]i32 {
	in_range := make([dynamic]i32, 0, len(entities), allocator, loc)
	for i in i32(0)..<i32(len(entities)) {
		if entities[i].in_use && linalg.distance(origin, entities[i].pos) < radius {
			append(&in_range, i)
		}
	}
	return in_range
}

update_entities :: proc(entities: []Entity) {
	for i in i32(0)..<i32(len(entities)) {
		entity := &entities[i]
		if entity.in_use {
			// Action code
			if entity.current_action != .NONE {
				if entity.is_acting {
					update_action(entity)
				} else {
					entity.action_charge += 0.15
					if entity.action_charge >= 30 {
						entity.action_charge = 30
						target := entities[entity.target_id]
						if linalg.distance(entity.pos, target.pos) < 2 {
							start_action(entity)
						}
					}
				}
			}
			// Travel code
			if entity.is_swinging {

			} else {
				if i == party_leader_idx {
					input_dir := Vec2{}
					if rl.IsKeyDown(.A) do input_dir.x -= 1
					if rl.IsKeyDown(.D) do input_dir.x += 1
					if rl.IsKeyDown(.W) do input_dir.y -= 1
					if rl.IsKeyDown(.S) do input_dir.y += 1

					input_dir = iso_rotation_matrix * input_dir
					input_dir = linalg.normalize0(input_dir)

					entity.velocity = input_dir * PLAYER_SPEED

					if test_mode && rl.IsKeyPressed(.RIGHT_BRACKET) {
						spawn_entity(entities[:], .SAMMY, entity.pos + {1, 0})
					}
				} else {
					update_entity_ai()
				}
				visible_velocity := render_pos_from_world_pos(entity.velocity)
				if visible_velocity == {0,0} {
					switch entity.direction {
					case .EAST: entity.animation_state = .IDLE_E
					case .NORTH: entity.animation_state = .IDLE_N
					case .SOUTH: entity.animation_state = .IDLE_S
					}
				} else {
					entity.direction = calculate_animation_direction(visible_velocity)
					switch entity.direction {
					case .EAST: entity.animation_state = .RUN_E
					case .NORTH: entity.animation_state = .RUN_N
					case .SOUTH: entity.animation_state = .RUN_S
					}
					if visible_velocity.x < 0 {
						entity.facing_left = true
					} else if visible_velocity.x > 0 {
						entity.facing_left = false
					}
				}
				entity.pos += entity.velocity
			}
			if entity.damage_timer > 0 {
				entity.damage_timer -= 1
			}
		}
	}
}

update_entity_ai :: proc() {

}

set_action :: proc(actor: ^Entity, target_id: i32) {
	actor.current_action = .ATTACK // Set this later when we have multiple possible actions
	actor.action_charge = 0
	actor.target_id = target_id
}

start_action :: proc(actor: ^Entity) {
	target := entities[actor.target_id]

	actor.direction = calculate_animation_direction(target.pos - actor.pos)
	switch actor.direction {
	case .EAST: actor.animation_state = .SWING_E
	case .NORTH: actor.animation_state = .SWING_N
	case .SOUTH: actor.animation_state = .SWING_S
	}
	actor.animation_frame = 0
	actor.frame_time = 0

	actor.is_acting = true
	actor.is_swinging = true
}

// This'll probably be a dynamic dispatch later
update_action :: proc(actor: ^Entity) {
	if actor.is_swinging == false {
		target := &entities[actor.target_id]
		damage_entity(target, actor.attack_power)
		end_action(actor)
	}
}

end_action :: proc(actor: ^Entity) {
	actor.current_action = .NONE
	actor.is_acting = false
}

draw_entities :: proc(entities: []Entity) {
	delta := rl.GetFrameTime()
	for i in 0..<len(entities) {
		entity := &(entities[i])
		if entity.in_use {
			renderer := entity_renderers[entity.type]
			mapping := renderer.animation_mappings[entity.animation_state]
			animation := renderer.animation_rows[mapping]
			current_frame := animation.frames[entity.animation_frame]

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
			} else {
				rl.DrawTextureRec(renderer.texture, source_texture_rec,	cast(Vec2) (render_pos - sprite_offset), {0xff, 0xff, 0xff, 0xff})
			}
		}
	}
}

Animation_Direction :: enum {
	EAST,
	NORTH,
	SOUTH,
}
calculate_animation_direction :: proc(vec: Vec2) -> Animation_Direction {
	direction := linalg.dot(linalg.normalize0(vec), {0, -1})
	if direction > 0.5 do return .NORTH
	else if direction < -0.5 do return .SOUTH
	else do return .EAST
}

damage_entity :: proc(target: ^Entity, power: i32) {
	target.health -= power
	target.damage_timer = 30
	if target.health <= 0 {
		target.ko_timer = 90
		target.in_use = false
	}
}
