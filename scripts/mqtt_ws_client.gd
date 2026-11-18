class_name MqttWsClient
extends RefCounted

signal mqtt_connected
signal mqtt_disconnected
signal mqtt_message(topic: String, payload: String)

var ws := WebSocketPeer.new()
var broker_url: String = ""
var client_id: String = ""
var is_ws_open: bool = false
var is_mqtt_ready: bool = false
var connecting: bool = false
var ping_timer: float = 0.0
var packet_id_counter: int = 1
var rx_buffer := PackedByteArray()

func connect_broker(url: String):
	close()
	broker_url = url
	client_id = "hamo_trade_%d_%d" % [randi() % 999999, Time.get_ticks_msec() % 100000]
	ws = WebSocketPeer.new()
	ws.supported_protocols = PackedStringArray(["mqtt"])
	ws.inbound_buffer_size = 131072
	ws.outbound_buffer_size = 131072
	var err = ws.connect_to_url(url)
	connecting = (err == OK)
	return err

func close():
	if ws.get_ready_state() != WebSocketPeer.STATE_CLOSED:
		ws.close()
	is_ws_open = false
	is_mqtt_ready = false
	connecting = false
	rx_buffer.clear()

func poll(delta: float):
	if not connecting and not is_ws_open:
		return

	ws.poll()
	var state = ws.get_ready_state()

	if state == WebSocketPeer.STATE_OPEN:
		if not is_ws_open:
			is_ws_open = true
			_send_connect()

		if is_mqtt_ready:
			ping_timer += delta
			if ping_timer >= 10.0:
				ping_timer = 0.0
				_send_ping()

		while ws.get_available_packet_count() > 0:
			var pkt = ws.get_packet()
			rx_buffer.append_array(pkt)
			_process_rx_buffer()

	elif state == WebSocketPeer.STATE_CLOSED:
		if is_ws_open or connecting:
			is_ws_open = false
			is_mqtt_ready = false
			connecting = false
			mqtt_disconnected.emit()

func subscribe(topic: String):
	if not is_mqtt_ready:
		return
	var pid = packet_id_counter
	packet_id_counter = (packet_id_counter % 65000) + 1
	var body := PackedByteArray()
	body.append((pid >> 8) & 0xFF)
	body.append(pid & 0xFF)
	body.append_array(_encode_str(topic))
	body.append(0x00) # QoS 0
	var pkt := PackedByteArray([0x82])
	pkt.append_array(_encode_rem_len(body.size()))
	pkt.append_array(body)
	ws.send(pkt, WebSocketPeer.WRITE_MODE_BINARY)

func publish(topic: String, payload: String):
	if not is_mqtt_ready:
		return
	var body := PackedByteArray()
	body.append_array(_encode_str(topic))
	body.append_array(payload.to_utf8_buffer())
	var pkt := PackedByteArray([0x30]) # PUBLISH QoS 0
	pkt.append_array(_encode_rem_len(body.size()))
	pkt.append_array(body)
	ws.send(pkt, WebSocketPeer.WRITE_MODE_BINARY)

func _send_connect():
	var vh := PackedByteArray([
		0x00, 0x04, 0x4D, 0x51, 0x54, 0x54, # "MQTT"
		0x04, # Level 4 (3.1.1)
		0x02, # Clean session
		0x03, 0x84 # Keepalive 900s (15 minutes!)
	])
	var pl := _encode_str(client_id)
	var body := PackedByteArray()
	body.append_array(vh)
	body.append_array(pl)
	var pkt := PackedByteArray([0x10])
	pkt.append_array(_encode_rem_len(body.size()))
	pkt.append_array(body)
	ws.send(pkt, WebSocketPeer.WRITE_MODE_BINARY)

func _send_ping():
	if is_mqtt_ready and ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		ws.send(PackedByteArray([0xC0, 0x00]), WebSocketPeer.WRITE_MODE_BINARY)

func _process_rx_buffer():
	while rx_buffer.size() >= 2:
		var header = rx_buffer[0]
		var mult = 1
		var rem_len = 0
		var idx = 1
		var complete_len = false
		while idx < rx_buffer.size():
			var b = rx_buffer[idx]
			rem_len += (b & 0x7F) * mult
			idx += 1
			if (b & 0x80) == 0:
				complete_len = true
				break
			mult *= 128
			if idx > 4:
				rx_buffer.clear()
				return
		if not complete_len:
			return
		var total_len = idx + rem_len
		if rx_buffer.size() < total_len:
			return

		var payload_bytes = rx_buffer.slice(idx, total_len)
		rx_buffer = rx_buffer.slice(total_len)

		var ptype = header & 0xF0
		if ptype == 0x20: # CONNACK
			if payload_bytes.size() >= 2 and payload_bytes[1] == 0x00:
				is_mqtt_ready = true
				ping_timer = 0.0
				mqtt_connected.emit()
		elif ptype == 0x30: # PUBLISH
			_handle_publish(header, payload_bytes)
		elif ptype == 0xD0: # PINGRESP
			pass

func _handle_publish(header: int, data: PackedByteArray):
	if data.size() < 2:
		return
	var tlen = (data[0] << 8) | data[1]
	if data.size() < 2 + tlen:
		return
	var topic = data.slice(2, 2 + tlen).get_string_from_utf8()
	var pos = 2 + tlen
	var qos = (header >> 1) & 0x03
	if qos > 0:
		pos += 2 # skip packet id
	var msg = data.slice(pos).get_string_from_utf8()
	mqtt_message.emit(topic, msg)

func _encode_str(s: String) -> PackedByteArray:
	var utf8 = s.to_utf8_buffer()
	var out := PackedByteArray()
	out.append((utf8.size() >> 8) & 0xFF)
	out.append(utf8.size() & 0xFF)
	out.append_array(utf8)
	return out

func _encode_rem_len(length: int) -> PackedByteArray:
	var out := PackedByteArray()
	while true:
		var digit = length % 128
		length = length / 128
		if length > 0:
			digit |= 0x80
		out.append(digit)
		if length <= 0:
			break
	return out
