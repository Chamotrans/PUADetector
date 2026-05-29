from PIL import Image, ImageDraw, ImageFont
import os, math

OUT_DIR = "/Users/sunnyyylai/Developer/PUADetector/AppStoreScreenshots"
os.makedirs(OUT_DIR, exist_ok=True)

BEZEL_W, BEZEL_H = 1320, 2868
SCREEN_X, SCREEN_Y = 57, 123
SCREEN_W, SCREEN_H = 1206, 2622
RADIUS = 70

BG = (15, 15, 30)
PANEL = (25, 25, 50)
TIFFANY = (129, 216, 209)
DANGER = (255, 89, 89)
WHITE = (255, 255, 255)
GRAY = (150, 150, 170)

def draw_rrect(d, xy, r, fill=None):
    x1, y1, x2, y2 = xy
    d.pieslice([x1, y1, x1+2*r, y1+2*r], 180, 270, fill=fill)
    d.pieslice([x2-2*r, y1, x2, y1+2*r], 270, 360, fill=fill)
    d.pieslice([x1, y2-2*r, x1+2*r, y2], 90, 180, fill=fill)
    d.pieslice([x2-2*r, y2-2*r, x2, y2], 0, 90, fill=fill)
    d.rectangle([x1+r, y1, x2-r, y2], fill=fill)
    d.rectangle([x1, y1+r, x2, y2-r], fill=fill)

font_big = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 52)
font_mid = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 40)
font_sml = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 28)

# 1: Main Gauge
img = Image.new("RGB", (BEZEL_W, BEZEL_H), (40,40,50))
d = ImageDraw.Draw(img)
draw_rrect(d, (SCREEN_X, SCREEN_Y, SCREEN_X+SCREEN_W, SCREEN_Y+SCREEN_H), RADIUS, fill=BG)
d.text((SCREEN_X+60, SCREEN_Y+100), "PUA DETECTOR", fill=TIFFANY, font=font_big)
d.text((SCREEN_X+60, SCREEN_Y+155), "Mic live · 粵語（香港）", fill=DANGER, font=font_sml)
cx, cy = SCREEN_X+SCREEN_W//2, SCREEN_Y+480
for i in range(180):
    a = math.radians(180+i)
    x = int(cx + 200*math.cos(a))
    y = int(cy + 200*math.sin(a))
    c = (100,255,100) if i<70 else ((255,200,50) if i<130 else (255,80,80))
    d.ellipse([x-5, y-5, x+5, y+5], fill=c)
d.text((cx-45, cy-55), "87", fill=WHITE, font=font_big)
d.text((cx-50, cy+10), "PUA 風險", fill=GRAY, font=font_sml)
tv = [20,25,40,35,55,60,75,80,87]
pts = [(SCREEN_X+100+i*130, SCREEN_Y+700+int(100-v*1.0)) for i,v in enumerate(tv)]
for i in range(len(pts)-1):
    d.line([pts[i], pts[i+1]], fill=TIFFANY, width=4)
for p in pts:
    d.ellipse([p[0]-5, p[1]-5, p[0]+5, p[1]+5], fill=TIFFANY)
by = SCREEN_Y+SCREEN_H-140
draw_rrect(d, (SCREEN_X+80, by, SCREEN_X+SCREEN_W-80, by+80), 40, fill=DANGER)
d.text((SCREEN_X+SCREEN_W//2-110, by+18), "STOP DETECTION", fill=WHITE, font=font_mid)
img.save(f"{OUT_DIR}/01-main-gauge.jpg", "JPEG", quality=95)
print("1 OK")

# 2: Alert
img2 = Image.new("RGB", (BEZEL_W, BEZEL_H), (40,40,50))
d2 = ImageDraw.Draw(img2)
draw_rrect(d2, (SCREEN_X, SCREEN_Y, SCREEN_X+SCREEN_W, SCREEN_Y+SCREEN_H), RADIUS, fill=BG)
draw_rrect(d2, (SCREEN_X+50, SCREEN_Y+250, SCREEN_X+SCREEN_W-50, SCREEN_Y+450), 30, fill=(160,40,40))
d2.text((SCREEN_X+80, SCREEN_Y+280), "PUA Detected!", fill=WHITE, font=font_mid)
d2.text((SCREEN_X+80, SCREEN_Y+340), "「你太敏感了，我只是關心你」", fill=(255,200,200), font=font_sml)
d2.text((SCREEN_X+80, SCREEN_Y+390), "Gaslighting · 可信度 92%", fill=GRAY, font=font_sml)
lines = [("你最近是不是很忙？",False),("都不陪我吃飯了",False),("你太敏感了，我只是關心你",True),("別的人都沒有這樣",True),("你變了",True)]
for i,(t,f) in enumerate(lines):
    ty = SCREEN_Y+530+i*55
    draw_rrect(d2, (SCREEN_X+60, ty, SCREEN_X+SCREEN_W-60, ty+45), 15, fill=(40,30,30) if f else PANEL)
    d2.text((SCREEN_X+80, ty+10), t, fill=DANGER if f else GRAY, font=font_sml)
    if f:
        d2.text((SCREEN_X+SCREEN_W-150, ty+10), "PUA", fill=DANGER, font=font_sml)
img2.save(f"{OUT_DIR}/02-alert.jpg", "JPEG", quality=95)
print("2 OK")

# 3: Settings
img3 = Image.new("RGB", (BEZEL_W, BEZEL_H), (40,40,50))
d3 = ImageDraw.Draw(img3)
draw_rrect(d3, (SCREEN_X, SCREEN_Y, SCREEN_X+SCREEN_W, SCREEN_Y+SCREEN_H), RADIUS, fill=BG)
d3.text((SCREEN_X+60, SCREEN_Y+100), "設定", fill=WHITE, font=font_big)
y = SCREEN_Y+180
items = [("敏感度","中等"),("背景偵測",True),("隱私模式",True),("預設類別","全部"),("警報方式","語音+震動")]
for l,v in items:
    d3.text((SCREEN_X+70, y), l, fill=WHITE, font=font_mid)
    if isinstance(v,bool):
        draw_rrect(d3, (SCREEN_X+SCREEN_W-150, y+5, SCREEN_X+SCREEN_W-70, y+45), 18, fill=TIFFANY)
        d3.ellipse([SCREEN_X+SCREEN_W-90, y+10, SCREEN_X+SCREEN_W-70, y+40], fill=WHITE)
    else:
        d3.text((SCREEN_X+SCREEN_W-250, y+3), v, fill=GRAY, font=font_sml)
    y += 65
y += 30
d3.text((SCREEN_X+70, y), "關於", fill=GRAY, font=font_sml)
for txt in ["私隱政策","服務條款","支援"]:
    y += 55
    d3.text((SCREEN_X+70, y), txt, fill=TIFFANY, font=font_mid)
img3.save(f"{OUT_DIR}/03-settings.jpg", "JPEG", quality=95)
print("3 OK")

# 4: Safety Resources
img4 = Image.new("RGB", (BEZEL_W, BEZEL_H), (40,40,50))
d4 = ImageDraw.Draw(img4)
draw_rrect(d4, (SCREEN_X, SCREEN_Y, SCREEN_X+SCREEN_W, SCREEN_Y+SCREEN_H), RADIUS, fill=BG)
d4.text((SCREEN_X+60, SCREEN_Y+100), "安全資源", fill=WHITE, font=font_big)
res = [("撒瑪利亞會 2896 0000","24小時情緒支援"),("明愛向晴熱線 18288","家庭危機支援"),("和諧之家 2522 0434","家庭暴力/操控關係"),("雨過天晴 2375 5322","性暴力支援"),("緊急求助 999","")]
y = SCREEN_Y+190
for t,dsc in res:
    draw_rrect(d4, (SCREEN_X+50, y, SCREEN_X+SCREEN_W-50, y+95), 20, fill=PANEL)
    d4.text((SCREEN_X+80, y+15), t, fill=WHITE, font=font_mid)
    if dsc:
        d4.text((SCREEN_X+80, y+55), dsc, fill=GRAY, font=font_sml)
    y += 115
img4.save(f"{OUT_DIR}/04-safety-resources.jpg", "JPEG", quality=95)
print("4 OK")

# 5: Score Trend
img5 = Image.new("RGB", (BEZEL_W, BEZEL_H), (40,40,50))
d5 = ImageDraw.Draw(img5)
draw_rrect(d5, (SCREEN_X, SCREEN_Y, SCREEN_X+SCREEN_W, SCREEN_Y+SCREEN_H), RADIUS, fill=BG)
d5.text((SCREEN_X+60, SCREEN_Y+100), "分數趨勢", fill=WHITE, font=font_big)
data = [10,15,22,18,30,45,38,55,62,70,78,65,82,87,75,68,80,92]
cx0, cy0, cw, ch = SCREEN_X+80, SCREEN_Y+220, SCREEN_W-160, 450
pts = [(cx0+i*(cw//(len(data)-1)), cy0+int(ch-(v/100)*ch)) for i,v in enumerate(data)]
for i in range(len(pts)-1):
    d5.line([pts[i], pts[i+1]], fill=TIFFANY, width=4)
for p in pts:
    d5.ellipse([p[0]-5, p[1]-5, p[0]+5, p[1]+5], fill=TIFFANY)
img5.save(f"{OUT_DIR}/05-score-trend.jpg", "JPEG", quality=95)
print("5 OK")

# 6: Categories
img6 = Image.new("RGB", (BEZEL_W, BEZEL_H), (40,40,50))
d6 = ImageDraw.Draw(img6)
draw_rrect(d6, (SCREEN_X, SCREEN_Y, SCREEN_X+SCREEN_W, SCREEN_Y+SCREEN_H), RADIUS, fill=BG)
d6.text((SCREEN_X+60, SCREEN_Y+100), "PUA 分類識別", fill=WHITE, font=font_big)
cats = [("Gaslighting","14次"),("Emotional Blackmail","8次"),("Love Bombing","5次"),("Isolation","3次"),("Guilt Tripping","11次"),("Triangulation","2次")]
y = SCREEN_Y+190
for n,c in cats:
    draw_rrect(d6, (SCREEN_X+50, y, SCREEN_X+SCREEN_W-50, y+90), 20, fill=PANEL)
    d6.text((SCREEN_X+80, y+20), n, fill=WHITE, font=font_mid)
    d6.text((SCREEN_X+SCREEN_W-140, y+22), c, fill=TIFFANY, font=font_mid)
    y += 105
img6.save(f"{OUT_DIR}/06-categories.jpg", "JPEG", quality=95)
print("6 OK")

# Bezel overlay
bezel = Image.new("RGBA", (BEZEL_W, BEZEL_H), (0,0,0,0))
bd = ImageDraw.Draw(bezel)
bd.rounded_rectangle([0,0,BEZEL_W,BEZEL_H], radius=100, fill=(20,20,25,255))
bd.rounded_rectangle([SCREEN_X,SCREEN_Y,SCREEN_X+SCREEN_W,SCREEN_Y+SCREEN_H], radius=RADIUS, fill=(0,0,0,0))
di_x = SCREEN_X+SCREEN_W//2-90
bd.rounded_rectangle([di_x,SCREEN_Y+15,di_x+180,SCREEN_Y+55], radius=20, fill=(20,20,25,255))
bezel.save(f"{OUT_DIR}/bezel_overlay.png", "PNG")

for name in ["01-main-gauge","02-alert","03-settings","04-safety-resources","05-score-trend","06-categories"]:
    screen = Image.open(f"{OUT_DIR}/{name}.jpg")
    screen.paste(bezel, (0,0), bezel)
    screen.save(f"{OUT_DIR}/{name}_framed.jpg", "JPEG", quality=95)
    print(f"Framed {name}")

import subprocess
r = subprocess.run(["ls", "-lh", OUT_DIR], capture_output=True, text=True)
print(r.stdout)
