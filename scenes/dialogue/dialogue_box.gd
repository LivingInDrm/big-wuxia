extends CanvasLayer
class_name DialogueBox

signal advance_requested
signal choice_selected(index: int)

const DEFAULT_PORTRAIT_PATH := "res://resources/ui/portraits/_default.png"
const WuxiaButton = preload("res://resources/ui/controls/wuxia_button.gd")

@onready var _root: Control = $Root
@onready var _backdrop: ColorRect = $Root/Backdrop
@onready var _frame: PanelContainer = $Root/BottomAnchor/Frame
@onready var _name_tag: PanelContainer = $Root/BottomAnchor/Frame/Margin/VBox/HeaderRow/LeftColumn/NameTag
@onready var _name_label: Label = $Root/BottomAnchor/Frame/Margin/VBox/HeaderRow/LeftColumn/NameTag/NameLabel
@onready var _portrait_rect: TextureRect = $Root/BottomAnchor/Frame/Margin/VBox/HeaderRow/LeftColumn/PortraitFrame/Portrait
@onready var _text_label: RichTextLabel = $Root/BottomAnchor/Frame/Margin/VBox/HeaderRow/BodyColumn/TextLabel
@onready var _choice_list: VBoxContainer = $Root/BottomAnchor/Frame/Margin/VBox/HeaderRow/BodyColumn/ChoiceList
@onready var _continue_indicator: Label = $Root/BottomAnchor/Frame/Margin/VBox/FooterRow/ContinueIndicator

var _indicator_time: float = 0.0
var _default_portrait: Texture2D = null
var _fade_target_alpha: float = 1.0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	_text_label.bbcode_enabled = true
	_text_label.visible_characters = -1
	_continue_indicator.visible = false
	_root.modulate.a = 0.0
	_fade_target_alpha = 1.0
	_default_portrait = _load_texture(DEFAULT_PORTRAIT_PATH)
	_portrait_rect.texture = _default_portrait
	_backdrop.gui_input.connect(_on_click_surface_input)
	_frame.gui_input.connect(_on_click_surface_input)


func _process(delta: float) -> void:
	var alpha_step := delta / 0.2
	_root.modulate.a = move_toward(_root.modulate.a, _fade_target_alpha, alpha_step)

	if not _continue_indicator.visible:
		return
	_indicator_time += delta * 4.0
	_continue_indicator.modulate.a = 0.45 + 0.55 * (0.5 + 0.5 * sin(_indicator_time))


func play_show() -> void:
	_fade_target_alpha = 1.0


func play_hide() -> void:
	_fade_target_alpha = 0.0


func set_speaker(name_text: String, portrait: Texture2D) -> void:
	var resolved_name := name_text.strip_edges()
	_name_label.text = resolved_name if not resolved_name.is_empty() else "佚名"
	_name_tag.visible = not resolved_name.is_empty()
	_portrait_rect.texture = portrait if portrait != null else _default_portrait


func set_dialogue_text(text: String) -> void:
	_text_label.text = text
	_text_label.visible_characters = -1


func set_visible_characters(count: int) -> void:
	_text_label.visible_characters = count


func reveal_all_text() -> void:
	_text_label.visible_characters = -1


func get_total_character_count() -> int:
	return _text_label.get_total_character_count()


func show_continue_indicator(is_visible: bool) -> void:
	_continue_indicator.visible = is_visible
	if is_visible:
		_indicator_time = 0.0
		_continue_indicator.modulate.a = 1.0


func set_choices(choices: Array[String]) -> void:
	for child in _choice_list.get_children():
		child.queue_free()

	for index in choices.size():
		var button := WuxiaButton.new()
		button.custom_minimum_size = Vector2(0.0, 48.0)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.label_text = choices[index]
		button.text = choices[index]
		button.pattern_style = "hui"
		button.pressed.connect(_on_choice_pressed.bind(index))
		_choice_list.add_child(button)

	_choice_list.visible = not choices.is_empty()


func has_choices() -> bool:
	return _choice_list.visible and _choice_list.get_child_count() > 0


func _on_click_surface_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	advance_requested.emit()
	get_viewport().set_input_as_handled()


func _on_choice_pressed(index: int) -> void:
	choice_selected.emit(index)


func cancel_fade() -> void:
	_fade_target_alpha = _root.modulate.a


func _load_texture(path: String) -> Texture2D:
	var absolute_path := ProjectSettings.globalize_path(path)
	if not FileAccess.file_exists(absolute_path):
		return _make_fallback_texture()
	var image := Image.new()
	var err := image.load(absolute_path)
	if err == OK:
		return ImageTexture.create_from_image(image)

	return _make_fallback_texture()


func _make_fallback_texture() -> Texture2D:
	var fallback := Image.create(96, 96, false, Image.FORMAT_RGBA8)
	fallback.fill(Color(0.88, 0.84, 0.76, 1.0))
	return ImageTexture.create_from_image(fallback)
