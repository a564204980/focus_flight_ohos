#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
generate_markers.py — 放大版（1.4x 视觉增强）机场地标 Marker PNG 批量生成器
- 画布扩至 580 x 140
- 胶囊宽度 58, 高度 116, 飞机图标与三行文字整体放大，在地图高分屏上更显目清晰
- 锚点 (86, 70) -> anchorU = 86 / 580 = 0.148
"""
import re, math, os
from PIL import Image, ImageDraw, ImageFont

SCRIPT_DIR  = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.join(SCRIPT_DIR, "..")
AIRPORT_TS  = os.path.join(PROJECT_DIR, "entry/src/main/ets/models/AllAirportsData.ts")
OUTPUT_DIR  = os.path.join(PROJECT_DIR, "entry/src/main/resources/rawfile/textures/markers")

CTU_LAT, CTU_LON = 30.5607, 103.9426
IMG_W, IMG_H = 580, 140

# 字体候选
FONT_CANDIDATES = [
    "C:/Windows/Fonts/msyhbd.ttc", # 微软雅黑粗体
    "C:/Windows/Fonts/msyh.ttc",   # 微软雅黑
    "C:/Windows/Fonts/simhei.ttf",
]

def _load_font(size):
    for path in FONT_CANDIDATES:
        try:
            return ImageFont.truetype(path, size)
        except Exception:
            continue
    return ImageFont.load_default()

def haversine_km(lat1, lon1, lat2, lon2):
    R = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat/2)**2 + math.cos(math.radians(lat1))*math.cos(math.radians(lat2))*math.sin(dlon/2)**2
    return R * 2 * math.asin(math.sqrt(a))

def parse_airports(ts_path):
    with open(ts_path, encoding='utf-8') as f:
        content = f.read()
    pattern = (r"\{\s*code:\s*'([A-Z]{3,4})'\s*,\s*name:\s*'([^']+)'\s*,\s*city:\s*'([^']+)'\s*,"
               r"\s*lat:\s*([-?\d.]+)\s*,\s*lon:\s*([-?\d.]+)")
    airports = []
    for m in re.finditer(pattern, content):
        airports.append({'code':m.group(1),'name':m.group(2),'city':m.group(3),'lat':float(m.group(4)),'lon':float(m.group(5))})
    return airports

def draw_capsule_icon(draw, cx, cy, is_active):
    """
    绘制左侧放大版竖向胶囊跑道+飞机图标 (中心 86, 70)
    """
    w, h = 58, 116
    left   = cx - w // 2 # 57
    top    = cy - h // 2 # 12
    right  = cx + w // 2 # 115
    bottom = cy + h // 2 # 128
    radius = 29

    bg_color = (15, 23, 42, 235) # 深蓝黑底色
    if is_active:
        border_color = (240, 101, 83, 255)  # 红色/橙红色 (目的地/出发)
        plane_color  = (255, 255, 255, 255)  # 白色小飞机
        line_color   = (255, 255, 255, 230)
    else:
        border_color = (56, 189, 248, 255)   # 天蓝色 (候选)
        plane_color  = (147, 197, 253, 255)  # 浅蓝色小飞机
        line_color   = (255, 255, 255, 190)

    # 1. 胶囊底色与边框 (加粗至 4px)
    draw.rounded_rectangle([left, top, right, bottom], radius=radius, fill=bg_color, outline=border_color, width=4)

    # 2. 上下跑道虚线 (白色短线)
    draw.line([(cx, top + 10), (cx, top + 24)], fill=line_color, width=4)
    draw.line([(cx, bottom - 24), (cx, bottom - 10)], fill=line_color, width=4)

    # 3. 中间放大版向上小飞机剪影
    plane_pts = [
        (cx, cy - 18),       # 机头
        (cx + 3, cy - 12),
        (cx + 3, cy - 4),
        (cx + 19, cy + 5),   # 右翼尖
        (cx + 19, cy + 9),
        (cx + 3, cy + 5),    # 右翼根
        (cx + 3, cy + 13),
        (cx + 9, cy + 19),   # 右尾翼
        (cx + 9, cy + 22),
        (cx, cy + 19),       # 尾部凹槽
        (cx - 9, cy + 22),
        (cx - 9, cy + 19),   # 左尾翼
        (cx - 3, cy + 13),
        (cx - 3, cy + 5),    # 左翼根
        (cx - 19, cy + 9),
        (cx - 19, cy + 5),   # 左翼尖
        (cx - 3, cy - 4),
        (cx - 3, cy - 12),
    ]
    draw.polygon(plane_pts, fill=plane_color)

def draw_text_with_shadow(draw, pos, text, font, fill, shadow_color=(0, 0, 0, 245)):
    x, y = pos
    # 四周多向加厚描边
    for dx in (-2, -1, 0, 1, 2):
        for dy in (-2, -1, 0, 1, 2):
            if dx != 0 or dy != 0:
                draw.text((x + dx, y + dy), text, font=font, fill=shadow_color)
    draw.text((x, y), text, font=font, fill=fill)

def generate_marker(code, name, dist_km, mode):
    is_active = mode in ('dest', 'orig')
    img  = Image.new('RGBA', (IMG_W, IMG_H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 1. 绘制左侧胶囊图标 (中心 86, 70)
    draw_capsule_icon(draw, 86, 70, is_active)

    # 2. 绘制右侧悬空文字区 (起始 x = 132)
    tx = 132

    # 动态适应名称字号，显目突出
    n_len = len(name)
    if n_len <= 6:
        name_font_size = 26
    elif n_len <= 10:
        name_font_size = 23
    elif n_len <= 15:
        name_font_size = 20
    else:
        name_font_size = 17

    font_code = _load_font(38) # 代码大字加粗
    font_name = _load_font(name_font_size)
    font_sub  = _load_font(20)

    if is_active:
        code_color = (240, 101, 83, 255)  # 橙红代码
        name_color = (255, 255, 255, 255) # 纯白机场名
        sub_color  = (255, 255, 255, 235) # 纯白说明
    else:
        code_color = (186, 230, 253, 255) # 淡蓝代码
        name_color = (255, 255, 255, 255) # 纯白机场名
        sub_color  = (147, 197, 253, 235) # 浅天蓝说明

    # 第一行：机场三字代码
    draw_text_with_shadow(draw, (tx, 10), code, font_code, code_color)

    # 第二行：全中文机场名称 (绝对不截断，原样完整输出)
    draw_text_with_shadow(draw, (tx, 54), name, font_name, name_color)

    # 第三行：辅助说明 (如 出发机场, 候选航线 · 396km)
    if mode == 'orig':
        sub_txt = "出发机场"
    elif mode == 'dest':
        sub_txt = f"到达机场 · {round(dist_km)}km" if dist_km > 0 else "到达机场"
    else:
        sub_txt = f"候选航线 · {round(dist_km)}km" if dist_km > 0 else "候选航线"

    draw_text_with_shadow(draw, (tx, 90), sub_txt, font_sub, sub_color)

    return img

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    airports = parse_airports(AIRPORT_TS)
    print(f"解析到 {len(airports)} 个机场，开始全量生成放大版 (1.4x) 地标...")
    for i, apt in enumerate(airports):
        code, name = apt['code'], apt['name']
        dist = haversine_km(CTU_LAT, CTU_LON, apt['lat'], apt['lon'])
        generate_marker(code, name, dist, 'cand').save(os.path.join(OUTPUT_DIR, f'mk_{code}_cand.png'))
        generate_marker(code, name, dist, 'dest').save(os.path.join(OUTPUT_DIR, f'mk_{code}_dest.png'))
        if (i+1)%50==0 or (i+1)==len(airports):
            print(f"  [{i+1}/{len(airports)}] 已完成")
    ctu = next((a for a in airports if a['code']=='CTU'), None)
    if ctu:
        generate_marker('CTU', ctu['name'], 0.0, 'orig').save(os.path.join(OUTPUT_DIR, 'mk_CTU_orig.png'))
    print(f"\n生成完成！共生成 {len(airports)*2+1} 张放大版高清地标图")

if __name__ == '__main__':
    main()
