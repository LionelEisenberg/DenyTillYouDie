class_name Saving

const SAVE_PATH : String = "user://save.tres"

static func save_data() -> void : 
	ResourceSaver.save(Game.ref.save_game_data, SAVE_PATH)

static func load_data() -> void :
	if not ResourceLoader.exists(SAVE_PATH) : return
	Game.ref.save_game_data = _sanitize(ResourceLoader.load(SAVE_PATH))

static func _sanitize(save : SaveGameData) -> SaveGameData:
	if save.goofyness_level > 3: save.goofyness_level = 3
	return save
