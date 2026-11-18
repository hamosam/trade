extends Node

var sounds = {}

func _ready():
	_load_sound("click", "res://assets/audio/click.wav")
	_load_sound("coin", "res://assets/audio/coin.wav")
	_load_sound("assemble", "res://assets/audio/assemble.wav")
	_load_sound("ship_horn", "res://assets/audio/ship_horn.mp3")
	_load_sound("news_alarm", "res://assets/audio/news_alarm.wav")

func _load_sound(sound_name: String, path: String):
	if FileAccess.file_exists(path):
		var s = load(path)
		sounds[sound_name] = s

func play(sound_name: String):
	if sounds.has(sound_name) and sounds[sound_name] != null:
		var player = AudioStreamPlayer.new()
		player.stream = sounds[sound_name]
		player.finished.connect(func(): player.queue_free())
		add_child(player)
		player.play()

func play_click():
	play("click")

func play_coin():
	play("coin")

func play_assemble():
	play("assemble")

func play_ship_horn():
	play("ship_horn")

func play_news_alarm():
	play("news_alarm")
