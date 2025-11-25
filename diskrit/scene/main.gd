extends Node2D

# --------------------------
# Konfigurasi
# --------------------------
@export var wall_layer: TileMapLayer 
@export var player_scene: PackedScene 
@export var ghost_scene: PackedScene 

# Konstanta
const TILE_SIZE = 24
const HALF_TILE = 12 

# Enum State: Tambah 'ERASER' untuk mode hapus
enum GameState { EDIT_PLAYER, EDIT_GHOST, ERASER }
var current_state = GameState.EDIT_PLAYER

func _ready():
	if wall_layer == null:
		push_error("LevelManager: Masukkan node 'wall' di Inspector!")
	
	Engine.time_scale=$CanvasLayer/Speed.value
	
func  _process(_delta: float) -> void:
	$"CanvasLayer/Int kecepatan".text=str($CanvasLayer/Speed.value)
func _unhandled_input(event):
	# Shortcut Ganti Mode (TAB)
	if event.is_action_pressed("ui_focus_next"): 
		_cycle_mode()
	
	# Klik Kiri Mouse
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var mouse_global = get_global_mouse_position()
			_handle_click(mouse_global)

# ---------------------------------------------------------
# LOGIC UTAMA KLIK MOUSE
# ---------------------------------------------------------
func _handle_click(mouse_global_pos: Vector2):
	if wall_layer == null: return

	# 1. Konversi ke Grid Map
	var local_mouse_pos = wall_layer.to_local(mouse_global_pos)
	var map_pos = wall_layer.local_to_map(local_mouse_pos)
	
	# 2. Validasi Tembok (Kecuali mode Eraser, tembok gak masalah diklik)
	var source_id = wall_layer.get_cell_source_id(map_pos)
	if current_state != GameState.ERASER and source_id != -1:
		print("Gagal: Grid ", map_pos, " adalah tembok!")
		return
		
	# 3. Eksekusi Sesuai Mode
	match current_state:
		GameState.EDIT_PLAYER:
			spawn_player_at(map_pos)
		GameState.EDIT_GHOST:
			spawn_ghost_at(map_pos)
		GameState.ERASER:
			delete_object_at(map_pos)

# ---------------------------------------------------------
# LOGIC SPAWN & DELETE
# ---------------------------------------------------------
func spawn_player_at(cell: Vector2i):
	if player_scene == null: return
	
	# Hapus player lama (Limit 1)
	var existing_players = get_tree().get_nodes_in_group("player")
	for p in existing_players: p.queue_free()
	
	# Spawn Baru
	var new_player = player_scene.instantiate()
	if not new_player.is_in_group("player"): new_player.add_to_group("player")
	
	_place_node_at(new_player, cell)
	add_child(new_player)
	print("Spawn PLAYER di: ", cell)

func spawn_ghost_at(cell: Vector2i):
	if ghost_scene == null: return
	
	# Cek dulu: Jangan tumpuk hantu di grid yang sama persis
	if is_occupied_by_group(cell, "ghost"):
		print("Sudah ada hantu di sini!")
		return

	# Spawn Hantu Baru
	var new_ghost = ghost_scene.instantiate()
	if not new_ghost.is_in_group("ghost"): new_ghost.add_to_group("ghost")
	
	# Inject dependency Wall ke script Ghost
	if "wall" in new_ghost:
		new_ghost.wall = wall_layer
	
	_place_node_at(new_ghost, cell)
	add_child(new_ghost)
	print("Spawn GHOST di: ", cell)

# --- LOGIC PENGHAPUS (ERASER) ---
func delete_object_at(cell: Vector2i):
	var deleted_something = false
	
	# Cek grup 'ghost' dan 'player'
	var targets = get_tree().get_nodes_in_group("ghost") + get_tree().get_nodes_in_group("player")
	
	for node in targets:
		# Konversi posisi dunia objek itu kembali ke Grid
		var node_local = wall_layer.to_local(node.global_position)
		var node_cell = wall_layer.local_to_map(node_local)
		
		# Jika posisinya sama dengan yang kita klik -> HAPUS
		if node_cell == cell:
			node.queue_free()
			deleted_something = true
			print("Menghapus objek di grid: ", cell)
	
	if not deleted_something:
		print("Tidak ada objek di grid: ", cell)

# ---------------------------------------------------------
# HELPER
# ---------------------------------------------------------
func _place_node_at(node: Node2D, cell: Vector2i):
	var center_pos_local = (Vector2(cell) * TILE_SIZE) + Vector2(HALF_TILE, HALF_TILE)
	node.global_position = wall_layer.to_global(center_pos_local)

# Cek apakah grid sudah terisi grup tertentu (biar gak numpuk)
func is_occupied_by_group(cell: Vector2i, group_name: String) -> bool:
	var nodes = get_tree().get_nodes_in_group(group_name)
	for node in nodes:
		var node_local = wall_layer.to_local(node.global_position)
		var node_cell = wall_layer.local_to_map(node_local)
		if node_cell == cell:
			return true
	return false

# ---------------------------------------------------------
# FUNGSI SIGNAL BUTTON (UI)
# ---------------------------------------------------------
func set_mode_player():
	current_state = GameState.EDIT_PLAYER
	print(">>> Mode: EDIT PLAYER")

func set_mode_ghost():
	current_state = GameState.EDIT_GHOST
	print(">>> Mode: EDIT GHOST")

func set_mode_eraser():
	current_state = GameState.ERASER
	print(">>> Mode: PENGHAPUS (Klik objek untuk hapus)")

func On_Menu_Presess():
	get_tree().change_scene_to_file("res://scene/menu.tscn")
func trigger_reset():
	# Hapus SEMUA
	var all_units = get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("ghost")
	for unit in all_units: unit.queue_free()
	print(">>> LEVEL DI-RESET")

func _cycle_mode():
	# Rotasi mode: Player -> Ghost -> Eraser -> Player
	match current_state:
		GameState.EDIT_PLAYER: set_mode_ghost()
		GameState.EDIT_GHOST: set_mode_eraser()
		GameState.ERASER: set_mode_player()

# ---------------------------------------------------------
# PENGATUR KECEPATAN GAME
# ---------------------------------------------------------

# Hubungkan ini ke signal 'value_changed' milik node HSlider
# value = 1.0 (Normal), 0.5 (Slow Motion), 2.0 (Cepat)
func set_game_speed(value: float):
	# Engine.time_scale mengubah seberapa cepat waktu berjalan di seluruh game
	Engine.time_scale = value
	print(">>> Kecepatan Game: ", value, "x")
