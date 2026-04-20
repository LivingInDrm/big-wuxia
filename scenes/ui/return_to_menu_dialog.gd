extends CanvasLayer

signal confirmed

@onready var _root: Control = $Root
@onready var _backdrop: ColorRect = $Root/Backdrop
@onready var _frame: PanelContainer = $Root/Center/Frame
@onready var _confirm_button: Button = $Root/Center/Frame/Margin/VBox/Buttons/ConfirmButton
@onready var _cancel_button: Button = $Root/Center/Frame/Margin/VBox/Buttons/CancelButton


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_root.visible = false
	_backdrop.gui_input.connect(_on_backdrop_input)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()


func open() -> void:
	visible = true
	_root.visible = true


func close() -> void:
	visible = false
	_root.visible = false


func _on_confirm_pressed() -> void:
	confirmed.emit()


func _on_cancel_pressed() -> void:
	close()


func _on_backdrop_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		close()
		get_viewport().set_input_as_handled()
