extends Control

const BattleHUDV3Scene := preload("res://scenes/battle/battle_hud_v3.tscn")
const BattleHUDV3Mock := preload("res://scripts/ui/battle_hud_v3_mock.gd")
@onready var _background_texture: TextureRect = %BackgroundTexture
@onready var _background_fill: ColorRect = %BackgroundFill


func _ready() -> void:
	var bg := _load_texture("res://tools/screenshots/s3_battle.png")
	if bg != null:
		_background_texture.texture = bg
		_background_texture.visible = true
		_background_fill.visible = false
	else:
		_background_texture.visible = false
		_background_fill.visible = true

	var hud := BattleHUDV3Scene.instantiate()
	hud.name = "BattleHUDV3"
	add_child(hud)
	if hud.has_method("apply_mock"):
		hud.call("apply_mock", BattleHUDV3Mock.mock_state())


func _load_texture(path: String) -> Texture2D:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)
