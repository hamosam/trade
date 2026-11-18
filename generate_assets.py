import os
import math
import struct
import zlib
import wave

os.makedirs('assets/sprites', exist_ok=True)
os.makedirs('assets/audio', exist_ok=True)
os.makedirs('assets/ui', exist_ok=True)

def create_png(width, height, rgba_data):
    def chunk(tag, data):
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff)
    raw = b''
    for y in range(height):
        raw += b'\x00' + rgba_data[y * width * 4:(y + 1) * width * 4]
    return b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')

class PixelCanvas:
    def __init__(self, w, h):
        self.w = w
        self.h = h
        self.buf = bytearray(w * h * 4)

    def set_pixel(self, x, y, r, g, b, a=255):
        if 0 <= x < self.w and 0 <= y < self.h:
            idx = (int(y) * self.w + int(x)) * 4
            self.buf[idx] = r
            self.buf[idx+1] = g
            self.buf[idx+2] = b
            self.buf[idx+3] = a

    def fill_rect(self, x0, y0, w, h, r, g, b, a=255):
        for y in range(y0, y0 + h):
            for x in range(x0, x0 + w):
                self.set_pixel(x, y, r, g, b, a)

    def draw_circle(self, cx, cy, rad, r, g, b, a=255):
        for y in range(cy - rad, cy + rad + 1):
            for x in range(cx - rad, cx + rad + 1):
                if (x - cx)**2 + (y - cy)**2 <= rad**2:
                    self.set_pixel(x, y, r, g, b, a)

    def save(self, path):
        with open(path, 'wb') as f:
            f.write(create_png(self.w, self.h, bytes(self.buf)))
        print(f"Generated: {path}")

# ========================================================
# 1. RESOURCE ICONS (32x32)
# ========================================================

# 1-1. Iron Ore (res_iron.png)
def make_iron_ore():
    c = PixelCanvas(32, 32)
    # Jagged rock base
    points = [
        (10, 6), (22, 6), (26, 12), (28, 22), (22, 27), (10, 27), (4, 21), (6, 11)
    ]
    # Fill rough rock
    for y in range(5, 29):
        for x in range(4, 29):
            dx = abs(x - 16)
            dy = abs(y - 17)
            if dx*dx + dy*dy <= 12*12 + ((x+y)%3):
                c.set_pixel(x, y, 75, 80, 95)
    # Highlights & facets
    for y in range(8, 26):
        for x in range(7, 26):
            if (x < 18 and y < 19) or ((x-y) % 5 == 0):
                c.set_pixel(x, y, 140, 150, 175)
            elif (x < 13 and y < 14):
                c.set_pixel(x, y, 210, 225, 245) # specular shine
            elif x > 20 or y > 22:
                c.set_pixel(x, y, 45, 50, 65) # deep shadow
    # Dark outline
    for y in range(5, 29):
        for x in range(4, 29):
            idx = (y * 32 + x) * 4
            if c.buf[idx+3] > 0:
                for nx, ny in [(x+1, y), (x-1, y), (x, y+1), (x, y-1)]:
                    if 0 <= nx < 32 and 0 <= ny < 32:
                        nidx = (ny * 32 + nx) * 4
                        if c.buf[nidx+3] == 0:
                            c.set_pixel(x, y, 25, 28, 38)
                            break
    c.save('assets/sprites/res_iron.png')

# 1-2. Food / Wheat & Apple (res_food.png)
def make_food():
    c = PixelCanvas(32, 32)
    # Golden wheat stalks
    for x in range(12, 22):
        c.set_pixel(x, 26 - (x - 16)**2 // 4, 180, 130, 40)
    # Wheat ears
    ears = [(10, 14), (12, 11), (14, 8), (17, 8), (19, 11), (21, 14), (16, 5)]
    for ex, ey in ears:
        c.draw_circle(ex, ey, 2, 240, 200, 70)
        c.set_pixel(ex-1, ey-1, 255, 240, 150)
        c.set_pixel(ex+1, ey+1, 190, 140, 30)
    # Red apple in front
    c.draw_circle(14, 22, 6, 210, 45, 40)
    c.draw_circle(18, 22, 6, 225, 50, 45)
    # Apple highlight
    c.draw_circle(13, 19, 2, 255, 120, 110)
    c.set_pixel(13, 19, 255, 255, 255)
    # Apple leaf & stem
    c.set_pixel(16, 15, 110, 70, 30)
    c.set_pixel(17, 14, 70, 170, 50)
    c.set_pixel(18, 14, 90, 200, 60)
    c.set_pixel(19, 15, 60, 140, 40)
    c.save('assets/sprites/res_food.png')

# 1-3. Energy / Lightning Crystal Battery (res_energy.png)
def make_energy():
    c = PixelCanvas(32, 32)
    # Outer cyan crystal
    for y in range(4, 28):
        for x in range(8, 24):
            dx = abs(x - 16)
            dy = abs(y - 16)
            if dx * 1.5 + dy * 0.9 <= 13:
                c.set_pixel(x, y, 30, 140, 220, 240)
    # Core lightning glow
    c.draw_circle(16, 16, 6, 120, 230, 255)
    # Bright lightning bolt shape
    bolt_coords = [
        (16, 7), (17, 8), (16, 9), (15, 10), (16, 11), (15, 12), (14, 13), (15, 14),
        (13, 15), (14, 15), (15, 15), (16, 15), (17, 15), (18, 15),
        (17, 16), (16, 17), (17, 18), (18, 19), (17, 20), (16, 21), (17, 22), (18, 23), (17, 24)
    ]
    for bx, by in bolt_coords:
        c.draw_circle(bx, by, 1, 255, 255, 180)
        c.set_pixel(bx, by, 255, 255, 255)
    # Crystal facets
    for y in range(6, 26):
        c.set_pixel(11, y, 160, 240, 255)
        c.set_pixel(21, y, 15, 90, 160)
    c.save('assets/sprites/res_energy.png')

# 1-4. Semiconductor / Microchip (res_semiconductor.png)
def make_semiconductor():
    c = PixelCanvas(32, 32)
    # Golden connector pins on 4 sides
    pins = [10, 13, 16, 19, 22]
    for p in pins:
        c.fill_rect(p, 4, 2, 3, 240, 190, 40) # Top
        c.fill_rect(p, 25, 2, 3, 240, 190, 40) # Bottom
        c.fill_rect(4, p, 3, 2, 240, 190, 40) # Left
        c.fill_rect(25, p, 3, 2, 240, 190, 40) # Right
    # Green PCB board
    c.fill_rect(7, 7, 18, 18, 30, 130, 60)
    c.fill_rect(8, 8, 16, 16, 45, 160, 75)
    # Black central processor package
    c.fill_rect(10, 10, 12, 12, 35, 38, 45)
    c.fill_rect(11, 11, 10, 10, 50, 55, 65)
    # Silicon core with silver text/notch
    c.set_pixel(12, 12, 200, 200, 210) # pin 1 notch
    c.fill_rect(13, 14, 6, 4, 180, 200, 220)
    # Circuit golden traces
    c.set_pixel(8, 11, 220, 180, 50)
    c.set_pixel(9, 11, 220, 180, 50)
    c.set_pixel(22, 15, 220, 180, 50)
    c.set_pixel(23, 15, 220, 180, 50)
    c.save('assets/sprites/res_semiconductor.png')

# 1-5. Assembled Smartphone (res_phone.png)
def make_smartphone():
    c = PixelCanvas(32, 32)
    # Phone body (rounded dark metallic frame)
    c.fill_rect(9, 3, 14, 26, 40, 44, 55)
    # Beveled edge
    c.fill_rect(10, 2, 12, 28, 40, 44, 55)
    # Glossy frame highlight
    c.fill_rect(9, 3, 1, 26, 90, 95, 110)
    c.fill_rect(10, 3, 12, 1, 90, 95, 110)
    # Bright glowing glass display
    c.fill_rect(11, 6, 10, 20, 25, 100, 180)
    for y in range(7, 25):
        for x in range(11, 21):
            grad = (y - 7) * 4
            c.set_pixel(x, y, 30 + grad, 120 + grad, 210 + grad // 2)
    # Screen glass reflection stripe
    for i in range(7):
        c.set_pixel(12 + i, 8 + i*2, 200, 240, 255)
        c.set_pixel(13 + i, 8 + i*2, 230, 250, 255)
    # Camera punch hole
    c.set_pixel(16, 4, 20, 22, 28)
    # Home bar indicator
    c.fill_rect(14, 24, 4, 1, 220, 240, 255)
    # Golden Sparkles outside phone
    sparkles = [(5, 5), (6, 6), (26, 7), (25, 8), (4, 24), (27, 22)]
    for sx, sy in sparkles:
        c.set_pixel(sx, sy, 255, 235, 100)
    c.set_pixel(5, 6, 255, 255, 200)
    c.set_pixel(26, 8, 255, 255, 200)
    c.save('assets/sprites/res_phone.png')

# 1-6. Gold Coin (res_gold.png)
def make_gold_coin():
    c = PixelCanvas(32, 32)
    # Outer golden ring
    c.draw_circle(16, 16, 12, 190, 130, 20)
    c.draw_circle(16, 16, 10, 245, 195, 40)
    # Inner face
    c.draw_circle(16, 16, 8, 255, 225, 75)
    # Embossed 'G' symbol
    g_pixels = [
        (14, 12), (15, 12), (16, 12), (17, 12),
        (13, 13), (13, 14), (13, 15), (13, 16), (13, 17), (13, 18),
        (14, 19), (15, 19), (16, 19), (17, 19), (18, 19),
        (18, 16), (18, 17), (18, 18),
        (16, 16), (17, 16)
    ]
    for gx, gy in g_pixels:
        c.set_pixel(gx, gy, 180, 120, 15)
        c.set_pixel(gx-1, gy-1, 255, 250, 160)
    # Coin top shine
    c.set_pixel(11, 10, 255, 255, 240)
    c.set_pixel(12, 10, 255, 255, 240)
    c.set_pixel(10, 11, 255, 255, 240)
    c.save('assets/sprites/res_gold.png')

# ========================================================
# 2. CARGO SHIP SPRITE (36x36)
# ========================================================
def make_cargo_ship():
    c = PixelCanvas(36, 36)
    # Hull (Sturdy wooden/steel boat hull)
    for y in range(20, 28):
        indent = (y - 20)
        c.fill_rect(5 + indent, y, 26 - indent * 2, 1, 120, 50, 30)
    # Hull water line & bottom
    c.fill_rect(7, 27, 22, 1, 80, 30, 20)
    # Deck
    c.fill_rect(7, 19, 22, 2, 200, 160, 110)
    # Wheelhouse / Bridge (rear)
    c.fill_rect(22, 13, 6, 6, 230, 230, 240)
    c.fill_rect(23, 15, 4, 2, 50, 120, 180) # windows
    # Smokestack & cute steam puff
    c.fill_rect(24, 9, 2, 4, 180, 40, 40)
    c.draw_circle(24, 6, 2, 220, 220, 230, 200)
    c.draw_circle(23, 3, 2, 240, 240, 245, 160)
    # Colorful cargo containers stacked on deck!
    # Container 1 (Red)
    c.fill_rect(8, 14, 6, 5, 200, 45, 40)
    c.fill_rect(9, 15, 4, 3, 230, 70, 60)
    # Container 2 (Blue)
    c.fill_rect(15, 14, 6, 5, 40, 110, 200)
    c.fill_rect(16, 15, 4, 3, 60, 140, 230)
    # Container 3 (Gold) top stack
    c.fill_rect(12, 10, 6, 4, 230, 180, 30)
    # Bow flag
    c.fill_rect(5, 15, 1, 4, 180, 180, 190)
    c.fill_rect(3, 15, 2, 2, 255, 60, 60)
    c.save('assets/sprites/ship_cargo.png')

def make_ship_wake():
    c = PixelCanvas(16, 16)
    c.draw_circle(8, 8, 6, 255, 255, 255, 180)
    c.draw_circle(8, 8, 4, 180, 230, 255, 220)
    c.save('assets/sprites/ship_wake.png')

# ========================================================
# 3. COUNTRY BUILDINGS / LANDMARKS (48x48)
# ========================================================

# 3-1. Iron Smelter / Forge (building_iron.png)
def make_building_iron():
    c = PixelCanvas(48, 48)
    # Stone furnace base
    c.fill_rect(8, 20, 32, 24, 85, 80, 85)
    c.fill_rect(10, 22, 28, 20, 115, 110, 120)
    # Dark stone roof with chimney
    c.fill_rect(12, 14, 24, 6, 60, 55, 60)
    c.fill_rect(16, 6, 6, 8, 70, 65, 70) # chimney
    c.fill_rect(26, 6, 6, 8, 70, 65, 70)
    # Smoke puff
    c.draw_circle(19, 4, 3, 180, 180, 190, 180)
    c.draw_circle(29, 3, 3, 180, 180, 190, 180)
    # Glowing molten metal furnace opening
    c.draw_circle(24, 32, 7, 240, 100, 20)
    c.draw_circle(24, 33, 5, 255, 210, 50)
    # Anvil in front
    c.fill_rect(32, 34, 10, 4, 50, 55, 65)
    c.fill_rect(34, 38, 6, 4, 40, 45, 55)
    c.save('assets/sprites/building_iron.png')

# 3-2. Agricultural Windmill & Farm (building_agri.png)
def make_building_agri():
    c = PixelCanvas(48, 48)
    # Red wooden barn body
    c.fill_rect(14, 20, 20, 24, 180, 55, 45)
    c.fill_rect(16, 22, 16, 20, 210, 75, 60)
    # Barn roof (slanted)
    for i in range(12):
        c.fill_rect(13 + i, 20 - i, 22 - i*2, 1, 120, 35, 30)
    # Barn door
    c.fill_rect(20, 32, 8, 12, 130, 90, 50)
    # Windmill blades (cross)
    cx, cy = 24, 15
    c.draw_circle(cx, cy, 3, 80, 60, 40)
    for r in range(4, 16):
        c.set_pixel(cx + r, cy, 240, 240, 230)
        c.set_pixel(cx - r, cy, 240, 240, 230)
        c.set_pixel(cx, cy + r, 240, 240, 230)
        c.set_pixel(cx, cy - r, 240, 240, 230)
        # sail canvas
        c.set_pixel(cx + r, cy - 1, 255, 255, 250)
        c.set_pixel(cx - r, cy + 1, 255, 255, 250)
        c.set_pixel(cx + 1, cy + r, 255, 255, 250)
        c.set_pixel(cx - 1, cy - r, 255, 255, 250)
    # Wheat stalks around base
    for wx in range(6, 14):
        c.set_pixel(wx, 40 - (wx % 3), 230, 190, 50)
    for wx in range(34, 42):
        c.set_pixel(wx, 40 - (wx % 3), 230, 190, 50)
    c.save('assets/sprites/building_agri.png')

# 3-3. High-Tech Research Lab Dome (building_tech.png)
def make_building_tech():
    c = PixelCanvas(48, 48)
    # Glass biodome / clean facility
    c.draw_circle(24, 26, 16, 60, 150, 220)
    c.draw_circle(24, 26, 14, 120, 210, 255)
    # High-tech base ring
    c.fill_rect(6, 32, 36, 12, 70, 80, 95)
    c.fill_rect(8, 34, 32, 8, 110, 125, 145)
    # Neon blue light lines
    c.fill_rect(8, 33, 32, 2, 40, 230, 255)
    c.fill_rect(8, 41, 32, 1, 40, 230, 255)
    # Satellite dish / radar antenna on top
    c.fill_rect(23, 4, 2, 7, 180, 190, 205)
    c.draw_circle(20, 5, 4, 210, 220, 235)
    c.draw_circle(20, 5, 3, 140, 150, 165)
    # Lab entrance airlock
    c.fill_rect(20, 36, 8, 8, 35, 45, 60)
    c.fill_rect(21, 37, 6, 7, 50, 180, 240)
    c.save('assets/sprites/building_tech.png')

# 3-4. Energy Substation & Tesla Reactor (building_energy.png)
def make_building_energy():
    c = PixelCanvas(48, 48)
    # Reactor platform
    c.fill_rect(8, 30, 32, 14, 55, 60, 70)
    c.fill_rect(10, 32, 28, 10, 85, 95, 110)
    # Glowing Energy Core Chamber (Yellow/Cyan)
    c.fill_rect(16, 16, 16, 16, 40, 45, 55)
    c.fill_rect(18, 18, 12, 12, 255, 200, 30)
    c.draw_circle(24, 24, 4, 255, 255, 200)
    # Twin Tesla Coils
    for tx in [12, 36]:
        c.fill_rect(tx-2, 12, 4, 18, 140, 150, 165)
        # Rings
        c.fill_rect(tx-4, 14, 8, 2, 210, 180, 40)
        c.fill_rect(tx-4, 19, 8, 2, 210, 180, 40)
        c.fill_rect(tx-4, 24, 8, 2, 210, 180, 40)
        # Top sphere
        c.draw_circle(tx, 10, 4, 80, 220, 255)
        c.draw_circle(tx, 10, 2, 255, 255, 255)
    # Electric arc connecting coils
    c.set_pixel(18, 9, 255, 255, 220)
    c.set_pixel(24, 8, 255, 255, 255)
    c.set_pixel(30, 9, 255, 255, 220)
    c.save('assets/sprites/building_energy.png')

# 3-5. Port Lighthouse & Pier (building_port.png)
def make_building_port():
    c = PixelCanvas(48, 48)
    # Wooden pier stretching out
    c.fill_rect(4, 36, 40, 8, 120, 80, 45)
    for px in [8, 16, 24, 32, 40]:
        c.fill_rect(px, 42, 2, 6, 75, 50, 30) # stilts
    # Lighthouse tower
    for y in range(12, 36):
        w = 12 - (36 - y) // 4
        c.fill_rect(14 + (12 - w)//2, y, w, 1, 235, 235, 240)
    # Red stripes on lighthouse
    c.fill_rect(14, 18, 10, 4, 210, 50, 45)
    c.fill_rect(13, 27, 12, 4, 210, 50, 45)
    # Light room & lantern top
    c.fill_rect(14, 8, 10, 5, 255, 230, 80)
    c.draw_circle(19, 10, 2, 255, 255, 255)
    # Conical roof
    for r in range(4):
        c.fill_rect(16 + r, 7 - r, 6 - r*2, 1, 50, 60, 75)
    # Mooring posts & lifebuoy
    c.fill_rect(34, 32, 3, 5, 160, 120, 80)
    c.draw_circle(36, 30, 3, 230, 60, 50)
    c.draw_circle(36, 30, 1, 255, 255, 255)
    c.save('assets/sprites/building_port.png')

# 3-6. Trade Union Grand Merchant Hall / Bank (building_trade.png)
def make_building_trade():
    c = PixelCanvas(48, 48)
    # Classical marble stone pediment & columns
    c.fill_rect(6, 38, 36, 6, 170, 160, 150) # base stairs
    c.fill_rect(8, 40, 32, 2, 210, 205, 195)
    # 4 Greek columns
    for col_x in [10, 18, 26, 34]:
        c.fill_rect(col_x, 18, 4, 20, 230, 225, 220)
        c.fill_rect(col_x-1, 18, 6, 2, 245, 240, 235)
        c.fill_rect(col_x-1, 36, 6, 2, 245, 240, 235)
    # Background wall behind columns (rich purple/royal blue)
    c.fill_rect(12, 19, 24, 17, 100, 45, 130)
    # Wooden double doors
    c.fill_rect(21, 26, 6, 10, 120, 80, 45)
    # Triangular pediment roof
    for y in range(9):
        c.fill_rect(6 + y*2, 17 - y, 36 - y*4, 1, 220, 210, 195)
    # Golden Scales of Trade medallion on pediment
    c.draw_circle(24, 14, 3, 255, 210, 40)
    c.save('assets/sprites/building_trade.png')

# ========================================================
# 4. STARDEW-STYLE RETRO UI ASSETS
# ========================================================

def make_stardew_panel():
    # 48x48 9-patch frame with authentic wooden texture & carved beveled border
    w, h = 48, 48
    c = PixelCanvas(w, h)
    # 1. Dark wood rim outer (3px)
    c.fill_rect(0, 0, w, h, 65, 36, 18)
    # 2. Golden brass highlight trim (1px)
    c.fill_rect(2, 2, w-4, h-4, 195, 145, 75)
    # 3. Inner shadow rim (1px)
    c.fill_rect(3, 3, w-6, h-6, 115, 68, 32)
    # 4. Warm parchment / honey wood center
    c.fill_rect(4, 4, w-8, h-8, 238, 206, 155)
    # Wood grain pattern
    for y in range(4, h-4):
        for x in range(4, w-8):
            if (y * 7 + x * 3) % 19 == 0:
                c.set_pixel(x, y, 225, 190, 140)
            elif (y * 5 + x * 11) % 29 == 0:
                c.set_pixel(x, y, 245, 218, 170)
    # Corner rivets
    for cx, cy in [(4, 4), (w-5, 4), (4, h-5), (w-5, h-5)]:
        c.draw_circle(cx, cy, 1, 140, 95, 45)
        c.set_pixel(cx, cy, 255, 225, 120)
    c.save('assets/ui/wood_panel.png')

def make_stardew_slot():
    w, h = 36, 36
    c = PixelCanvas(w, h)
    # Deep recessed item slot
    c.fill_rect(0, 0, w, h, 70, 40, 20)
    c.fill_rect(1, 1, w-2, h-2, 45, 25, 12)
    c.fill_rect(2, 2, w-4, h-4, 140, 100, 60)
    c.fill_rect(3, 3, w-6, h-6, 190, 150, 100)
    c.fill_rect(4, 4, w-8, h-8, 220, 185, 135)
    c.save('assets/ui/item_slot.png')

def make_stardew_button():
    # Normal button
    w, h = 48, 24
    c = PixelCanvas(w, h)
    c.fill_rect(0, 0, w, h, 65, 36, 18)
    c.fill_rect(1, 1, w-2, h-2, 215, 165, 85)
    c.fill_rect(2, 2, w-4, h-4, 180, 125, 60)
    c.fill_rect(2, 2, w-4, 2, 245, 205, 130) # top highlight
    c.save('assets/ui/wood_btn_normal.png')

    # Pressed button
    c_pressed = PixelCanvas(w, h)
    c_pressed.fill_rect(0, 0, w, h, 45, 24, 12)
    c_pressed.fill_rect(1, 1, w-2, h-2, 130, 85, 40)
    c_pressed.fill_rect(2, 2, w-4, h-4, 150, 100, 50)
    c_pressed.fill_rect(2, h-4, w-4, 2, 190, 140, 70)
    c_pressed.save('assets/ui/wood_btn_pressed.png')

# ========================================================
# 5. ROLE ICONS (32x32)
# ========================================================

def make_role_icons():
    # Diplomat (Scroll & feather quill)
    c = PixelCanvas(32, 32)
    c.fill_rect(6, 8, 16, 18, 235, 220, 175) # parchment
    c.fill_rect(5, 7, 18, 2, 200, 170, 120)
    c.fill_rect(5, 25, 18, 2, 200, 170, 120)
    # Wax seal
    c.draw_circle(14, 17, 3, 200, 45, 40)
    # Quill
    for i in range(12):
        c.set_pixel(16 + i, 22 - i, 240, 240, 250)
        c.set_pixel(17 + i, 22 - i, 160, 200, 240)
    c.save('assets/sprites/role_diplomat.png')

    # Treasurer (Chest & gold coins)
    c = PixelCanvas(32, 32)
    c.fill_rect(6, 14, 20, 14, 130, 80, 40)
    c.fill_rect(8, 10, 16, 6, 160, 100, 50) # lid
    c.fill_rect(6, 13, 20, 2, 240, 190, 40) # brass band
    c.fill_rect(14, 16, 4, 5, 255, 215, 60) # keyhole
    # Coins spilling
    for cx, cy in [(8, 25), (12, 26), (22, 25), (25, 23)]:
        c.draw_circle(cx, cy, 2, 255, 220, 40)
    c.save('assets/sprites/role_treasurer.png')

    # Technician (Wrench & gear)
    c = PixelCanvas(32, 32)
    c.draw_circle(16, 16, 8, 160, 170, 185)
    c.draw_circle(16, 16, 4, 40, 45, 55)
    # Gear teeth
    for deg in range(0, 360, 45):
        rad = math.radians(deg)
        gx = int(16 + math.cos(rad) * 10)
        gy = int(16 + math.sin(rad) * 10)
        c.fill_rect(gx-1, gy-1, 3, 3, 160, 170, 185)
    # Wrench crossing
    for i in range(14):
        c.set_pixel(9 + i, 23 - i, 220, 225, 235)
        c.set_pixel(10 + i, 23 - i, 180, 185, 195)
    c.save('assets/sprites/role_technician.png')

    # Analyst (Telescope / Chart)
    c = PixelCanvas(32, 32)
    # Bar chart in background
    c.fill_rect(6, 20, 4, 8, 80, 160, 240)
    c.fill_rect(12, 14, 4, 14, 90, 210, 110)
    c.fill_rect(18, 8, 4, 20, 245, 180, 50)
    c.fill_rect(24, 5, 4, 23, 235, 75, 70)
    # Trend arrow line
    for i in range(20):
        c.set_pixel(7 + i, 21 - i * 16 // 20, 255, 255, 255)
    c.save('assets/sprites/role_analyst.png')

    # Spokesperson (Golden Megaphone)
    c = PixelCanvas(32, 32)
    # Cone body
    for x in range(10, 24):
        h = (x - 10) * 14 // 14 + 4
        c.fill_rect(x, 16 - h//2, 1, h, 245, 195, 40)
    c.fill_rect(8, 14, 3, 4, 200, 140, 30) # mouthpiece
    # Handle
    c.fill_rect(12, 18, 3, 8, 120, 60, 25)
    # Sound waves
    for r in [26, 29]:
        for y in range(10, 23):
            if abs(y - 16) <= 5:
                c.set_pixel(r, y, 255, 235, 120)
    c.save('assets/sprites/role_spokesperson.png')

    # Teacher Admin (Graduation Cap & Golden Star)
    c = PixelCanvas(32, 32)
    # Cap rhombus
    for y in range(8, 18):
        w = 12 - abs(y - 13) * 2
        c.fill_rect(16 - w, y, w * 2, 1, 45, 50, 70)
    # Tassel
    c.set_pixel(16, 13, 240, 200, 50)
    c.fill_rect(17, 14, 4, 1, 240, 200, 50)
    c.fill_rect(21, 15, 2, 5, 240, 200, 50)
    # Skull cap base
    c.fill_rect(11, 18, 10, 5, 35, 40, 55)
    # Golden badge star below
    c.draw_circle(16, 26, 3, 255, 215, 50)
    c.set_pixel(16, 26, 255, 255, 220)
    c.save('assets/sprites/role_teacher.png')

# ========================================================
# 6. AUDIO SYNTHESIS (.WAV)
# ========================================================

def synth_wav(filename, samples, sample_rate=22050):
    with wave.open(filename, 'w') as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        raw = bytearray()
        for s in samples:
            s_clamped = max(-1.0, min(1.0, s))
            val = int(s_clamped * 32767 * 0.5)
            raw += struct.pack('<h', val)
        wf.writeframes(raw)
    print(f"Synthesized: {filename}")

def make_sounds():
    sr = 22050

    # 1. Click sound (Crisp UI click)
    dur = 0.04
    n = int(dur * sr)
    samples = []
    for i in range(n):
        t = i / sr
        env = (1.0 - t/dur)**2
        s = math.sin(2 * math.pi * 1200 * t) * env
        samples.append(s)
    synth_wav('assets/audio/click.wav', samples, sr)

    # 2. Coin sound (Retro 2-tone cheerful chime)
    dur = 0.25
    n = int(dur * sr)
    samples = []
    for i in range(n):
        t = i / sr
        if t < 0.1:
            freq = 987.77 # B5
            env = 1.0 - (t / 0.1) * 0.4
        else:
            freq = 1318.51 # E6
            env = 1.0 - ((t - 0.1) / 0.15)
        s = (math.sin(2 * math.pi * freq * t) + 0.3 * math.sin(4 * math.pi * freq * t)) * max(0.0, env)
        samples.append(s)
    synth_wav('assets/audio/coin.wav', samples, sr)

    # 3. Assemble smartphone fanfare (Triumphant 4-tone retro arpeggio)
    dur = 0.6
    n = int(dur * sr)
    samples = []
    notes = [523.25, 659.25, 783.99, 1046.50] # C5, E5, G5, C6
    for i in range(n):
        t = i / sr
        note_idx = min(3, int(t / 0.12))
        freq = notes[note_idx]
        note_t = t - note_idx * 0.12
        env = max(0.0, 1.0 - note_t / 0.25)
        s = (math.sin(2 * math.pi * freq * t) + 0.5 * math.sin(4 * math.pi * freq * t) + 0.25 * math.sin(6 * math.pi * freq * t)) * env
        samples.append(s)
    synth_wav('assets/audio/assemble.wav', samples, sr)

    # 4. Ship horn (Deep reverberating steam horn)
    dur = 0.7
    n = int(dur * sr)
    samples = []
    for i in range(n):
        t = i / sr
        env = math.sin(math.pi * min(1.0, t / dur))
        freq = 145.0 + math.sin(2 * math.pi * 5 * t) * 2.0
        s = (math.sin(2 * math.pi * freq * t) + 0.6 * math.sin(4 * math.pi * freq * t) + 0.3 * math.sin(6 * math.pi * freq * t)) * env
        samples.append(s)
    synth_wav('assets/audio/ship_horn.wav', samples, sr)

    # 5. News alarm (Urgent breaking news telegraph chime)
    dur = 0.5
    n = int(dur * sr)
    samples = []
    for i in range(n):
        t = i / sr
        env = (1.0 - t/dur)**1.5
        beep = 1.0 if (int(t * 16) % 2 == 0) else 0.0
        freq = 880.0
        s = math.sin(2 * math.pi * freq * t) * env * beep
        samples.append(s)
    synth_wav('assets/audio/news_alarm.wav', samples, sr)

if __name__ == '__main__':
    print("Generating Stardew-style 2D pixel assets...")
    make_iron_ore()
    make_food()
    make_energy()
    make_semiconductor()
    make_smartphone()
    make_gold_coin()

    make_cargo_ship()
    make_ship_wake()

    make_building_iron()
    make_building_agri()
    make_building_tech()
    make_building_energy()
    make_building_port()
    make_building_trade()

    make_stardew_panel()
    make_stardew_slot()
    make_stardew_button()

    make_role_icons()
    make_sounds()
    print("All assets successfully generated!")
