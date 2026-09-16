#!/usr/bin/env python3
# 生成大字时钟全部图片（PNG 格式，fbink 原生支持）
#   time/    HHMM.png      1440 张  600x800 全屏白底，时间居中于中部
#   banner/  {M}{D}-{W}.png 2562 张 600x200 日期+星期（顶部带，W=1..7 周一..周日）
#   wx/      T{t}D{d}.png   793 张 600x200 温度+天气（底部带，t=-10..50，d=0..12）
# 全部内容预渲染成图片，设备端零文字排版（消灭字体/定位类故障）。
import os
from PIL import Image, ImageDraw, ImageFont

BASE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(BASE, "..", "clockimg"))
ARIAL = os.path.join(BASE, "Arial-Bold.ttf")
W, H = 600, 800

def load_cjk(size):
    for p, i in [("/System/Library/Fonts/Hiragino Sans GB.ttc", 1),
                 ("/System/Library/Fonts/Hiragino Sans GB.ttc", 0),
                 ("/System/Library/Fonts/STHeiti Medium.ttc", 0),
                 ("/System/Library/Fonts/STHeiti Light.ttc", 0)]:
        try:
            return ImageFont.truetype(p, size, index=i)
        except Exception:
            continue
    raise RuntimeError("no CJK font found")

def center_text(d, text, font, cy, width):
    try:
        l, t, r, b = d.textbbox((0, 0), text, font=font)
        w, h, ox, oy = r - l, b - t, l, t
    except AttributeError:
        w, h = d.textsize(text, font=font)
        ox = oy = 0
    d.text(((width - w) // 2 - ox, cy - h // 2 - oy), text, fill=0, font=font)

for sub in ("time", "banner", "wx"):
    os.makedirs(os.path.join(OUT, sub), exist_ok=True)

WD = ["星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日"]
DESCS = ["晴", "局部多云", "多云", "阴", "雾", "毛毛雨", "冻雨",
         "小雨", "中雨", "大雨", "雪", "阵雨", "雷阵雨"]
MDAYS = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

# 1) 时间：全屏 600x800，时间画在正中（y=400），顶/底留白给横幅与天气
fT = ImageFont.truetype(ARIAL, 192)
n = 0
for hh in range(24):
    for mm in range(60):
        img = Image.new("L", (W, H), 255)
        d = ImageDraw.Draw(img)
        center_text(d, "%02d:%02d" % (hh, mm), fT, 400, W)
        img.save(os.path.join(OUT, "time", "%02d%02d.png" % (hh, mm)))
        n += 1
print("time:", n, flush=True)

# 2) 日期横幅：600x200，"9月16日" + "星期三"，覆盖任意年份的全部日期x星期组合
fD = load_cjk(72)
fWd = load_cjk(58)
n = 0
for m in range(1, 13):
    for dd in range(1, MDAYS[m - 1] + 1):
        for w in range(1, 8):
            img = Image.new("L", (600, 200), 255)
            d = ImageDraw.Draw(img)
            center_text(d, "%d月%d日" % (m, dd), fD, 58, 600)
            center_text(d, WD[w - 1], fWd, 148, 600)
            img.save(os.path.join(OUT, "banner", "%02d%02d-%d.png" % (m, dd, w)))
            n += 1
print("banner:", n, flush=True)

# 3) 天气：600x200，"25°C" + "晴"
fTemp = ImageFont.truetype(ARIAL, 96)
fDesc = load_cjk(58)
n = 0
for t in range(-10, 51):
    for di, desc in enumerate(DESCS):
        img = Image.new("L", (600, 200), 255)
        d = ImageDraw.Draw(img)
        center_text(d, "%d°C" % t, fTemp, 55, 600)
        center_text(d, desc, fDesc, 148, 600)
        img.save(os.path.join(OUT, "wx", "T%dD%d.png" % (t, di)))
        n += 1
print("wx:", n, flush=True)
print("ALL DONE")
