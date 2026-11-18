import os
import math
from generate_assets import PixelCanvas

os.makedirs('assets/sprites/characters', exist_ok=True)
os.makedirs('assets/sprites/portraits', exist_ok=True)

def draw_chibi_frame(c: PixelCanvas, ox: int, oy: int, step: int,
                     hat_col, hair_col, shirt_col, pants_col, accent_col, hat_style="cap"):
    # Outline helper color
    ol = (35, 22, 18)
    skin = (250, 212, 175)
    skin_sh = (225, 175, 138)
    eye = (30, 25, 35)

    bob = -1 if step == 1 else 0

    # Shadow on ground
    for sx in range(6, 18):
        c.set_pixel(ox + sx, oy + 29, 20, 30, 20, 90)
        c.set_pixel(ox + sx, oy + 30, 20, 30, 20, 60)

    # Feet / Boots
    l_foot_y = oy + (26 if step == 0 else 25)
    r_foot_y = oy + (26 if step == 0 else 27)
    c.fill_rect(ox + 8, l_foot_y, 3, 3, 75, 45, 30)
    c.fill_rect(ox + 13, r_foot_y, 3, 3, 75, 45, 30)

    # Pants / Legs
    c.fill_rect(ox + 8, oy + 22 + bob, 3, 4, *pants_col)
    c.fill_rect(ox + 13, oy + 22 + bob, 3, 4, *pants_col)

    # Torso / Shirt
    c.fill_rect(ox + 7, oy + 15 + bob, 10, 7, *shirt_col)
    c.fill_rect(ox + 9, oy + 16 + bob, 6, 5, *accent_col) # vest/overall detail
    # Arms
    arm_l_y = oy + 16 + bob + (1 if step == 1 else 0)
    arm_r_y = oy + 16 + bob - (1 if step == 1 else 0)
    c.fill_rect(ox + 5, arm_l_y, 2, 5, *shirt_col)
    c.fill_rect(ox + 5, arm_l_y + 4, 2, 2, *skin)
    c.fill_rect(ox + 17, arm_r_y, 2, 5, *shirt_col)
    c.fill_rect(ox + 17, arm_r_y + 4, 2, 2, *skin)

    # Head
    c.fill_rect(ox + 7, oy + 6 + bob, 10, 9, *skin)
    c.fill_rect(ox + 7, oy + 13 + bob, 10, 2, *skin_sh)
    # Eyes (Stardew cute 2px tall eyes)
    c.fill_rect(ox + 9, oy + 10 + bob, 2, 2, *eye)
    c.fill_rect(ox + 13, oy + 10 + bob, 2, 2, *eye)
    # Rosy cheeks
    c.set_pixel(ox + 8, oy + 12 + bob, 240, 140, 140)
    c.set_pixel(ox + 15, oy + 12 + bob, 240, 140, 140)

    # Hair
    c.fill_rect(ox + 7, oy + 5 + bob, 10, 3, *hair_col)
    c.fill_rect(ox + 6, oy + 7 + bob, 2, 4, *hair_col)
    c.fill_rect(ox + 16, oy + 7 + bob, 2, 4, *hair_col)

    # Hat styles
    if hat_style == "helmet": # Miner hard hat
        c.fill_rect(ox + 6, oy + 3 + bob, 12, 4, *hat_col)
        c.fill_rect(ox + 5, oy + 6 + bob, 14, 1, *hat_col)
        c.fill_rect(ox + 11, oy + 3 + bob, 2, 2, 255, 245, 160) # headlamp
    elif hat_style == "straw": # Farmer straw hat
        c.fill_rect(ox + 4, oy + 5 + bob, 16, 2, *hat_col)
        c.fill_rect(ox + 7, oy + 2 + bob, 10, 3, *hat_col)
        c.fill_rect(ox + 7, oy + 4 + bob, 10, 1, 200, 60, 50) # red ribbon
    elif hat_style == "goggles": # Tech goggles
        c.fill_rect(ox + 6, oy + 4 + bob, 12, 2, 60, 70, 90)
        c.fill_rect(ox + 8, oy + 4 + bob, 3, 2, 100, 220, 255)
        c.fill_rect(ox + 13, oy + 4 + bob, 3, 2, 100, 220, 255)
    elif hat_style == "sailor": # Sailor cap
        c.fill_rect(ox + 7, oy + 2 + bob, 10, 4, 245, 248, 255)
        c.fill_rect(ox + 8, oy + 5 + bob, 8, 1, 40, 90, 170)
    elif hat_style == "tophat": # Trade union merchant hat
        c.fill_rect(ox + 5, oy + 5 + bob, 14, 1, 65, 35, 85)
        c.fill_rect(ox + 7, oy + 1 + bob, 10, 4, 85, 45, 110)
        c.fill_rect(ox + 7, oy + 4 + bob, 10, 1, 240, 195, 50)
    else: # Energy visor
        c.fill_rect(ox + 6, oy + 4 + bob, 12, 3, *hat_col)
        c.fill_rect(ox + 8, oy + 5 + bob, 8, 1, 255, 240, 90)

def make_all_characters():
    specs = [
        ("char_iron.png", (240, 195, 40), (90, 50, 30), (165, 55, 45), (65, 70, 85), (120, 40, 35), "helmet"),
        ("char_agri.png", (235, 195, 95), (140, 85, 40), (225, 215, 185), (55, 110, 165), (65, 145, 65), "straw"),
        ("char_tech.png", (70, 160, 230), (45, 55, 75), (235, 240, 248), (50, 65, 90), (80, 185, 240), "goggles"),
        ("char_energy.png", (245, 150, 30), (50, 40, 35), (230, 130, 30), (55, 60, 70), (255, 220, 60), "visor"),
        ("char_port.png", (240, 245, 255), (120, 70, 35), (45, 105, 175), (220, 225, 235), (245, 245, 250), "sailor"),
        ("char_trade.png", (95, 50, 125), (60, 40, 55), (125, 60, 155), (45, 35, 55), (235, 185, 50), "tophat"),
    ]
    for fname, hat, hair, shirt, pants, accent, style in specs:
        c = PixelCanvas(48, 32)
        draw_chibi_frame(c, 0, 0, 0, hat, hair, shirt, pants, accent, style)
        draw_chibi_frame(c, 24, 0, 1, hat, hair, shirt, pants, accent, style)
        c.save(f"assets/sprites/characters/{fname}")

def draw_portrait(fname, bg_col, hair_col, coat_col, tie_col, accessory="none"):
    c = PixelCanvas(48, 48)
    # Warm Stardew portrait frame background
    c.fill_rect(0, 0, 48, 48, 70, 38, 18)
    c.fill_rect(2, 2, 44, 44, 195, 145, 75)
    c.fill_rect(3, 3, 42, 42, *bg_col)

    skin = (250, 212, 175)
    skin_sh = (225, 175, 138)

    # Shoulders / Coat
    c.fill_rect(10, 32, 28, 13, *coat_col)
    c.fill_rect(18, 32, 12, 13, 245, 242, 235) # shirt collar
    c.fill_rect(22, 34, 4, 11, *tie_col) # tie/scarf

    # Neck
    c.fill_rect(20, 28, 8, 5, *skin_sh)

    # Face
    c.fill_rect(15, 13, 18, 16, *skin)
    c.fill_rect(15, 26, 18, 3, *skin_sh)
    # Eyes
    c.fill_rect(18, 19, 3, 3, 35, 30, 45)
    c.fill_rect(27, 19, 3, 3, 35, 30, 45)
    c.set_pixel(18, 19, 255, 255, 255) # eye shine
    c.set_pixel(27, 19, 255, 255, 255)
    # Smile
    c.fill_rect(21, 25, 6, 1, 185, 95, 85)
    # Cheeks
    c.fill_rect(16, 22, 2, 2, 245, 150, 145)
    c.fill_rect(30, 22, 2, 2, 245, 150, 145)

    # Hair
    c.fill_rect(14, 9, 20, 6, *hair_col)
    c.fill_rect(13, 12, 3, 9, *hair_col)
    c.fill_rect(32, 12, 3, 9, *hair_col)

    # Accessories
    if accessory == "glasses":
        c.fill_rect(17, 18, 5, 4, 40, 40, 60, 90)
        c.fill_rect(26, 18, 5, 4, 40, 40, 60, 90)
        c.fill_rect(22, 19, 4, 1, 40, 40, 60)
    elif accessory == "goggles":
        c.fill_rect(14, 10, 20, 3, 60, 70, 90)
        c.fill_rect(17, 9, 5, 4, 100, 225, 255)
        c.fill_rect(26, 9, 5, 4, 100, 225, 255)
    elif accessory == "headset":
        c.fill_rect(12, 16, 3, 7, 235, 185, 45)
        c.fill_rect(14, 23, 6, 1, 60, 60, 70)
    elif accessory == "hat":
        c.fill_rect(11, 8, 26, 2, 45, 50, 70)
        c.fill_rect(15, 5, 18, 4, 45, 50, 70)
        c.fill_rect(33, 10, 2, 6, 245, 200, 50)

    c.save(f"assets/sprites/portraits/{fname}")

def make_all_portraits():
    draw_portrait("portrait_diplomat.png", (175, 210, 235), (75, 45, 30), (50, 80, 135), (200, 55, 50), "none")
    draw_portrait("portrait_treasurer.png", (235, 215, 165), (110, 75, 45), (120, 75, 40), (235, 185, 40), "glasses")
    draw_portrait("portrait_technician.png", (170, 225, 215), (45, 55, 75), (225, 230, 240), (50, 155, 220), "goggles")
    draw_portrait("portrait_analyst.png", (195, 190, 235), (50, 40, 60), (70, 65, 115), (90, 195, 120), "glasses")
    draw_portrait("portrait_spokesperson.png", (245, 200, 190), (165, 75, 55), (185, 65, 65), (245, 210, 60), "headset")
    draw_portrait("portrait_teacher.png", (215, 230, 195), (95, 75, 65), (65, 105, 75), (210, 155, 45), "hat")

def make_nature_props():
    # Wildflowers
    c = PixelCanvas(16, 16)
    for fx, fy, col in [(3, 4, (255, 230, 80)), (11, 5, (255, 160, 190)), (6, 11, (255, 255, 240)), (12, 12, (255, 210, 70))]:
        c.set_pixel(fx, fy+1, 50, 130, 45)
        c.set_pixel(fx-1, fy, *col)
        c.set_pixel(fx+1, fy, *col)
        c.set_pixel(fx, fy-1, *col)
        c.set_pixel(fx, fy, 255, 245, 180)
    c.save("assets/sprites/flower_patch.png")

    # Wood button hover
    hb = PixelCanvas(48, 24)
    hb.fill_rect(0, 0, 48, 24, 65, 36, 18)
    hb.fill_rect(1, 1, 46, 22, 245, 195, 105)
    hb.fill_rect(2, 2, 44, 20, 210, 150, 75)
    hb.fill_rect(2, 2, 44, 2, 255, 230, 155)
    hb.save("assets/ui/wood_btn_hover.png")

if __name__ == "__main__":
    make_all_characters()
    make_all_portraits()
    make_nature_props()
    print("V2 characters, portraits, and props generated!")
