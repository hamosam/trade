from generate_assets import PixelCanvas

def make_industrial_complex_64():
    c = PixelCanvas(64, 64)
    # Concrete base
    c.fill_rect(4, 46, 56, 14, 85, 88, 95)
    c.fill_rect(6, 48, 52, 10, 120, 122, 130)
    # Main brick factory hall
    c.fill_rect(8, 24, 30, 24, 145, 68, 52)
    c.fill_rect(10, 26, 26, 20, 175, 86, 66)
    # Sawtooth roof
    for i in range(5):
        c.fill_rect(8 + i*6, 19, 6, 5, 65, 70, 80)
        c.fill_rect(9 + i*6, 20, 4, 3, 95, 102, 115)
    # Three tall smokestacks
    for sx, sy in [(40, 6), (48, 10), (55, 14)]:
        c.fill_rect(sx, sy, 5, 42 - sy, 75, 78, 86)
        c.fill_rect(sx-1, sy, 7, 2, 195, 135, 50)
        c.fill_rect(sx+1, sy+2, 2, 38 - sy, 105, 108, 118)
    # Warm glowing factory windows
    for wx in [12, 19, 26, 33]:
        c.fill_rect(wx, 30, 4, 5, 255, 215, 90)
        c.fill_rect(wx, 38, 4, 5, 255, 185, 60)
    # Big brass gear & gate
    c.draw_circle(23, 44, 5, 225, 175, 50)
    c.draw_circle(23, 44, 2, 75, 50, 25)
    c.save("assets/sprites/building_industrial.png")

def make_future_spire_64():
    c = PixelCanvas(64, 64)
    # Hovering energy pad
    c.fill_rect(8, 48, 48, 10, 38, 60, 96)
    c.fill_rect(10, 49, 44, 2, 50, 240, 255)
    # Side sleek glass wings
    c.fill_rect(10, 34, 12, 16, 135, 175, 215)
    c.fill_rect(42, 34, 12, 16, 135, 175, 215)
    c.fill_rect(12, 37, 8, 2, 60, 245, 255)
    c.fill_rect(44, 37, 8, 2, 60, 245, 255)
    # Central towering spire
    for y in range(10, 50):
        half_w = 4 + (y - 10) // 4
        c.fill_rect(32 - half_w, y, half_w * 2, 1, 185, 220, 245)
        c.fill_rect(32 - half_w + 2, y, half_w * 2 - 4, 1, 220, 242, 255)
    # Glowing cyan plasma core & antenna
    c.fill_rect(30, 4, 4, 44, 45, 230, 255)
    c.fill_rect(31, 2, 2, 46, 215, 255, 255)
    # Holographic rings
    for rx in range(16, 49):
        if rx % 2 == 0:
            c.set_pixel(rx, 16, 80, 245, 255)
            c.set_pixel(rx, 26, 80, 245, 255)
    c.save("assets/sprites/building_future.png")

def make_era_props():
    # Mini factory (32x32)
    f = PixelCanvas(32, 32)
    f.fill_rect(4, 16, 18, 13, 135, 65, 50)
    f.fill_rect(6, 18, 14, 9, 165, 85, 65)
    f.fill_rect(22, 6, 4, 23, 75, 78, 86)
    f.fill_rect(21, 6, 6, 2, 190, 130, 45)
    f.fill_rect(8, 21, 3, 3, 255, 210, 80)
    f.fill_rect(14, 21, 3, 3, 255, 210, 80)
    f.save("assets/sprites/prop_factory.png")

    # Steel warehouse / crane silo (28x28)
    w = PixelCanvas(28, 28)
    w.fill_rect(4, 12, 20, 13, 95, 102, 114)
    w.fill_rect(6, 10, 16, 3, 125, 132, 145)
    w.fill_rect(8, 16, 12, 9, 70, 75, 85)
    w.fill_rect(10, 18, 8, 7, 150, 115, 55)
    w.save("assets/sprites/prop_warehouse.png")

    # Futuristic glowing spirelet (28x36)
    s = PixelCanvas(28, 36)
    s.fill_rect(6, 28, 16, 5, 45, 70, 110)
    for y in range(6, 29):
        hw = 2 + (y - 6) // 5
        s.fill_rect(14 - hw, y, hw * 2, 1, 180, 225, 250)
    s.fill_rect(13, 3, 2, 26, 60, 240, 255)
    s.fill_rect(8, 29, 12, 2, 60, 240, 255)
    s.save("assets/sprites/prop_spire.png")

    # Energy pylon (24x28)
    p = PixelCanvas(24, 28)
    p.fill_rect(7, 20, 10, 5, 45, 65, 95)
    p.fill_rect(10, 8, 4, 13, 165, 205, 235)
    p.draw_circle(12, 6, 4, 45, 230, 255)
    p.draw_circle(12, 6, 2, 220, 255, 255)
    p.save("assets/sprites/prop_pylon.png")

if __name__ == "__main__":
    make_industrial_complex_64()
    make_future_spire_64()
    make_era_props()
    print("Detailed 64x64 era buildings and props generated!")
