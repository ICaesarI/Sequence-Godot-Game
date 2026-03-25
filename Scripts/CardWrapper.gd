extends Control

@onready var card_btn: Button = $CardHand

func setup(id: String) -> void:
	card_btn.setup(id)

func set_selected(state: bool) -> void:
	card_btn.set_selected(state)

func get_card_id() -> String:
	return card_btn.card_id

func connect_pressed(callable: Callable) -> void:
	if not card_btn.pressed.is_connected(callable):
		card_btn.pressed.connect(callable)
		
func play_discard_anim() -> Tween:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if card_btn:
		card_btn.disabled = true

	var t := create_tween()
	t.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)

	t.tween_property(self, "scale", Vector2(0.9, 0.9), 0.08)
	t.parallel().tween_property(self, "modulate:a", 0.0, 0.10)

	t.finished.connect(func():
		queue_free()
	)

	return t
