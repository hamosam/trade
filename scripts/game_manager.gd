extends Node

signal country_data_changed(country_id)
signal all_data_changed
signal trade_proposed(trade_id, trade_data)
signal trade_resolved(trade_id, status, trade_data)
signal cargo_ship_spawned(from_id, to_id, trade_data)
signal cargo_ship_arrived(from_id, to_id, trade_data)
signal breaking_news_alert(news_data)
signal smartphone_assembled(country_id, count)
signal upgrade_leveled(country_id, upgrade_type, new_level)
signal role_changed(country_id, role_name)
signal timer_updated(time_left_sec)
signal game_ended(winner_country_id)
signal game_reset
signal pr_message_received(country_id, msg)
signal private_chat_received(from_id, to_id, msg)
signal team_order_received(country_id, order_text)
signal network_status_changed(status_text, is_connected)
signal room_code_ready(code)
signal roster_updated

const DEFAULT_RELAY_URL: String = "wss://broker.emqx.io:8084/mqtt"
const FALLBACK_BROKERS: Array = [
	"wss://broker.emqx.io:8084/mqtt",
	"wss://broker.hivemq.com:8884/mqtt",
	"wss://test.mosquitto.org:8081/mqtt"
]
const TOPIC_PREFIX: String = "hamo_trade_2026"
const TEACHER_PASSWORD: String = "1234"

# Mode: "solo_ai", "host", "client"
var play_mode: String = "solo_ai"
var is_game_started: bool = false

# Public MQTT-over-WebSocket Relay State (no private server needed!)
var mqtt := MqttWsClient.new()
var ws_url: String = DEFAULT_RELAY_URL
var room_code: String = ""
var my_peer_id: int = 0
var ws_connected: bool = false
var ws_connecting: bool = false
var client_joined: bool = false
var broker_try_idx: int = 0
var reconnect_timer: float = 0.0
var connect_timeout: float = 0.0
var host_keepalive_timer: float = 0.0
var host_has_started: bool = false

# Game loop variables
var game_time_left: float = 900.0 # 15 minutes
var is_game_running: bool = false
var production_timer: float = 0.0
var production_interval: float = 3.5
var production_tick_count: int = 0

# AI simulation timer (for solo_ai mode and optional empty countries in small classes)
var ai_trade_timer: float = 0.0
var ai_trade_interval: float = 8.0
var ai_fill_empty_countries: bool = false

# Connected students roster: str(peer_id) -> { "name": String, "country": String, "role": String }
var connected_players: Dictionary = {}

# Active modifiers from Breaking News
var active_event: Dictionary = {
	"title": "평화로운 무역 협정",
	"description": "바다가 잔잔합니다. 각 섬의 항구에서 활발한 무역이 이루어지고 있습니다.",
	"ship_speed_mult": 1.0,
	"tariff_fee": 0,
	"food_mult": 1.0,
	"semi_mult": 1.0,
	"energy_mult": 1.0,
	"iron_mult": 1.0,
	"phone_score_mult": 1.0
}

var trade_counter: int = 1
var pending_trades: Dictionary = {}
var trade_history: Array = []
var pr_feed: Array = []
var team_orders: Dictionary = {}

# Selected player profile
var current_player_country: String = "iron_kingdom"
var current_player_role: String = "overworld"
var student_assigned_role: String = ""
var student_name: String = "학생"
var lock_student_role: bool = false
var lock_country_switch: bool = false

# 6 Nations
var countries: Dictionary = {
	"iron_kingdom": {
		"id": "iron_kingdom", "name": "철강 왕국", "short": "철강",
		"color": Color("d94e41"),
		"iron": 25, "food": 2, "energy": 2, "semiconductor": 2, "gold": 120,
		"smartphones": 0, "score": 0,
		"special_trait": "철광석 풍부 (+35% 철 생산), 철 판매 시 20% 골드 우대",
		"building_sprite": "res://assets/sprites/building_iron.png",
		"char_sprite": "res://assets/sprites/characters/char_iron.png",
		"map_pos": Vector2(230, 195), "port_pos": Vector2(305, 245),
		"automation_lvl": 1, "logistics_lvl": 1, "tech_rnd_lvl": 1, "converts_left": 3, "era_lvl": 0
	},
	"agri_empire": {
		"id": "agri_empire", "name": "농업 대국", "short": "농업",
		"color": Color("3ca35c"),
		"iron": 2, "food": 25, "energy": 2, "semiconductor": 2, "gold": 120,
		"smartphones": 0, "score": 0,
		"special_trait": "식량 생산량 풍부 (+35% 식량 생산), 무역 협상 우선권",
		"building_sprite": "res://assets/sprites/building_agri.png",
		"char_sprite": "res://assets/sprites/characters/char_agri.png",
		"map_pos": Vector2(640, 155), "port_pos": Vector2(640, 225),
		"automation_lvl": 1, "logistics_lvl": 1, "tech_rnd_lvl": 1, "converts_left": 3, "era_lvl": 0
	},
	"tech_lab": {
		"id": "tech_lab", "name": "기술 연구소", "short": "기술",
		"color": Color("3b82c4"),
		"iron": 2, "food": 2, "energy": 2, "semiconductor": 22, "gold": 120,
		"smartphones": 0, "score": 0,
		"special_trait": "반도체 생산 및 스마트폰 조립 시 R&D 점수 1.5배 보너스",
		"building_sprite": "res://assets/sprites/building_tech.png",
		"char_sprite": "res://assets/sprites/characters/char_tech.png",
		"map_pos": Vector2(1050, 195), "port_pos": Vector2(975, 245),
		"automation_lvl": 1, "logistics_lvl": 1, "tech_rnd_lvl": 1, "converts_left": 3, "era_lvl": 0
	},
	"energy_base": {
		"id": "energy_base", "name": "에너지 기지", "short": "에너지",
		"color": Color("e09026"),
		"iron": 2, "food": 2, "energy": 25, "semiconductor": 2, "gold": 120,
		"smartphones": 0, "score": 0,
		"special_trait": "에너지 공급 (+35% 에너지 생산) 및 특별 자원 교환",
		"building_sprite": "res://assets/sprites/building_energy.png",
		"char_sprite": "res://assets/sprites/characters/char_energy.png",
		"map_pos": Vector2(230, 455), "port_pos": Vector2(305, 415),
		"automation_lvl": 1, "logistics_lvl": 1, "tech_rnd_lvl": 1, "converts_left": 3, "era_lvl": 0
	},
	"port_city": {
		"id": "port_city", "name": "항구 도시", "short": "항구",
		"color": Color("249ea0"),
		"iron": 4, "food": 4, "energy": 2, "semiconductor": 2, "gold": 140,
		"smartphones": 0, "score": 0,
		"special_trait": "해상 무역 속도 50% 단축, 해상 운송 관세 면제",
		"building_sprite": "res://assets/sprites/building_port.png",
		"char_sprite": "res://assets/sprites/characters/char_port.png",
		"map_pos": Vector2(640, 495), "port_pos": Vector2(640, 425),
		"automation_lvl": 1, "logistics_lvl": 2, "tech_rnd_lvl": 1, "converts_left": 3, "era_lvl": 0
	},
	"trade_union": {
		"id": "trade_union", "name": "무역 연합", "short": "연합",
		"color": Color("8e54a8"),
		"iron": 2, "food": 2, "energy": 4, "semiconductor": 3, "gold": 220,
		"smartphones": 0, "score": 0,
		"special_trait": "초기 자본금 220G 시작, 모든 거래 수수료 50% 영구 감면",
		"building_sprite": "res://assets/sprites/building_trade.png",
		"char_sprite": "res://assets/sprites/characters/char_trade.png",
		"map_pos": Vector2(1050, 455), "port_pos": Vector2(975, 415),
		"automation_lvl": 1, "logistics_lvl": 1, "tech_rnd_lvl": 1, "converts_left": 3, "era_lvl": 0
	}
}

var breaking_news_list: Array = [
	{
		"title": "글로벌 해상 물류 대란",
		"description": "주요 해협이 혼잡해져 모든 화물선의 운송 시간이 2배로 늘어납니다.",
		"ship_speed_mult": 0.5, "tariff_fee": 10, "food_mult": 1.0, "semi_mult": 1.0, "energy_mult": 1.0, "iron_mult": 1.0, "phone_score_mult": 1.0
	},
	{
		"title": "국제 무역 관세 인상",
		"description": "각국의 보호무역 강화로 무역 체결 시 25G의 관세가 추가 부과됩니다.",
		"ship_speed_mult": 1.0, "tariff_fee": 25, "food_mult": 1.0, "semi_mult": 1.0, "energy_mult": 1.0, "iron_mult": 1.0, "phone_score_mult": 1.0
	},
	{
		"title": "전 세계 농업 대풍년",
		"description": "맑은 날씨 덕분에 모든 국가의 식량 생산량이 2배로 증가합니다.",
		"ship_speed_mult": 1.0, "tariff_fee": 0, "food_mult": 2.0, "semi_mult": 1.0, "energy_mult": 1.0, "iron_mult": 1.0, "phone_score_mult": 1.0
	},
	{
		"title": "반도체 공급 부족 (쇼티지)",
		"description": "반도체 생산 속도가 절반으로 줄지만, 스마트폰 완제품 점수가 1.5배로 오릅니다!",
		"ship_speed_mult": 1.0, "tariff_fee": 0, "food_mult": 1.0, "semi_mult": 0.5, "energy_mult": 1.0, "iron_mult": 1.0, "phone_score_mult": 1.5
	},
	{
		"title": "신재생 에너지 기술 혁신",
		"description": "새로운 발전 기술이 보급되어 에너지 생산량이 2배 빨라집니다.",
		"ship_speed_mult": 1.0, "tariff_fee": 0, "food_mult": 1.0, "semi_mult": 1.0, "energy_mult": 2.0, "iron_mult": 1.0, "phone_score_mult": 1.0
	},
	{
		"title": "자원 섬 고대 유적 발견",
		"description": "섬 지하에서 보물 창고가 발견되어 모든 국가에 전 자원 +5개가 지급됩니다!",
		"ship_speed_mult": 1.2, "tariff_fee": 0, "food_mult": 1.2, "semi_mult": 1.2, "energy_mult": 1.2, "iron_mult": 1.2, "phone_score_mult": 1.2,
		"special_instant": "bonus_resources"
	}
]

var news_timer: float = 0.0
var next_news_interval: float = 95.0

func _ready():
	mqtt.mqtt_connected.connect(_on_mqtt_connected)
	mqtt.mqtt_disconnected.connect(_on_mqtt_disconnected)
	mqtt.mqtt_message.connect(_on_mqtt_message)
	if OS.has_feature("web"):
		# Prevent browser tab throttling sleep as much as possible
		JavaScriptBridge.eval("if(navigator.wakeLock){navigator.wakeLock.request('screen').catch(()=>{});}")

func _notification(what):
	# When returning from another browser tab (e.g. YouTube), immediately check & keep connection alive
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		if play_mode in ["host", "client"] and is_game_started:
			_send_heartbeat()

func _process(delta):
	# Poll WebSocket relay if in host or client mode
	if play_mode in ["host", "client"] and is_game_started:
		_poll_websocket(delta)

	if not is_game_running:
		return

	if play_mode == "client":
		return

	game_time_left -= delta
	if game_time_left <= 0:
		game_time_left = 0
		is_game_running = false
		_check_victory()
	timer_updated.emit(game_time_left)

	if play_mode == "host" and int(game_time_left) != int(game_time_left + delta):
		_relay_to_all({"cmd": "sync_timer", "t": game_time_left, "running": is_game_running})

	production_timer += delta
	if production_timer >= production_interval:
		production_timer = 0.0
		_tick_production()

	if play_mode == "solo_ai":
		news_timer += delta
		if news_timer >= next_news_interval:
			news_timer = 0.0
			trigger_random_breaking_news()

		ai_trade_timer += delta
		if ai_trade_timer >= ai_trade_interval:
			ai_trade_timer = 0.0
			_run_ai_trade_step()
	elif play_mode == "host" and ai_fill_empty_countries and not connected_players.is_empty():
		ai_trade_timer += delta
		if ai_trade_timer >= ai_trade_interval:
			ai_trade_timer = 0.0
			_run_empty_country_ai()

# ========================================================
# MQTT WEBSOCKET RELAY & ROOM CODE SYSTEM (Zero-Server!)
# ========================================================
func _exit_tree():
	mqtt.close()

func leave_current_session():
	mqtt.close()
	ws_connected = false
	ws_connecting = false
	client_joined = false
	is_game_running = false
	is_game_started = false
	room_code = ""
	lock_student_role = false
	lock_country_switch = false
	connected_players.clear()
	_reset_world_state()
	network_status_changed.emit("준비 중", false)

func start_solo_mode(country_id: String, role_name: String):
	mqtt.close()
	play_mode = "solo_ai"
	ai_fill_empty_countries = true
	ws_connected = false
	ws_connecting = false
	client_joined = false
	room_code = ""
	current_player_country = country_id
	current_player_role = role_name
	lock_student_role = false
	lock_country_switch = true
	is_game_started = true
	is_game_running = true
	role_changed.emit(country_id, role_name)
	network_status_changed.emit("혼자 체험 모드 (AI 경쟁국 가동)", true)

func start_teacher_host(relay_url: String = DEFAULT_RELAY_URL) -> bool:
	mqtt.close()
	ws_url = relay_url.strip_edges() if relay_url.strip_edges() != "" else DEFAULT_RELAY_URL
	play_mode = "host"
	ai_fill_empty_countries = false
	room_code = str(randi_range(1000, 9999))
	current_player_country = "iron_kingdom"
	current_player_role = "overworld"
	lock_student_role = false
	lock_country_switch = false
	is_game_started = true
	is_game_running = false
	connected_players.clear()
	ws_connected = false
	ws_connecting = true
	client_joined = false
	host_has_started = false
	broker_try_idx = 0
	connect_timeout = 0.0

	var err = mqtt.connect_broker(ws_url)
	if err != OK:
		ws_connecting = false
		network_status_changed.emit("연결 실패 (%s)" % ws_url, false)
		return false
	network_status_changed.emit("교실 방 [%s] 여는 중..." % room_code, false)
	return true

func join_classroom_by_code(relay_url: String, code: String, p_name: String, country_id: String, role_name: String) -> bool:
	var clean_code = code.strip_edges()
	if clean_code == "":
		network_status_changed.emit("방 코드를 입력해주세요.", false)
		return false
	mqtt.close()
	ws_url = relay_url.strip_edges() if relay_url.strip_edges() != "" else DEFAULT_RELAY_URL
	play_mode = "client"
	room_code = clean_code
	my_peer_id = randi_range(100000, 999999)
	student_name = p_name.strip_edges() if p_name.strip_edges() != "" else "학생"
	current_player_country = country_id
	student_assigned_role = role_name
	current_player_role = "overworld" if role_name == "all_roles" else role_name
	lock_student_role = true
	lock_country_switch = true
	is_game_started = true
	ws_connected = false
	ws_connecting = true
	client_joined = false
	host_has_started = false
	broker_try_idx = 0
	connect_timeout = 0.0

	var err = mqtt.connect_broker(ws_url)
	if err != OK:
		ws_connecting = false
		network_status_changed.emit("연결 실패 (%s)" % ws_url, false)
		return false
	network_status_changed.emit("방 [%s]에 입장 중..." % clean_code, false)
	return true

func _poll_websocket(delta: float):
	mqtt.poll(delta)

	if ws_connecting or (play_mode == "client" and ws_connected and not client_joined):
		connect_timeout += delta
		if connect_timeout >= 5.0:
			connect_timeout = 0.0
			if play_mode == "client" and ws_connected and not client_joined:
				mqtt.close()
				ws_connected = false
				ws_connecting = false
				network_status_changed.emit("방 코드 '%s'를 찾을 수 없습니다! 선생님이 방을 열었는지 확인하세요." % room_code, false)
			elif ws_connecting:
				mqtt.close()
				broker_try_idx += 1
				if ws_url == DEFAULT_RELAY_URL and broker_try_idx < FALLBACK_BROKERS.size():
					var next_url = FALLBACK_BROKERS[broker_try_idx]
					network_status_changed.emit("예비 중계 채널(%d)로 연결 시도 중..." % (broker_try_idx + 1), false)
					mqtt.connect_broker(next_url)
				else:
					ws_connecting = false
					network_status_changed.emit("네트워크 응답 시간 초과! 인터넷/방화벽을 확인하세요.", false)
			return

	if not ws_connected and not ws_connecting and room_code != "" and is_game_started:
		if play_mode == "host" or client_joined:
			reconnect_timer += delta
			if reconnect_timer >= 2.0:
				reconnect_timer = 0.0
				ws_connecting = true
				connect_timeout = 0.0
				mqtt.connect_broker(FALLBACK_BROKERS[min(broker_try_idx, FALLBACK_BROKERS.size() - 1)] if ws_url == DEFAULT_RELAY_URL else ws_url)

	if ws_connected and play_mode == "host":
		host_keepalive_timer += delta
		if host_keepalive_timer >= 12.0:
			host_keepalive_timer = 0.0
			_relay_to_all({"cmd": "keepalive"})

func _on_mqtt_connected():
	ws_connected = true
	ws_connecting = false
	connect_timeout = 0.0
	if play_mode == "host":
		mqtt.subscribe("%s/%s/to_host" % [TOPIC_PREFIX, room_code])
		if not host_has_started:
			host_has_started = true
			is_game_running = true
		room_code_ready.emit(room_code)
		role_changed.emit(current_player_country, current_player_role)
		network_status_changed.emit("방 코드: %s (접속 중: %d명)" % [room_code, connected_players.size()], true)
	elif play_mode == "client":
		mqtt.subscribe("%s/%s/to_clients" % [TOPIC_PREFIX, room_code])
		_relay_to_host({"cmd": "register_student", "name": student_name, "country": current_player_country, "role": current_player_role})

func _on_mqtt_disconnected():
	if ws_connected:
		ws_connected = false
		ws_connecting = false
		network_status_changed.emit("연결 끊김 — 자동 재연결 시도 중...", false)
	elif ws_connecting:
		ws_connecting = false
		network_status_changed.emit("네트워크에 연결할 수 없습니다.", false)

func _on_mqtt_message(_topic: String, msg_str: String):
	var parsed = JSON.parse_string(msg_str)
	if parsed is Dictionary:
		var from_pid = int(parsed.get("from", 0))
		var target = parsed.get("target", "all")
		if play_mode == "client" and target is int and target != my_peer_id:
			return
		var payload = parsed.get("payload", {})
		if payload is Dictionary:
			_handle_relay_payload(from_pid, payload)

func _send_heartbeat():
	if ws_connected:
		mqtt._send_ping()

func _relay_to_all(payload: Dictionary):
	if play_mode == "host" and ws_connected:
		mqtt.publish("%s/%s/to_clients" % [TOPIC_PREFIX, room_code], JSON.stringify({"from": 1, "target": "all", "payload": payload}))

func _relay_to_peer(peer_id: int, payload: Dictionary):
	if play_mode == "host" and ws_connected:
		mqtt.publish("%s/%s/to_clients" % [TOPIC_PREFIX, room_code], JSON.stringify({"from": 1, "target": peer_id, "payload": payload}))

func _relay_to_host(payload: Dictionary):
	if play_mode == "client" and ws_connected:
		mqtt.publish("%s/%s/to_host" % [TOPIC_PREFIX, room_code], JSON.stringify({"from": my_peer_id, "payload": payload}))

func _handle_relay_payload(from_pid: int, p: Dictionary):
	var cmd = p.get("cmd", "")
	if play_mode == "host":
		match cmd:
			"register_student":
				connected_players[str(from_pid)] = {
					"name": p.get("name", "학생"),
					"country": p.get("country", "iron_kingdom"),
					"role": p.get("role", "diplomat")
				}
				_relay_to_peer(from_pid, {
					"cmd": "full_sync",
					"countries": _serialize_countries(),
					"trades": _serialize_trades(),
					"event": active_event,
					"t": game_time_left,
					"running": is_game_running
				})
				_relay_to_all({"cmd": "sync_roster", "roster": connected_players})
				network_status_changed.emit("방 코드: %s (접속 중: %d명)" % [room_code, connected_players.size()], true)
				roster_updated.emit()
			"req_assemble":
				_do_assemble_smartphone(p.get("country_id", ""), bool(p.get("is_perfect", false)))
			"req_manual_gather":
				_do_manual_gather(p.get("country_id", ""))
			"req_convert_res":
				_do_convert_resource(p.get("country_id", ""), p.get("from_res", ""), p.get("to_res", ""))
			"send_team_order":
				var cid = p.get("country_id", "")
				var ord = p.get("order_text", "")
				_relay_to_all({"cmd": "team_order", "country_id": cid, "order_text": ord})
				_on_team_order_received(cid, ord)
			"req_upgrade":
				_do_buy_upgrade(p.get("country_id", ""), p.get("upgrade_type", ""))
			"req_upgrade_era":
				_do_upgrade_era(p.get("country_id", ""))
			"req_propose_trade":
				_do_propose_trade(
					p.get("from_id", ""), p.get("to_id", ""),
					p.get("offer_res", "none"), int(p.get("offer_qty", 0)),
					p.get("req_res", "none"), int(p.get("req_qty", 0)),
					int(p.get("offer_gold", 0)), int(p.get("req_gold", 0))
				)
			"req_accept_trade":
				_do_accept_trade(int(p.get("trade_id", 0)))
			"req_reject_trade":
				_do_reject_trade(int(p.get("trade_id", 0)))
			"send_pr":
				var cid = p.get("country_id", "")
				var txt = p.get("msg", "")
				_relay_to_all({"cmd": "pr_msg", "country_id": cid, "msg": txt})
				_on_pr_received(cid, txt)
			"send_private_chat":
				var fid = p.get("from_id", "")
				var tid = p.get("to_id", "")
				var txt = p.get("msg", "")
				_relay_to_all({"cmd": "private_chat", "from_id": fid, "to_id": tid, "msg": txt})
				_on_private_chat_received(fid, tid, txt)
	elif play_mode == "client":
		match cmd:
			"full_sync":
				_apply_serialized_countries(p.get("countries", {}))
				_apply_serialized_trades(p.get("trades", {}))
				active_event = p.get("event", active_event)
				game_time_left = float(p.get("t", 900.0))
				is_game_running = bool(p.get("running", true))
				if not client_joined:
					client_joined = true
					role_changed.emit(current_player_country, current_player_role)
					network_status_changed.emit("방 [%s] 연결 완료!" % room_code, true)
				all_data_changed.emit()
			"sync_timer":
				game_time_left = float(p.get("t", game_time_left))
				is_game_running = bool(p.get("running", is_game_running))
				timer_updated.emit(game_time_left)
			"sync_countries":
				_apply_serialized_countries(p.get("countries", {}))
				all_data_changed.emit()
			"sync_trades":
				_apply_serialized_trades(p.get("trades", {}))
				trade_resolved.emit(0, "sync", {})
			"sync_roster":
				connected_players = p.get("roster", {})
				roster_updated.emit()
			"spawn_ship":
				SoundManager.play_ship_horn()
				cargo_ship_spawned.emit(p.get("from_id", ""), p.get("to_id", ""), p.get("trade", {}))
			"notify_assemble":
				SoundManager.play_assemble()
				smartphone_assembled.emit(p.get("country_id", ""), int(p.get("count", 0)))
			"broadcast_news":
				active_event = p.get("news", active_event)
				SoundManager.play_news_alarm()
				breaking_news_alert.emit(active_event)
			"pr_msg":
				_on_pr_received(p.get("country_id", ""), p.get("msg", ""))
			"private_chat":
				_on_private_chat_received(p.get("from_id", ""), p.get("to_id", ""), p.get("msg", ""))
			"team_order":
				_on_team_order_received(p.get("country_id", ""), p.get("order_text", ""))

func _serialize_countries() -> Dictionary:
	var out = {}
	var fields = ["iron", "food", "energy", "semiconductor", "gold", "smartphones", "score", "automation_lvl", "logistics_lvl", "tech_rnd_lvl", "converts_left", "era_lvl"]
	for c_id in countries:
		var d = {}
		for f in fields:
			d[f] = countries[c_id][f]
		out[c_id] = d
	return out

func _apply_serialized_countries(data: Dictionary):
	for c_id in data:
		if countries.has(c_id) and data[c_id] is Dictionary:
			for f in data[c_id]:
				countries[c_id][f] = int(data[c_id][f])

func _serialize_trades() -> Dictionary:
	var pt = {}
	for k in pending_trades:
		pt[str(k)] = pending_trades[k]
	return {"pending": pt, "history": trade_history.slice(-10)}

func _apply_serialized_trades(data: Dictionary):
	pending_trades.clear()
	var pt = data.get("pending", {})
	for k in pt:
		pending_trades[int(k)] = pt[k]
	trade_history = data.get("history", [])

# ========================================================
# PRODUCTION & AI LIVING WORLD
# ========================================================
func _tick_production():
	for c_id in countries:
		var c = countries[c_id]
		var era_mult = 1.0 + c.get("era_lvl", 0) * 0.5 # 0: 1.0x, 1: 1.5x, 2: 2.0x
		var auto_bonus = (1.0 + (c["automation_lvl"] - 1) * 0.25) * era_mult
		c["gold"] += int(2 * auto_bonus)

		# 비교우위 & 무역 필수 구조: 각 국가는 2종류만 생산하고 나머지 2종류는 0(무역으로 조달!)
		var iron_base = 0
		var food_base = 0
		var energy_base = 0
		var semi_base = 0

		match c_id:
			"iron_kingdom":
				iron_base = 3 + c["automation_lvl"]
				energy_base = 1
			"agri_empire":
				food_base = 3 + c["automation_lvl"]
				iron_base = 1
			"tech_lab":
				semi_base = 2 + c["automation_lvl"]
				food_base = 1
			"energy_base":
				energy_base = 3 + c["automation_lvl"]
				semi_base = 1
			"port_city":
				iron_base = 1; food_base = 1
				c["gold"] += int(round(2 * era_mult))
			"trade_union":
				energy_base = 1; semi_base = 1
				c["gold"] += int(round(3 * era_mult))

		if iron_base > 0:
			c["iron"] += int(round(iron_base * auto_bonus * active_event["iron_mult"]))
		if food_base > 0:
			c["food"] += int(round(food_base * auto_bonus * active_event["food_mult"]))
		if energy_base > 0:
			c["energy"] += int(round(energy_base * auto_bonus * active_event["energy_mult"]))
		if semi_base > 0:
			c["semiconductor"] += max(0, int(round(semi_base * auto_bonus * active_event["semi_mult"])))

		country_data_changed.emit(c_id)

	if play_mode == "host":
		_relay_to_all({"cmd": "sync_countries", "countries": _serialize_countries()})

func _run_ai_trade_step():
	var keys = countries.keys()
	var ai_keys = []
	for k in keys:
		if k != current_player_country:
			ai_keys.append(k)

	# 1. AI countries evaluate and accept fair trade proposals sent BY the player!
	for tid in pending_trades.keys():
		var t = pending_trades[tid]
		if t["from_id"] == current_player_country and t["to_id"] in ai_keys:
			if t["offer_res"] != "none" or t["offer_gold"] > 0:
				_do_accept_trade(tid)

	# 2. AI sends varied trade proposals (2~8 units or gold) to the player
	if randf() < 0.35 and pending_trades.size() < 4:
		var from_ai = ai_keys[randi() % ai_keys.size()]
		var offer_res = _get_specialty_res(from_ai)
		var req_res = _get_specialty_res(current_player_country)
		var avail = countries[from_ai][offer_res]
		if offer_res != req_res and avail >= 4:
			var qty = [2, 3, 4, 5, 6, 8][randi() % 6]
			qty = min(qty, max(2, avail / 2))
			if randf() < 0.25 and countries[from_ai]["gold"] >= 60:
				# Occasionally offer Gold instead of resources
				propose_trade(from_ai, current_player_country, "none", 0, req_res, qty, qty * 18, 0)
			else:
				propose_trade(from_ai, current_player_country, offer_res, qty, req_res, qty, 0, 0)
			return

	var a = ai_keys[randi() % ai_keys.size()]
	var b = ai_keys[randi() % ai_keys.size()]
	if a == b:
		return
	var res_a = _get_specialty_res(a)
	var res_b = _get_specialty_res(b)
	if countries[a][res_a] >= 3 and countries[b][res_b] >= 3:
		var q = [2, 3, 4, 5][randi() % 4]
		if countries[a][res_a] >= q and countries[b][res_b] >= q:
			var tid = propose_trade(a, b, res_a, q, res_b, q, 0, 0)
			if tid > 0:
				accept_trade(tid)

	for ai_id in ai_keys:
		if can_assemble_smartphone(ai_id):
			assemble_smartphone(ai_id)

func _run_empty_country_ai():
	var occupied = {}
	for pid in connected_players:
		var cid = connected_players[pid].get("country", "")
		if cid != "":
			occupied[cid] = true

	var empty_keys = []
	for k in countries:
		if not occupied.has(k):
			empty_keys.append(k)

	if empty_keys.is_empty():
		return

	# Empty AI countries automatically accept valid trade proposals sent to them by students!
	for tid in pending_trades.keys():
		var t = pending_trades[tid]
		if t["to_id"] in empty_keys:
			_do_accept_trade(tid)

	# Empty AI countries also trade & assemble so the world stays alive
	if empty_keys.size() >= 2:
		var a = empty_keys[randi() % empty_keys.size()]
		var b = empty_keys[randi() % empty_keys.size()]
		if a != b:
			var ra = _get_specialty_res(a)
			var rb = _get_specialty_res(b)
			if countries[a][ra] >= 3 and countries[b][rb] >= 3:
				var tid = _do_propose_trade(a, b, ra, 3, rb, 3, 0, 0)
				if tid > 0:
					_do_accept_trade(tid)

	for eid in empty_keys:
		if can_assemble_smartphone(eid):
			_do_assemble_smartphone(eid)

func _get_specialty_res(c_id: String) -> String:
	match c_id:
		"iron_kingdom": return "iron"
		"agri_empire": return "food"
		"tech_lab": return "semiconductor"
		"energy_base": return "energy"
		_: return ["iron", "food", "energy", "semiconductor"][randi() % 4]

func set_role(country_id: String, role_name: String):
	current_player_country = country_id
	current_player_role = role_name
	role_changed.emit(country_id, role_name)

# ========================================================
# SMARTPHONE ASSEMBLY
# ========================================================
func can_assemble_smartphone(country_id: String) -> bool:
	if not countries.has(country_id):
		return false
	var c = countries[country_id]
	return c["iron"] >= 1 and c["food"] >= 1 and c["energy"] >= 1 and c["semiconductor"] >= 1

func assemble_smartphone(country_id: String, is_perfect: bool = false) -> bool:
	if play_mode == "client":
		_relay_to_host({"cmd": "req_assemble", "country_id": country_id, "is_perfect": is_perfect})
		return true
	return _do_assemble_smartphone(country_id, is_perfect)

func _do_assemble_smartphone(country_id: String, is_perfect: bool = false) -> bool:
	if not can_assemble_smartphone(country_id):
		return false
	var c = countries[country_id]
	c["iron"] -= 1
	c["food"] -= 1
	c["energy"] -= 1
	c["semiconductor"] -= 1
	c["smartphones"] += 1

	var base_score = 100
	var rnd_bonus = 1.0 + (c["tech_rnd_lvl"] - 1) * 0.35
	if country_id == "tech_lab":
		rnd_bonus *= 1.5
	if c.get("era_lvl", 0) >= 2:
		rnd_bonus *= 1.5
	var final_score = int(base_score * rnd_bonus * active_event["phone_score_mult"])
	if is_perfect:
		final_score += 50
		c["gold"] += 80
	else:
		c["gold"] += 50
	c["score"] += final_score

	SoundManager.play_assemble()
	smartphone_assembled.emit(country_id, c["smartphones"])
	country_data_changed.emit(country_id)
	if play_mode == "host":
		_relay_to_all({"cmd": "sync_countries", "countries": _serialize_countries()})
		_relay_to_all({"cmd": "notify_assemble", "country_id": country_id, "count": c["smartphones"]})
	return true

func manual_gather(country_id: String) -> String:
	var res_key = _get_specialty_res(country_id)
	if play_mode == "client":
		_relay_to_host({"cmd": "req_manual_gather", "country_id": country_id})
		return res_key
	return _do_manual_gather(country_id)

func _do_manual_gather(country_id: String) -> String:
	if not countries.has(country_id):
		return ""
	var res_key = _get_specialty_res(country_id)
	countries[country_id][res_key] += 2
	SoundManager.play_coin()
	country_data_changed.emit(country_id)
	if play_mode == "host":
		_relay_to_all({"cmd": "sync_countries", "countries": _serialize_countries()})
	return res_key

func convert_resource(country_id: String, from_res: String, to_res: String) -> bool:
	if from_res == to_res or from_res == "" or to_res == "":
		return false
	if play_mode == "client":
		_relay_to_host({"cmd": "req_convert_res", "country_id": country_id, "from_res": from_res, "to_res": to_res})
		return true
	return _do_convert_resource(country_id, from_res, to_res)

func _do_convert_resource(country_id: String, from_res: String, to_res: String) -> bool:
	if not countries.has(country_id) or from_res == to_res:
		return false
	var c = countries[country_id]
	if c.get("converts_left", 0) <= 0:
		return false
	var req_amt = 3 if country_id == "energy_base" else 4
	if c.get(from_res, 0) < req_amt:
		return false
	c[from_res] -= req_amt
	c[to_res] += 1
	c["converts_left"] -= 1
	SoundManager.play_coin()
	country_data_changed.emit(country_id)
	if play_mode == "host":
		_relay_to_all({"cmd": "sync_countries", "countries": _serialize_countries()})
	return true

func send_team_order(country_id: String, order_text: String):
	if play_mode == "client":
		_relay_to_host({"cmd": "send_team_order", "country_id": country_id, "order_text": order_text})
	elif play_mode == "host":
		_relay_to_all({"cmd": "team_order", "country_id": country_id, "order_text": order_text})
		_on_team_order_received(country_id, order_text)
	else:
		_on_team_order_received(country_id, order_text)

func _on_team_order_received(country_id: String, order_text: String):
	team_orders[country_id] = order_text
	team_order_received.emit(country_id, order_text)

# ========================================================
# UPGRADES
# ========================================================
func get_upgrade_cost(country_id: String, upgrade_type: String) -> int:
	return countries[country_id][upgrade_type + "_lvl"] * 120

func buy_upgrade(country_id: String, upgrade_type: String) -> bool:
	if play_mode == "client":
		_relay_to_host({"cmd": "req_upgrade", "country_id": country_id, "upgrade_type": upgrade_type})
		return true
	return _do_buy_upgrade(country_id, upgrade_type)

func _do_buy_upgrade(country_id: String, upgrade_type: String) -> bool:
	var c = countries[country_id]
	var current_lvl = c[upgrade_type + "_lvl"]
	if current_lvl >= 5:
		return false
	var cost = get_upgrade_cost(country_id, upgrade_type)
	if c["gold"] < cost:
		return false
	c["gold"] -= cost
	c[upgrade_type + "_lvl"] += 1
	SoundManager.play_coin()
	upgrade_leveled.emit(country_id, upgrade_type, c[upgrade_type + "_lvl"])
	country_data_changed.emit(country_id)
	if play_mode == "host":
		_relay_to_all({"cmd": "sync_countries", "countries": _serialize_countries()})
	return true

func get_era_name(era_lvl: int) -> String:
	match era_lvl:
		1: return "산업 국가"
		2: return "미래 국가"
		_: return "자원 국가"

func get_era_upgrade_cost(country_id: String) -> int:
	var lvl = countries[country_id].get("era_lvl", 0)
	if lvl == 0:
		return 1000
	elif lvl == 1:
		return 2000
	return 0

func upgrade_era(country_id: String) -> bool:
	if play_mode == "client":
		_relay_to_host({"cmd": "req_upgrade_era", "country_id": country_id})
		return true
	return _do_upgrade_era(country_id)

func _do_upgrade_era(country_id: String) -> bool:
	if not countries.has(country_id):
		return false
	var c = countries[country_id]
	var lvl = c.get("era_lvl", 0)
	if lvl >= 2:
		return false
	var cost = get_era_upgrade_cost(country_id)
	if c["gold"] < cost:
		return false
	c["gold"] -= cost
	c["era_lvl"] = lvl + 1
	SoundManager.play_assemble()
	upgrade_leveled.emit(country_id, "era", c["era_lvl"])
	country_data_changed.emit(country_id)
	if play_mode == "host":
		_relay_to_all({"cmd": "sync_countries", "countries": _serialize_countries()})
	return true

# ========================================================
# TRADE NEGOTIATION
# ========================================================
func has_pending_trade_between(from_id: String, to_id: String) -> bool:
	for tid in pending_trades:
		var t = pending_trades[tid]
		if t["from_id"] == from_id and t["to_id"] == to_id:
			return true
	return false

func propose_trade(from_id: String, to_id: String, offer_res: String, offer_qty: int, request_res: String, request_qty: int, offer_gold: int, request_gold: int) -> int:
	if (offer_res == "none" and offer_gold <= 0) or (request_res == "none" and request_gold <= 0):
		return -3
	if has_pending_trade_between(from_id, to_id):
		return -2
	if play_mode == "client":
		_relay_to_host({
			"cmd": "req_propose_trade", "from_id": from_id, "to_id": to_id,
			"offer_res": offer_res, "offer_qty": offer_qty,
			"req_res": request_res, "req_qty": request_qty,
			"offer_gold": offer_gold, "req_gold": request_gold
		})
		return 1
	return _do_propose_trade(from_id, to_id, offer_res, offer_qty, request_res, request_qty, offer_gold, request_gold)

func _do_propose_trade(from_id: String, to_id: String, offer_res: String, offer_qty: int, request_res: String, request_qty: int, offer_gold: int, request_gold: int) -> int:
	if (offer_res == "none" and offer_gold <= 0) or (request_res == "none" and request_gold <= 0):
		return -3
	if has_pending_trade_between(from_id, to_id):
		return -2
	var from_c = countries[from_id]
	if offer_res != "none" and from_c[offer_res] < offer_qty:
		return -1
	if from_c["gold"] < offer_gold:
		return -1

	var trade_id = trade_counter
	trade_counter += 1
	var trade_data = {
		"id": trade_id, "from_id": from_id, "to_id": to_id,
		"offer_res": offer_res, "offer_qty": offer_qty,
		"request_res": request_res, "request_qty": request_qty,
		"offer_gold": offer_gold, "request_gold": request_gold,
		"timestamp": Time.get_time_string_from_system()
	}
	pending_trades[trade_id] = trade_data
	if play_mode == "host":
		_relay_to_all({"cmd": "sync_trades", "trades": _serialize_trades()})
	trade_proposed.emit(trade_id, trade_data)
	return trade_id

func accept_trade(trade_id: int) -> bool:
	if play_mode == "client":
		_relay_to_host({"cmd": "req_accept_trade", "trade_id": trade_id})
		return true
	return _do_accept_trade(trade_id)

func _do_accept_trade(trade_id: int) -> bool:
	if not pending_trades.has(trade_id):
		return false
	var trade = pending_trades[trade_id]
	var from_id = trade["from_id"]
	var to_id = trade["to_id"]
	var from_c = countries[from_id]
	var to_c = countries[to_id]

	if trade["offer_res"] != "none" and from_c[trade["offer_res"]] < trade["offer_qty"]:
		return false
	if from_c["gold"] < trade["offer_gold"]:
		return false
	if trade["request_res"] != "none" and to_c[trade["request_res"]] < trade["request_qty"]:
		return false
	if to_c["gold"] < trade["request_gold"]:
		return false

	if trade["offer_res"] != "none":
		from_c[trade["offer_res"]] -= trade["offer_qty"]
	from_c["gold"] -= trade["offer_gold"]

	if trade["request_res"] != "none":
		to_c[trade["request_res"]] -= trade["request_qty"]
	to_c["gold"] -= trade["request_gold"]

	var tariff = active_event["tariff_fee"]
	if from_id == "trade_union" or to_id == "trade_union":
		tariff = int(tariff * 0.5)
	if from_id == "port_city" or to_id == "port_city":
		tariff = 0
	if tariff > 0:
		from_c["gold"] = max(0, from_c["gold"] - tariff)
		to_c["gold"] = max(0, to_c["gold"] - tariff)

	pending_trades.erase(trade_id)
	trade_history.append({"trade": trade, "status": "accepted"})

	SoundManager.play_ship_horn()
	trade_resolved.emit(trade_id, "accepted", trade)
	cargo_ship_spawned.emit(from_id, to_id, trade)
	country_data_changed.emit(from_id)
	country_data_changed.emit(to_id)

	if play_mode == "host":
		_relay_to_all({"cmd": "sync_countries", "countries": _serialize_countries()})
		_relay_to_all({"cmd": "sync_trades", "trades": _serialize_trades()})
		_relay_to_all({"cmd": "spawn_ship", "from_id": from_id, "to_id": to_id, "trade": trade})
	return true

func reject_trade(trade_id: int):
	if play_mode == "client":
		_relay_to_host({"cmd": "req_reject_trade", "trade_id": trade_id})
		return
	_do_reject_trade(trade_id)

func _do_reject_trade(trade_id: int):
	if pending_trades.has(trade_id):
		var trade = pending_trades[trade_id]
		pending_trades.erase(trade_id)
		trade_history.append({"trade": trade, "status": "rejected"})
		if play_mode == "host":
			_relay_to_all({"cmd": "sync_trades", "trades": _serialize_trades()})
		trade_resolved.emit(trade_id, "rejected", trade)

func complete_cargo_delivery(from_id: String, to_id: String, trade: Dictionary):
	if play_mode == "client":
		cargo_ship_arrived.emit(from_id, to_id, trade)
		return

	var from_c = countries[from_id]
	var to_c = countries[to_id]
	if trade["offer_res"] != "none":
		to_c[trade["offer_res"]] += int(trade["offer_qty"])
	var offer_g = int(trade["offer_gold"])
	if to_id == "iron_kingdom" and trade["request_res"] == "iron" and offer_g > 0:
		offer_g += int(ceil(offer_g * 0.2)) # 철강 왕국 철 판매 20% 골드 우대
	to_c["gold"] += offer_g

	if trade["request_res"] != "none":
		from_c[trade["request_res"]] += int(trade["request_qty"])
	var req_g = int(trade["request_gold"])
	if from_id == "iron_kingdom" and trade["offer_res"] == "iron" and req_g > 0:
		req_g += int(ceil(req_g * 0.2)) # 철강 왕국 철 판매 20% 골드 우대
	from_c["gold"] += req_g

	# 농업 대국 무역 협상 우선권 보너스 (+15G)
	if from_id == "agri_empire":
		from_c["gold"] += 15
	if to_id == "agri_empire":
		to_c["gold"] += 15

	SoundManager.play_coin()
	cargo_ship_arrived.emit(from_id, to_id, trade)
	country_data_changed.emit(from_id)
	country_data_changed.emit(to_id)
	if play_mode == "host":
		_relay_to_all({"cmd": "sync_countries", "countries": _serialize_countries()})

# ========================================================
# PR & BREAKING NEWS
# ========================================================
func send_pr_message(country_id: String, msg: String):
	if play_mode == "client":
		_relay_to_host({"cmd": "send_pr", "country_id": country_id, "msg": msg})
	elif play_mode == "host":
		_relay_to_all({"cmd": "pr_msg", "country_id": country_id, "msg": msg})
		_on_pr_received(country_id, msg)
	else:
		_on_pr_received(country_id, msg)

func _on_pr_received(country_id: String, msg: String):
	pr_feed.push_front({"country_id": country_id, "msg": msg})
	if pr_feed.size() > 25:
		pr_feed.pop_back()
	pr_message_received.emit(country_id, msg)

func send_private_chat(from_id: String, to_id: String, msg: String):
	if play_mode == "client":
		_relay_to_host({"cmd": "send_private_chat", "from_id": from_id, "to_id": to_id, "msg": msg})
	elif play_mode == "host":
		_relay_to_all({"cmd": "private_chat", "from_id": from_id, "to_id": to_id, "msg": msg})
		_on_private_chat_received(from_id, to_id, msg)
	else:
		_on_private_chat_received(from_id, to_id, msg)

func _on_private_chat_received(from_id: String, to_id: String, msg: String):
	private_chat_received.emit(from_id, to_id, msg)

func broadcast_breaking_news(news_data: Dictionary):
	if play_mode == "client":
		return
	active_event = news_data
	if news_data.has("special_instant") and news_data["special_instant"] == "bonus_resources":
		for c_id in countries:
			var c = countries[c_id]
			c["iron"] += 5; c["food"] += 5; c["energy"] += 5; c["semiconductor"] += 3; c["gold"] += 50
			country_data_changed.emit(c_id)
	SoundManager.play_news_alarm()
	breaking_news_alert.emit(news_data)
	if play_mode == "host":
		_relay_to_all({"cmd": "sync_countries", "countries": _serialize_countries()})
		_relay_to_all({"cmd": "broadcast_news", "news": news_data})

func trigger_random_breaking_news():
	var idx = randi() % breaking_news_list.size()
	broadcast_breaking_news(breaking_news_list[idx])

func _reset_world_state():
	game_time_left = 900.0
	pending_trades.clear()
	trade_history.clear()
	team_orders.clear()
	pr_feed.clear()
	active_event = {
		"title": "평화로운 무역 협정",
		"description": "바다가 잔잔합니다. 각 섬의 항구에서 활발한 무역이 이루어지고 있습니다.",
		"ship_speed_mult": 1.0, "tariff_fee": 0,
		"food_mult": 1.0, "semi_mult": 1.0, "energy_mult": 1.0, "iron_mult": 1.0, "phone_score_mult": 1.0
	}
	for c_id in countries:
		var c = countries[c_id]
		c["smartphones"] = 0
		c["score"] = 0
		c["automation_lvl"] = 1
		c["logistics_lvl"] = 2 if c_id == "port_city" else 1
		c["tech_rnd_lvl"] = 1
		c["converts_left"] = 3
		c["era_lvl"] = 0
		match c_id:
			"iron_kingdom": c["iron"] = 25; c["food"] = 2; c["energy"] = 2; c["semiconductor"] = 2; c["gold"] = 120
			"agri_empire": c["iron"] = 2; c["food"] = 25; c["energy"] = 2; c["semiconductor"] = 2; c["gold"] = 120
			"tech_lab": c["iron"] = 2; c["food"] = 2; c["energy"] = 2; c["semiconductor"] = 22; c["gold"] = 120
			"energy_base": c["iron"] = 2; c["food"] = 2; c["energy"] = 25; c["semiconductor"] = 2; c["gold"] = 120
			"port_city": c["iron"] = 4; c["food"] = 4; c["energy"] = 2; c["semiconductor"] = 2; c["gold"] = 140
			"trade_union": c["iron"] = 2; c["food"] = 2; c["energy"] = 4; c["semiconductor"] = 3; c["gold"] = 220
		country_data_changed.emit(c_id)
	game_reset.emit()
	all_data_changed.emit()

func admin_reset_game():
	is_game_running = true
	_reset_world_state()
	if play_mode == "host":
		_relay_to_all({"cmd": "sync_countries", "countries": _serialize_countries()})
		_relay_to_all({"cmd": "sync_trades", "trades": _serialize_trades()})

func get_total_score(c_id: String) -> int:
	var c = countries[c_id]
	return c["smartphones"] * 500 + c["score"] + c["gold"]

func _check_victory():
	var highest_score = -1
	var winner = "iron_kingdom"
	for c_id in countries:
		var total_score = get_total_score(c_id)
		if total_score > highest_score:
			highest_score = total_score
			winner = c_id
	game_ended.emit(winner)
