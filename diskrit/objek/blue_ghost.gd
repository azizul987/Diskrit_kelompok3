extends CharacterBody2D

# ------------------------
# Konfigurasi Blue Ghost (Inky)
# ------------------------
@export var speed: float = 95.0
@export var wall: TileMapLayer

# REFERENSI PENTING: Inky butuh Red Ghost untuk berpikir!
@export var red_ghost: CharacterBody2D 
var player: CharacterBody2D = null

# Target Scatter: Biasanya POJOK KANAN BAWAH
@export var scatter_target: Vector2i = Vector2i(20, 20) 

# ------------------------
# State & Timer
# ------------------------
enum State { CHASE, SCATTER }
var current_state = State.CHASE
var chase_time: float = 25.0
var scatter_time: float = 7.0
var timer: float = 0.0

# ------------------------
# Movement State
# ------------------------
var direction: Vector2 = Vector2.ZERO
var moving: bool = false
var target_pos: Vector2

func _ready():
	if wall == null:
		push_error("BlueGhost: Wall belum di-assign!")
		set_physics_process(false)
		return
	
	global_position = get_tile_center(global_position)
	target_pos = global_position
	modulate = Color.CYAN # Warna Biru Muda

func _process(delta: float) -> void:
	# Cari Player
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
	else:
		player = null
		
	# Cari Red Ghost otomatis jika belum di-assign di Inspector
	if red_ghost == null:
		var reds = get_tree().get_nodes_in_group("red_ghost")
		if reds.size() > 0: red_ghost = reds[0]

	# Timer Logic
	timer += delta
	if current_state == State.CHASE:
		if timer >= chase_time: switch_state(State.SCATTER)
	elif current_state == State.SCATTER:
		if timer >= scatter_time: switch_state(State.CHASE)

func _physics_process(delta):
	if player == null: return

	if not moving:
		var current_grid_pos = world_to_map(global_position)
		var target_grid_pos: Vector2i
		
		if current_state == State.CHASE:
			# --- LOGIKA UNIK INKY (BIRU) ---
			if red_ghost != null:
				# 1. Ambil posisi grid Player & Arah hadapnya
				var p_pos = world_to_map(player.global_position)
				# Cek aman untuk mendapatkan direction player
				var p_dir = Vector2.ZERO
				if "direction" in player: p_dir = player.direction
				elif "last_direction" in player: p_dir = player.last_direction

				# 2. Tentukan Titik Pivot (2 kotak di DEPAN Player)
				var pivot = p_pos + Vector2i(p_dir.x, p_dir.y) * 2
				
				# 3. Ambil posisi Red Ghost
				var r_pos = world_to_map(red_ghost.global_position)
				
				# 4. Hitung Vektor: Jarak dari Red ke Pivot
				var vec = pivot - r_pos
				
				# 5. Target Akhir: Red Pos + (Vektor x 2)
				target_grid_pos = r_pos + (vec * 2)
			else:
				# Fallback: Kalau si Merah gak ada, kejar Player langsung
				target_grid_pos = world_to_map(player.global_position)
		else:
			# Mode Scatter: Ke Pojok Kanan Bawah
			target_grid_pos = scatter_target
		
		# Jalankan Pathfinding
		var next_grid_pos = find_path_bfs(current_grid_pos, target_grid_pos)
		
		if next_grid_pos != current_grid_pos:
			var diff = next_grid_pos - current_grid_pos
			direction = Vector2(diff.x, diff.y)
			start_move(direction)
		else:
			direction = Vector2.ZERO
	else:
		# Interpolasi Gerak
		var to_target = target_pos - global_position
		var step = direction * speed * delta
		if step.length() >= to_target.length():
			global_position = target_pos
			moving = false
		else:
			global_position += step

# ------------------------
# Helpers & BFS (Sama)
# ------------------------
func switch_state(new_state):
	current_state = new_state
	timer = 0.0

func find_path_bfs(start_node: Vector2i, target_node: Vector2i) -> Vector2i:
	if start_node == target_node: return start_node
	var queue: Array[Vector2i] = [start_node]
	var came_from = {start_node: null}
	var found_target = false
	var limit = 0
	
	while queue.size() > 0:
		limit += 1; if limit > 500: break # Safety break
		var current = queue.pop_front()
		if current == target_node: found_target = true; break
		
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
		
	# Fallback cerdas jika target di dalam tembok
	return _move_towards_naive(start_node, target_node)

func _move_towards_naive(start: Vector2i, target: Vector2i) -> Vector2i:
	var best_move = start
	var min_dist = 999999.0
	for move in get_neighbors(start):
		var d = Vector2(move).distance_squared_to(Vector2(target))
		if d < min_dist:
			min_dist = d
			best_move = move
	return best_move

func get_neighbors(node: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var next = node + dir
		if wall.get_cell_source_id(next) == -1: neighbors.append(next)
	return neighbors

func start_move(dir: Vector2) -> void:
	moving = true
	var map_pos = world_to_map(global_position)
	target_pos = map_to_world(map_pos + Vector2i(dir.x, dir.y))

func world_to_map(pos: Vector2) -> Vector2i:
	return wall.local_to_map(wall.to_local(pos))

func map_to_world(cell: Vector2i) -> Vector2:
	return wall.to_global(wall.map_to_local(cell))

func get_tile_center(world_pos: Vector2) -> Vector2:
	return map_to_world(world_to_map(world_pos))
