extends Control

@onready var market_label = $Panel/VBox/MarketBox/MarketText
@onready var table_container = $Panel/VBox/ScrollContainer/TableVBox
@onready var strategy_label = $Panel/VBox/StrategyBox/StrategyText
@onready var find_match_btn = $Panel/VBox/CommandRow/FindMatchBtn
@onready var ime_btn = $Panel/VBox/CommandRow/ImeBtn
@onready var send_order_btn = $Panel/VBox/CommandRow/SendOrderBtn
@onready var order_input = $Panel/VBox/CommandRow/OrderInput

var ime := HangulIME.new()
var korean_mode: bool = true

var res_keys = ["iron", "food", "energy", "semiconductor"]
var res_names = {"iron": "철광석", "food": "식량", "energy": "에너지", "semiconductor": "반도체"}

func _ready():
	find_match_btn.pressed.connect(_on_find_match_pressed)
	send_order_btn.pressed.connect(_on_send_order_pressed)
	ime_btn.pressed.connect(_toggle_ime_mode)
	order_input.gui_input.connect(_on_input_gui_input)
	order_input.focus_entered.connect(func():
		if korean_mode:
			DisplayServer.window_set_ime_active(false)
	)
	_update_ime_btn()

	GameManager.country_data_changed.connect(func(_id): _refresh_analysis())
	GameManager.role_changed.connect(func(_c, _r): _refresh_analysis())
	GameManager.all_data_changed.connect(_refresh_analysis)
	_refresh_analysis()

func _refresh_analysis():
	for child in table_container.get_children():
		child.queue_free()

	# 1. Global Scarcity & Market Price Index (Relative supply + Breaking News)
	var totals = {"iron": 0, "food": 0, "energy": 0, "semiconductor": 0}
	var sum_all = 0
	var list = []
	for c_id in GameManager.countries:
		var c = GameManager.countries[c_id]
		for k in res_keys:
			totals[k] += c[k]
			sum_all += c[k]
		var total = GameManager.get_total_score(c_id)
		list.append({"id": c_id, "data": c, "total": total})

	var avg_amt = max(1.0, float(sum_all) / 4.0)
	var ev = GameManager.active_event
	var price_parts = []
	for k in res_keys:
		var amt = totals[k]
		var ratio = float(amt) / avg_amt
		var tier = "보통"
		var price = 20

		if ratio < 0.78:
			tier = "품귀"
			price = int(clamp(35.0 + (0.78 - ratio) * 30.0, 30, 50))
		elif ratio > 1.12:
			tier = "풍부"
			price = int(clamp(15.0 - (ratio - 1.12) * 15.0, 8, 15))
		else:
			tier = "보통"
			price = 20

		# Apply Breaking News market shock
		if k == "semiconductor" and ev.get("semi_mult", 1.0) < 1.0:
			price += 15
			tier = "급등!"
		elif k == "food" and ev.get("food_mult", 1.0) > 1.0:
			price = max(5, price - 5)
			tier = "하락"
		elif k == "energy" and ev.get("energy_mult", 1.0) > 1.0:
			price = max(5, price - 5)
			tier = "하락"

		price_parts.append("%s %d개(%s·%dG)" % [res_names[k], amt, tier, price])
	market_label.text = "실시간 시세 | " + " / ".join(price_parts)

	# 2. 6-Country Leaderboard
	list.sort_custom(func(a, b): return a["total"] > b["total"])
	for rank in range(list.size()):
		var item = list[rank]
		var c = item["data"]

		var row = PanelContainer.new()
		var hbox = HBoxContainer.new()
		hbox.custom_minimum_size = Vector2(0, 32)

		var rank_lbl = Label.new()
		rank_lbl.custom_minimum_size = Vector2(40, 0)
		rank_lbl.text = "%d위" % (rank + 1)
		hbox.add_child(rank_lbl)

		var name_lbl = Label.new()
		name_lbl.custom_minimum_size = Vector2(140, 0)
		name_lbl.text = c["name"]
		if item["id"] == GameManager.current_player_country:
			name_lbl.text += " (우리)"
			name_lbl.modulate = Color(1.0, 0.85, 0.25)
		hbox.add_child(name_lbl)

		var phone_lbl = Label.new()
		phone_lbl.custom_minimum_size = Vector2(95, 0)
		phone_lbl.text = "스마트폰 %d대" % c["smartphones"]
		hbox.add_child(phone_lbl)

		var score_lbl = Label.new()
		score_lbl.custom_minimum_size = Vector2(95, 0)
		score_lbl.text = "총점 %d점" % item["total"]
		score_lbl.modulate = Color(0.55, 0.95, 1.0)
		hbox.add_child(score_lbl)

		var gold_lbl = Label.new()
		gold_lbl.custom_minimum_size = Vector2(68, 0)
		gold_lbl.text = "%d G" % c["gold"]
		hbox.add_child(gold_lbl)

		var res_lbl = Label.new()
		res_lbl.text = "철:%d  식량:%d  에너지:%d  반도체:%d" % [c["iron"], c["food"], c["energy"], c["semiconductor"]]
		res_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(res_lbl)

		row.add_child(hbox)
		table_container.add_child(row)

	_generate_strategy_tips()

func _generate_strategy_tips():
	var my_c = GameManager.countries[GameManager.current_player_country]
	var lacks = []
	if my_c["iron"] < 3: lacks.append("철광석")
	if my_c["food"] < 3: lacks.append("식량")
	if my_c["energy"] < 3: lacks.append("에너지")
	if my_c["semiconductor"] < 3: lacks.append("반도체")

	if lacks.size() > 0:
		strategy_label.text = "분석 요약: 현재 %s 자원이 부족합니다. 아래 버튼으로 최적 무역 상대를 찾아 협상가에게 지시를 내리세요." % ", ".join(lacks)
	else:
		strategy_label.text = "분석 요약: 모든 부품이 충분합니다! 기술 총괄에게 조립을 요청하고, 남는 자원은 비싼 값에 수출하세요."

func _on_find_match_pressed():
	SoundManager.play_click()
	var my_id = GameManager.current_player_country
	var my_c = GameManager.countries[my_id]

	# Find our most scarce and most abundant resource
	var min_res = res_keys[0]
	var max_res = res_keys[0]
	for k in res_keys:
		if my_c[k] < my_c[min_res]: min_res = k
		if my_c[k] > my_c[max_res]: max_res = k

	# Find rival country with the most of min_res
	var best_partner = ""
	var best_score = -1
	for c_id in GameManager.countries:
		if c_id == my_id:
			continue
		var c = GameManager.countries[c_id]
		var sc = c[min_res] * 2 - c[max_res]
		if sc > best_score:
			best_score = sc
			best_partner = c_id

	if best_partner != "":
		var p_name = GameManager.countries[best_partner]["name"]
		var rec = "[추천 작전] %s에 %s 3개를 보내고 %s 3개를 받아오세요!" % [p_name, res_names[max_res], res_names[min_res]]
		ime.reset()
		ime.committed = rec
		order_input.text = rec
		strategy_label.text = rec

func _toggle_ime_mode():
	SoundManager.play_click()
	ime.flush()
	korean_mode = not korean_mode
	if not korean_mode:
		ime.committed = order_input.text
	_update_ime_btn()
	order_input.grab_focus()

func _update_ime_btn():
	ime_btn.text = "한글" if korean_mode else "영문"
	ime_btn.modulate = Color(0.85, 1.0, 0.85) if korean_mode else Color(1, 1, 1)

func _on_input_gui_input(event: InputEvent):
	if not (event is InputEventKey and event.pressed):
		return
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		get_viewport().set_input_as_handled()
		_on_send_order_pressed()
		return
	if not korean_mode:
		return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		return
	if event.keycode == KEY_BACKSPACE:
		get_viewport().set_input_as_handled()
		var t = ime.backspace()
		order_input.text = t
		order_input.set_caret_line(0)
		order_input.set_caret_column(t.length())
		return
	if event.unicode >= 32 and event.unicode <= 126:
		get_viewport().set_input_as_handled()
		var t = ime.feed_key(char(event.unicode))
		order_input.text = t
		order_input.set_caret_line(0)
		order_input.set_caret_column(t.length())

func _on_send_order_pressed():
	SoundManager.play_click()
	ime.flush()
	var txt = (ime.get_full_text() if korean_mode else order_input.text).strip_edges()
	if txt == "":
		_on_find_match_pressed()
		txt = order_input.text.strip_edges()
	if txt != "":
		GameManager.send_team_order(GameManager.current_player_country, txt)
		strategy_label.text = "대외 협상가 화면으로 작전 지시를 전송했습니다!"
