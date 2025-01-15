class_name Game
extends Node

static var ref : Game

@export var restart : bool = true

func _init() -> void:
	if not ref : ref = self
	else : queue_free()

var save_game_data : SaveGameData
@onready var save_timer : Timer = %SaveTimer

func _enter_tree() -> void:
	save_game_data = SaveGameData.new()
	if not restart: Saving.load_data()

func _ready() -> void:
	save_timer.timeout.connect(Saving.save_data)
