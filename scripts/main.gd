extends Control

@onready var timer_label = $TopBar/HBox/TimerLabel
@onready var country_option = $TopBar/HBox/CountryOption
@onready var home_btn = $TopBar/HBox/HomeBtn
@onready var net_status_label = $TopBar/HBox/NetStatusLabel
@onready var tab_container = $TabButtonsContainer
@onready var views_container = $MainViews

# View panels
@onready var view_map = $MainViews/WorldMap
@onready var view_diplomat = $MainViews/DiplomatView
@onready var view_treasurer = $MainViews/TreasurerView
@onready var view_technician = $MainViews/TechnicianView
@onready var view_analyst = $MainViews/AnalystView
@onready var view_spokesperson = $MainViews/SpokespersonView
@onready var view_teacher = $MainViews/TeacherView

# Character Portrait Guide Strip
@onready var guide_strip = $GuideStrip
@onready var guide_portrait = $GuideStrip/HBox/PortraitTex
@onready var guide_name = $GuideStrip/HBox/VBox/RoleName
@onready var guide_speech = $GuideStrip/HBox/VBox/SpeechText

# News Banner
@onready var news_banner = $NewsBannerOverlay
@onready var news_title = $NewsBannerOverlay/Panel/VBox/Title
@onready var news_desc = $NewsBannerOverlay/Panel/VBox/Desc
@onready var news_close_btn = $NewsBannerOverlay/Panel/VBox/CloseBtn

# Victory Modal
@onready var victory_modal = $VictoryModal
@onready var victory_text = $VictoryModal/Panel/VBox/WinnerText
@onready var victory_restart_btn = $VictoryModal/Panel/VBox/RestartBtn

# Island Info Modal (Read-only country trait & status viewer)
@onready var island_modal = $IslandInfoModal
@onready var island_title = $IslandInfoModal/Panel/VBox/TopRow/Title
@onready var island_icon = $IslandInfoModal/Panel/VBox/TopRow/BuildingTex
@onready var island_trait = $IslandInfoModal/Panel/VBox/TraitBox/TraitText
@onready var island_prod = $IslandInfoModal/Panel/VBox/ProdText
@onready var island_stats = $IslandInfoModal/Panel/VBox/StatsText
@onready var island_close_btn = $IslandInfoModal/Panel/VBox/CloseBtn

# Touch Numpad Modal (for tablets / mobile)
@onready var numpad_modal = $NumpadModal
@onready var numpad_title = $NumpadModal/Panel/VBox/Title
@onready var numpad_display = $NumpadModal/Panel/VBox/DisplayLbl
@onready var numpad_grid = $NumpadModal/Panel/VBox/Grid

var numpad_target: LineEdit = null
var numpad_value: String = ""
var numpad_secret: bool = false

# Title Screen Overlay
@onready var title_overlay = $TitleOverlay
@onready var title_resume_btn = $TitleOverlay/Panel/VBox/BtnRow/ResumeBtn
@onready var title_start_btn = $TitleOverlay/Panel/VBox/BtnRow/StartBtn
@onready var title_howto_btn = $TitleOverlay/Panel/VBox/BtnRow/HowToBtn
@onready var title_quit_btn = $TitleOverlay/Panel/VBox/BtnRow/QuitBtn
@onready var title_howto_box = $TitleOverlay/Panel/VBox/HowToBox

# Lobby Overlay
@onready var lobby_modal = $LobbyOverlay
@onready var lobby_back_btn = $LobbyOverlay/Panel/VBox/BackBtn
@onready var lobby_name_input = $LobbyOverlay/Panel/VBox/StudentSection/NameRow/NameInput
@onready var lobby_name_web_btn = $LobbyOverlay/Panel/VBox/StudentSection/NameRow/WebNameBtn
@onready var lobby_code_input = $LobbyOverlay/Panel/VBox/StudentSection/CodeRow/CodeInput
@onready var lobby_code_pad_btn = $LobbyOverlay/Panel/VBox/StudentSection/CodeRow/CodePadBtn
@onready var lobby_relay_row = $LobbyOverlay/Panel/VBox/RelayRow
@onready var lobby_relay_input = $LobbyOverlay/Panel/VBox/RelayRow/RelayInput
@onready var lobby_server_toggle = $LobbyOverlay/Panel/VBox/TeacherSection/ServerToggleBtn
@onready var lobby_country_opt = $LobbyOverlay/Panel/VBox/StudentSection/SelectRow/CountryOpt
@onready var lobby_role_opt = $LobbyOverlay/Panel/VBox/StudentSection/SelectRow/RoleOpt
@onready var lobby_join_btn = $LobbyOverlay/Panel/VBox/StudentSection/JoinBtn
@onready var lobby_host_btn = $LobbyOverlay/Panel/VBox/TeacherSection/HostBtn
@onready var lobby_solo_btn = $LobbyOverlay/Panel/VBox/SoloBtn
@onready var lobby_msg_lbl = $LobbyOverlay/Panel/VBox/StatusMsg

var news_banner_timer: float = 0.0
var portraits: Dictionary = {}
var default_wood_panel: StyleBox = null
var default_wood_bar: StyleBox = null
var current_applied_era: int = -1

var role_guides: Dictionary = {
	"overworld": {
		"title": "세계 지도",
		"portrait": "res://assets/sprites/portraits/portrait_analyst.png",
		"speech": "섬을 클릭해 국가를 선택하거나, 바다 위를 오가는 무역선들을 살펴보세요!"
	},
	"diplomat": {
		"title": "외교부 장관 (대외 협상가)",
		"portrait": "res://assets/sprites/portraits/portrait_diplomat.png",
		"speech": "우리 나라에 남는 자원을 보내고, 스마트폰 조립에 필요한 부품을 요청해 보세요."
	},
	"treasurer": {
		"title": "재무·자원부 장관 (자원 관리자)",
		"portrait": "res://assets/sprites/portraits/portrait_treasurer.png",
		"speech": "모은 골드로 생산 자동화와 물류 인프라에 투자하면 훨씬 빨리 성장할 수 있어요."
	},
	"technician": {
		"title": "기술·제조부 장관 (생산 총괄)",
		"portrait": "res://assets/sprites/portraits/portrait_technician.png",
		"speech": "철광석, 식량, 에너지, 반도체가 1개씩 모이면 제 버튼으로 스마트폰을 조립할 수 있습니다!"
	},
	"analyst": {
		"title": "경제기획원 (정보 분석가)",
		"portrait": "res://assets/sprites/portraits/portrait_analyst.png",
		"speech": "다른 나라의 자원 현황을 분석해서 어느 나라와 무역하는 게 유리할지 팀원에게 알려주세요."
	},
	"spokesperson": {
		"title": "홍보대사 (국가 대변인)",
		"portrait": "res://assets/sprites/portraits/portrait_spokesperson.png",
		"speech": "돌발 뉴스를 빠르게 파악하고, 전 세계에 우리 국가의 홍보 메시지를 전파하세요!"
	},
	"teacher": {
		"title": "교사 제어판",
		"portrait": "res://assets/sprites/portraits/portrait_teacher.png",
		"speech": "학생들이 무역에 익숙해지면 돌발 경제 뉴스를 방송해 시장의 변화를 체험하게 해주세요."
	}
}

func _ready():
	_load_portraits()
	_setup_country_selector()
	_setup_role_buttons()
	_setup_lobby()

	GameManager.timer_updated.connect(_on_timer_updated)
	GameManager.breaking_news_alert.connect(_on_breaking_news)
	GameManager.game_ended.connect(_on_game_ended)
	GameManager.role_changed.connect(_on_role_changed)
	GameManager.country_data_changed.connect(func(cid):
		if cid == GameManager.current_player_country:
			_apply_era_ui_theme()
	)
	GameManager.all_data_changed.connect(_apply_era_ui_theme)
	GameManager.trade_proposed.connect(func(_id, _d): _update_trade_badge())
	GameManager.trade_resolved.connect(func(_id, _s, _d): _update_trade_badge())
	GameManager.network_status_changed.connect(func(txt, ok):
		net_status_label.text = txt
		lobby_msg_lbl.text = txt
		if ok and GameManager.play_mode == "client":
			lobby_modal.visible = false
	)
	GameManager.room_code_ready.connect(func(_code):
		lobby_modal.visible = false
	)

	news_close_btn.pressed.connect(func():
		SoundManager.play_click()
		news_banner.visible = false
	)

	victory_restart_btn.pressed.connect(func():
		SoundManager.play_click()
		victory_modal.visible = false
		GameManager.admin_reset_game()
	)

	view_map.island_clicked.connect(_on_island_clicked)
	island_close_btn.pressed.connect(func():
		SoundManager.play_click()
		island_modal.visible = false
	)

	_setup_title_screen()

	news_banner.visible = false
	victory_modal.visible = false
	island_modal.visible = false
	numpad_modal.visible = false
	lobby_modal.visible = false
	title_overlay.visible = true
	_setup_numpad()
	home_btn.pressed.connect(_on_return_to_title)
	default_wood_panel = guide_strip.get_theme_stylebox("panel")
	default_wood_bar = $TopBar.get_theme_stylebox("panel")
	_switch_view("overworld")
	_apply_era_ui_theme()

func _load_portraits():
	for r in role_guides:
		portraits[r] = load(role_guides[r]["portrait"])

func _process(delta):
	if news_banner.visible:
		news_banner_timer -= delta
		if news_banner_timer <= 0:
			news_banner.visible = false

func _setup_title_screen():
	title_howto_box.visible = false
	title_resume_btn.visible = false
	if OS.has_feature("web"):
		title_quit_btn.visible = false

	title_resume_btn.pressed.connect(func():
		SoundManager.play_click()
		title_overlay.visible = false
	)
	title_start_btn.pressed.connect(func():
		SoundManager.play_click()
		if GameManager.is_game_started:
			GameManager.leave_current_session()
		title_overlay.visible = false
		lobby_modal.visible = true
	)
	title_howto_btn.pressed.connect(func():
		SoundManager.play_click()
		title_howto_box.visible = not title_howto_box.visible
	)
	title_quit_btn.pressed.connect(func():
		SoundManager.play_click()
		get_tree().quit()
	)

func _on_return_to_title():
	SoundManager.play_click()
	# Keep room & relay connection alive! Just show TitleOverlay with Resume button.
	news_banner.visible = false
	victory_modal.visible = false
	island_modal.visible = false
	lobby_modal.visible = false
	if GameManager.is_game_started:
		title_resume_btn.visible = true
		if GameManager.room_code != "":
			title_resume_btn.text = "방으로 돌아가기 (%s)" % GameManager.room_code
		else:
			title_resume_btn.text = "진행 중인 게임으로 돌아가기"
		title_start_btn.text = "새로 시작 (방 나가기)"
	else:
		title_resume_btn.visible = false
		title_start_btn.text = "게임 시작하기"
	title_overlay.visible = true

func _setup_lobby():
	lobby_code_pad_btn.pressed.connect(func():
		SoundManager.play_click()
		open_numpad(lobby_code_input, "방 코드 4자리 입력", false)
	)
	lobby_name_web_btn.visible = OS.has_feature("web")
	lobby_name_web_btn.pressed.connect(func():
		SoundManager.play_click()
		if OS.has_feature("web"):
			var res = JavaScriptBridge.eval("window.prompt('이름을 입력하세요:', '%s') || ''" % lobby_name_input.text.replace("'", ""))
			if res is String and res.strip_edges() != "":
				lobby_name_input.text = res.strip_edges()
	)
	lobby_relay_row.visible = false
	lobby_server_toggle.pressed.connect(func():
		SoundManager.play_click()
		lobby_relay_row.visible = not lobby_relay_row.visible
	)
	lobby_back_btn.pressed.connect(func():
		SoundManager.play_click()
		lobby_modal.visible = false
		title_overlay.visible = true
	)
	lobby_country_opt.clear()
	for c_id in GameManager.countries:
		var c = GameManager.countries[c_id]
		lobby_country_opt.add_item(c["name"])
		lobby_country_opt.set_item_metadata(lobby_country_opt.item_count - 1, c_id)

	var roles = [
		["all_roles", "전체 역할 (소인원·1~4인 팀 겸직)"],
		["diplomat", "대외 협상가 (외교부 장관)"],
		["treasurer", "자원 관리자 (재무·자원부 장관)"],
		["technician", "생산·기술 총괄 (기술·제조부)"],
		["analyst", "정보 분석가 (경제기획원)"],
		["spokesperson", "국가 대변인 (홍보대사)"]
	]
	lobby_role_opt.clear()
	for r in roles:
		lobby_role_opt.add_item(r[1])
		lobby_role_opt.set_item_metadata(lobby_role_opt.item_count - 1, r[0])

	lobby_join_btn.pressed.connect(func():
		SoundManager.play_click()
		var c_id = lobby_country_opt.get_item_metadata(lobby_country_opt.selected)
		var r_id = lobby_role_opt.get_item_metadata(lobby_role_opt.selected)
		var code = lobby_code_input.text.strip_edges()
		var r_url = lobby_relay_input.text.strip_edges()
		GameManager.join_classroom_by_code(r_url, code, lobby_name_input.text, c_id, r_id)
	)

	lobby_host_btn.pressed.connect(func():
		SoundManager.play_click()
		var r_url = lobby_relay_input.text.strip_edges()
		GameManager.start_teacher_host(r_url)
	)

	lobby_solo_btn.pressed.connect(func():
		SoundManager.play_click()
		var c_id = lobby_country_opt.get_item_metadata(lobby_country_opt.selected)
		GameManager.start_solo_mode(c_id, "overworld")
		lobby_modal.visible = false
	)

func _setup_country_selector():
	country_option.clear()
	for c_id in GameManager.countries:
		var c = GameManager.countries[c_id]
		country_option.add_item(c["name"])
		country_option.set_item_metadata(country_option.item_count - 1, c_id)

	country_option.item_selected.connect(func(idx):
		SoundManager.play_click()
		var c_id = country_option.get_item_metadata(idx)
		GameManager.set_role(c_id, GameManager.current_player_role)
	)

func _setup_role_buttons():
	for btn in tab_container.get_children():
		if btn is Button:
			btn.pressed.connect(func():
				SoundManager.play_click()
				var role_tag = btn.get_meta("role", "overworld")
				GameManager.set_role(GameManager.current_player_country, role_tag)
				_switch_view(role_tag)
			)

func _on_role_changed(c_id: String, role_tag: String):
	for i in range(country_option.item_count):
		if country_option.get_item_metadata(i) == c_id:
			country_option.select(i)
			break

	country_option.disabled = GameManager.lock_country_switch
	for btn in tab_container.get_children():
		if btn is Button:
			var r = btn.get_meta("role", "overworld")
			if GameManager.lock_student_role:
				if GameManager.student_assigned_role == "all_roles":
					btn.visible = (r != "teacher")
				else:
					btn.visible = (r == "overworld" or r == GameManager.student_assigned_role)
			else:
				btn.visible = true

	_switch_view(role_tag)
	_apply_era_ui_theme()
	_update_trade_badge()

func _apply_era_ui_theme():
	var c = GameManager.countries[GameManager.current_player_country]
	var era = c.get("era_lvl", 0)
	if era == current_applied_era:
		return
	current_applied_era = era

	var panels = [
		$MainViews/DiplomatView/Panel,
		$MainViews/TreasurerView/Panel,
		$MainViews/TechnicianView/Panel,
		$MainViews/AnalystView/Panel,
		$MainViews/SpokespersonView/Panel,
		$MainViews/TeacherView/Panel,
		guide_strip
	]

	if era == 0:
		$TopBar.add_theme_stylebox_override("panel", default_wood_bar)
		for p in panels:
			p.add_theme_stylebox_override("panel", default_wood_panel)
	elif era == 1:
		# 산업 국가 UI (스틸 & 브론즈 인더스트리얼 테마)
		var bar = StyleBoxFlat.new()
		bar.bg_color = Color(0.20, 0.23, 0.27)
		bar.border_width_bottom = 3
		bar.border_color = Color(0.75, 0.55, 0.20)
		$TopBar.add_theme_stylebox_override("panel", bar)

		var pan = StyleBoxFlat.new()
		pan.bg_color = Color(0.84, 0.85, 0.87, 0.97)
		pan.border_width_left = 4; pan.border_width_top = 4; pan.border_width_right = 4; pan.border_width_bottom = 4
		pan.border_color = Color(0.55, 0.38, 0.14)
		pan.corner_radius_top_left = 4; pan.corner_radius_top_right = 4; pan.corner_radius_bottom_left = 4; pan.corner_radius_bottom_right = 4
		pan.content_margin_left = 14; pan.content_margin_top = 12; pan.content_margin_right = 14; pan.content_margin_bottom = 12
		for p in panels:
			p.add_theme_stylebox_override("panel", pan)
	else:
		# 미래 국가 UI (사이버 네이비 & 네온 시안 테마)
		var bar = StyleBoxFlat.new()
		bar.bg_color = Color(0.08, 0.14, 0.28)
		bar.border_width_bottom = 3
		bar.border_color = Color(0.15, 0.85, 0.98)
		$TopBar.add_theme_stylebox_override("panel", bar)

		var pan = StyleBoxFlat.new()
		pan.bg_color = Color(0.86, 0.94, 0.98, 0.97)
		pan.border_width_left = 4; pan.border_width_top = 4; pan.border_width_right = 4; pan.border_width_bottom = 4
		pan.border_color = Color(0.08, 0.70, 0.90)
		pan.corner_radius_top_left = 8; pan.corner_radius_top_right = 8; pan.corner_radius_bottom_left = 8; pan.corner_radius_bottom_right = 8
		pan.content_margin_left = 14; pan.content_margin_top = 12; pan.content_margin_right = 14; pan.content_margin_bottom = 12
		for p in panels:
			p.add_theme_stylebox_override("panel", pan)

	# Refresh guide strip title with new era tag
	if role_guides.has(GameManager.current_player_role):
		var g = role_guides[GameManager.current_player_role]
		guide_name.text = "%s [%s] · %s" % [c["name"], GameManager.get_era_name(era), g["title"]]

func _switch_view(role_tag: String):
	# Keep WorldMap ALWAYS visible in background so ships & islands are alive!
	view_map.visible = true
	view_diplomat.visible = (role_tag == "diplomat")
	view_treasurer.visible = (role_tag == "treasurer")
	view_technician.visible = (role_tag == "technician")
	view_analyst.visible = (role_tag == "analyst")
	view_spokesperson.visible = (role_tag == "spokesperson")
	view_teacher.visible = (role_tag == "teacher")

	if role_guides.has(role_tag):
		var g = role_guides[role_tag]
		var c = GameManager.countries[GameManager.current_player_country]
		var era_name = GameManager.get_era_name(c.get("era_lvl", 0))
		guide_name.text = "%s [%s] · %s" % [c["name"], era_name, g["title"]]
		guide_speech.text = g["speech"]
		if portraits.has(role_tag):
			guide_portrait.texture = portraits[role_tag]

func _update_trade_badge():
	var my_id = GameManager.current_player_country
	var count = 0
	for tid in GameManager.pending_trades:
		if GameManager.pending_trades[tid]["to_id"] == my_id:
			count += 1
	var dip_btn = $TabButtonsContainer/BtnDiplomat
	if count > 0:
		dip_btn.text = "대외 협상가 (%d)" % count
	else:
		dip_btn.text = "대외 협상가"

func _on_timer_updated(secs: float):
	var m = int(secs) / 60
	var s = int(secs) % 60
	timer_label.text = "%02d:%02d" % [m, s]

func _on_breaking_news(news: Dictionary):
	news_title.text = "긴급 경제 속보: " + news["title"]
	news_desc.text = news["description"]
	news_banner.visible = true
	news_banner_timer = 7.0

func _on_game_ended(winner_id: String):
	var w = GameManager.countries[winner_id]
	victory_text.text = "최우수 무역 국가: %s\n스마트폰: %d대 조립  |  보유 자산: %d G\n성공적인 글로벌 무역과 부품 협력을 달성했습니다!" % [w["name"], w["smartphones"], w["gold"]]
	victory_modal.visible = true

func _on_island_clicked(c_id: String):
	if not GameManager.countries.has(c_id):
		return
	var c = GameManager.countries[c_id]
	var era = c.get("era_lvl", 0)
	var era_name = GameManager.get_era_name(era)
	var mine_tag = " (우리 나라)" if c_id == GameManager.current_player_country else ""

	island_title.text = "%s [%s]%s" % [c["name"], era_name, mine_tag]
	if era == 2:
		island_icon.texture = load("res://assets/sprites/building_future.png")
	elif era == 1:
		island_icon.texture = load("res://assets/sprites/building_industrial.png")
	else:
		island_icon.texture = load(c["building_sprite"])

	island_trait.text = "고유 특성: " + c["special_trait"]

	var prod_map = {
		"iron_kingdom": "생산 가능: 철광석, 에너지   |   수입 필요: 식량, 반도체",
		"agri_empire": "생산 가능: 식량, 철광석   |   수입 필요: 에너지, 반도체",
		"tech_lab": "생산 가능: 반도체, 식량   |   수입 필요: 철광석, 에너지",
		"energy_base": "생산 가능: 에너지, 반도체   |   수입 필요: 철광석, 식량",
		"port_city": "생산 가능: 철광석, 식량, 골드   |   수입 필요: 에너지, 반도체",
		"trade_union": "생산 가능: 에너지, 반도체, 골드   |   수입 필요: 철광석, 식량"
	}
	island_prod.text = prod_map.get(c_id, "")

	island_stats.text = "보유 자원: 철광석 %d / 식량 %d / 에너지 %d / 반도체 %d\n국고: %d G   |   완성 스마트폰: %d대   |   총점: %d점\n인프라: 자동화 Lv.%d · 물류 Lv.%d · R&D Lv.%d" % [
		c["iron"], c["food"], c["energy"], c["semiconductor"],
		c["gold"], c["smartphones"], GameManager.get_total_score(c_id),
		c["automation_lvl"], c["logistics_lvl"], c["tech_rnd_lvl"]
	]
	island_modal.visible = true

func _setup_numpad():
	for child in numpad_grid.get_children():
		child.queue_free()
	var keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "지우기", "0", "확인"]
	for k in keys:
		var b = Button.new()
		b.text = k
		b.custom_minimum_size = Vector2(72, 46)
		b.pressed.connect(func():
			SoundManager.play_click()
			if k == "지우기":
				if numpad_value.length() > 0:
					numpad_value = numpad_value.substr(0, numpad_value.length() - 1)
			elif k == "확인":
				if numpad_target != null:
					numpad_target.text = numpad_value
				numpad_modal.visible = false
				return
			else:
				if numpad_value.length() < 8:
					numpad_value += k
			_refresh_numpad_display()
		)
		numpad_grid.add_child(b)

func open_numpad(target: LineEdit, title_str: String, is_secret: bool = false):
	numpad_target = target
	numpad_value = target.text
	numpad_secret = is_secret
	numpad_title.text = title_str
	_refresh_numpad_display()
	numpad_modal.visible = true

func _refresh_numpad_display():
	if numpad_value == "":
		numpad_display.text = "(입력하세요)"
	elif numpad_secret:
		numpad_display.text = "*".repeat(numpad_value.length())
	else:
		numpad_display.text = numpad_value
