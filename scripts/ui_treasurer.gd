extends Control

@onready var iron_val = $Panel/VBox/VaultGrid/IronCard/HBox/Val
@onready var food_val = $Panel/VBox/VaultGrid/FoodCard/HBox/Val
@onready var energy_val = $Panel/VBox/VaultGrid/EnergyCard/HBox/Val
@onready var semi_val = $Panel/VBox/VaultGrid/SemiCard/HBox/Val
@onready var gold_val = $Panel/VBox/VaultGrid/GoldCard/HBox/Val
@onready var phone_val = $Panel/VBox/VaultGrid/PhoneCard/HBox/Val

@onready var trait_desc = $Panel/VBox/TraitBox/TraitDesc
@onready var auto_btn = $Panel/VBox/UpgradesBox/UpgradeGrid/AutoCard/BuyBtn
@onready var auto_lbl = $Panel/VBox/UpgradesBox/UpgradeGrid/AutoCard/LvlLbl
@onready var log_btn = $Panel/VBox/UpgradesBox/UpgradeGrid/LogCard/BuyBtn
@onready var log_lbl = $Panel/VBox/UpgradesBox/UpgradeGrid/LogCard/LvlLbl
@onready var rnd_btn = $Panel/VBox/UpgradesBox/UpgradeGrid/RndCard/BuyBtn
@onready var rnd_lbl = $Panel/VBox/UpgradesBox/UpgradeGrid/RndCard/LvlLbl

@onready var era_status_lbl = $Panel/VBox/EraBox/HBox/EraStatusLbl
@onready var era_btn = $Panel/VBox/EraBox/HBox/EraBtn

func _ready():
	auto_btn.pressed.connect(func(): _buy_upgrade("automation"))
	log_btn.pressed.connect(func(): _buy_upgrade("logistics"))
	rnd_btn.pressed.connect(func(): _buy_upgrade("tech_rnd"))
	era_btn.pressed.connect(_on_era_upgrade_pressed)

	GameManager.country_data_changed.connect(func(_id): _update_display())
	GameManager.role_changed.connect(func(_c, _r): _update_display())
	GameManager.all_data_changed.connect(_update_display)
	_update_display()

func _update_display():
	var c_id = GameManager.current_player_country
	var c = GameManager.countries[c_id]

	iron_val.text = str(c["iron"]) + "개"
	food_val.text = str(c["food"]) + "개"
	energy_val.text = str(c["energy"]) + "개"
	semi_val.text = str(c["semiconductor"]) + "개"
	gold_val.text = str(c["gold"]) + " G"
	phone_val.text = str(c["smartphones"]) + "대"

	trait_desc.text = c["name"] + " 고유 특성: " + c["special_trait"]

	var auto_lvl = c["automation_lvl"]
	var auto_cost = GameManager.get_upgrade_cost(c_id, "automation")
	auto_lbl.text = "Lv.%d / 5 (생산량 +%d%%)" % [auto_lvl, (auto_lvl - 1) * 25]
	auto_btn.text = "투자 (%d G)" % auto_cost if auto_lvl < 5 else "최고 단계"
	auto_btn.disabled = auto_lvl >= 5 or c["gold"] < auto_cost

	var log_lvl = c["logistics_lvl"]
	var log_cost = GameManager.get_upgrade_cost(c_id, "logistics")
	log_lbl.text = "Lv.%d / 5 (선박 속도 +%d%%)" % [log_lvl, (log_lvl - 1) * 35]
	log_btn.text = "투자 (%d G)" % log_cost if log_lvl < 5 else "최고 단계"
	log_btn.disabled = log_lvl >= 5 or c["gold"] < log_cost

	var rnd_lvl = c["tech_rnd_lvl"]
	var rnd_cost = GameManager.get_upgrade_cost(c_id, "tech_rnd")
	rnd_lbl.text = "Lv.%d / 5 (스마트폰 점수 +%d%%)" % [rnd_lvl, (rnd_lvl - 1) * 35]
	rnd_btn.text = "투자 (%d G)" % rnd_cost if rnd_lvl < 5 else "최고 단계"
	rnd_btn.disabled = rnd_lvl >= 5 or c["gold"] < rnd_cost

	# Era Evolution Status
	var era_lvl = c.get("era_lvl", 0)
	var era_name = GameManager.get_era_name(era_lvl)
	var era_cost = GameManager.get_era_upgrade_cost(c_id)
	if era_lvl == 0:
		era_status_lbl.text = "현재 발전 단계: [%s] -> 다음 단계: 산업 국가 (모든 생산 +50%%, 산업 UI 해금)" % era_name
		era_btn.text = "산업 국가 승급 (%d G)" % era_cost
		era_btn.disabled = c["gold"] < era_cost
	elif era_lvl == 1:
		era_status_lbl.text = "현재 발전 단계: [%s] -> 다음 단계: 미래 국가 (생산 2배 + R&D 1.5배, 미래 UI 해금)" % era_name
		era_btn.text = "미래 국가 승급 (%d G)" % era_cost
		era_btn.disabled = c["gold"] < era_cost
	else:
		era_status_lbl.text = "현재 발전 단계: [%s] (최고 단계 도달! 모든 생산 2배 및 첨단 UI 적용 중)" % era_name
		era_btn.text = "미래 국가 달성"
		era_btn.disabled = true

func _buy_upgrade(u_type: String):
	SoundManager.play_click()
	var c_id = GameManager.current_player_country
	GameManager.buy_upgrade(c_id, u_type)
	_update_display()

func _on_era_upgrade_pressed():
	SoundManager.play_click()
	GameManager.upgrade_era(GameManager.current_player_country)
	_update_display()
