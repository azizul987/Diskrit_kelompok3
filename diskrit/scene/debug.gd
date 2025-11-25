extends Button

func _ready():
	# Hubungkan signal pressed ke fungsi lokal di script ini
	pressed.connect(_on_button_pressed)

func _on_button_pressed():
	# 1. AMBIL LIST SEMUA HANTU
	# Fungsi ini akan mengembalikan Array berisi semua node yang punya grup "ghost"
	var all_ghosts = get_tree().get_nodes_in_group("ghost")
	
	# Cek jika tidak ada hantu
	if all_ghosts.size() == 0:
		print("Tidak ada hantu yang ditemukan dalam grup 'ghost'!")
		return

	# 2. LOOPING (ULANGI UNTUK SETIAP HANTU)
	for ghost in all_ghosts:
		# Panggil fungsi toggle di setiap hantu
		# Pastikan script hantu punya fungsi bernama 'show_debug'
		if ghost.has_method("show_debug"):
			ghost.show_debug()
