"""
글로벌 무역 대작전 - 클라우드/학교 방화벽 우회용 WebSocket 중계 서버
- 외부 라이브러리 설치 없이 Python 3 기본 내장 모듈만으로 동작합니다.
- 일반 웹사이트와 동일한 WebSocket(TCP) 통신을 사용하여 교육청 유/무선 망 분리 및 P2P 차단을 우회합니다.
- 다른 탭(유튜브 등) 시청으로 브라우저가 절전되어도 방이 유지되도록 Keep-Alive 및 재접속을 지원합니다.
"""

import asyncio
import base64
import hashlib
import json
import os
import random
import struct
import time

HOST = os.environ.get("HOST", "0.0.0.0")
PORT = int(os.environ.get("PORT", "8765"))
ROOM_TTL_SECONDS = 3 * 3600  # 3시간 동안 방 유지

GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"

# rooms[code] = { "host": ws_conn_or_None, "clients": {peer_id: ws_conn}, "last_active": float }
rooms = {}
next_peer_id = 2


class WSConn:
    def __init__(self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
        self.reader = reader
        self.writer = writer
        self.room_code = None
        self.is_host = False
        self.peer_id = 0
        self.closed = False

    async def send_json(self, obj: dict):
        if self.closed:
            return
        try:
            payload = json.dumps(obj, ensure_ascii=False).encode("utf-8")
            frame = self._encode_frame(0x1, payload)
            self.writer.write(frame)
            await self.writer.drain()
        except Exception:
            self.closed = True

    async def send_pong(self, data: bytes):
        if self.closed:
            return
        try:
            self.writer.write(self._encode_frame(0xA, data))
            await self.writer.drain()
        except Exception:
            self.closed = True

    def _encode_frame(self, opcode: int, payload: bytes) -> bytes:
        header = bytearray([0x80 | opcode])
        length = len(payload)
        if length < 126:
            header.append(length)
        elif length < 65536:
            header.append(126)
            header.extend(struct.pack("!H", length))
        else:
            header.append(127)
            header.extend(struct.pack("!Q", length))
        return bytes(header) + payload

    async def read_message(self):
        while not self.closed:
            b1, b2 = await self.reader.readexactly(2)
            opcode = b1 & 0x0F
            masked = (b2 & 0x80) != 0
            length = b2 & 0x7F
            if length == 126:
                (length,) = struct.unpack("!H", await self.reader.readexactly(2))
            elif length == 127:
                (length,) = struct.unpack("!Q", await self.reader.readexactly(8))

            mask_key = await self.reader.readexactly(4) if masked else b""
            data = bytearray(await self.reader.readexactly(length))
            if masked:
                for i in range(length):
                    data[i] ^= mask_key[i % 4]

            if opcode == 0x8:  # Close
                self.closed = True
                return None
            elif opcode == 0x9:  # Ping
                await self.send_pong(bytes(data))
                continue
            elif opcode == 0xA:  # Pong
                continue
            elif opcode in (0x1, 0x2):  # Text / Binary
                return bytes(data).decode("utf-8")
        return None


def generate_room_code() -> str:
    for _ in range(100):
        code = str(random.randint(1000, 9999))
        if code not in rooms:
            return code
    return str(random.randint(10000, 99999))


async def handle_client(reader: asyncio.StreamReader, writer: asyncio.StreamWriter):
    global next_peer_id
    conn = None
    try:
        # HTTP WebSocket Handshake
        raw_headers = await reader.readuntil(b"\r\n\r\n")
        header_text = raw_headers.decode("utf-8", errors="ignore")
        ws_key = None
        for line in header_text.split("\r\n"):
            if line.lower().startswith("sec-websocket-key:"):
                ws_key = line.split(":", 1)[1].strip()
                break

        if not ws_key:
            # 일반 브라우저 HTTP 접속 시 안내 페이지 반환
            body = "Global Trade Relay Server Running!".encode("utf-8")
            resp = (
                "HTTP/1.1 200 OK\r\n"
                "Content-Type: text/plain; charset=utf-8\r\n"
                f"Content-Length: {len(body)}\r\n\r\n"
            ).encode("utf-8") + body
            writer.write(resp)
            await writer.drain()
            writer.close()
            return

        accept_val = base64.b64encode(
            hashlib.sha1((ws_key + GUID).encode("utf-8")).digest()
        ).decode("utf-8")
        handshake = (
            "HTTP/1.1 101 Switching Protocols\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            f"Sec-WebSocket-Accept: {accept_val}\r\n\r\n"
        )
        writer.write(handshake.encode("utf-8"))
        await writer.drain()

        conn = WSConn(reader, writer)
        while not conn.closed:
            msg_str = await conn.read_message()
            if msg_str is None:
                break
            try:
                msg = json.loads(msg_str)
            except Exception:
                continue

            mtype = msg.get("type", "")

            if mtype == "ping":
                if conn.room_code and conn.room_code in rooms:
                    rooms[conn.room_code]["last_active"] = time.time()
                await conn.send_json({"type": "pong"})

            elif mtype == "create_room":
                req_code = str(msg.get("code", "")).strip()
                code = req_code if (req_code and req_code not in rooms) else generate_room_code()
                rooms[code] = {
                    "host": conn,
                    "clients": {},
                    "last_active": time.time(),
                }
                conn.room_code = code
                conn.is_host = True
                conn.peer_id = 1
                print(f"[방 생성] 방 코드: {code}")
                await conn.send_json({"type": "room_created", "code": code})

            elif mtype == "rejoin_host":
                code = str(msg.get("code", "")).strip()
                if code in rooms:
                    rooms[code]["host"] = conn
                    rooms[code]["last_active"] = time.time()
                    conn.room_code = code
                    conn.is_host = True
                    conn.peer_id = 1
                    print(f"[방장 재접속] 방 코드: {code}")
                    await conn.send_json({"type": "room_created", "code": code})
                else:
                    await conn.send_json({"type": "error", "message": "방을 찾을 수 없습니다."})

            elif mtype == "join_room":
                code = str(msg.get("code", "")).strip()
                if code not in rooms:
                    await conn.send_json({"type": "error", "message": f"방 코드 '{code}'를 찾을 수 없습니다."})
                    continue
                pid = next_peer_id
                next_peer_id += 1
                conn.room_code = code
                conn.is_host = False
                conn.peer_id = pid
                rooms[code]["clients"][pid] = conn
                rooms[code]["last_active"] = time.time()
                print(f"[학생 입장] 방 {code} <- peer {pid}")
                await conn.send_json({"type": "joined", "code": code, "peer_id": pid})
                host_ws = rooms[code]["host"]
                if host_ws and not host_ws.closed:
                    await host_ws.send_json({"type": "peer_joined", "peer_id": pid})

            elif mtype == "relay":
                code = conn.room_code
                if not code or code not in rooms:
                    continue
                room = rooms[code]
                room["last_active"] = time.time()
                payload = msg.get("payload", {})
                target = msg.get("target", "all")

                if conn.is_host:
                    # 호스트 -> 전체 또는 특정 학생에게 전달
                    out = {"type": "relay", "from": 1, "payload": payload}
                    if target == "all":
                        for pid, cws in list(room["clients"].items()):
                            await cws.send_json(out)
                    elif isinstance(target, int) and target in room["clients"]:
                        await room["clients"][target].send_json(out)
                else:
                    # 학생 -> 호스트에게 전달
                    host_ws = room["host"]
                    if host_ws and not host_ws.closed:
                        await host_ws.send_json({
                            "type": "relay",
                            "from": conn.peer_id,
                            "payload": payload,
                        })

    except (asyncio.IncompleteReadError, ConnectionResetError, BrokenPipeError):
        pass
    except Exception as e:
        print(f"[연결 오류] {e}")
    finally:
        if conn and conn.room_code and conn.room_code in rooms:
            room = rooms[conn.room_code]
            if conn.is_host:
                # 브라우저 절전 등으로 호스트가 잠시 끊겨도 방을 즉시 지우지 않고 유지
                if room["host"] is conn:
                    room["host"] = None
                print(f"[방장 일시 이탈] 방 {conn.room_code} (유지 중)")
            else:
                if conn.peer_id in room["clients"]:
                    del room["clients"][conn.peer_id]
                    host_ws = room["host"]
                    if host_ws and not host_ws.closed:
                        await host_ws.send_json({"type": "peer_left", "peer_id": conn.peer_id})
        try:
            writer.close()
        except Exception:
            pass


async def cleanup_expired_rooms():
    while True:
        await asyncio.sleep(60)
        now = time.time()
        expired = [c for c, r in rooms.items() if now - r["last_active"] > ROOM_TTL_SECONDS]
        for c in expired:
            del rooms[c]
            print(f"[방 만료 삭제] {c}")


async def main():
    server = await asyncio.start_server(handle_client, HOST, PORT)
    print(f"==================================================")
    print(f" 글로벌 무역 대작전 - 클라우드 중계 서버 가동 중")
    print(f" 주소: ws://{HOST}:{PORT}")
    print(f"==================================================")
    asyncio.create_task(cleanup_expired_rooms())
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    asyncio.run(main())
