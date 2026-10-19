package game

import "core:math"
import rl "vendor:raylib"

swamp_music_bytes :: #load("../embed/music/夏色ビードロ.mp3")

swamp_music: rl.Music

select_sound: rl.Sound
navigate_sound: rl.Sound

bibi_damaged_sound: rl.Sound
bibi_eh_sound: rl.Sound
bibi_intro_sound: rl.Sound
bibi_victory_sound: rl.Sound
nitya_damaged_sound: rl.Sound
nitya_eh_sound: rl.Sound
nitya_intro_sound: rl.Sound
nitya_victory_sound: rl.Sound

spoon_ring_sound: rl.Sound
spoon_short_sound: rl.Sound
spoon_ting_sound: rl.Sound
thud_sound: rl.Sound
wood_bash_sound: rl.Sound
cookie_crumble_sound: rl.Sound
metal_sound: rl.Sound
laser_sound: rl.Sound

master_volume: i32 = 75
sfx_volume: i32 = 100
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
		rl.SetSoundVolume(bibi_damaged_sound, vol)
		rl.SetSoundVolume(bibi_eh_sound, vol)
		rl.SetSoundVolume(bibi_intro_sound, vol)
		rl.SetSoundVolume(bibi_victory_sound, vol)
		rl.SetSoundVolume(nitya_damaged_sound, vol)
		rl.SetSoundVolume(nitya_eh_sound, vol)
		rl.SetSoundVolume(nitya_intro_sound, vol)
		rl.SetSoundVolume(nitya_victory_sound, vol)

		rl.SetSoundVolume(spoon_ring_sound, vol)
		rl.SetSoundVolume(spoon_short_sound, vol)
		rl.SetSoundVolume(spoon_ting_sound, vol)
		rl.SetSoundVolume(thud_sound, vol)
		rl.SetSoundVolume(wood_bash_sound, vol)
		rl.SetSoundVolume(cookie_crumble_sound, vol)
		rl.SetSoundVolume(metal_sound, vol)
		rl.SetSoundVolume(laser_sound, vol)
	case .Ui:
		ui_volume = math.clamp(ui_volume + amount, 0, 100)
		vol := f32(ui_volume) / 100
		rl.SetSoundVolume(select_sound, vol)
		rl.SetSoundVolume(navigate_sound, vol)
	case .Music:
		music_volume = math.clamp(music_volume + amount, 0, 100)
		vol := f32(music_volume) / 100
		rl.SetMusicVolume(swamp_music, vol)
	}
}

load_audio :: proc() {
	select_sound = rl.LoadSound("assets/sounds/ui_select.wav")
	navigate_sound = rl.LoadSound("assets/sounds/ui_navigate.wav")
	swamp_music = rl.LoadMusicStreamFromMemory(".mp3", raw_data(swamp_music_bytes), i32(len(swamp_music_bytes)))
	rl.SetMasterVolume(f32(master_volume) / 100)
	rl.SetSoundVolume(select_sound, f32(ui_volume) / 100)
	rl.SetSoundVolume(navigate_sound, f32(ui_volume) / 100)
	rl.SetMusicVolume(swamp_music, f32(music_volume) / 100)

	// Character Sounds
	bibi_damaged_sound = rl.LoadSound("assets/sounds/bibi_scream.wav")
	bibi_eh_sound = rl.LoadSound("assets/sounds/bibi_eh.wav")
	bibi_intro_sound = rl.LoadSound("assets/sounds/bibi_intro.wav")
	bibi_victory_sound = rl.LoadSound("assets/sounds/bibi_yay.wav")

	nitya_damaged_sound = rl.LoadSound("assets/sounds/nitya_scream.wav")
	nitya_eh_sound = rl.LoadSound("assets/sounds/nitya_eh.wav")
	nitya_intro_sound = rl.LoadSound("assets/sounds/nitya_intro.wav")
	nitya_victory_sound = rl.LoadSound("assets/sounds/nitya_yippee.wav")

	rl.SetSoundVolume(bibi_damaged_sound, f32(sfx_volume) / 100)
	rl.SetSoundVolume(bibi_eh_sound, f32(sfx_volume) / 100)
	rl.SetSoundVolume(bibi_intro_sound, f32(sfx_volume) / 100)
	rl.SetSoundVolume(bibi_victory_sound, f32(sfx_volume) / 100)
	rl.SetSoundVolume(nitya_damaged_sound, f32(sfx_volume) / 100)
	rl.SetSoundVolume(nitya_eh_sound, f32(sfx_volume) / 100)
	rl.SetSoundVolume(nitya_intro_sound, f32(sfx_volume) / 100)
	rl.SetSoundVolume(nitya_victory_sound, f32(sfx_volume) / 100)

	// Other SFX
	spoon_ring_sound = rl.LoadSound("assets/sounds/sfx/spoon_ring.wav")
	spoon_short_sound = rl.LoadSound("assets/sounds/sfx/spoon_short.wav")
	spoon_ting_sound = rl.LoadSound("assets/sounds/sfx/spoon_ting.wav")
	thud_sound = rl.LoadSound("assets/sounds/sfx/thud.wav")
	wood_bash_sound = rl.LoadSound("assets/sounds/sfx/wood_bash.wav")
	cookie_crumble_sound = rl.LoadSound("assets/sounds/sfx/cookie_crumble.wav")
	metal_sound = rl.LoadSound("assets/sounds/sfx/metal_sound.wav")
	laser_sound = rl.LoadSound("assets/sounds/sfx/laser.wav")

	rl.SetSoundVolume(spoon_ring_sound, f32(sfx_volume) / 100)
	rl.SetSoundVolume(spoon_short_sound, f32(sfx_volume) / 100)
	rl.SetSoundVolume(spoon_ting_sound, f32(sfx_volume) / 100)
	rl.SetSoundVolume(thud_sound, f32(sfx_volume) / 100)
	rl.SetSoundVolume(wood_bash_sound, f32(sfx_volume) / 100)
	rl.SetSoundVolume(cookie_crumble_sound, f32(sfx_volume) / 100)
	rl.SetSoundVolume(metal_sound, f32(sfx_volume) / 100)
	rl.SetSoundVolume(laser_sound, f32(sfx_volume) / 100)
}

unload_audio :: proc() {
	rl.UnloadSound(select_sound)
	rl.UnloadSound(navigate_sound)
	rl.UnloadMusicStream(swamp_music)
}
