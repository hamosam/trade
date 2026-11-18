extends Control

@onready var news_title_lbl = $Panel/VBox/NewsCard/VBox/Title
@onready var news_desc_lbl = $Panel/VBox/NewsCard/VBox/Desc
@onready var target_opt = $Panel/VBox/BroadcastBox/TargetOpt
@onready var ime_btn = $Panel/VBox/BroadcastBox/ImeBtn
@onready var broadcast_input = $Panel/VBox/BroadcastBox/InputText
@onready var broadcast_send_btn = $Panel/VBox/BroadcastBox/SendBtn
@onready var quick_btn1 = $Panel/VBox/QuickBox/Btn1
@onready var quick_btn2 = $Panel/VBox/QuickBox/Btn2
@onready var quick_btn3 = $Panel/VBox/QuickBox/Btn3
@onready var feed_label = $Panel/VBox/FeedScroll/FeedLabel

var ime := HangulIME.new()
var korean_mode: bool = true

func _ready():
	_setup_targets()
	ime_btn.pressed.connect(_toggle_ime_mode)
	broadcast_send_btn.pressed.connect(_on_custom_send_pressed)
	broadcast_input.gui_input.connect(_on_input_gui_input)
	broadcast_input.focus_entered.connect(func():
		if korean_mode:
			DisplayServer.window_set_ime_active(false)
	)

	quick_btn1.pressed.connect(func(): _send_to_selected_target("[특가 수출] 우리 국가의 특화 자원을 저렴하게 수출합니다! 제안서를 보내주세요."))
	quick_btn2.pressed.connect(func(): _send_to_selected_target("[긴급 수입] 스마트폰 조립용 부품을 최고가 골드로 매입합니다!"))
	quick_btn3.pressed.connect(func(): _send_to_selected_target("[1:1 제안] 잠시 후 좋은 조건으로 무역 제안서를 보내겠습니다!"))

	GameManager.breaking_news_alert.connect(_on_news_received)
	GameManager.pr_message_received.connect(_on_pr_received)
	GameManager.private_chat_received.connect(_on_private_chat_received)
	GameManager.role_changed.connect(func(_c, _r): _setup_targets())
	_update_current_news()
	_update_ime_btn()

func _toggle_ime_mode():
	SoundManager.play_click()
	ime.flush()
	korean_mode = not korean_mode
	if not korean_mode:
		ime.committed = broadcast_input.text
	_update_ime_btn()
	broadcast_input.grab_focus()

func _update_ime_btn():
	ime_btn.text = "한글" if korean_mode else "영문"
	ime_btn.modulate = Color(0.85, 1.0, 0.85) if korean_mode else Color(1, 1, 1)

func _on_input_gui_input(event: InputEvent):
	if OS.has_feature("web") and DisplayServer.is_touchscreen_available():
		if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
			get_viewport().set_input_as_handled()
			var cur = broadcast_input.text.replace("'", "")
			var res = JavaScriptBridge.eval("window.prompt('메시지를 입력하세요:', '%s')" % cur)
			if res is String:
				ime.reset()
				ime.committed = res
				_sync_text(res)
			return

	if not (event is InputEventKey and event.pressed):
		return

	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		get_viewport().set_input_as_handled()
		_on_custom_send_pressed()
		return

	if not korean_mode:
		return

	# Allow Ctrl shortcuts (copy/paste/select all)
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return

	if event.keycode == KEY_BACKSPACE:
		get_viewport().set_input_as_handled()
		_sync_text(ime.backspace())
		return

	if event.unicode >= 32 and event.unicode <= 126:
		get_viewport().set_input_as_handled()
		var ch = char(event.unicode)
		_sync_text(ime.feed_key(ch))
	elif event.unicode > 126:
		# 웹/태블릿 가상 키보드가 완성된 한글을 직접 보낼 때도 정상 반영
		get_viewport().set_input_as_handled()
		ime.flush()
		ime.committed += char(event.unicode)
		_sync_text(ime.get_full_text())

func _sync_text(new_text: String):
	broadcast_input.text = new_text
	broadcast_input.set_caret_line(0)
	broadcast_input.set_caret_column(new_text.length())

func _setup_targets():
	target_opt.clear()
	target_opt.add_item("전체 방송 (모든 국가)", 0)
	target_opt.set_item_metadata(0, "all")

	var my_id = GameManager.current_player_country
	for c_id in GameManager.countries:
		if c_id != my_id:
			var idx = target_opt.item_count
			target_opt.add_item("1:1 대화 · " + GameManager.countries[c_id]["name"], idx)
			target_opt.set_item_metadata(idx, c_id)

func _update_current_news():
	var ev = GameManager.active_event
	news_title_lbl.text = "현재 국제 정세: " + ev["title"]
	news_desc_lbl.text = ev["description"]

func _prepend_feed(bbcode_line: String):
	feed_label.text = bbcode_line + "\n" + feed_label.text

func _on_news_received(ev: Dictionary):
	_update_current_news()
	_prepend_feed("[color=#b8251e][b][속보] %s[/b] - %s[/color]" % [ev["title"], ev["description"]])

func _on_pr_received(country_id: String, msg: String):
	var c_name = GameManager.countries[country_id]["name"]
	_prepend_feed("[color=#38200f][b][전체 방송 · %s][/b] %s[/color]" % [c_name, msg])

func _on_private_chat_received(from_id: String, to_id: String, msg: String):
	var my_id = GameManager.current_player_country
	if from_id == my_id or to_id == my_id or GameManager.play_mode == "host":
		var from_name = GameManager.countries[from_id]["name"]
		var to_name = GameManager.countries[to_id]["name"]
		_prepend_feed("[color=#6b1d9e][b][1:1 비밀 대화 | %s → %s][/b] %s[/color]" % [from_name, to_name, msg])

func _on_custom_send_pressed():
	ime.flush()
	var txt = (ime.get_full_text() if korean_mode else broadcast_input.text).strip_edges()
	if txt == "":
		return
	_send_to_selected_target(txt)
	ime.reset()
	broadcast_input.text = ""

func _send_to_selected_target(msg: String):
	SoundManager.play_click()
	var target = target_opt.get_item_metadata(target_opt.selected)
	var my_id = GameManager.current_player_country
	if target == "all":
		GameManager.send_pr_message(my_id, msg)
	else:
		GameManager.send_private_chat(my_id, target, msg)
