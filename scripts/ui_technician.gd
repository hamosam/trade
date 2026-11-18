extends Control

@onready var slot_iron = $Panel/VBox/RecipeContainer/IronSlot/Status
@onready var slot_food = $Panel/VBox/RecipeContainer/FoodSlot/Status
@onready var slot_energy = $Panel/VBox/RecipeContainer/EnergySlot/Status
@onready var slot_semi = $Panel/VBox/RecipeContainer/SemiSlot/Status

@onready var count_iron = $Panel/VBox/RecipeContainer/IronSlot/Count
@onready var count_food = $Panel/VBox/RecipeContainer/FoodSlot/Count
@onready var count_energy = $Panel/VBox/RecipeContainer/EnergySlot/Count
@onready var count_semi = $Panel/VBox/RecipeContainer/SemiSlot/Count

@onready var assemble_btn = $Panel/VBox/AssembleBtn
@onready var progress_bar = $Panel/VBox/ProgressBar
@onready var target_hint = $Panel/VBox/TargetHint
@onready var result_label = $Panel/VBox/ResultLabel
@onready var stats_label = $Panel/VBox/StatsLabel

@onready var gather_btn = $Panel/VBox/ActionRow/GatherBtn
@onready var from_opt = $Panel/VBox/ActionRow/ConvertBox/FromOpt
@onready var to_opt = $Panel/VBox/ActionRow/ConvertBox/ToOpt
@onready var convert_btn = $Panel/VBox/ActionRow/ConvertBox/ConvertBtn

var timing_active: bool = false
var timing_val: float = 0.0
var timing_dir: float = 1.0
var gather_cooldown: float = 0.0

var res_keys = ["iron", "food", "energy", "semiconductor"]
var res_names = ["철광석", "식량", "에너지", "반도체"]

func _ready():
	assemble_btn.pressed.connect(_on_assemble_pressed)
	gather_btn.pressed.connect(_on_gather_pressed)
	convert_btn.pressed.connect(_on_convert_pressed)

	from_opt.clear()
	to_opt.clear()
	for i in range(res_keys.size()):
		from_opt.add_item(res_names[i], i)
		from_opt.set_item_metadata(i, res_keys[i])
		to_opt.add_item(res_names[i], i)
		to_opt.set_item_metadata(i, res_keys[i])
	from_opt.select(0)
	to_opt.select(3)

	GameManager.country_data_changed.connect(func(_id): _update_display())
	GameManager.role_changed.connect(func(_c, _r): timing_active = false; _update_display())
	GameManager.all_data_changed.connect(_update_display)
	_update_display()

func _process(delta):
	if timing_active:
		timing_val += delta * 145.0 * timing_dir
		if timing_val >= 100.0:
			timing_val = 100.0
			timing_dir = -1.0
		elif timing_val <= 0.0:
			timing_val = 0.0
			timing_dir = 1.0
		progress_bar.value = timing_val
		if timing_val >= 50.0 and timing_val <= 51.0:
			progress_bar.modulate = Color(0.4, 1.0, 0.45)
		else:
			progress_bar.modulate = Color(1.0, 0.85, 0.45)
	else:
		progress_bar.modulate = Color(1, 1, 1)

	if gather_cooldown > 0.0:
		gather_cooldown -= delta
		if gather_cooldown <= 0.0:
			gather_cooldown = 0.0
		_update_gather_btn()

func _on_assemble_pressed():
	var c_id = GameManager.current_player_country
	if not timing_active:
		if not GameManager.can_assemble_smartphone(c_id):
			return
		SoundManager.play_click()
		timing_active = true
		timing_val = 0.0
		timing_dir = 1.0
		assemble_btn.text = "지금 정밀 결합! (목표 구간: 50% ~ 51%)"
		result_label.text = "게이지가 정확히 50% ~ 51% 구간에 들어왔을 때 다시 클릭하세요!"
	else:
		timing_active = false
		var is_perfect = (timing_val >= 50.0 and timing_val <= 51.0)
		GameManager.assemble_smartphone(c_id, is_perfect)
		if is_perfect:
			result_label.text = "명품 스마트폰 조립 대성공! (+80G, 추가 승점 +50점 보너스!)"
		else:
			result_label.text = "스마트폰 조립 완료! (+50G 및 기본 승점 획득)"
		_update_display()

func _on_gather_pressed():
	if gather_cooldown > 0.0:
		return
	var c_id = GameManager.current_player_country
	var res_key = GameManager.manual_gather(c_id)
	gather_cooldown = 8.0
	var idx = res_keys.find(res_key)
	var rname = res_names[idx] if idx >= 0 else "특산 자원"
	result_label.text = "직접 생산 성공! %s +2개를 확보했습니다." % rname
	_update_display()

func _on_convert_pressed():
	SoundManager.play_click()
	var c_id = GameManager.current_player_country
	var c = GameManager.countries[c_id]
	if c.get("converts_left", 0) <= 0:
		result_label.text = "비상 가공 횟수(3회)를 모두 사용했습니다."
		return
	var f_res = from_opt.get_item_metadata(from_opt.selected)
	var t_res = to_opt.get_item_metadata(to_opt.selected)
	if f_res == t_res:
		result_label.text = "변환할 자원과 받을 자원을 서로 다르게 선택하세요."
		return
	var req_amt = 3 if c_id == "energy_base" else 4
	if GameManager.convert_resource(c_id, f_res, t_res):
		result_label.text = "비상 가공 완료! %s %d개를 %s 1개로 변환했습니다." % [res_names[from_opt.selected], req_amt, res_names[to_opt.selected]]
	else:
		result_label.text = "재료가 부족합니다. 변환에는 %d개의 자원이 필요합니다." % req_amt
	_update_display()

func _update_gather_btn():
	if gather_cooldown > 0.0:
		gather_btn.disabled = true
		gather_btn.text = "직접 생산 대기 (%.1f초)" % gather_cooldown
	else:
		gather_btn.disabled = false
		var c_id = GameManager.current_player_country
		var sp = GameManager._get_specialty_res(c_id)
		var idx = res_keys.find(sp)
		var rname = res_names[idx] if idx >= 0 else "특산품"
		gather_btn.text = "%s 직접 생산 (+2개)" % rname

func _update_display():
	var c_id = GameManager.current_player_country
	var c = GameManager.countries[c_id]

	count_iron.text = "보유: %d / 1" % c["iron"]
	count_food.text = "보유: %d / 1" % c["food"]
	count_energy.text = "보유: %d / 1" % c["energy"]
	count_semi.text = "보유: %d / 1" % c["semiconductor"]

	slot_iron.text = "준비됨" if c["iron"] >= 1 else "부족"
	slot_iron.modulate = Color(0.15, 0.55, 0.2) if c["iron"] >= 1 else Color(0.75, 0.2, 0.2)
	slot_food.text = "준비됨" if c["food"] >= 1 else "부족"
	slot_food.modulate = Color(0.15, 0.55, 0.2) if c["food"] >= 1 else Color(0.75, 0.2, 0.2)
	slot_energy.text = "준비됨" if c["energy"] >= 1 else "부족"
	slot_energy.modulate = Color(0.15, 0.55, 0.2) if c["energy"] >= 1 else Color(0.75, 0.2, 0.2)
	slot_semi.text = "준비됨" if c["semiconductor"] >= 1 else "부족"
	slot_semi.modulate = Color(0.15, 0.55, 0.2) if c["semiconductor"] >= 1 else Color(0.75, 0.2, 0.2)

	var can_build = GameManager.can_assemble_smartphone(c_id)
	if not timing_active:
		assemble_btn.disabled = not can_build
		assemble_btn.text = "스마트폰 조립 시작 (독점 권한)" if can_build else "재료가 부족합니다 (직접 생산/변환/무역 활용)"

	var conv_left = c.get("converts_left", 0)
	var req_amt = 3 if c_id == "energy_base" else 4
	convert_btn.disabled = (conv_left <= 0)
	convert_btn.text = "%d→1 변환 (%d회)" % [req_amt, conv_left] if conv_left > 0 else "횟수 소진"

	_update_gather_btn()
	stats_label.text = "%s 완성 스마트폰: %d대  |  누적 승점: %d점" % [c["name"], c["smartphones"], c["score"]]
