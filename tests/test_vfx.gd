extends SceneTree

const VFX = preload("res://scripts/systems/vfx.gd")
const DUST_VFX: SpriteFrames = preload("res://resources/sprites/vfx/dust.tres")

var _pass: int = 0
var _fail: int = 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	print("[test_vfx] ==== BEGIN ====")
	var parent := Node2D.new()
	root.add_child(parent)
	await process_frame

	var before := parent.get_child_count()
	var sprite := VFX.spawn_at(parent, DUST_VFX, Vector2(32, 32), 1.0)
	_assert(parent.get_child_count() == before + 1, "T1 spawn_at 后 parent child +1")
	_assert(sprite.is_playing(), "T2 VFX 已开始播放")

	for _i in 90:
		await process_frame

	_assert(not is_instance_valid(sprite), "T3 非循环动画结束后自动 queue_free")
	_finish()


func _assert(ok: bool, msg: String) -> void:
	if ok:
		_pass += 1
		print("  [PASS] %s" % msg)
	else:
		_fail += 1
		print("  [FAIL] %s" % msg)


func _finish() -> void:
	print("[test_vfx] ==== END: pass=%d fail=%d ====" % [_pass, _fail])
	quit(0 if _fail == 0 else 1)
