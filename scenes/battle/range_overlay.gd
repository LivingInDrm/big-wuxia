extends Node2D
class_name RangeOverlay
## RangeOverlay —— 移动/攻击范围视觉覆盖层
##
## S4 简化实现：用 ColorRect 节点画半透明方块覆盖在 grid 上，不走 TileMapLayer autotile。
##
## 用法：
##   overlay.show_move_range(coords, Color(0.3, 0.5, 1.0, 0.4))
##   overlay.show_attack_range(coords, Color(1.0, 0.3, 0.3, 0.4))
##   overlay.clear()
##
## 多层覆盖：move 和 attack 可同时显示（比如选完移动后同时亮蓝+红）。

const TILE_PX := 64

var _rects: Array[ColorRect] = []


func clear() -> void:
	for r in _rects:
		r.queue_free()
	_rects.clear()


func show_cells(cells: Array[Vector2i], color: Color) -> void:
	for c in cells:
		var rect := ColorRect.new()
		rect.color = color
		rect.size = Vector2(TILE_PX, TILE_PX)
		rect.position = Vector2(c.x * TILE_PX, c.y * TILE_PX)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rect)
		_rects.append(rect)


func show_move_range(cells: Array[Vector2i]) -> void:
	show_cells(cells, Color(0.3, 0.5, 1.0, 0.35))


func show_attack_range(cells: Array[Vector2i]) -> void:
	show_cells(cells, Color(1.0, 0.3, 0.3, 0.35))
