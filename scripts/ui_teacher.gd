extends Control

@onready var lock_box = $Panel/VBox/LockBox
@onready var pw_input = $Panel/VBox/LockBox/PwRow/PwInput
@onready var pw_pad_btn = $Panel/VBox/LockBox/PwRow/PwPadBtn
@onready var unlock_btn = $Panel/VBox/LockBox/PwRow/UnlockBtn
@onready var pw_msg = $Panel/VBox/LockBox/PwMsg

@onready var content_box = $Panel/VBox/ContentBox
@onready var btn_shipping = $Panel/VBox/ContentBox/NewsGrid/BtnShipping
@onready var btn_tariff = $Panel/VBox/ContentBox/NewsGrid/BtnTariff
@onready var btn_harvest = $Panel/VBox/ContentBox/NewsGrid/BtnHarvest
@onready var btn_semi = $Panel/VBox/ContentBox/NewsGrid/BtnSemi
@onready var btn_energy = $Panel/VBox/ContentBox/NewsGrid/BtnEnergy
@onready var btn_relic = $Panel/VBox/ContentBox/NewsGrid/BtnRelic

@onready var btn_pause = $Panel/VBox/ContentBox/ControlRow/BtnPause
@onready var btn_add_time = $Panel/VBox/ContentBox/ControlRow/BtnAddTime
@onready var btn_ai_fill = $Panel/VBox/ContentBox/ControlRow/BtnAiFill
@onready var btn_reset = $Panel/VBox/ContentBox/ControlRow/BtnReset
@onready var btn_lock = $Panel/VBox/ContentBox/ControlRow/BtnLock
@onready var status_lbl = $Panel/VBox/ContentBox/StatusLabel

var is_unlocked: bool = false

func _ready():
	unlock_btn.pressed.connect(_try_unlock)
	pw_input.text_submitted.connect(func(_t): _try_unlock())
	pw_input.focus_entered.connect(func(): DisplayServer.window_set_ime_active(false))
	pw_input.gui_input.connect(func(ev):
		if DisplayServer.is_touchscreen_available() and ((ev is InputEventScreenTouch and ev.pressed) or (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT)):
			get_viewport().set_input_as_handled()
			get_tree().current_scene.open_numpad(pw_input, "교사 비밀번호 입력", true)
	)
	pw_pad_btn.pressed.connect(func():
		SoundManager.play_click()
		get_tree().current_scene.open_numpad(pw_input, "교사 비밀번호 입력", true)
	)
	btn_lock.pressed.connect(_lock_panel)

	btn_shipping.pressed.connect(func(): _trigger_news(0))
	btn_tariff.pressed.connect(func(): _trigger_news(1))
	btn_harvest.pressed.connect(func(): _trigger_news(2))
	btn_semi.pressed.connect(func(): _trigger_news(3))
	btn_energy.pressed.connect(func(): _trigger_news(4))
	btn_relic.pressed.connect(func(): _trigger_news(5))

	btn_pause.pressed.connect(_on_pause_pressed)
	btn_add_time.pressed.connect(_on_add_time_pressed)
	btn_ai_fill.pressed.connect(_on_ai_fill_pressed)
	btn_reset.pressed.connect(_on_reset_pressed)

	GameManager.country_data_changed.connect(func(_id): _update_stats())
	GameManager.all_data_changed.connect(_update_stats)
	GameManager.roster_updated.connect(_update_stats)

	_apply_lock_state()
	_update_stats()

func _try_unlock():
	SoundManager.play_click()
	if pw_input.text.strip_edges() == GameManager.TEACHER_PASSWORD:
		is_unlocked = true
		pw_input.text = ""
		pw_msg.text = ""
		_apply_lock_state()
	else:
		pw_msg.text = "비밀번호가 올바르지 않습니다. (기본값: 1234)"

func _lock_panel():
	SoundManager.play_click()
	is_unlocked = false
	_apply_lock_state()

func _apply_lock_state():
	lock_box.visible = not is_unlocked
	content_box.visible = is_unlocked

func _trigger_news(idx: int):
	SoundManager.play_click()
	if idx >= 0 and idx < GameManager.breaking_news_list.size():
		GameManager.broadcast_breaking_news(GameManager.breaking_news_list[idx])
		_update_stats()

func _on_pause_pressed():
	SoundManager.play_click()
	GameManager.set_game_running(not GameManager.is_game_running)
	btn_pause.text = "게임 재개" if not GameManager.is_game_running else "일시 정지"

func _on_add_time_pressed():
	SoundManager.play_click()
	GameManager.add_game_time(180.0)
	_update_stats()

func _on_ai_fill_pressed():
	SoundManager.play_click()
	GameManager.ai_fill_empty_countries = not GameManager.ai_fill_empty_countries
	btn_ai_fill.text = "빈 국가 AI: ON" if GameManager.ai_fill_empty_countries else "빈 국가 AI: OFF"
	_update_stats()

func _on_reset_pressed():
	SoundManager.play_click()
	GameManager.admin_reset_game()
	_update_stats()

func _update_stats():
	btn_pause.text = "게임 재개" if not GameManager.is_game_running else "일시 정지"
	btn_ai_fill.text = "빈 국가 AI: ON" if GameManager.ai_fill_empty_countries else "빈 국가 AI: OFF"
	var total_phones = 0
	var top_country = ""
	var max_score = -1

	for c_id in GameManager.countries:
		var c = GameManager.countries[c_id]
		total_phones += c["smartphones"]
		var sc = GameManager.get_total_score(c_id)
		if sc > max_score:
			max_score = sc
			top_country = c["name"]

	var student_count = GameManager.connected_players.size() if GameManager.play_mode == "host" else 1
	var mode_desc = ""
	if GameManager.play_mode == "host":
		var country_counts := {}
		for c_id in GameManager.countries:
			country_counts[c_id] = 0
		for pid in GameManager.connected_players:
			var cid = GameManager.connected_players[pid].get("country", "")
			if country_counts.has(cid):
				country_counts[cid] += 1
		var parts: Array = []
		for c_id in GameManager.countries:
			parts.append("%s %d" % [GameManager.countries[c_id]["name"], country_counts[c_id]])
		mode_desc = "방 코드 [%s] | 접속 학생: %d명 (%s)" % [GameManager.room_code, student_count, " · ".join(parts)]
	else:
		mode_desc = "혼자 체험 모드 (AI 경쟁국 가동 중)"

	status_lbl.text = "학급 운영 현황 (%s)\n• 전체 완성된 스마트폰: %d대   |   선두 국가: %s (%d점)\n• 교사 안내: 학생들이 자원을 독점하지 않고 무역선으로 자원을 교환하도록 격려해 주세요." % [mode_desc, total_phones, top_country, max_score]
