## Player options (music, sound, language, touch button size). Persisted in user://options.cfg.
extends Node

const PATH := "user://options.cfg"
## Touch button size steps: small, normal, large.
const BUTTON_SCALES: Array[float] = [0.85, 1.0, 1.25]

## Emitted when the touch button size changes (HUDs reflow).
signal button_size_changed

var music_on: bool = true
var sound_on: bool = true
var locale: String = "ca"
## Index into BUTTON_SCALES: 0 small, 1 normal, 2 large.
var button_size: int = 1


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
	button_size = clampi(int(cfg.get_value("touch", "button_size", button_size)), 0, BUTTON_SCALES.size() - 1)


## Saves the current options.
func save_options() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_on", music_on)
	cfg.set_value("audio", "sound_on", sound_on)
	cfg.set_value("general", "locale", locale)
	cfg.set_value("touch", "button_size", button_size)
	cfg.save(PATH)


## Changes the game language ("en" or "ca") and saves it.
func set_locale(code: String) -> void:
	locale = code
	TranslationServer.set_locale(code)
	save_options()


## Multiplier of the touch buttons (0.85 / 1.0 / 1.25).
func button_scale() -> float:
	return BUTTON_SCALES[clampi(button_size, 0, BUTTON_SCALES.size() - 1)]


## Sets the touch button size (0 small, 1 normal, 2 large), saves it and tells the HUDs.
func set_button_size(index: int) -> void:
	button_size = clampi(index, 0, BUTTON_SCALES.size() - 1)
	save_options()
	button_size_changed.emit()


## Small -> normal -> large -> small. Returns the new index.
func cycle_button_size() -> int:
	set_button_size((button_size + 1) % BUTTON_SCALES.size())
	return button_size
