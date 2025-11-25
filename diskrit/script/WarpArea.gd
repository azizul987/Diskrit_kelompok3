# WarpArea.gd (fixed: use monitoring instead of disabled)
extends Area2D

@export var target_cell: Vector2i = Vector2i(0, 0)            # set di Inspector! jangan biarkan (0,0)
@export var require_direction: Vector2 = Vector2.ZERO         # Vector2.LEFT/RIGHT untuk batasi, atau (0,0) = semua arah
@export var auto_disable_after_trigger: bool = true
@export var disable_seconds: float = 0.2                      # durasi disable area sesudah trigger
@export var DO_DEBUG: bool = true

func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body: Node) -> void:
	if not body:
		return
	# pastikan objek yang masuk adalah Player (CharacterBody2D) dan punya perform_warp()
	if not (body is CharacterBody2D and body.has_method("perform_warp")):
		return

	# Debug
	if DO_DEBUG:
		print("[WarpArea] body_entered:", body.name, " target_cell:", target_cell, " require_dir:", require_direction)

	# validasi target_cell: tolak (0,0)
	if target_cell == Vector2i(0, 0):
		push_warning("[WarpArea] target_cell is (0,0) — please set target_cell in the Inspector for this Area2D.")
		return

	# cek arah bila require_direction diset (opsional)
	if require_direction != Vector2.ZERO:
		# body harus Player (punya properti direction), jadi bandingkan langsung
		if not body.has_variable("direction"):
			if DO_DEBUG:
				print("[WarpArea] body has no 'direction' var; skipping require_direction check")
		else:
			if body.direction != require_direction:
				if DO_DEBUG:
					print("[WarpArea] require_direction mismatch; ignoring.")
				return

	# panggil perform_warp di player
	if DO_DEBUG:
		print("[WarpArea] calling perform_warp ->", target_cell)
	body.perform_warp(target_cell)

	# disable area sementara agar tidak retrigger saat player baru datang
	if auto_disable_after_trigger:
		# nonaktifkan monitoring agar tidak mendeteksi body masuk lagi
		# gunakan set_deferred agar aman selama callback
		set_deferred("monitoring", false)
		# tunggu timer secara async lalu aktifkan kembali
		await get_tree().create_timer(disable_seconds).timeout
		set_deferred("monitoring", true)
		if DO_DEBUG:
			print("[WarpArea] re-enabled after", disable_seconds, "s")
