class_name BattleHUDV3Mock
extends RefCounted


static func mock_state() -> Dictionary:
	return {
		"turn": 1,
		"name": "李淳罡",
		"portrait": "res://resources/ui/portraits/half/li_chungang.png",
		"hp_current": 2877,
		"hp_max": 2877,
		"mp_current": 3765,
		"mp_max": 3765,
		"qinggong": 398,
		"exp_current": 5,
		"exp_max": 8050,
		"level": 54,
		"buffs": [
			{"icon": "●", "icon_color": Color("#D68B2A"), "text": "连击+10%"},
			{"icon": "♥", "icon_color": Color("#B33A3A"), "text": "自动回血+5%"},
		],
	}
