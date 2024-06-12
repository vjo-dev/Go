extends CanvasLayer

signal start_game


func show_message(text : String) -> void:
	$Message.text = text
	$Message.show()


func _on_start_button_pressed():
	start_game.emit()
