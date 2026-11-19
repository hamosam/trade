extends Control

signal island_clicked(country_id)

var ship_texture: Texture2D
var wake_texture: Texture2D
var oak_texture: Texture2D
var pine_texture: Texture2D
var bush_texture: Texture2D
var flower_texture: Texture2D
var building_industrial_tex: Texture2D
var building_future_tex: Texture2D
var prop_factory_tex: Texture2D
var prop_warehouse_tex: Texture2D
var prop_spire_tex: Texture2D
var prop_pylon_tex: Texture2D

var res_textures: Dictionary = {}
var building_textures: Dictionary = {}
var char_textures: Dictionary = {}

var active_ships: Array = []
var wake_particles: Array = []
var floating_texts: Array = []
var villagers: Array = []
var wave_anim_time: float = 0.0
var hovered_country: String = ""

# Organic multi-layered island definitions
var island_data: Dictionary = {
	"iron_kingdom": {
		"center": Vector2(230, 195), "rx": 125.0, "ry": 82.0, "seed": 1.1,
		"grass": Color(0.30, 0.56, 0.24), "grass_hi": Color(0.38, 0.66, 0.28),
		"trees": [Vector2(-75, -25), Vector2(-90, 15), Vector2(78, -20)],
		"pines": [Vector2(-45, -45), Vector2(65, 32)],
		"bushes": [Vector2(-25, 42), Vector2(40, -38)],
		"flowers": [Vector2(-55, 22), Vector2(30, 35)]
	},
	"agri_empire": {
		"center": Vector2(640, 155), "rx": 140.0, "ry": 82.0, "seed": 2.4,
		"grass": Color(0.36, 0.64, 0.24), "grass_hi": Color(0.45, 0.74, 0.30),
		"trees": [Vector2(-90, -18), Vector2(92, -15), Vector2(85, 25)],
		"pines": [Vector2(-55, -42), Vector2(52, -40)],
		"bushes": [Vector2(-35, 38), Vector2(35, 38)],
		"flowers": [Vector2(-65, 18), Vector2(55, 18), Vector2(0, -45)]
	},
	"tech_lab": {
		"center": Vector2(1050, 195), "rx": 125.0, "ry": 82.0, "seed": 3.7,
		"grass": Color(0.26, 0.54, 0.30), "grass_hi": Color(0.34, 0.64, 0.36),
		"trees": [Vector2(-75, -25), Vector2(75, -25), Vector2(82, 20)],
		"pines": [Vector2(-78, 22), Vector2(-38, -44)],
		"bushes": [Vector2(-42, 38), Vector2(35, 36)],
		"flowers": [Vector2(45, -35), Vector2(-50, 12)]
	},
	"energy_base": {
		"center": Vector2(230, 455), "rx": 125.0, "ry": 82.0, "seed": 4.9,
		"grass": Color(0.33, 0.58, 0.22), "grass_hi": Color(0.42, 0.68, 0.28),
		"trees": [Vector2(-75, -25), Vector2(-80, 20), Vector2(72, 28)],
		"pines": [Vector2(-35, 42), Vector2(76, -22)],
		"bushes": [Vector2(-25, -42), Vector2(45, -36)],
		"flowers": [Vector2(40, 35), Vector2(-55, -5)]
	},
	"port_city": {
		"center": Vector2(640, 495), "rx": 140.0, "ry": 82.0, "seed": 5.3,
		"grass": Color(0.31, 0.59, 0.27), "grass_hi": Color(0.40, 0.69, 0.33),
		"trees": [Vector2(-92, -15), Vector2(-78, 28), Vector2(90, -15), Vector2(78, 28)],
		"pines": [Vector2(-45, -42), Vector2(45, -42)],
		"bushes": [Vector2(-28, 40), Vector2(28, 40)],
		"flowers": [Vector2(-60, 5), Vector2(60, 5)]
	},
	"trade_union": {
		"center": Vector2(1050, 455), "rx": 125.0, "ry": 82.0, "seed": 6.8,
		"grass": Color(0.29, 0.56, 0.25), "grass_hi": Color(0.38, 0.66, 0.31),
		"trees": [Vector2(-70, 28), Vector2(75, -25), Vector2(80, 18)],
		"pines": [Vector2(-76, -20), Vector2(36, -44)],
		"bushes": [Vector2(-38, -40), Vector2(32, 38)],
		"flowers": [Vector2(-45, 35), Vector2(50, -12)]
	}
}

func _ready():
	_load_textures()
	_spawn_villagers()
	GameManager.cargo_ship_spawned.connect(_on_cargo_ship_spawned)
	GameManager.smartphone_assembled.connect(_on_phone_assembled)
	GameManager.country_data_changed.connect(func(_id): queue_redraw())
	GameManager.all_data_changed.connect(queue_redraw)
	GameManager.game_reset.connect(func():
		active_ships.clear()
		wake_particles.clear()
		floating_texts.clear()
		queue_redraw()
	)

func _load_textures():
	ship_texture = load("res://assets/sprites/ship_cargo.png")
	wake_texture = load("res://assets/sprites/ship_wake.png")
	oak_texture = load("res://assets/sprites/tree_oak.png")
	pine_texture = load("res://assets/sprites/tree_pine.png")
	bush_texture = load("res://assets/sprites/bush.png")
	flower_texture = load("res://assets/sprites/flower_patch.png")
	building_industrial_tex = load("res://assets/sprites/building_industrial.png")
	building_future_tex = load("res://assets/sprites/building_future.png")
	prop_factory_tex = load("res://assets/sprites/prop_factory.png")
	prop_warehouse_tex = load("res://assets/sprites/prop_warehouse.png")
	prop_spire_tex = load("res://assets/sprites/prop_spire.png")
	prop_pylon_tex = load("res://assets/sprites/prop_pylon.png")

	res_textures["iron"] = load("res://assets/sprites/res_iron.png")
	res_textures["food"] = load("res://assets/sprites/res_food.png")
	res_textures["energy"] = load("res://assets/sprites/res_energy.png")
	res_textures["semiconductor"] = load("res://assets/sprites/res_semiconductor.png")
	res_textures["phone"] = load("res://assets/sprites/res_phone.png")
	res_textures["gold"] = load("res://assets/sprites/res_gold.png")

	for c_id in GameManager.countries:
		var c = GameManager.countries[c_id]
		building_textures[c_id] = load(c["building_sprite"])
		char_textures[c_id] = load(c["char_sprite"])

func _spawn_villagers():
	villagers.clear()
	for c_id in island_data:
		var isl = island_data[c_id]
		for i in range(3):
			var offset = Vector2(randf_range(-55, 55), randf_range(-25, 32))
			villagers.append({
				"country_id": c_id,
				"pos": isl["center"] + offset,
				"target": isl["center"] + Vector2(randf_range(-55, 55), randf_range(-25, 32)),
				"wait_timer": randf_range(0.5, 2.5),
				"anim_time": randf_range(0.0, 1.0),
				"facing_left": false,
				"emote": "",
				"emote_timer": 0.0
			})

func _gui_input(event):
	if event is InputEventMouseMotion:
		hovered_country = _find_island_at(event.position)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked = _find_island_at(event.position)
		if clicked != "":
			SoundManager.play_click()
			island_clicked.emit(clicked)

func _find_island_at(p: Vector2) -> String:
	for c_id in island_data:
		var isl = island_data[c_id]
		var d = (p - isl["center"]) / Vector2(isl["rx"], isl["ry"])
		if d.length() <= 1.05:
			return c_id
	return ""

func _process(delta):
	wave_anim_time += delta

	# Update walking villagers on islands
	for v in villagers:
		if v["emote_timer"] > 0:
			v["emote_timer"] -= delta
		if v["wait_timer"] > 0:
			v["wait_timer"] -= delta
			continue
		var diff = v["target"] - v["pos"]
		if diff.length() < 4.0:
			v["wait_timer"] = randf_range(1.0, 3.0)
			var isl = island_data[v["country_id"]]
			v["target"] = isl["center"] + Vector2(randf_range(-60, 60), randf_range(-22, 34))
		else:
			var step = diff.normalized() * 22.0 * delta
			v["pos"] += step
			v["facing_left"] = step.x < 0
			v["anim_time"] += delta * 5.0

	# Update wake & smoke particles
	var w_remove = []
	for wp in wake_particles:
		wp["life"] -= delta
		wp["pos"] += wp["vel"] * delta
		if wp["life"] <= 0:
			w_remove.append(wp)
	for wr in w_remove:
		wake_particles.erase(wr)

	# Update active cargo ships (paused when game is paused)
	var to_remove = []
	if GameManager.is_game_running:
		for ship in active_ships:
			ship["progress"] += delta * ship["speed"]
			ship["wake_timer"] += delta
			var cur_p = _get_ship_pos(ship)
			if ship["wake_timer"] >= 0.14:
				ship["wake_timer"] = 0.0
				wake_particles.append({"pos": cur_p + Vector2(0, 6), "vel": Vector2(0, 0), "life": 0.9, "max": 0.9, "kind": "wake"})
				wake_particles.append({"pos": cur_p + Vector2(4, -14), "vel": Vector2(-4, -14), "life": 0.8, "max": 0.8, "kind": "smoke"})

			if ship["progress"] >= 1.0:
				ship["progress"] = 1.0
				to_remove.append(ship)
				GameManager.complete_cargo_delivery(ship["from_id"], ship["to_id"], ship["trade"])
				var to_c = GameManager.countries[ship["to_id"]]
				_spawn_floating_text(ship["end_pos"], to_c["short"] + " 도착!", Color(1.0, 0.92, 0.3))
				_trigger_island_emote(ship["to_id"], "♥")

	for r in to_remove:
		active_ships.erase(r)

	# Update floating texts
	var texts_to_remove = []
	for ft in floating_texts:
		ft["life"] -= delta
		ft["pos"].y -= delta * 28.0
		if ft["life"] <= 0:
			texts_to_remove.append(ft)
	for tr in texts_to_remove:
		floating_texts.erase(tr)

	queue_redraw()

func _get_ship_pos(ship: Dictionary) -> Vector2:
	var t = ship["progress"]
	var p0 = ship["start_pos"]
	var p1 = ship["ctrl_pos"]
	var p2 = ship["end_pos"]
	var q0 = p0.lerp(p1, t)
	var q1 = p1.lerp(p2, t)
	return q0.lerp(q1, t)

func _trigger_island_emote(c_id: String, emote: String):
	for v in villagers:
		if v["country_id"] == c_id:
			v["emote"] = emote
			v["emote_timer"] = 2.5

func _on_phone_assembled(country_id: String, count: int):
	var isl = island_data[country_id]
	_spawn_floating_text(isl["center"] + Vector2(0, -30), "스마트폰 완성! (" + str(count) + "대)", Color(0.5, 0.95, 1.0))
	_trigger_island_emote(country_id, "!")

func _on_cargo_ship_spawned(from_id: String, to_id: String, trade: Dictionary):
	var from_c = GameManager.countries[from_id]
	var to_c = GameManager.countries[to_id]
	var start_p = from_c["port_pos"]
	var end_p = to_c["port_pos"]

	var mid = (start_p + end_p) * 0.5
	var dir = (end_p - start_p).normalized()
	var perp = Vector2(-dir.y, dir.x)
	var ctrl_p = mid + perp * 48.0

	var base_duration = 5.5
	var speed_mult = GameManager.active_event["ship_speed_mult"]
	var log_bonus = 1.0 + (from_c["logistics_lvl"] - 1) * 0.35
	if from_id == "port_city" or to_id == "port_city":
		log_bonus *= 1.5

	var final_speed = (1.0 / base_duration) * speed_mult * log_bonus

	active_ships.append({
		"from_id": from_id, "to_id": to_id,
		"start_pos": start_p, "ctrl_pos": ctrl_p, "end_pos": end_p,
		"trade": trade, "progress": 0.0, "speed": final_speed, "wake_timer": 0.0
	})
	_spawn_floating_text(start_p, "무역선 출항!", Color(0.65, 0.95, 1.0))
	_trigger_island_emote(from_id, "!")

func _spawn_floating_text(pos: Vector2, text: String, color: Color):
	floating_texts.append({
		"pos": pos + Vector2(-35, -18),
		"text": text, "color": color,
		"life": 2.0, "max_life": 2.0
	})

func _make_island_poly(center: Vector2, rx: float, ry: float, seed_val: float, steps: int = 24) -> PackedVector2Array:
	var pts = PackedVector2Array()
	for i in range(steps):
		var a = (float(i) / steps) * TAU
		var wobble = 1.0 + 0.08 * sin(a * 3.0 + seed_val) + 0.05 * cos(a * 5.0 - seed_val * 2.0)
		pts.append(center + Vector2(cos(a) * rx * wobble, sin(a) * ry * wobble))
	return pts

func _draw():
	var w = size.x
	var h = size.y
	var font = get_theme_default_font()

	# 1. Deep Ocean Backdrop
	draw_rect(Rect2(0, 0, w, h), Color(0.14, 0.38, 0.54))

	# Soft ocean current bands
	for wy in range(30, int(h), 46):
		for wx in range(25, int(w), 68):
			var phase = sin(wave_anim_time * 2.0 + wx * 0.025 + wy * 0.04)
			if phase > 0.25:
				var off = Vector2(sin(wave_anim_time * 1.4 + wy) * 6.0, 0)
				draw_line(Vector2(wx, wy) + off, Vector2(wx + 14, wy) + off, Color(0.35, 0.68, 0.84, 0.42), 2.0)
				draw_line(Vector2(wx + 4, wy + 2) + off, Vector2(wx + 10, wy + 2) + off, Color(0.85, 0.96, 1.0, 0.55), 1.0)

	# 2. Sea Trade Routes (subtle dotted sea lanes)
	var route_pairs = [
		["iron_kingdom", "agri_empire"], ["agri_empire", "tech_lab"],
		["iron_kingdom", "energy_base"], ["energy_base", "port_city"],
		["port_city", "trade_union"], ["tech_lab", "trade_union"],
		["agri_empire", "port_city"]
	]
	for pair in route_pairs:
		var p1 = GameManager.countries[pair[0]]["port_pos"]
		var p2 = GameManager.countries[pair[1]]["port_pos"]
		draw_dashed_line(p1, p2, Color(0.85, 0.95, 1.0, 0.18), 2.0, 8.0)

	# 3. Draw 6 Organic Islands
	for c_id in island_data:
		var isl = island_data[c_id]
		var c = isl["center"]
		var rx = isl["rx"]
		var ry = isl["ry"]
		var sd = isl["seed"]
		var c_data = GameManager.countries[c_id]
		var era = c_data.get("era_lvl", 0)

		# Shallow Turquoise Reef
		draw_colored_polygon(_make_island_poly(c, rx + 24, ry + 18, sd), Color(0.24, 0.62, 0.72, 0.65))
		# Animated Seafoam Shoreline
		var foam_pulse = 10.0 + sin(wave_anim_time * 2.5 + sd) * 2.5
		draw_colored_polygon(_make_island_poly(c, rx + foam_pulse, ry + foam_pulse * 0.75, sd), Color(0.82, 0.95, 0.98, 0.55))
		# Beach / Seawall
		var beach_col = Color(0.90, 0.76, 0.46)
		if era == 1:
			beach_col = Color(0.66, 0.64, 0.60) # Stone seawall
		elif era == 2:
			beach_col = Color(0.70, 0.85, 0.94) # Titanium/glass shore
		draw_colored_polygon(_make_island_poly(c, rx + 4, ry + 3, sd), beach_col)

		# Lush Grassland / Era Terrain
		var g_col = isl["grass"]
		var ghi_col = isl["grass_hi"]
		if era == 1:
			g_col = Color(0.38, 0.48, 0.28)
			ghi_col = Color(0.55, 0.54, 0.48) # Paved industrial plaza
		elif era == 2:
			g_col = Color(0.22, 0.52, 0.56)
			ghi_col = Color(0.32, 0.70, 0.78) # Futuristic eco-cyber terrace
		draw_colored_polygon(_make_island_poly(c, rx - 10, ry - 9, sd), g_col)
		draw_colored_polygon(_make_island_poly(c + Vector2(-4, -3), rx - 28, ry - 22, sd + 0.5), ghi_col)

		# Era Aura Ring
		if era == 1:
			draw_polyline(_make_island_poly(c, rx + 6, ry + 4, sd), Color(0.85, 0.65, 0.22, 0.8), 2.0, true)
		elif era == 2:
			var pulse_a = 0.55 + 0.35 * sin(wave_anim_time * 4.0)
			draw_polyline(_make_island_poly(c, rx + 7, ry + 5, sd), Color(0.2, 0.92, 1.0, pulse_a), 2.5, true)
			# Subtle cyan energy lines
			draw_line(c + Vector2(-45, 0), c + Vector2(45, 0), Color(0.3, 0.95, 1.0, 0.45), 1.5)
			draw_line(c + Vector2(0, -25), c + Vector2(0, 25), Color(0.3, 0.95, 1.0, 0.45), 1.5)

		# Selection / Hover ring
		if c_id == GameManager.current_player_country:
			draw_polyline(_make_island_poly(c, rx + 14, ry + 11, sd), Color(1.0, 0.92, 0.35, 0.9), 2.5, true)
		elif c_id == hovered_country:
			draw_polyline(_make_island_poly(c, rx + 14, ry + 11, sd), Color(1.0, 1.0, 1.0, 0.6), 2.0, true)

		# Pier / Dock (transforms with Era!)
		var port_p = c_data["port_pos"]
		if era == 2:
			draw_rect(Rect2(port_p.x - 16, port_p.y - 8, 32, 16), Color(0.15, 0.35, 0.55), true)
			draw_rect(Rect2(port_p.x - 14, port_p.y - 6, 28, 12), Color(0.35, 0.80, 0.95), true)
		elif era == 1:
			draw_rect(Rect2(port_p.x - 15, port_p.y - 8, 30, 16), Color(0.35, 0.35, 0.38), true)
			draw_rect(Rect2(port_p.x - 13, port_p.y - 6, 26, 12), Color(0.58, 0.56, 0.52), true)
		else:
			draw_rect(Rect2(port_p.x - 15, port_p.y - 8, 30, 16), Color(0.45, 0.27, 0.14), true)
			draw_rect(Rect2(port_p.x - 13, port_p.y - 6, 26, 12), Color(0.68, 0.46, 0.25), true)
			for px in range(-10, 11, 5):
				draw_line(Vector2(port_p.x + px, port_p.y - 6), Vector2(port_p.x + px, port_p.y + 6), Color(0.45, 0.27, 0.14), 1.0)

		# Props & Landmark Building (completely transforms with Era!)
		if era == 1:
			# 산업 국가: 나무/꽃 제거 -> 미니 공장 & 철강 창고 & 굴뚝 연기
			for bp in isl["bushes"]:
				if prop_warehouse_tex:
					draw_texture(prop_warehouse_tex, c + bp - Vector2(14, 20))
			for tp in isl["trees"]:
				if prop_factory_tex:
					draw_texture(prop_factory_tex, c + tp - Vector2(16, 24))
					var smoke_y = fmod(wave_anim_time * 18.0 + tp.x, 16.0)
					draw_circle(c + tp + Vector2(8, -22 - smoke_y), 3.0, Color(0.85, 0.85, 0.88, 0.65 - smoke_y * 0.03))
			for pp in isl["pines"]:
				if prop_warehouse_tex:
					draw_texture(prop_warehouse_tex, c + pp - Vector2(14, 22))
			if building_industrial_tex:
				draw_texture(building_industrial_tex, c - Vector2(32, 42))
				var main_smoke = fmod(wave_anim_time * 22.0 + sd * 5.0, 22.0)
				draw_circle(c + Vector2(12, -38 - main_smoke), 4.5, Color(0.85, 0.85, 0.9, 0.7 - main_smoke * 0.028))
				draw_circle(c + Vector2(20, -34 - main_smoke * 0.8), 3.5, Color(0.85, 0.85, 0.9, 0.6 - main_smoke * 0.024))
		elif era == 2:
			# 미래 국가: 나무/공장 제거 -> 빛나는 첨탑 & 에너지 파일론 & 사이버 오라
			for bp in isl["bushes"]:
				if prop_pylon_tex:
					draw_texture(prop_pylon_tex, c + bp - Vector2(12, 22))
			for tp in isl["trees"]:
				if prop_spire_tex:
					draw_texture(prop_spire_tex, c + tp - Vector2(14, 30))
			for pp in isl["pines"]:
				if prop_pylon_tex:
					draw_texture(prop_pylon_tex, c + pp - Vector2(12, 22))
			if building_future_tex:
				draw_texture(building_future_tex, c - Vector2(32, 44))
				var orb_y = sin(wave_anim_time * 3.5 + sd) * 5.0
				draw_circle(c + Vector2(0, -46 + orb_y), 4.0, Color(0.4, 0.95, 1.0, 0.85))
				draw_circle(c + Vector2(0, -46 + orb_y), 7.5, Color(0.2, 0.85, 1.0, 0.30))
		else:
			# 자원 국가 (기본): 야생화, 덤불, 참나무, 소나무, 국가 고유 건물
			if flower_texture:
				for fp in isl["flowers"]:
					draw_texture(flower_texture, c + fp - Vector2(8, 8))
			for bp in isl["bushes"]:
				if bush_texture:
					draw_texture(bush_texture, c + bp - Vector2(12, 10))
			for tp in isl["trees"]:
				if oak_texture:
					draw_texture(oak_texture, c + tp - Vector2(16, 32))
			for pp in isl["pines"]:
				if pine_texture:
					draw_texture(pine_texture, c + pp - Vector2(16, 36))
			if building_textures.has(c_id) and building_textures[c_id]:
				draw_texture(building_textures[c_id], c - Vector2(24, 30))

	# 4. Walking Villagers (sorted slightly by Y)
	for v in villagers:
		var tex = char_textures.get(v["country_id"])
		if tex:
			var frame = int(v["anim_time"]) % 2 if v["wait_timer"] <= 0 else 0
			var src_rect = Rect2(frame * 24, 0, 24, 32)
			var dst_w = -24.0 if v["facing_left"] else 24.0
			var dst_x = v["pos"].x + 12.0 if v["facing_left"] else v["pos"].x - 12.0
			draw_texture_rect_region(tex, Rect2(dst_x, v["pos"].y - 26, dst_w, 32), src_rect)

		if v["emote_timer"] > 0 and v["emote"] != "":
			draw_rect(Rect2(v["pos"].x - 8, v["pos"].y - 42, 16, 14), Color(1, 0.98, 0.9), true)
			draw_rect(Rect2(v["pos"].x - 8, v["pos"].y - 42, 16, 14), Color(0.3, 0.15, 0.05), false, 1.0)
			draw_string(font, v["pos"] + Vector2(-4, -31), v["emote"], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.85, 0.2, 0.2))

	# 5. Wake & Smoke Particles
	for wp in wake_particles:
		var a = wp["life"] / wp["max"]
		if wp["kind"] == "wake" and wake_texture:
			draw_texture(wake_texture, wp["pos"] - Vector2(8, 8), Color(1, 1, 1, a * 0.7))
		elif wp["kind"] == "smoke":
			draw_circle(wp["pos"], 3.0 + (1.0 - a) * 3.0, Color(0.95, 0.95, 0.98, a * 0.55))

	# 6. Sailing Cargo Ships
	for ship in active_ships:
		var cur_p = _get_ship_pos(ship)
		var next_p = _get_ship_pos({"start_pos": ship["start_pos"], "ctrl_pos": ship["ctrl_pos"], "end_pos": ship["end_pos"], "progress": min(1.0, ship["progress"] + 0.02)})
		var bob_y = sin(wave_anim_time * 5.0 + ship["progress"] * 10.0) * 2.5
		var draw_p = cur_p + Vector2(0, bob_y)
		var flip_left = (next_p.x < cur_p.x)

		if ship_texture:
			var sw = -36.0 if flip_left else 36.0
			var sx = draw_p.x + 18.0 if flip_left else draw_p.x - 18.0
			draw_texture_rect(ship_texture, Rect2(sx, draw_p.y - 20, sw, 36), false)

		# Show traded resource icon floating above the ship!
		var t = ship["trade"]
		var icon_res = t["offer_res"] if t["offer_res"] != "none" else "gold"
		if res_textures.has(icon_res) and res_textures[icon_res]:
			draw_texture_rect(res_textures[icon_res], Rect2(draw_p.x - 10, draw_p.y - 38, 20, 20), false)

	# 7. Island Wooden Status Banners (rendered on top cleanly)
	for c_id in island_data:
		var isl = island_data[c_id]
		_draw_island_badge(isl["center"] + Vector2(0, -isl["ry"] - 22), GameManager.countries[c_id], font)

	# 8. Floating Notification Texts
	for ft in floating_texts:
		var alpha = ft["life"] / ft["max_life"]
		var col = ft["color"]
		col.a = alpha
		draw_string(font, ft["pos"] + Vector2(1, 1), ft["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, 13, Color(0, 0, 0, alpha * 0.7))
		draw_string(font, ft["pos"], ft["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, 13, col)

func _draw_island_badge(pos: Vector2, c_data: Dictionary, font: Font):
	var w = 212.0
	var h = 50.0
	var r = Rect2(pos.x - w / 2.0, pos.y - h / 2.0, w, h)
	var era = c_data.get("era_lvl", 0)

	# Frame colors shift with Era: 0=Wood, 1=Industrial Steel, 2=Future Cyber
	var outer_col = Color(0.26, 0.14, 0.07)
	var mid_col = Color(0.82, 0.62, 0.34)
	var inner_col = Color(0.95, 0.88, 0.72)
	var prefix = ""
	if era == 1:
		outer_col = Color(0.20, 0.22, 0.26)
		mid_col = Color(0.75, 0.56, 0.22)
		inner_col = Color(0.86, 0.87, 0.89)
		prefix = "[산업] "
	elif era == 2:
		outer_col = Color(0.06, 0.14, 0.28)
		mid_col = Color(0.10, 0.80, 0.96)
		inner_col = Color(0.86, 0.95, 0.99)
		prefix = "[미래] "

	draw_rect(r, outer_col, true)
	draw_rect(Rect2(r.position.x + 2, r.position.y + 2, r.size.x - 4, r.size.y - 4), mid_col, true)
	draw_rect(Rect2(r.position.x + 3, r.position.y + 3, r.size.x - 6, r.size.y - 6), inner_col, true)

	# Country Color Flag Stripe
	draw_rect(Rect2(r.position.x + 4, r.position.y + 4, 6, r.size.y - 8), c_data["color"], true)

	# Country Name + Gold + Phones
	draw_string(font, Vector2(r.position.x + 14, r.position.y + 17), prefix + c_data["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.15, 0.1, 0.05))
	if res_textures.get("gold"):
		draw_texture_rect(res_textures["gold"], Rect2(r.position.x + 114, r.position.y + 6, 13, 13), false)
	draw_string(font, Vector2(r.position.x + 129, r.position.y + 17), str(c_data["gold"]) + "G", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.65, 0.40, 0.05))

	if res_textures.get("phone"):
		draw_texture_rect(res_textures["phone"], Rect2(r.position.x + 170, r.position.y + 6, 13, 13), false)
	draw_string(font, Vector2(r.position.x + 185, r.position.y + 17), str(c_data["smartphones"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.1, 0.35, 0.65))

	# 4 Resource Pixel Icons + Counts
	var keys = ["iron", "food", "energy", "semiconductor"]
	var rx = r.position.x + 14
	var ry = r.position.y + 27
	for k in keys:
		if res_textures.get(k):
			draw_texture_rect(res_textures[k], Rect2(rx, ry, 14, 14), false)
		draw_string(font, Vector2(rx + 16, ry + 12), str(c_data[k]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.25, 0.18, 0.12))
		rx += 42
