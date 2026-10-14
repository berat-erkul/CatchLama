# art/ altındaki görsellerden ikonları üretir. Pillow gerekir.
#   T=$(mktemp -d); mkdir $T/AppIcon.iconset
#   python3 scripts/make-icons.py $T Resources && iconutil -c icns $T/AppIcon.iconset -o Resources/AppIcon.icns
import sys, pathlib
from PIL import Image, ImageDraw, ImageFilter, ImageChops
D = str(pathlib.Path(__file__).parent.parent / "art") + "/"
S, R = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])  # S: geçici klasör (iconset + önizleme), R: Resources

# 1) Uygulama ikonu: renkli görselin ortasındaki karo, macOS ikon ızgarası (1024 tuvalde 824'lük yuvarlak kare)
src = Image.open(D + "app-icon-source.jpg").convert("RGB")
# macOS 26 kendi squircle maskesini uyguluyor; saydam kenarlı ikonu gri çerçeveye hapsediyor → kenardan kenara opak kare
icon = src.crop((458, 88, 958, 588)).resize((1024, 1024), Image.LANCZOS).convert("RGBA")
for px in (16, 32, 128, 256, 512):
    icon.resize((px, px), Image.LANCZOS).save(S / f"AppIcon.iconset/icon_{px}x{px}.png")
    icon.resize((px * 2, px * 2), Image.LANCZOS).save(S / f"AppIcon.iconset/icon_{px}x{px}@2x.png")
icon.save(S / "appicon_1024.png")

# 2) Menü çubuğu: çizgi çizimden template ikon (siyah + alfa); macOS açık/koyu bara göre boyar
def menu_icon(fname, name):
    g = Image.open(D + fname).convert("L")
    inner = g.crop((450, 105, 955, 610))                 # karonun içi (kenar gölgesi hariç)
    alpha = inner.point(lambda v: max(0, min(255, (190 - v) * 255 // 110)))  # koyu = opak
    alpha = alpha.crop(alpha.point(lambda v: 255 if v > 128 else 0).getbbox())
    alpha = alpha.filter(ImageFilter.MaxFilter(5))       # küçülünce çizgiler kaybolmasın diye kalınlaştır
    side = max(alpha.size) + 20
    sq = Image.new("L", (side, side), 0)
    sq.paste(alpha, ((side - alpha.width) // 2, (side - alpha.height) // 2))
    for scale, suffix in ((1, ""), (2, "@2x")):
        a = sq.resize((22 * scale, 22 * scale), Image.LANCZOS)
        out = Image.new("RGBA", a.size, (0, 0, 0, 0)); out.putalpha(a)
        out.save(R / f"{name}{suffix}.png")
    return sq

idle = menu_icon("menu-idle-source.jpg", "MenuIdle")
busy = menu_icon("menu-busy-source.jpg", "MenuBusy")

# Önizleme: gerçek boy (@2x) açık ve koyu bar üstünde, 4 kat büyütülmüş
prev = Image.new("RGB", (4 * 44 * 2 + 30, 4 * 44 * 2 + 30), "white")
for col, name in enumerate(("MenuIdle", "MenuBusy")):
    a = Image.open(R / f"{name}@2x.png").getchannel("A")
    for row, (bg, fg) in enumerate((((236, 236, 236), (0, 0, 0)), ((40, 40, 40), (255, 255, 255)))):
        tile = Image.new("RGB", (44, 44), bg); tile.paste(Image.new("RGB", (44, 44), fg), (0, 0), a)
        prev.paste(tile.resize((176, 176), Image.NEAREST), (10 + col * 186, 10 + row * 186))
prev.save(S / "menu_preview.png")
icon.resize((256, 256), Image.LANCZOS).save(S / "appicon_preview.png")
print("ok")
