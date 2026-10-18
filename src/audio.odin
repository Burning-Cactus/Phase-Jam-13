package game

import "core:math"
import rl "vendor:raylib"

// swamp_music :: #load("embed/music/rainy_day")

select_sound: rl.Sound
navigate_sound: rl.Sound

master_volume: i32 = 75
sfx_volume: i32 = 75
ui_volume: i32 = 75
music_volume: i32 = 75

Audio_Type :: enum {
	Master,
	Sfx,
	Ui,
	Music,
}

adjust_sound_volume :: proc(sound_type: Audio_Type, amount: i32) {
	switch sound_type {
	case .Master:
		master_volume = math.clamp(master_volume + amount, 0, 100)
		rl.SetMasterVolume(f32(master_volume) / 100)
	case .Sfx:
		sfx_volume = math.clamp(sfx_volume + amount, 0, 100)
		vol := f32(sfx_volume) / 100
	case .Ui:
		ui_volume = math.clamp(ui_volume + amount, 0, 100)
		vol := f32(ui_volume) / 100
		rl.SetSoundVolume(select_sound, vol)
		rl.SetSoundVolume(navigate_sound, vol)
	case .Music:
		music_volume = math.clamp(music_volume + amount, 0, 100)
		vol := f32(music_volume) / 100
	}
}

load_audio :: proc() {
	select_sound = rl.LoadSound("assets/sounds/ui_select.wav")
	navigate_sound = rl.LoadSound("assets/sounds/ui_navigate.wav")
}

unload_audio :: proc() {
	rl.UnloadSound(select_sound)
	rl.UnloadSound(navigate_sound)
}
