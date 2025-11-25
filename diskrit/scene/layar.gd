extends CanvasLayer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func  on_Finding_press():
	get_tree().change_scene_to_file("res://scene/main.tscn")


func  on_play_press():
	get_tree().change_scene_to_file("res://scene/True_Main.tscn")
func On_Quit_press():
	get_tree().quit()
	
func On_Back_press():
	$Layer2.hide()
	$Layer1.show()
	$"../Ready_Sound".play()
	
func On_About_press():
	$Layer1.hide()
	$Layer2.show()
