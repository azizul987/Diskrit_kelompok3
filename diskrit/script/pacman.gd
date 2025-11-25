extends CharacterBody2D

# ------------------------
# Config (edit sesuai kebutuhan)
# ------------------------
@export var speed: float = 120.0
@export var nyawa: int = 3
# [BARU] Pilih file scene menu Anda di sini (contoh: res://Menu.tscn)
@export_file("*.tscn") var menu_scene_path: String = "res://scene/menu.tscn" 

@onready var wall: TileMapLayer = $"../wall"
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

const TILE_SIZE := 24

# ------------------------
# SKOR SYSTEM
# ------------------------
var skor: int = 0 

# ------------------------
# INVINCIBILITY (KEBAL)
# ------------------------
@export var invincibility_duration: float = 3.0
var _invincible_timer: float = 0.0
var _is_invincible: bool = false

# ------------------------
# WARP CONFIG
# ------------------------
@export_group("Warp Settings")
@export var LEFT_BOUND: int = -9
@export var RIGHT_BOUND: int = 9
@export var WARP_ANY_ROW: bool = false
@export var WARP_ROW: int = 0
@export var WARP_COOLDOWN: float = 0.08

# ------------------------
# LANDING CONFIG
# ------------------------
@export_group("Landing Settings")
@export var USE_LANDING_OFFSET: bool = true
@export var WARP_LANDING_OFFSET_RIGHT: int = -1
@export var WARP_LANDING_OFFSET_LEFT: int = -1
@export var WARP_LANDING_CELL_RIGHT: Vector2i = Vector2i(19, 1)
@export var WARP_LANDING_CELL_LEFT: Vector2i = Vector2i(-21, 1)
@export var RESOLVE_WARP_TO_WALKABLE: bool = true
const WARP_RESOLVE_SCAN := 200

# ------------------------
# DEBUG
# ------------------------
@export var DO_DEBUG: bool = true
var _last_debug_pos: Vector2i = Vector2i(9999, 9999)

# ------------------------
# Movement state
# ------------------------
var direction: Vector2 = Vector2.ZERO
var desired_direction: Vector2 = Vector2.ZERO
var moving: bool = false
var target_pos: Vector2

# Warp & Spawn state
var _warp_lock: bool = false
var _warp_lock_timer: float = 0.0
var initial_spawn_pos: Vector2

# ------------------------
# Godot callbacks
# ------------------------
func _ready():
	if wall == null:
		push_error("Player.gd: TileMapLayer 'wall' not found at path ../wall.")
		return
	
	if has_node("../CanvasLayer/Losee"):
		$"../CanvasLayer/Losee".hide()
	
	if has_node("../CanvasLayer/Win"):
		$"../CanvasLayer/Win".hide()
		
	if anim:
		anim.play("default")
		anim.stop()
		
	global_position = get_tile_center(global_position)
	target_pos = global_position
	initial_spawn_pos = global_position
	
	_start_invincibility()
	
	if DO_DEBUG:
		print("--- DEBUG MODE ACTIVE ---")
		print("Nyawa Awal: ", nyawa)
		print("Skor Awal: ", skor)


func _process(delta):
	if _is_invincible:
		_invincible_timer -= delta
		modulate.a = 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02)
		
		if _invincible_timer <= 0:
			_is_invincible = false
			modulate.a = 1.0
			print("Mode Kebal Berakhir")

	if has_node("../CanvasLayer/Poin_n"):
		$"../CanvasLayer/Poin_n".text = str(skor)
	if has_node("../CanvasLayer/nyawa_n"):
		$"../CanvasLayer/nyawa_n".text = str(nyawa)

	_check_enemy_collision()
	_check_coin_collision()
	
	if _warp_lock:
		_warp_lock_timer -= delta
		if _warp_lock_timer <= 0.0:
			_warp_lock = false
			_warp_lock_timer = 0.0

	var in_dir = Vector2.ZERO
	if Input.is_action_pressed("ui_right"): in_dir = Vector2.RIGHT
	elif Input.is_action_pressed("ui_left"): in_dir = Vector2.LEFT
	elif Input.is_action_pressed("ui_up"): in_dir = Vector2.UP
	elif Input.is_action_pressed("ui_down"): in_dir = Vector2.DOWN

	if in_dir != Vector2.ZERO:
		desired_direction = in_dir
		if not moving and can_move(desired_direction):
			start_move(desired_direction)
	
	queue_redraw()

func _physics_process(delta):
	if DO_DEBUG: _debug_position_check()

	if not moving: return

	var to_target = target_pos - global_position
	var step = direction * speed * delta

	if step.length() >= to_target.length():
		global_position = target_pos

		if not _warp_lock: _try_warp_at_center()

		if desired_direction != direction and can_move(desired_direction):
			start_move(desired_direction)
			return

		if can_move(direction):
			start_move(direction)
			return

		moving = false
		direction = Vector2.ZERO
		if anim: anim.stop()
	else:
		global_position += step

# ------------------------
# LOGIKA KOIN (COIN) & MENANG
# ------------------------
func _check_coin_collision():
	var coins = get_tree().get_nodes_in_group("Coin")
	
	for coin in coins:
		if global_position.distance_to(coin.global_position) < 12.0:
			_collect_coin(coin)
			break 
		
func _collect_coin(coin_node):
	skor += 10
	print("Koin Diambil! Total Skor: ", skor)
	
	if has_node("../Node/Eat"):
		$"../Node/Eat".play()
	
	coin_node.queue_free()
	
	# Kurangi 1 karena koin saat ini belum sepenuhnya hilang dari tree
	var sisa_koin = get_tree().get_nodes_in_group("Coin").size() - 1
	print("Sisa Koin: ", sisa_koin)
	
	if sisa_koin <= 0:
		_game_won()

func _game_won():
	print(">>> YOU WIN! SEMUA KOIN HABIS <<<")
	
	if has_node("../CanvasLayer/Win"):
		$"../CanvasLayer/Win".show()
	
	get_tree().paused = true
	
	# [BARU] Pindah scene setelah 3 detik
	_change_scene_after_delay()

# ------------------------
# SISTEM NYAWA & RESPAWN
# ------------------------
func _check_enemy_collision():
	if _is_invincible:
		return

	var ghosts = get_tree().get_nodes_in_group("ghostti")
	
	for ghost in ghosts:
		if global_position.distance_to(ghost.global_position) < 12.0:
			$"../Node/Deadth".play()
			_take_damage()
			break

func _take_damage():
	nyawa -= 1
	print("!!! KENA HANTU !!! Sisa Nyawa: ", nyawa)
	
	if nyawa > 0:
		_respawn()
	else:
		_game_over()

func _respawn():
	print(">> Respawning ke posisi awal...")
	
	global_position = initial_spawn_pos
	target_pos = initial_spawn_pos
	
	moving = false
	direction = Vector2.ZERO
	desired_direction = Vector2.ZERO
	_warp_lock = false
	
	if anim: 
		anim.stop()
		anim.frame = 0
	
	_start_invincibility()

func _start_invincibility():
	_is_invincible = true
	_invincible_timer = invincibility_duration
	print("Mode Kebal Aktif selama ", invincibility_duration, " detik")

func _game_over():
	print(">>> GAME OVER <<< Skor Akhir: ", skor)
	if has_node("../CanvasLayer/Losee"):
		$"../CanvasLayer/Losee".show()
		
	get_tree().paused = true
	
	# [BARU] Pindah scene setelah 3 detik
	_change_scene_after_delay()

# ------------------------
# [BARU] FUNGSI PINDAH SCENE
# ------------------------
func _change_scene_after_delay():
	# Membuat Timer 3 detik.
	# Parameter 'true' pertama membuat timer tetap jalan meski game dipause.
	await get_tree().create_timer(3.0, true, false, true).timeout
	
	print("Memuat ulang ke Menu...")
	
	# PENTING: Matikan pause sebelum pindah scene
	# Kalau tidak, scene menu akan stuck (berhenti) saat dimuat.
	get_tree().paused = false 
	
	if menu_scene_path != "":
		get_tree().change_scene_to_file(menu_scene_path)
	else:
		print("PERINGATAN: Path Menu Scene belum diisi di Inspector!")
		# Opsional: Reload scene saat ini jika menu belum diset
		# get_tree().reload_current_scene()

# ------------------------
# FUNGSI DEBUG
# ------------------------
func _draw():
	if not DO_DEBUG or not moving: return
	draw_line(Vector2.ZERO, to_local(target_pos), Color(1, 0, 0, 0.5), 2)

func _debug_position_check():
	var current_map = world_to_map(global_position)
	if current_map != _last_debug_pos:
		_last_debug_pos = current_map

# ------------------------
# Movement helpers
# ------------------------
func start_move(dir: Vector2) -> void:
	direction = dir
	moving = true
	target_pos = get_next_tile_center(dir)
	_update_visual_orientation(dir)

func _update_visual_orientation(dir: Vector2) -> void:
	if anim == null: return
	if not anim.is_playing(): anim.play("default")
	if dir == Vector2.RIGHT: anim.rotation_degrees = 0
	elif dir == Vector2.DOWN: anim.rotation_degrees = 90
	elif dir == Vector2.LEFT: anim.rotation_degrees = 180
	elif dir == Vector2.UP: anim.rotation_degrees = -90

func can_move(dir: Vector2) -> bool:
	if dir == Vector2.ZERO: return false
	var map_pos: Vector2i = world_to_map(global_position)
	var next_pos: Vector2i = map_pos + Vector2i(dir.x, dir.y)
	return wall.get_cell_source_id(next_pos) == -1

# ------------------------
# Warp logic
# ------------------------
func _try_warp_at_center() -> void:
	var map_pos: Vector2i = world_to_map(global_position)
	if not WARP_ANY_ROW and map_pos.y != WARP_ROW: return

	if map_pos.x < LEFT_BOUND and direction == Vector2.LEFT:
		var requested = _get_landing_cell_from_side(true, map_pos.y)
		_perform_warp_safe(requested)
		return

	if map_pos.x > RIGHT_BOUND and direction == Vector2.RIGHT:
		var requested = _get_landing_cell_from_side(false, map_pos.y)
		_perform_warp_safe(requested)
		return

func _get_landing_cell_from_side(is_left_trigger: bool, row: int) -> Vector2i:
	if USE_LANDING_OFFSET:
		if is_left_trigger: return Vector2i(RIGHT_BOUND + WARP_LANDING_OFFSET_RIGHT, row)
		else: return Vector2i(LEFT_BOUND + WARP_LANDING_OFFSET_LEFT, row)
	else:
		if is_left_trigger: return Vector2i(WARP_LANDING_CELL_RIGHT.x, row)
		else: return Vector2i(WARP_LANDING_CELL_LEFT.x, row)

func _perform_warp_safe(requested_cell: Vector2i) -> void:
	var resolved = requested_cell
	if RESOLVE_WARP_TO_WALKABLE: resolved = _resolve_warp_target(requested_cell)
	if resolved == null or not _is_valid_map_cell(resolved): return
	_perform_warp(resolved)
	_warp_lock = true
	_warp_lock_timer = WARP_COOLDOWN

func _resolve_warp_target(requested_cell: Vector2i):
	var row = requested_cell.y
	var start_x = requested_cell.x
	var step = -1 if start_x > 0 else 1
	var x = start_x
	for i in range(WARP_RESOLVE_SCAN):
		var v = Vector2i(x, row)
		if wall.get_cell_source_id(v) == -1: return v
		x += step
	if wall.get_cell_source_id(requested_cell) == -1: return requested_cell
	return null

func _perform_warp(target_cell: Vector2i) -> void:
	global_position = map_to_world(target_cell)
	target_pos = get_next_tile_center(direction)
	if not can_move(direction):
		moving = false
		direction = Vector2.ZERO
		if anim: anim.stop()

# ------------------------
# Helper Map
# ------------------------
func _is_valid_map_cell(cell: Vector2i) -> bool:
	if cell == Vector2i(0, 0): return false
	return wall.get_cell_source_id(cell) == -1

func world_to_map(pos: Vector2) -> Vector2i:
	var local = wall.to_local(pos)
	return wall.local_to_map(local)

func map_to_world(cell: Vector2i) -> Vector2:
	var local = wall.map_to_local(cell)
	return wall.to_global(local)

func get_tile_center(world_pos: Vector2) -> Vector2:
	return map_to_world(world_to_map(world_pos))

func get_next_tile_center(dir: Vector2) -> Vector2:
	var map_pos: Vector2i = world_to_map(global_position)
	var next_cell: Vector2i = map_pos + Vector2i(dir.x, dir.y)
	return map_to_world(next_cell)
