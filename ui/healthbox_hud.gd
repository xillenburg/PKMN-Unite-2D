class_name HealthboxHUD
extends CanvasLayer

# Constants
const HEALTHBOX_ITEM_SCRIPT := preload("res://ui/healthbox_item.gd")
const FONT_PKMN := preload("res://assets/pokemon-emerald-pro.ttf")
const GameFont := preload("res://ui/game_font.gd")

# Mobile-enlarged dimensions: 860x268 for Player/Ally, 680x216 for Enemy
const BOX_WIDTH_PLAYER := 860.0
const BOX_HEIGHT_PLAYER := 268.0
const BOX_WIDTH_ENEMY := 680.0
const BOX_HEIGHT_ENEMY := 216.0
const BOX_WIDTH := 860.0
const BOX_HEIGHT := 268.0
const SPACING := 24.0
const MARGIN_Y := 20.0
const MARGIN_TOP_ENEMY := 120.0 # Placed cleanly below enlarged top buttons

# References
var player: Fighter
var player_box: Control

# Active healthbox mappings: Fighter -> Control
var enemy_boxes: Dictionary = {}
var ally_boxes: Dictionary = {}

# Cooldown indicator label for Attack 2 and Attack 3
var cooldown_label: Label


func _ready() -> void:
	layer = 70 # Below red tint (80) and CRT (90) so CRT affects healthboxes
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_cooldown_label()
	_find_player()


func _setup_cooldown_label() -> void:
	cooldown_label = Label.new()
	var vp_size := _get_viewport_size()
	cooldown_label.position = Vector2(0, vp_size.y - BOX_HEIGHT - MARGIN_Y - 28)
	cooldown_label.size = Vector2(vp_size.x, 28)
	cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cooldown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cooldown_label.visible = false # Cooldown timers are now directly on the circular MOBA buttons
	GameFont.apply_label(cooldown_label, GameFont.SIZE_COOLDOWN, Color(1.0, 1.0, 1.0, 0.95), true, Color(0.1, 0.1, 0.1, 0.9), 2)
	add_child(cooldown_label)


func _find_player() -> void:
	if player == null:
		var tree := get_tree()
		if tree != null:
			for node in tree.get_nodes_in_group(&"fighters"):
				var f := node as Fighter
				if f != null and is_instance_valid(f) and f.team == &"player":
					player = f
					break

	if player != null and player_box == null:
		player_box = HEALTHBOX_ITEM_SCRIPT.new(true)
		player_box.bind_fighter(player)
		var vp_size := _get_viewport_size()
		var init_pos := Vector2((vp_size.x - BOX_WIDTH) * 0.5, vp_size.y - BOX_HEIGHT - MARGIN_Y)
		player_box.position = init_pos
		player_box.target_position = init_pos
		player_box.set_meta(&"just_spawned", false)
		add_child(player_box)


func _get_viewport_size() -> Vector2:
	var vp := get_viewport()
	if vp != null:
		var rect := vp.get_visible_rect()
		if rect.size.x > 0 and rect.size.y > 0:
			return rect.size
	return Vector2(1920, 1080)


func _process(delta: float) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	if player == null or not is_instance_valid(player):
		_find_player()
		if player == null:
			return

	var vp_size := _get_viewport_size()
	var hb_range := player.get_healthbox_range()

	# 1. Gather all active allies and enemies within the valid healthbox range
	var current_allies: Array[Fighter] = []
	var current_enemies: Array[Fighter] = []

	for node in get_tree().get_nodes_in_group(&"fighters"):
		var f := node as Fighter
		if f == null or not is_instance_valid(f):
			continue
		if f == player:
			continue

		var dist := player.distance_to_fighter(f)
		if dist <= hb_range:
			if f.team == &"player":
				current_allies.append(f)
			else:
				current_enemies.append(f)

	# 2. Update Ally Healthboxes (displayed below screen alongside player)
	_sync_fighter_boxes(current_allies, ally_boxes)

	# 3. Update Enemy Healthboxes (displayed above screen)
	_sync_fighter_boxes(current_enemies, enemy_boxes)

	# 4. Calculate dynamic positions for Friendly (Player + Allies) at bottom
	var friendly_list: Array[Control] = []
	if player_box != null:
		friendly_list.append(player_box)
	for ally in current_allies:
		if ally_boxes.has(ally):
			friendly_list.append(ally_boxes[ally])

	_layout_boxes_horizontal(friendly_list, vp_size.y - BOX_HEIGHT - MARGIN_Y, vp_size.x)

	# 5. Calculate dynamic positions for Enemies at top
	var enemy_list: Array[Control] = []
	for enemy in current_enemies:
		if enemy_boxes.has(enemy):
			enemy_list.append(enemy_boxes[enemy])

	_layout_boxes_horizontal(enemy_list, MARGIN_TOP_ENEMY, vp_size.x)

	# 6. Update and sync all active boxes
	if player_box != null and is_instance_valid(player_box):
		player_box.sync_values()
		player_box.update_position(delta)

	for item in ally_boxes.values():
		var box := item as Control
		if box != null and is_instance_valid(box):
			box.sync_values()
			box.update_position(delta)

	for item in enemy_boxes.values():
		var box := item as Control
		if box != null and is_instance_valid(box):
			box.sync_values()
			box.update_position(delta)

	# 7. Update Attack 2 & Attack 3 Cooldown Timers
	_update_cooldown_display(vp_size)


func _update_cooldown_display(vp_size: Vector2) -> void:
	if cooldown_label == null:
		return
	cooldown_label.position = Vector2(0, vp_size.y - BOX_HEIGHT - MARGIN_Y - 28)
	cooldown_label.size = Vector2(vp_size.x, 28)

	var cds: Dictionary = player.get("slot_cooldowns") if "slot_cooldowns" in player else {}
	var cd2_frames: int = cds.get(&"attack_2", 0)
	var cd3_frames: int = cds.get(&"attack_3", 0)
	var spec_frames: int = cds.get(&"special", 0)

	var cd2_str := "READY" if cd2_frames == 0 else ("%.1fs" % (float(cd2_frames) / 60.0))
	var cd3_str := "READY" if cd3_frames == 0 else ("%.1fs" % (float(cd3_frames) / 60.0))
	var spec_str := "READY" if spec_frames == 0 else ("%ds" % int(ceilf(float(spec_frames) / 60.0)))

	cooldown_label.text = "[E/X] RAZOR LEAF: %s   |   [R/A] ATK 3: %s   |   [F/ZR] SPEC: %s" % [cd2_str, cd3_str, spec_str]


func _sync_fighter_boxes(fighters: Array[Fighter], box_dict: Dictionary) -> void:
	# Add new fighters entering range
	for f in fighters:
		if not box_dict.has(f):
			var is_ally: bool = (f != null and f.team == &"player")
			var item: Control = HEALTHBOX_ITEM_SCRIPT.new(is_ally)
			item.bind_fighter(f)
			# Mark as just spawned so it appears instantly at its slot without sliding in
			item.set_meta(&"just_spawned", true)
			add_child(item)
			box_dict[f] = item

	# Remove fighters that left range or were freed
	var to_remove: Array = []
	for f in box_dict.keys():
		var fighter_ref := f as Fighter
		if fighter_ref == null or not is_instance_valid(fighter_ref) or not fighters.has(fighter_ref):
			to_remove.append(f)

	for f in to_remove:
		var item: Control = box_dict[f]
		box_dict.erase(f)
		if item != null and is_instance_valid(item):
			item.queue_free()


func _layout_boxes_horizontal(boxes: Array[Control], y_pos: float, screen_width: float) -> void:
	var n := boxes.size()
	if n == 0:
		return

	var total_w := 0.0
	for i in range(n):
		var w: float = boxes[i].custom_minimum_size.x if boxes[i].custom_minimum_size.x > 0.0 else boxes[i].size.x
		total_w += w
	total_w += float(n - 1) * SPACING

	var current_x := (screen_width - total_w) * 0.5

	for i in range(n):
		var w: float = boxes[i].custom_minimum_size.x if boxes[i].custom_minimum_size.x > 0.0 else boxes[i].size.x
		var target_pos := Vector2(current_x, y_pos)
		boxes[i].target_position = target_pos

		# If just spawned, set position immediately without sliding in
		if boxes[i].has_meta(&"just_spawned") and bool(boxes[i].get_meta(&"just_spawned")):
			boxes[i].position = target_pos
			boxes[i].set_meta(&"just_spawned", false)

		current_x += w + SPACING
