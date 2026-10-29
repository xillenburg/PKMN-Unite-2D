class_name HapticManager
extends RefCounted

# =============================================================================
# HAPTIC MANAGER
# Manages Android handheld vibration patterns and gamepad rumble feedback.
# Required Android permission: android.permission.VIBRATE (enabled in export preset)
# =============================================================================

# Base vibration helper with Android amplitude and controller fallback
static func vibrate(duration_ms: int, amplitude: float = -1.0) -> void:
	# Android mobile vibration (supports amplitude on API 26+)
	Input.vibrate_handheld(duration_ms, amplitude)

	# Gamepad / controller rumble fallback
	var joy_amp: float = clampf(amplitude if amplitude >= 0.0 else 0.5, 0.0, 1.0)
	Input.start_joy_vibration(0, joy_amp, joy_amp * 0.5, float(duration_ms) / 1000.0)


# 1. 1st level up confirmation tap (standard confirmation vibration)
static func play_level_up_confirm_1() -> void:
	vibrate(45, 0.45)


# 2. 2nd level up confirmation tap (STRONG final confirmation vibration)
static func play_level_up_confirm_2() -> void:
	vibrate(110, 0.95)


# 3. Leveling up player (STRONG vibration)
static func play_player_level_up() -> void:
	vibrate(140, 1.0)


# 4. Successful tackle (melee hit landed on target)
static func play_tackle_hit() -> void:
	vibrate(55, 0.65)


# 5. Entity attack landed on target (e.g. Razor Leaf hit)
static func play_entity_hit() -> void:
	vibrate(50, 0.55)


# 6. Dash executed (vibrate when dashed)
static func play_dash() -> void:
	vibrate(40, 0.60)
