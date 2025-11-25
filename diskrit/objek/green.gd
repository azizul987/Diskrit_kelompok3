extends CharacterBody2D

# ------------------------
# Config: Pink Ghost (Pinky)
# ------------------------
@export var speed: float = 95.0
@export var wall: TileMapLayer
var player: CharacterBody2D = null

# TARGET ISTIRAHAT: Pojok Kiri Atas
@export var scatter_target: Vector2i = Vector2i(1, 1)

# Timer & State
enum State { CHASE, SCATTER }
var current_state = State.CHASE
var chase_time: float = 25.0
var scatter_time: float = 7.0
var timer: float = 0.0

# Movement
var direction: Vector2 = Vector2.ZERO
var moving: bool = false
var target_pos: Vector2

func _ready():
	if wall == null: set_physics_process(false); return
	global_position = get_tile_center(global_position)
	target_pos = global_position
	modulate = Color(1, 0.7, 0.8) # Warna Pink

func _process(delta):
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0: player = players[0]
	
	# Timer Logic
	timer += delta
	if current_state == State.CHASE and timer >= chase_time:
		switch_state(State.SCATTER)
	elif current_state == State.SCATTER and timer >= scatter_time:
		switch_state(State.CHASE)

func _physics_process(delta):
	if player == null: return

	if not moving:
		var current_grid = world_to_map(global_position)
		var target_grid: Vector2i
		
		if current_state == State.CHASE:
			# --- LOGIKA PINKY ---
			# Target: 4 Tile di DEPAN arah hadap Player
			var p_grid = world_to_map(player.global_position)
			
			# Cek apakah player punya variabel 'direction', kalau tidak default (0,0)
			var p_dir = Vector2.ZERO
			if "direction" in player:
				p_dir = player.direction
			elif "last_direction" in player: # Fallback kalau pakai nama lain
				p_dir = player.last_direction
			
			# Hitung 4 tile di depan
			# (Konversi float vector ke int vector)
			var offset = Vector2i(p_dir.x, p_dir.y) * 4
			target_grid = p_grid + offset
		else:
			target_grid = scatter_target # Mode Istirahat
			
		# Pathfinding
		var next_grid = find_path_bfs(current_grid, target_grid)
		
		if next_grid != current_grid:
			var diff = next_grid - current_grid
			direction = Vector2(diff.x, diff.y)
			start_move(direction)
		else:
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

# --- HELPERS (Sama seperti hantu lain) ---
func switch_state(new_state):
	current_state = new_state
	timer = 0.0

func find_path_bfs(start, target) -> Vector2i:
	if start == target: return start
	var queue: Array[Vector2i] = [start]
	var came_from = {start: null}
	var found = false
	var limit = 0
	
	while queue.size() > 0:
		limit += 1; if limit > 400: break # Safety break
		var curr = queue.pop_front()
		if curr == target: found = true; break
		
		for n in get_neighbors(curr):
			if not came_from.has(n):
				came_from[n] = curr
				queue.append(n)
	
	if found:
		var curr = target
		while came_from[curr] != start:
			curr = came_from[curr]
			if curr == null: return start
		return curr
	
	# Fallback cerdas: cari tetangga terdekat (jarak euclidean)
	var best = start
	var min_d = 999999.0
	for n in get_neighbors(start):
		var d = Vector2(n).distance_squared_to(Vector2(target))
		if d < min_d: min_d = d; best = n
	return best

func get_neighbors(node):
	var res: Array[Vector2i] = []
	for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var n = node + d
		if wall.get_cell_source_id(n) == -1: res.append(n)
	return res

func start_move(dir):
	moving = true
	var m = world_to_map(global_position)
	target_pos = map_to_world(m + Vector2i(dir.x, dir.y))

func world_to_map(p): return wall.local_to_map(wall.to_local(p))
func map_to_world(c): return wall.to_global(wall.map_to_local(c))
func get_tile_center(p): return map_to_world(world_to_map(p))
