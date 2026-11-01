## Business-owned setting defaults, constraints and UI hierarchy. No runtime side effects.
extends RefCounted

static func schema() -> Dictionary:
	return {
		"schema_format": 3,
		"settings_version": 1,
		"fields": {
			"duration": {
				"type": "int",
				"default": 90,
				"title": "回合秒数",
				"audience": "room",
				"apply": "next_round",
				"min": 15,
				"max": 300,
				"control": "number"
			},
			"reduced_motion": {
				"type": "bool",
				"default": false,
				"title": "减弱动态效果",
				"audience": "local",
				"apply": "next_activation",
				"control": "toggle"
			},
			"slice": {
				"type": "array",
				"title": "切水果",
				"action": "fruit_slice",
				"audience": "local",
				"default": [
					{
						"kind": "mouse",
						"code": 1
					}
				],
				"apply": "immediate",
				"control": "binding",
				"items": {
					"type": "object",
					"format": "binding"
				},
				"max_items": 2
			}
		},
		"layout": [
			{
				"id": "room",
				"title": "游戏规则",
				"expanded": true,
				"children": [
					{
						"field": "duration"
					}
				]
			},
			{
				"id": "local",
				"title": "本机偏好",
				"expanded": true,
				"children": [
					{
						"field": "reduced_motion"
					},
					{
						"field": "slice"
					}
				]
			}
		]
	}
