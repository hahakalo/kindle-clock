#!/usr/bin/env python3
# 生成大字时钟全部图片（PNG 格式，fbink 原生支持）
#
# 竖屏 600x800：
#   time/    HHMM.png        1440 张  全屏，时间居中（y=400）
#   banner/  {MMDD}-{W}.png  2562 张  600x200 顶部带：日期 + 星期
#   wx/      T{t}D{d}.png     793 张  600x200 底部带：温度 + 天气
#
# 横屏（内容按 800x600 设计，预旋转 90° 后仍以 600x800 存储，设备端按普通竖屏图显示）：
#   *_l = 顺时针预旋转 —— 设备横着看时充电口在右侧
#   *_r = 逆时针预旋转 —— 设备横着看时充电口在左侧
#   （横竖切换由设备端 documents/HENG 文件控制，见 clock.sh）
#
# 设备端零文字排版，全部内容预渲染成图片。
import os
from PIL import Image, ImageDraw, ImageFont

BASE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(os.path.join(BASE, "..", "clockimg"))
ARIAL = os.path.join(BASE, "Arial-Bold.ttf")
W, H = 600, 800      # 竖屏
LW, LH = 800, 600    # 横屏内容

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

SUBS = ("time", "banner", "wx", "time_l", "time_r",
        "banner_l", "banner_r", "wx_l", "wx_r")
for s in SUBS:
    os.makedirs(os.path.join(OUT, s), exist_ok=True)

WD = ["星期一", "星期二", "星期三", "星期四", "星期五", "星期六", "星期日"]
DESCS = ["晴", "局部多云", "多云", "阴", "雾", "毛毛雨", "冻雨",
         "小雨", "中雨", "大雨", "雪", "阵雨", "雷阵雨"]
MDAYS = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

CW, CH = Image.ROTATE_270, Image.ROTATE_90   # l=顺时针90°，r=逆时针90°

# 1) 时间
fT = ImageFont.truetype(ARIAL, 192)     # 竖屏
fTL = ImageFont.truetype(ARIAL, 252)    # 横屏
n = 0
for hh in range(24):
    for mm in range(60):
        name = "%02d%02d.png" % (hh, mm)
        img = Image.new("L", (W, H), 255)
        center_text(ImageDraw.Draw(img), "%02d:%02d" % (hh, mm), fT, 400, W)
        img.save(os.path.join(OUT, "time", name))
        imgl = Image.new("L", (LW, LH), 255)
        center_text(ImageDraw.Draw(imgl), "%02d:%02d" % (hh, mm), fTL, 300, LW)
        imgl.transpose(CW).save(os.path.join(OUT, "time_l", name))
        imgl.transpose(CH).save(os.path.join(OUT, "time_r", name))
        n += 1
        if n % 240 == 0:
            print("time", n, flush=True)
print("time:", n * 3, flush=True)

# 2) 日期横幅（日期 + 星期）
fD, fWd = load_cjk(72), load_cjk(58)      # 竖屏
fDL, fWdL = load_cjk(64), load_cjk(50)    # 横屏
n = 0
for m in range(1, 13):
    for dd in range(1, MDAYS[m - 1] + 1):
        for w in range(1, 8):
            name = "%02d%02d-%d.png" % (m, dd, w)
            img = Image.new("L", (600, 200), 255)
            d = ImageDraw.Draw(img)
            center_text(d, "%d月%d日" % (m, dd), fD, 58, 600)
            center_text(d, WD[w - 1], fWd, 148, 600)
            img.save(os.path.join(OUT, "banner", name))
            imgl = Image.new("L", (800, 170), 255)
            dl = ImageDraw.Draw(imgl)
            center_text(dl, "%d月%d日" % (m, dd), fDL, 52, 800)
            center_text(dl, WD[w - 1], fWdL, 128, 800)
            imgl.transpose(CW).save(os.path.join(OUT, "banner_l", name))
            imgl.transpose(CH).save(os.path.join(OUT, "banner_r", name))
            n += 1
print("banner:", n * 3, flush=True)

# 3) 天气（温度 + 天气描述）
fTemp, fDesc = ImageFont.truetype(ARIAL, 96), load_cjk(58)
fTempL, fDescL = ImageFont.truetype(ARIAL, 84), load_cjk(50)
n = 0
for t in range(-10, 51):
    for di, desc in enumerate(DESCS):
        name = "T%dD%d.png" % (t, di)
        img = Image.new("L", (600, 200), 255)
        d = ImageDraw.Draw(img)
        center_text(d, "%d°C" % t, fTemp, 55, 600)
        center_text(d, desc, fDesc, 148, 600)
        img.save(os.path.join(OUT, "wx", name))
        imgl = Image.new("L", (800, 170), 255)
        dl = ImageDraw.Draw(imgl)
        center_text(dl, "%d°C" % t, fTempL, 55, 800)
        center_text(dl, desc, fDescL, 128, 800)
        imgl.transpose(CW).save(os.path.join(OUT, "wx_l", name))
        imgl.transpose(CH).save(os.path.join(OUT, "wx_r", name))
        n += 1
print("wx:", n * 3, flush=True)
print("ALL DONE")
