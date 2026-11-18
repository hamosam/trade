extends Control

@onready var target_country_btn = $Panel/VBox/TradeForm/TargetRow/TargetOption
@onready var offer_res_btn = $Panel/VBox/TradeForm/OfferRow/OfferResOption
@onready var offer_qty_spin = $Panel/VBox/TradeForm/OfferRow/OfferQtySpin
@onready var offer_gold_spin = $Panel/VBox/TradeForm/OfferRow/OfferGoldSpin

@onready var request_res_btn = $Panel/VBox/TradeForm/RequestRow/ReqResOption
@onready var request_qty_spin = $Panel/VBox/TradeForm/RequestRow/ReqQtySpin
@onready var request_gold_spin = $Panel/VBox/TradeForm/RequestRow/ReqGoldSpin

@onready var send_proposal_btn = $Panel/VBox/TradeForm/SendBtn
@onready var team_order_lbl = $Panel/VBox/TeamOrderBox/OrderText
@onready var proposals_container = $Panel/VBox/InboxScroll/ProposalsVBox
@onready var history_label = $Panel/VBox/HistoryLabel

var res_keys = ["none", "iron", "food", "energy", "semiconductor"]
var res_names = ["(자원 없음)", "철광석", "식량", "에너지", "반도체"]

func _ready():
	_setup_options()
	send_proposal_btn.pressed.connect(_on_send_proposal_pressed)
	GameManager.trade_proposed.connect(func(_id, _data): _refresh_inbox())
	GameManager.trade_resolved.connect(func(_id, _status, _data): _refresh_inbox(); _refresh_history())
	GameManager.country_data_changed.connect(func(_id): _refresh_inbox())
	GameManager.role_changed.connect(func(_c, _r): _setup_options(); _refresh_inbox(); _refresh_team_order())
	GameManager.team_order_received.connect(func(cid, _ord):
		if cid == GameManager.current_player_country:
			_refresh_team_order()
	)
	GameManager.all_data_changed.connect(func(): _refresh_inbox(); _refresh_history())
	_refresh_inbox()
	_refresh_history()
	_refresh_team_order()

func _setup_options():
	target_country_btn.clear()
	for c_id in GameManager.countries:
		if c_id != GameManager.current_player_country:
			var c = GameManager.countries[c_id]
			target_country_btn.add_item(c["name"], target_country_btn.item_count)
			target_country_btn.set_item_metadata(target_country_btn.item_count - 1, c_id)

	offer_res_btn.clear()
	request_res_btn.clear()
	for i in range(res_names.size()):
		offer_res_btn.add_item(res_names[i], i)
		offer_res_btn.set_item_metadata(i, res_keys[i])
		request_res_btn.add_item(res_names[i], i)
		request_res_btn.set_item_metadata(i, res_keys[i])
	offer_res_btn.select(1)
	request_res_btn.select(4)

func _on_send_proposal_pressed():
	SoundManager.play_click()
	var selected_idx = target_country_btn.selected
	if selected_idx < 0:
		return
	var to_id = target_country_btn.get_item_metadata(selected_idx)
	var from_id = GameManager.current_player_country

	var offer_res = offer_res_btn.get_item_metadata(offer_res_btn.selected)
	var offer_qty = int(offer_qty_spin.value)
	var offer_gold = int(offer_gold_spin.value)

	var req_res = request_res_btn.get_item_metadata(request_res_btn.selected)
	var req_qty = int(request_qty_spin.value)
	var req_gold = int(request_gold_spin.value)

	var trade_id = GameManager.propose_trade(from_id, to_id, offer_res, offer_qty, req_res, req_qty, offer_gold, req_gold)
	if trade_id > 0:
		history_label.text = GameManager.countries[to_id]["name"] + " 외교부에 무역 제안서를 보냈습니다."
	elif trade_id == -3:
		history_label.text = "보낼 품목(자원 또는 골드)과 받을 품목을 최소 1개 이상 선택하세요."
	elif trade_id == -2:
		history_label.text = GameManager.countries[to_id]["name"] + "에 이미 대기 중인 제안서가 있습니다. 상대의 응답을 기다려주세요."
	else:
		history_label.text = "보유한 자원이나 골드가 부족해 제안서를 보낼 수 없습니다."
	_refresh_inbox()

func _refresh_inbox():
	for child in proposals_container.get_children():
		child.queue_free()

	var my_id = GameManager.current_player_country
	var my_proposals = []
	for trade_id in GameManager.pending_trades:
		var trade = GameManager.pending_trades[trade_id]
		if trade["to_id"] == my_id:
			my_proposals.append(trade)

	# 농업 대국 무역 협상 우선권: 제안함 최상단 우선 정렬
	my_proposals.sort_custom(func(a, b):
		var a_prio = 1 if a["from_id"] == "agri_empire" else 0
		var b_prio = 1 if b["from_id"] == "agri_empire" else 0
		if a_prio != b_prio:
			return a_prio > b_prio
		return int(a["id"]) < int(b["id"])
	)

	var found_any = my_proposals.size() > 0
	for trade in my_proposals:
		var trade_id = int(trade["id"])
		var from_c = GameManager.countries[trade["from_id"]]

		var card = PanelContainer.new()
		var hbox = HBoxContainer.new()
		hbox.custom_minimum_size = Vector2(0, 40)

		var info_lbl = Label.new()
		var offer_str = ""
		if trade["offer_res"] != "none":
			offer_str += _get_res_label(trade["offer_res"]) + " " + str(trade["offer_qty"]) + "개 "
		if trade["offer_gold"] > 0:
			offer_str += str(trade["offer_gold"]) + "G "

		var req_str = ""
		if trade["request_res"] != "none":
			req_str += _get_res_label(trade["request_res"]) + " " + str(trade["request_qty"]) + "개 "
		if trade["request_gold"] > 0:
			req_str += str(trade["request_gold"]) + "G "

		var prio_prefix = "[우선 협상] " if trade["from_id"] == "agri_empire" else ""
		info_lbl.text = "%s%s 제안 | 주는 것: %s -> 원하는 것: %s" % [prio_prefix, from_c["name"], offer_str, req_str]
		if trade["from_id"] == "agri_empire":
			info_lbl.modulate = Color(1.0, 0.92, 0.45)
		info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(info_lbl)

		var accept_btn = Button.new()
		accept_btn.text = "수락"
		accept_btn.custom_minimum_size = Vector2(72, 30)
		accept_btn.pressed.connect(func():
			SoundManager.play_click()
			if not GameManager.accept_trade(trade_id):
				history_label.text = "양측 중 한 곳의 자원 또는 골드가 부족해 수락할 수 없습니다."
		)
		hbox.add_child(accept_btn)

		var reject_btn = Button.new()
		reject_btn.text = "거절"
		reject_btn.custom_minimum_size = Vector2(72, 30)
		reject_btn.pressed.connect(func():
			SoundManager.play_click()
			GameManager.reject_trade(trade_id)
		)
		hbox.add_child(reject_btn)

		card.add_child(hbox)
		proposals_container.add_child(card)

	if not found_any:
		var empty_lbl = Label.new()
		empty_lbl.text = "도착한 무역 제안이 없습니다. 먼저 다른 나라에 제안을 보내보세요."
		empty_lbl.modulate = Color(0.45, 0.35, 0.25)
		proposals_container.add_child(empty_lbl)

func _refresh_history():
	if GameManager.trade_history.is_empty():
		return
	var hist_text = "최근 무역 기록: "
	var recent = GameManager.trade_history.slice(-3)
	var items = []
	for h in recent:
		var t = h["trade"]
		var from_c = GameManager.countries[t["from_id"]]["name"]
		var to_c = GameManager.countries[t["to_id"]]["name"]
		var status_str = "출항" if h["status"] == "accepted" else "거절"
		items.append("%s-%s(%s)" % [from_c, to_c, status_str])
	history_label.text = hist_text + " / ".join(items)

func _refresh_team_order():
	var cid = GameManager.current_player_country
	if GameManager.team_orders.has(cid) and GameManager.team_orders[cid] != "":
		team_order_lbl.text = "정보 분석가 지시: " + GameManager.team_orders[cid]
	else:
		team_order_lbl.text = "정보 분석가의 작전 지시를 기다리는 중입니다."

func _get_res_label(k: String) -> String:
	match k:
		"iron": return "철광석"
		"food": return "식량"
		"energy": return "에너지"
		"semiconductor": return "반도체"
		_: return ""
