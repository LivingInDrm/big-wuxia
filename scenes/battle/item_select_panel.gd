extends PanelContainer
class_name ItemSelectPanel

const ItemData = preload("res://scripts/core/item_data.gd")

@onready var item_list: ItemList = $Margin/VBox/ItemList
@onready var close_button: Button = $Margin/VBox/CloseButton

var _item_ids: Array[String] = []

signal item_chosen(item_id: String)
signal panel_closed()


func _ready() -> void:
	item_list.item_selected.connect(_on_item_selected)
	item_list.item_activated.connect(_on_item_activated)
	close_button.pressed.connect(_on_close_pressed)
	hide_panel()


func set_items(entries: Array) -> void:
	_item_ids.clear()
	item_list.clear()

	for entry in entries:
		if not (entry is Dictionary):
			continue
		var item_data = entry.get("item_data") as ItemData
		var count := int(entry.get("count", 0))
		if item_data == null or count <= 0:
			continue
		var label := "%s x%d" % [item_data.name, count]
		item_list.add_item(label, item_data.icon)
		var index := item_list.item_count - 1
		item_list.set_item_tooltip(index, item_data.description)
		_item_ids.append(item_data.id)

	close_button.disabled = _item_ids.is_empty()


func show_panel() -> void:
	visible = true


func hide_panel() -> void:
	visible = false


func has_items() -> bool:
	return not _item_ids.is_empty()


func _on_item_selected(index: int) -> void:
	if index < 0 or index >= _item_ids.size():
		return
	item_chosen.emit(_item_ids[index])


func _on_item_activated(index: int) -> void:
	_on_item_selected(index)


func _on_close_pressed() -> void:
	panel_closed.emit()
	hide_panel()
