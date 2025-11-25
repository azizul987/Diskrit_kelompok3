extends CharacterBody2D

# ------------------------
# Konfigurasi
# ------------------------
@export var speed: float = 95.0 
var player: Node2D = null 
@export var wall: TileMapLayer 

# --- KONFIGURASI BARU UNTUK "NAPAS" (SCATTER) ---
# Koordinat Grid pojok peta (misal: kanan atas) tempat hantu istirahat
# Ganti angka ini di Inspector sesuai koordinat TileMap kamu!
@export var scatter_target: Vector2i = Vector2i(0, 0) 

# Durasi (detik)
var chase_time: float = 23.0
var scatter_time: float = 7.0
var timer: float = 0.0

enum State { CHASE, SCATTER }
var current_state = State.CHASE

# ------------------------
# State Pergerakan
# ------------------------
var direction: Vector2 = Vector2.ZERO
var moving: bool = false
var target_pos: Vector2

func _ready():
	if wall == null: 
		push_error("RedGhost: Wall belum di-assign!")
		set_physics_process(false)
		return
	
	global_position = get_tile_center(global_position)
	target_pos = global_position
	modulate = Color.RED 

func _process(delta: float) -> void:
	# 1. Cari Player
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	else:
		player = null
		
	# 2. LOGIKA TIMER (Ganti mode Chase <-> Scatter)
	timer += delta
	
	if current_state == State.CHASE:
		if timer >= chase_time:
			switch_state(State.SCATTER)
	elif current_state == State.SCATTER:
		if timer >= scatter_time:
			switch_state(State.CHASE)

func _physics_process(delta):
	if player == null: return 

	if not moving:
		var current_grid_pos = world_to_map(global_position)
		var target_grid_pos: Vector2i
		
		# --- PENENTUAN TARGET BERDASARKAN STATE ---
		if current_state == State.CHASE:
			# Mode Agresif: Kejar posisi Player
			target_grid_pos = world_to_map(player.global_position)
		else:
			# Mode Napas: Lari ke pojok (Scatter Target)
			target_grid_pos = scatter_target
		
		# Jalankan BFS ke target yang sudah ditentukan di atas
		var next_grid_pos = find_path_bfs(current_grid_pos, target_grid_pos)
		
		# Eksekusi Gerak
		if next_grid_pos != current_grid_pos:
			var diff = next_grid_pos - current_grid_pos
			direction = Vector2(diff.x, diff.y)
			start_move(direction)
		else:
			# Kalau sudah sampai di pojok scatter, dia akan diam/muter
			# (Tergantung topologi map kamu)
			direction = Vector2.ZERO
			
	else:
		# Gerak Halus
		var to_target = target_pos - global_position
		var step = direction * speed * delta
		
		if step.length() >= to_target.length():
			global_position = target_pos
			moving = false 
		else:
			global_position += step

# ------------------------
# Helper Ganti State
# ------------------------
func switch_state(new_state):
	current_state = new_state
	timer = 0.0
	
	# Debug visual & print (Bisa dihapus nanti)
	if new_state == State.SCATTER:
		print("Mode: NAPAS DULU (Scatter)")
		modulate = Color(1, 0.5, 0.5) # Merah Pucat
	else:
		print("Mode: KEJAR LAGI (Chase)")
		modulate = Color.RED # Merah Asli

# ------------------------
# Algoritma Pathfinding (BFS) - Tetap Sama
# ------------------------
func find_path_bfs(start_node: Vector2i, target_node: Vector2i) -> Vector2i:
	if start_node == target_node: return start_node
	var queue: Array[Vector2i] = []
	queue.append(start_node)
	var came_from = {}
	came_from[start_node] = null
	var found_target = false
	
	while queue.size() > 0:
		var current = queue.pop_front()
		if current == target_node:
			found_target = true
			break
		for neighbor in get_neighbors(current):
			if not came_from.has(neighbor):
				queue.append(neighbor)
				came_from[neighbor] = current
	
	if found_target:
		var curr = target_node
		while came_from[curr] != start_node:
			curr = came_from[curr]
			if curr == null: return start_node
		return curr
	return start_node

func get_neighbors(node: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	var directions = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	for dir in directions:
		var next_node = node + dir
		if is_walkable(next_node):
			neighbors.append(next_node)
	return neighbors

func is_walkable(cell: Vector2i) -> bool:
	var src_id = wall.get_cell_source_id(cell)
	return src_id == -1 

# ------------------------
# Helpers Grid - Tetap Sama
# ------------------------
func start_move(dir: Vector2) -> void:
	moving = true
	var map_pos = world_to_map(global_position)
	var next_cell = map_pos + Vector2i(dir.x, dir.y)
	target_pos = map_to_world(next_cell)

func world_to_map(pos: Vector2) -> Vector2i:
	var local = wall.to_local(pos)
	return wall.local_to_map(local)

func map_to_world(cell: Vector2i) -> Vector2:
	var local = wall.map_to_local(cell)
	return wall.to_global(local)

func get_tile_center(world_pos: Vector2) -> Vector2:
	return map_to_world(world_to_map(world_pos))
