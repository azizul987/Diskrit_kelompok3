extends CanvasLayer # <-- Sesuaikan dengan node indukmu

# Drag node label "StatusText" ke sini lewat Inspector
@export var status_label: RichTextLabel

func _ready():
	# Ambil semua anak (TombolMulai, TombolKeluar, JudulGame, StatusText, dll)
	var semua_anak = get_children()
	
	for anak in semua_anak:
		# --- FILTER PENGAMAN ---
		# Di sinilah Label akan "disaring" dan dicuekin.
		# Label bukan Button, jadi dia tidak akan masuk ke blok kode if ini.
		if anak is Button:
			print("Menyambungkan tombol: ", anak.name)
			# Hubungkan signal DAN kirim data tombolnya (bind)
			anak.pressed.connect(_on_tombol_ditekan.bind(anak))
		else:
			# Kode ini cuma buat bukti di output console
			print("Melewati node non-button: ", anak.name)

func _on_tombol_ditekan(tombol_nya: Button):
	# Ubah teks label sesuai teks tombol yang ditekan
	if status_label != null:
		status_label.text = "Kamu menekan: " + tombol_nya.text
