## Player options (music, sound, language). Persisted in user://options.cfg.
extends Node

const PATH := "user://options.cfg"

var music_on: bool = true
var sound_on: bool = true
var locale: String = "ca"


func _ready() -> void:
	load_options()
	TranslationServer.set_locale(locale)


## Loads the options file; missing values keep their defaults.
func load_options() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	music_on = cfg.get_value("audio", "music_on", music_on)
	sound_on = cfg.get_value("audio", "sound_on", sound_on)
	locale = cfg.get_value("general", "locale", locale)


## Saves the current options.
func save_options() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_on", music_on)
	cfg.set_value("audio", "sound_on", sound_on)
	cfg.set_value("general", "locale", locale)
	cfg.save(PATH)


## Changes the game language ("en" or "ca") and saves it.
func set_locale(code: String) -> void:
	locale = code
	TranslationServer.set_locale(code)
	save_options()
