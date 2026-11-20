## Game colours by name. Values come from the original CSS variables (reference/css/styles.css:1-13) and the canvas colours.
class_name Palette
extends RefCounted

# Base surfaces
const PAGE_BG := Color("#06070a")
const OBSIDIAN := Color("#090b0f")
const SLATE_PANEL := Color("#141820")
const SLATE_INNER := Color("#1b202b")
const FRAME_TOP := Color("#161a23")
const FRAME_BOTTOM := Color("#0e1117")
const GLASS := Color(14.0 / 255.0, 18.0 / 255.0, 26.0 / 255.0, 0.80)
const GLASS_PILL := Color(14.0 / 255.0, 18.0 / 255.0, 26.0 / 255.0, 0.78)
const CMD_BG := Color(16.0 / 255.0, 20.0 / 255.0, 28.0 / 255.0, 0.78)
const CMD_BG_HOVER := Color(34.0 / 255.0, 42.0 / 255.0, 58.0 / 255.0, 0.92)
const OVERLAY_DARK := Color(6.0 / 255.0, 8.0 / 255.0, 12.0 / 255.0, 0.82)

# Brass and ivory
const BRASS := Color("#d4a153")
const BRASS_BRIGHT := Color("#f6cf77")
const BRASS_DIM := Color(212.0 / 255.0, 161.0 / 255.0, 83.0 / 255.0, 0.34)
const BRASS_BORDER_SOFT := Color(240.0 / 255.0, 195.0 / 255.0, 110.0 / 255.0, 0.32)
const BRASS_BORDER_GLASS := Color(240.0 / 255.0, 195.0 / 255.0, 110.0 / 255.0, 0.28)
const BRASS_BORDER_RACK := Color(240.0 / 255.0, 195.0 / 255.0, 110.0 / 255.0, 0.52)
const IVORY := Color("#f2ecdf")
const IVORY_MUTED := Color(242.0 / 255.0, 236.0 / 255.0, 223.0 / 255.0, 0.64)
const IVORY_HINT := Color(242.0 / 255.0, 236.0 / 255.0, 223.0 / 255.0, 0.72)
const IVORY_FAINT := Color(242.0 / 255.0, 236.0 / 255.0, 223.0 / 255.0, 0.14)

# Teams
const TEAM_GOLD := Color("#f5b945")
const TEAM_CRIMSON := Color("#ea5648")
const POISON_VIOLET := Color("#c678ff")

# Accents
const KICKER_ORANGE := Color("#e6883a")
const LOW_TIME_RED := Color("#ff5247")
const RETREAT_YELLOW := Color("#ffd966")
const WIND_LEFT := Color("#7ec8e3")
const WIND_RIGHT := Color("#f5b945")
const WIND_GUST_LEFT := Color("#b8f0ff")
const WIND_GUST_RIGHT := Color("#ffe899")
const FOCUS_OUTLINE := Color("#ffd966")
const FOCUS_BORDER := Color("#ffe49e")
const FOCUS_RING := Color(246.0 / 255.0, 207.0 / 255.0, 119.0 / 255.0, 0.28)
const TITLE_TOP := Color("#fff6df")
const TITLE_MID := Color("#f3c46b")
const TITLE_BOTTOM := Color("#b8742a")
const DEPLOY_TOP := Color("#f3be5c")
const DEPLOY_BOTTOM := Color("#c48224")
const DEPLOY_BORDER := Color("#ffe094")
const FIRE_TOP := Color("#f5be58")
const FIRE_MID := Color("#d46528")
const FIRE_BOTTOM := Color("#9e261b")
const RIPPLE_TARGET := Color("#ff6b5b")
const RIPPLE_FLIP := Color("#ff8b3d")


# Floating-text colours of the sim (JS hex values)
const FT_TEAM_0 := TEAM_GOLD
const FT_TEAM_1 := TEAM_CRIMSON
const FT_GOLD := BRASS_BRIGHT
const FT_GOLD_SOFT := Color("#ffe082")
const FT_GOLD_BRIGHT := RETREAT_YELLOW
const FT_RED := RIPPLE_TARGET
const FT_PURPLE := Color("#d88aff")
const FT_CREAM := TITLE_TOP
const FT_ORANGE := Color("#ff9e44")
const FT_AMBER := Color("#ffae42")
const FT_GREEN := Color("#76e082")
const FT_WINE := Color("#e85d75")
const FT_GREY := Color("#cbd5e1")
const FT_STONE := Color("#e8e2d5")
const FT_WHIP := Color("#f4eee1")
const FT_WATER := WIND_LEFT
const FT_GUST_RIGHT := BRASS_BRIGHT
const FT_GUST_LEFT := Color("#8fd8f2")

# Literal colours of the HUD widgets
const SLOT_BG := Color(1, 1, 1, 0.035)
const SLOT_BORDER := Color(242.0 / 255.0, 236.0 / 255.0, 223.0 / 255.0, 0.12)
const SLOT_CURSOR_BG := Color(246.0 / 255.0, 207.0 / 255.0, 119.0 / 255.0, 0.30)
const SLOT_ACTIVE_BG := Color(212.0 / 255.0, 161.0 / 255.0, 83.0 / 255.0, 0.20)
const SLOT_HOVER_BG := Color(212.0 / 255.0, 161.0 / 255.0, 83.0 / 255.0, 0.14)
const SLOT_HOVER_BORDER := Color(212.0 / 255.0, 161.0 / 255.0, 83.0 / 255.0, 0.5)
const MODAL_BOX_FILL := Color(0, 0, 0, 0.35)
const MODAL_BOX_BORDER := Color(1, 1, 1, 0.08)
const INK_ON_BRASS := Color("#0b0d12")
const WIND_TRACK_BG := Color(0, 0, 0, 0.55)
const WIND_TRACK_BORDER := Color(1, 1, 1, 0.14)
const RACK_BG := Color(14.0 / 255.0, 18.0 / 255.0, 26.0 / 255.0, 0.86)
const BRASS_BORDER_35 := Color(240.0 / 255.0, 195.0 / 255.0, 110.0 / 255.0, 0.35)
const BTN_TOP := Color(18.0 / 255.0, 23.0 / 255.0, 32.0 / 255.0, 0.92)
const BTN_BOTTOM := Color(12.0 / 255.0, 15.0 / 255.0, 22.0 / 255.0, 0.95)
const BRASS_BORDER_58 := Color(240.0 / 255.0, 195.0 / 255.0, 110.0 / 255.0, 0.58)
const BTN_TOP_HOVER := Color(28.0 / 255.0, 34.0 / 255.0, 46.0 / 255.0, 0.95)
const BTN_TOP_SELECTED := Color(70.0 / 255.0, 54.0 / 255.0, 28.0 / 255.0, 0.96)
const BTN_BOTTOM_SELECTED := Color(18.0 / 255.0, 22.0 / 255.0, 32.0 / 255.0, 0.96)
const CHIP_BG := Color(240.0 / 255.0, 184.0 / 255.0, 73.0 / 255.0, 0.14)
const TITLE_SHADOW := Color(0, 0, 0, 0.85)
const FADE_DARK := Color(20.0 / 255.0, 24.0 / 255.0, 32.0 / 255.0, 0.85)

## Team colour: 0 = gold, otherwise crimson.
static func team_color(team: int) -> Color:
	return TEAM_GOLD if team == 0 else TEAM_CRIMSON
