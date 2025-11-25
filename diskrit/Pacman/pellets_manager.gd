extends CharacterBody2D

@export var cell_size: int = 16          # ukuran 1 grid (px)
@export var speed_in_cells: float = 6.0  # seberapa cepat (grid per detik)
@export var tilemap_path: NodePath       # isi di inspector: TileMap maze

var tilemap: TileMap

var grid_pos: Vector2i
var dir: Vector2i = Vector2i.ZERO        # arah sekarang
var next_dir: Vector2i = Vector2i.ZERO   # arah yang diminta player
var target_world_pos: Vector2            # posisi dunia yg dituju (tengah tile)


func _ready() -> void:
	tilemap = get_node(tilemap_path) as TileMap

	# Snap posisi awal ke grid
	grid_pos = Vector2i(
		round(global_position.x / cell_size),
		round(global_position.y / cell_size)
	)
	global_position = Vector2(grid_pos * cell_size)
	target_world_pos = global_position

	add_to_group("player")


func _process(delta: float) -> void:
	_get_input()
	_move_on_grid(delta)


func _get_input() -> void:
	var d := Vector2i.ZERO

	if Input.is_action_just_pressed("ui_right"):
		d = Vector2i.RIGHT
	elif Input.is_action_just_pressed("ui_left"):
		d = Vector2i.LEFT
	elif Input.is_action_just_pressed("ui_up"):
		d = Vector2i.UP
	elif Input.is_action_just_pressed("ui_down"):
		d = Vector2i.DOWN

	if d != Vector2i.ZERO:
		next_dir = d


func _move_on_grid(delta: float) -> void:
	# Kalau sudah sampai target tile → lock ke posisi grid
	if global_position.distance_to(target_world_pos) < 0.5:
		global_position = target_world_pos
		grid_pos = Vector2i(global_position / float(cell_size))

		# Coba ganti arah ke next_dir dulu (feel pacman)
		if next_dir != Vector2i.ZERO and not _is_cell_blocked(grid_pos + next_dir):
			dir = next_dir

		# Kalau arah sekarang mentok dinding → stop
		if dir == Vector2i.ZERO or _is_cell_blocked(grid_pos + dir):
			return

		# Tentukan tile berikutnya yang jadi tujuan
		var new_grid_pos: Vector2i = grid_pos + dir
		target_world_pos = Vector2(new_grid_pos * cell_size)

	# Gerak menuju target_world_pos secara halus
	var step := speed_in_cells * cell_size * delta
	global_position = global_position.move_toward(target_world_pos, step)


func _is_cell_blocked(cell: Vector2i) -> bool:
	# Contoh simple: anggap layer index = 0 untuk dinding
	# Kalau tile ada di situ → dinding (tidak bisa lewat)
	var source_id := tilemap.get_cell_source_id(0, cell)
	return source_id != -1   # kalau bukan -1 berarti ada tile (dianggap tembok)
