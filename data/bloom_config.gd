class_name BloomConfig
extends RefCounted

const BLOOM_SHADER := preload("res://shaders/bloom.gdshader")

# =============================================================================
# DATA-DRIVEN BLOOM REGISTRY / TAGGING
# Control which move effects or spawned entities receive 2D bloom glow effects.
# =============================================================================
static var REGISTRY: Dictionary = {
	"tackle": true,       # Tackle melee hit (hit_1) has bloom effect
	"hit_1": true,        # Melee impact visual sprite
	"melee_hit": true,
	"razor_leaf": false,  # Razor leaf projectile has no bloom
	"solar_beam": true,   # Solar beam attack has bloom
}
static var BLOOM_FLAGS := REGISTRY


# Check if an attack, entity, or asset key has bloom enabled
static func has_bloom(key: String) -> bool:
	return REGISTRY.get(key.to_lower(), false)


# Dynamically set or register bloom flag for an asset/move key
static func set_bloom(key: String, enabled: bool) -> void:
	REGISTRY[key.to_lower()] = enabled


# Create configured ShaderMaterial with bloom parameters
static func create_bloom_material(key: String, intensity: float = 2.2, radius: float = 3.5, tint: Color = Color(1.0, 1.0, 0.95, 1.0)) -> ShaderMaterial:
	if not has_bloom(key):
		return null
	var mat := ShaderMaterial.new()
	mat.shader = BLOOM_SHADER
	mat.set_shader_parameter("bloom_enabled", true)
	mat.set_shader_parameter("bloom_intensity", intensity)
	mat.set_shader_parameter("bloom_radius", radius)
	mat.set_shader_parameter("bloom_tint", tint)
	return mat


# Apply bloom material to target CanvasItem if registered as true
static func apply_bloom_if_enabled(node: CanvasItem, key: String, intensity: float = 2.2, radius: float = 3.5, tint: Color = Color(1.0, 1.0, 0.95, 1.0)) -> bool:
	if node == null or not has_bloom(key):
		return false
	var mat := create_bloom_material(key, intensity, radius, tint)
	if mat != null:
		node.material = mat
		return true
	return false
