package game

import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:mem"
import "core:strings"
import rl "vendor:raylib"
import "core:math/rand"

DAMAGE_FLASH_DURATION :: 30

entity_definitions: [Entity_Type]Entity_Info
entity_renderers: [Entity_Type]Entity_Renderer

Entity_Team :: enum {
	PLAYER,
	ENEMY,
	ALLY,
}

Entity_Type :: enum {
	NITYA,
	// MALICE,
	BIBI,
	// SINON,
	// WILHELMINA,
	SAMMY,
	MALISTOCRAT,
	BISCUITEER,
	WILLAGER,
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
	is_floating: bool,
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
	y_offset: i32,
}

// Instance of an entity. This should not be serialized except for in save data.
Entity :: struct {
	in_use: bool,
	type: Entity_Type,
	team: Entity_Team,
	pos: Vec2,
	velocity: Vec2,
	facing_dir: Vec2,
	living_ticks: u32,

	max_health: i32,
	health: i32,
	attack_power: i32,
	damage_timer: i32,
	heal_timer: i32,
	attack_range: f32,
	movement_speed: f32,

	current_action: Action_Type,
	action_charge: f32,
	ko_timer: i32,
	is_acting: bool,
	target_id: i32,
	effects: bit_set[Status_Effect],
	action_selected_tick: u32,

	// Properties related to animation
	animation_state: Animation_State,
	direction: Animation_Direction,
	animation_frame: i32,
	frame_time: f32,
	facing_left: bool,
	is_swinging: bool,
	is_floating: bool,
}

enemies_nearby_player: bool

register_entities :: proc() {
	entity_definitions[.NITYA] = {
		name = "Nitya",
		sprite_name = "nitty",
		color_code = rl.GetColor(0x5d8000ff),
		base_health = 90,
		base_attack = 16,
		entity_width = 32,
	}
	entity_definitions[.BIBI] = {
		name = "Bibi",
		sprite_name = "bibi",
		color_code = rl.GetColor(0xbd2d4eff),
		base_health = 110,
		base_attack = 12,
		entity_width = 32,
	}
	entity_definitions[.SAMMY] = {
		name = "Sammy",
		sprite_name = "Sammie",
		color_code = rl.GetColor(0x5d8000ff),
		base_health = 35,
		base_attack = 4,
		entity_width = 32,
	}
	entity_definitions[.MALISTOCRAT] = {
		name = "Malistocrat",
		sprite_name = "Malistocrat",
		color_code = rl.GetColor(0x8f2555ff),
		base_health = 25,
		base_attack = 8,
		entity_width = 32,
		is_floating = true,
	}
	entity_definitions[.BISCUITEER] = {
		name = "Biscuiteer",
		sprite_name = "Biscuiteer",
		color_code = rl.GetColor(0xbd2d4eff),
		base_health = 50,
		base_attack = 4,
		entity_width = 32,
	}
	entity_definitions[.WILLAGER] = {
		name = "Willager",
		sprite_name = "willager",
		color_code = rl.GetColor(0x98cbd6ff),
		base_health = 40,
		base_attack = 6,
		entity_width = 32,
	}

	register_renderers()
}

unregister_entities :: proc() {
	unregister_renderers()
}

register_renderers :: proc() {
	Animation_Info :: struct {
		type: Entity_Type,
		sprite_name: cstring,
		y_offset: i32,
	}

	json_fmt :: "assets/sprites/%s.json"
	png_fmt :: "assets/sprites/%s.png"

	definitions :: [?]Animation_Info{
		{ type = .NITYA, sprite_name = "nitty", y_offset = 23 },
		{ type = .BIBI, sprite_name = "bibi", y_offset = 23 },
		{ type = .SAMMY, sprite_name = "Sammie", y_offset = 8 },
		{ type = .MALISTOCRAT, sprite_name = "Malistocrat", y_offset = 13 },
		{ type = .BISCUITEER, sprite_name = "Biscuiteer", y_offset = 14 },
		{ type = .WILLAGER, sprite_name = "willager", y_offset = 16 },
	}

	arena: mem.Dynamic_Arena
	mem.dynamic_arena_init(&arena)
	defer mem.dynamic_arena_destroy(&arena)
	arena_allocator := mem.dynamic_arena_allocator(&arena)

	for info in definitions {
		json_path := fmt.aprintf(json_fmt, info.sprite_name, allocator = arena_allocator)
		json_rows, ok := parse_aseprite_json(string(info.sprite_name), json_path)
		if ok {
			mappings := map_animations(json_rows)
			texture_path := fmt.caprintf(png_fmt, info.sprite_name, allocator = arena_allocator)
			entity_renderers[info.type] = {
				texture = rl.LoadTexture(texture_path),
				animation_rows = json_rows,
				animation_mappings = mappings,
				y_offset = info.y_offset,
			}
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
spawn_entity :: proc(type: Entity_Type, pos: Vec2, team: Entity_Team) -> bool {
	for i in 0..<len(entities) {
		if !entities[i].in_use {
			definition := entity_definitions[type]
			entities[i] = Entity {
				in_use = true,
				type = type,
				team = team,
				pos = pos,
				max_health = definition.base_health,
				health = definition.base_health,
				attack_power = definition.base_attack,
				attack_range = 1,
				movement_speed = 0.02,
				is_floating = definition.is_floating,
			}
			return true
		}
	}
	return false
}

update_entities :: proc() {
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
			if !entity.is_swinging {
				// TODO: Change this when the party system is set up
				if i == party_leader_idx {
					input_dir := Vec2{}
					if rl.IsKeyDown(.A) do input_dir.x -= 1
					if rl.IsKeyDown(.D) do input_dir.x += 1
					if rl.IsKeyDown(.W) do input_dir.y -= 1
					if rl.IsKeyDown(.S) do input_dir.y += 1

					entity.facing_dir = linalg.normalize0(input_dir)

					input_dir = iso_rotation_matrix * input_dir
					input_dir = linalg.normalize0(input_dir)

					entity.velocity = input_dir * entity.movement_speed

					// Search for enemy
					_, found := get_closest_entity_in_range(entity.pos, 6, {.ENEMY})
					if enemies_nearby_player {
						if !found{
							enemies_nearby_player = false
							target := &entities[party_leader_idx]
							if target.type == .NITYA{
								rl.PlaySound(nitya_victory_sound)
							} else if target.type == .BIBI{
								rl.PlaySound(bibi_victory_sound)
							}
							fmt.println("WOA")
						}
					} else {
						if found {
							enemies_nearby_player = true
						}
					}

				} else {
					update_entity_ai(entity)
				}

				// Calculate animations
				visible_velocity := render_pos_from_world_pos(entity.velocity)
				entity.direction = calculate_animation_direction(entity.facing_dir)
				if entity.facing_dir.x < 0 {
					entity.facing_left = true
				} else if entity.facing_dir.x > 0 {
					entity.facing_left = false
				}
				if visible_velocity == {0,0} {
					switch entity.direction {
					case .EAST: set_animation(entity, .IDLE_E)
					case .NORTH: set_animation(entity, .IDLE_N)
					case .SOUTH: set_animation(entity, .IDLE_S)
					}
				} else {
					switch entity.direction {
					case .EAST: set_animation(entity, .RUN_E)
					case .NORTH: set_animation(entity, .RUN_N)
					case .SOUTH: set_animation(entity, .RUN_S)
					}
				}

				// Move and slide/collisions
				if entity.is_floating {
					entity.pos += entity.velocity
				} else {
					old_pos := entity.pos
					entity.pos.x += entity.velocity.x
					check_pos := Vec2i{i32(math.floor(entity.pos.x)), i32(math.floor(entity.pos.y))}
					if is_tile_solid(check_pos, current_floor.tile_map) {
						entity.pos.x = old_pos.x
					}

					entity.pos.y += entity.velocity.y
					check_pos = Vec2i{i32(math.floor(entity.pos.x)), i32(math.floor(entity.pos.y))}
					if is_tile_solid(check_pos, current_floor.tile_map) {
						entity.pos.y = old_pos.y
					}
				}

				// info := entity_definitions[entity.type]
				// width_offset := f32(info.entity_width) / (2 * TILE_WIDTH)
// 				{ // Slide on x axis
// 					entity.pos.x += entity.velocity.x
// 					min_y := entity.pos.y - width_offset
// 					max_y := entity.pos.y + width_offset
// 					x_dir := -1 if entity.velocity.x < 0 else 1
// 					x_check := i32(math.floor(entity.pos.x + f32(x_dir) * width_offset))
// 					for j in i32(math.floor(min_y))..=i32(math.floor(max_y)) {
// 						if is_tile_solid({x_check, j}, current_floor.tile_map) {
// 							if x_dir == -1 {
// 								entity.pos.x = f32(x_check) + 1 + width_offset
// 							} else {
// 								entity.pos.x = f32(x_check) - width_offset
// 							}
// 						}
// 					}
// 				}
//
// 				{ // Slide on y axis
// 					entity.pos.y += entity.velocity.y
// 					min_x := entity.pos.x - width_offset
// 					max_x := entity.pos.x + width_offset
// 					y_dir := -1 if entity.velocity.y < 0 else 1
// 					y_check := i32(math.floor(entity.pos.y + f32(y_dir) * width_offset))
// 					for j in i32(math.floor(min_x))..=i32(math.floor(max_x)) {
// 						if is_tile_solid({j, y_check}, current_floor.tile_map) {
// 							if y_dir == -1 {
// 								entity.pos.y = f32(y_check) + 1 + width_offset
// 							} else {
// 								entity.pos.y = f32(y_check) - width_offset
// 							}
// 						}
// 					}
// 				}

			}
			if entity.damage_timer > 0 {
				entity.damage_timer -= 1
			}
			if entity.heal_timer > 0 {
				entity.heal_timer -= 1
			}
			entity.living_ticks += 1
		}
	}
}

update_entity_ai :: proc(actor: ^Entity) {
	FOLLOW_RANGE :: 10
	enemy_teams: bit_set[Entity_Team]
	switch actor.team {
	case .PLAYER:
		enemy_teams = {.ENEMY}
	case .ALLY:
		enemy_teams = {.ENEMY}
	case .ENEMY:
		enemy_teams = {.PLAYER, .ALLY}
	}
	if actor.current_action != .NONE {
		target := entities[actor.target_id]
		dist_vector := target.pos - actor.pos
		dist := linalg.length(dist_vector)
		direction := linalg.normalize0(dist_vector)
		actor.facing_dir = linalg.normalize0(render_pos_from_world_pos(direction))
		if dist > FOLLOW_RANGE {
			actor.current_action = .NONE
		} else if dist > actor.attack_range + 1 {
			actor.velocity = direction * actor.movement_speed
		} else if dist > actor.attack_range - 0.5 {
			actor.velocity = direction * actor.movement_speed * 0.5
		} else {
			actor.velocity = {0, 0}
		}
	} else {
		// Search for enemy
		nearest_target_idx, found := get_closest_entity_in_range(actor.pos, 6, enemy_teams)
		if found {
			set_action(actor, nearest_target_idx, .ATTACK)
		} else {
			switch actor.team {
			case .PLAYER:
				// party_leader := entities[party_leader_idx] // TODO: Change this when party system is added
			case .ALLY, .ENEMY:
			}
		}
	}
}

set_action :: proc(actor: ^Entity, target_id: i32, action: Action_Type) {
	actor.current_action = action // Set this later when we have multiple possible actions
	actor.action_charge = 0
	actor.action_selected_tick = actor.living_ticks
	actor.target_id = target_id
}

start_action :: proc(actor: ^Entity) {
	target := entities[actor.target_id]

	actor.direction = calculate_animation_direction(target.pos - actor.pos)
	switch actor.direction {
	case .EAST: set_animation(actor, .SWING_E)
	case .NORTH: set_animation(actor, .SWING_N)
	case .SOUTH: set_animation(actor, .SWING_S)
	}
	actor.animation_frame = 0
	actor.frame_time = 0

	actor.is_acting = true
	actor.is_swinging = true
}

// This'll probably be a dynamic dispatch later
update_action :: proc(actor: ^Entity) {
	random_pitch := 0.95 + (rand.float32() * 0.10)
	if actor.is_swinging == false {
		// Play sound
		if actor.type == .NITYA {
			rl.SetSoundPitch(metal_sound, random_pitch)
			rl.PlaySound(metal_sound)
		} else if actor.type == .BIBI {
			num := rand.int_max(2) + 1
			if num == 1 {
				rl.SetSoundPitch(spoon_ring_sound, random_pitch)
				rl.PlaySound(spoon_ring_sound)
			} else {
				rl.SetSoundPitch(spoon_short_sound, random_pitch)
				rl.PlaySound(spoon_short_sound)
			}
		} else if actor.type == .MALISTOCRAT{
			rl.SetSoundPitch(laser_sound, random_pitch)
			rl.PlaySound(laser_sound)
		} else if actor.type == .SAMMY{
			rl.SetSoundPitch(thud_sound, random_pitch)
			rl.PlaySound(thud_sound)
		} else if actor.type == .BISCUITEER{
			rl.SetSoundPitch(spoon_short_sound, random_pitch)
			rl.PlaySound(spoon_short_sound)
		}

		damage_entity(actor.target_id, actor.attack_power)
		end_action(actor)
	}
}

end_action :: proc(actor: ^Entity) {
	actor.current_action = .NONE
	actor.is_acting = false
}

Animation_Direction :: enum {
	EAST,
	NORTH,
	SOUTH,
}
calculate_animation_direction :: proc(vec: Vec2) -> Animation_Direction {
	direction := linalg.dot(linalg.normalize0(vec), {0, -1})
	if direction > 0.8 do return .NORTH
	else if direction < -0.8 do return .SOUTH
	else do return .EAST
}

damage_entity :: proc(target_idx: i32, power: i32) {
	target := &entities[target_idx]
	target.health -= power
	target.damage_timer = 30
	add_damage_marker(target_idx, power, false)
	if target.health <= 0 {
		target.health = 0
		target.ko_timer = 90
		target.in_use = false
	}

	// Play hurt sound
	num := rand.int_max(4) + 1
	if num == 1 {
		if target.type == .NITYA do rl.PlaySound(nitya_damaged_sound)
		else if target.type == .BIBI do rl.PlaySound(bibi_damaged_sound)
	}
}

heal_entity :: proc(target_idx: i32, power: i32) {
	target := &entities[target_idx]
	target.health += power
	target.heal_timer = 30
	add_damage_marker(target_idx, power, true)
	if target.health > target.max_health {
		target.health = target.max_health
	}
}

set_animation :: proc(entity: ^Entity, animation: Animation_State) {
	if entity.animation_state != animation {
		entity.animation_state = animation
		entity.animation_frame = 0
	}
}

// Utils for getting entities based on criteria.

get_entities_on_screen :: proc(screen_space: rl.Rectangle, allocator := context.allocator, loc := #caller_location) -> [dynamic]i32 {
	on_screen := make([dynamic]i32, 0, len(entities), allocator, loc)
	for i in 0..<i32(len(entities)) {
		target := entities[i]
		if target.in_use {
			screen_pos := render_pos_from_world_pos(target.pos)
			if is_inside_rec(screen_pos, screen_space) do append(&on_screen, i)
		}
	}
	return on_screen
}

// The returned result will need to live beyond the frame.
get_entities_in_range :: proc(origin: Vec2, radius: f32, entities: []Entity, allocator := context.allocator, loc := #caller_location) -> [dynamic]i32 {
	in_range := make([dynamic]i32, 0, len(entities), allocator, loc)
	for i in 0..<i32(len(entities)) {
		if entities[i].in_use && linalg.distance(origin, entities[i].pos) < radius {
			append(&in_range, i)
		}
	}
	return in_range
}

get_closest_entity_in_range :: proc(origin: Vec2, radius: f32, teams := bit_set[Entity_Team]{.PLAYER, .ALLY, .ENEMY}) -> (entity_idx: i32, found: bool) {
	current_min: f32 = math.F32_MAX
	for i in 0..<i32(len(entities)) {
		target := entities[i]
		if target.in_use && target.team in teams {
			distance := linalg.distance(origin, target.pos)
			if distance < radius && distance < current_min {
				entity_idx = i
				found = true
			}
		}
	}
	return entity_idx, found
}

get_first_entity_in_range :: proc(origin: Vec2, radius: f32, teams := bit_set[Entity_Team]{.PLAYER, .ALLY, .ENEMY}) -> (entity_idx: i32, found: bool) {
	for i in 0..<i32(len(entities)) {
		target := entities[i]
		if target.in_use && target.team in teams && linalg.distance(origin, target.pos) < radius {
			return i, true
		}
	}
	return -1, false
}
