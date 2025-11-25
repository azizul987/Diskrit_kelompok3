extends CharacterBody2D

@export_category("Ghost Settings")
@export var speed: float = 90.0
@export var wall: TileMapLayer

@export_group("Debug & Visualization")
@export var slow_motion_visualizer: bool = true
@export var scan_delay: float = 0.02

@export_subgroup("Visibility Toggles")
@export var show_scan_area: bool = true
@export var show_path_line: bool = true
@export var show_console_proof: bool = true

var player: Node2D = null
var direction: Vector2 = Vector2.ZERO
var moving: bool = false
var target_pos: Vector2
var is_calculating_path: bool = false

var navigation_stack: Array[Vector2i] = []
var path_found: bool = false
var last_player_grid_pos: Vector2i = Vector2i(-999, -999)

var debug_visited_cells: Array[Vector2i] = []
var debug_final_path: Array[Vector2i] = []

func _ready():
	if wall == null:
		push_error("CRITICAL ERROR: 'Wall' belum di-assign di Inspector! Script berhenti.")
		set_physics_process(false)
		return
	
	global_position = get_tile_center(global_position)
	target_pos = global_position

func _process(_delta):
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0: 
		player = players[0]
	else: 
		player = null

func _physics_process(delta):
	if player == null: return

	var current_player_grid_pos = world_to_map(player.global_position)
	
	if current_player_grid_pos != last_player_grid_pos:
		path_found = false
		moving = false
		navigation_stack.clear()
		last_player_grid_pos = current_player_grid_pos
	
	if moving:
		var to_target = target_pos - global_position
		var step = direction * speed * delta
		
		if step.length() >= to_target.length():
			global_position = target_pos
			moving = false 
		else:
			global_position += step
			
	else:
		if not path_found and not is_calculating_path:
			var current_grid_pos = world_to_map(global_position)
			find_path_bfs_async(current_grid_pos, current_player_grid_pos)
		
		elif path_found and navigation_stack.size() > 0:
			var next_grid_pos = navigation_stack.pop_back()
			var current_grid_pos = world_to_map(global_position)
			
			var diff = next_grid_pos - current_grid_pos
			direction = Vector2(diff.x, diff.y)
			start_move(direction)
			
			if debug_final_path.size() > 0:
				debug_final_path.pop_front()
			queue_redraw()

func find_path_bfs_async(start_node: Vector2i, target_node: Vector2i):
	is_calculating_path = true
	
	debug_visited_cells.clear()
	debug_final_path.clear()
	navigation_stack.clear()
	
	if start_node == target_node:
		is_calculating_path = false
		path_found = true
		return

	var queue: Array[Vector2i] = []
	queue.append(start_node)
	
	var came_from = {}
	came_from[start_node] = null
	var found_target = false
	
	while queue.size() > 0:
		if player == null: break
		var real_time_player_pos = world_to_map(player.global_position)
		if real_time_player_pos != target_node:
			is_calculating_path = false
			return 

		var current = queue.pop_front()
		debug_visited_cells.append(current)
		
		if slow_motion_visualizer:
			queue_redraw()
			if show_scan_area: 
				await get_tree().create_timer(scan_delay).timeout 
		
		if current == target_node:
			found_target = true
			break
			
		for neighbor in get_neighbors(current):
			if not came_from.has(neighbor):
				queue.append(neighbor)
				came_from[neighbor] = current
	
	if found_target:
		var curr = target_node
		while curr != null:
			debug_final_path.append(curr)
			curr = came_from[curr]
		
		debug_final_path.reverse()
		
		navigation_stack = debug_final_path.duplicate()
		navigation_stack.reverse() 
		if navigation_stack.size() > 0:
			navigation_stack.pop_back()
			
		path_found = true
		queue_redraw()
		
		if show_console_proof:
			print_math_proof()
	
	is_calculating_path = false

func _draw():
	if is_calculating_path and show_scan_area:
		for cell in debug_visited_cells:
			var local_pos = to_local(map_to_world(cell))
			draw_rect(Rect2(local_pos - Vector2(8,8), Vector2(16,16)), Color(1, 0, 0, 0.4))

	if (navigation_stack.size() > 0 or debug_final_path.size() > 0) and show_path_line:
		var path_to_draw = debug_final_path
		
		if path_to_draw.size() > 1:
			for i in range(path_to_draw.size() - 1):
				var p1 = to_local(map_to_world(path_to_draw[i]))
				var p2 = to_local(map_to_world(path_to_draw[i+1]))
				draw_line(p1, p2, Color(0, 1, 0), 3.0)

func print_math_proof():
	var start_pos = world_to_map(global_position)
	var steps_count = debug_final_path.size()
	var visited_count = debug_visited_cells.size()
	
	print("\n")
	print("╔════════════════════════════════════════════════════╗")
	print("║      ⚡ BFS ALGORITHM DIAGNOSTICS ⚡      ║")
	print("╠════════════════════════════════════════════════════╣")
	print("║ ◈ STATUS        : %-30s ║" % ["TARGET ACQUIRED" if path_found else "SEARCHING..."])
	print("╠════════════════════════════════════════════════════╣")
	print("║ 📍 COORDINATES                                    ║")
	print("║    • Ghost (Start)    : %-25s ║" % str(start_pos))
	print("║    • Player (Goal)    : %-25s ║" % str(last_player_grid_pos))
	print("╠════════════════════════════════════════════════════╣")
	print("║ 📊 METRICS                                        ║")
	print("║    • Time Complexity : %-4d Node (Visited/Scanned) ║" % visited_count)
	print("║    • Shortest Path    : %-4d Steps (Distance)        ║" % steps_count)
	print("╚════════════════════════════════════════════════════╝")

func get_neighbors(node: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var next = node + dir
		if is_walkable(next): neighbors.append(next)
	return neighbors

func is_walkable(cell: Vector2i) -> bool:
	var tile_data = wall.get_cell_tile_data(cell)
	if tile_data and tile_data.get_collision_polygons_count(0) > 0:
		return false
	return wall.get_cell_source_id(cell) == -1

func start_move(dir: Vector2) -> void:
	moving = true
	var map_pos = world_to_map(global_position)
	target_pos = map_to_world(map_pos + Vector2i(dir.x, dir.y))

func world_to_map(pos: Vector2) -> Vector2i:
	return wall.local_to_map(wall.to_local(pos))

func map_to_world(cell: Vector2i) -> Vector2:
	return wall.to_global(wall.map_to_local(cell))

func get_tile_center(world_pos: Vector2) -> Vector2:
	var cell = world_to_map(world_pos)
	var local_center = wall.map_to_local(cell) 
	return wall.to_global(local_center)
 	
