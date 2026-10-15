package game

import rl "vendor:raylib"
import "core:c"

damage_shader: rl.Shader
damage_frames_loc: c.int
damage_duration_loc: c.int

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
}

load_shaders_web :: proc() {
	damage_shader = rl.LoadShader(nil, "assets/shaders/web/damage.fs")
	damage_frames_loc = rl.GetShaderLocation(damage_shader, "damageFrames")
	damage_duration_loc = rl.GetShaderLocation(damage_shader, "damageDuration")
}

unload_shaders :: proc() {
	rl.UnloadShader(damage_shader)
}
