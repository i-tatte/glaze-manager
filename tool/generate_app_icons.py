# -*- coding: utf-8 -*-
"""アプリアイコン候補のPNGを生成する。

デザイン案 (docs/実装計画.md 第6章、プレビューSVGと同じ100x100単位座標系):
  A: 釉掛けタイル / B: テスピグリッド / D: 釉掛けの壺

実行 (functions の venv に Pillow が入っている):
  .\\functions\\venv\\Scripts\\python.exe tool\\generate_app_icons.py

出力:
  assets/icon/app_icon_a.png, app_icon_b.png, app_icon_d.png (各1024x1024)
  assets/icon/app_icon_adaptive_fg.png (アダプティブ前景: 透明)

アイコンの切替は tool/set_app_icon.ps1 を使う。
"""
import math
import os

from PIL import Image, ImageChops, ImageDraw

SIZE = 1024
S = SIZE / 100.0  # 100単位デザイン → 1024px

GLAZE = (127, 174, 163, 255)   # #7FAEA3 青磁釉
CLAY = (201, 180, 154, 255)    # #C9B49A 素地土


def icon_a() -> Image.Image:
    """案A 釉掛けタイル: 素地土の上半分に青磁釉+垂れ3本+光沢"""
    img = Image.new("RGBA", (SIZE, SIZE), CLAY)
    draw = ImageDraw.Draw(img)
    draw.rectangle((0, 0, SIZE, 50 * S), fill=GLAZE)
    for x, y, w, h in [(20, 22, 12, 42), (62, 22, 12, 54), (43, 22, 9, 34)]:
        draw.rounded_rectangle(
            (x * S, y * S, (x + w) * S, (y + h) * S),
            radius=(w / 2) * S,
            fill=GLAZE,
        )
    overlay = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(overlay).ellipse(
        ((74 - 5) * S, (16 - 5) * S, (74 + 5) * S, (16 + 5) * S),
        fill=(255, 255, 255, 89),  # alpha 0.35
    )
    return Image.alpha_composite(img, overlay)


def icon_b() -> Image.Image:
    """案B テスピグリッド: 焦茶地に青磁・白萩・飴・瑠璃の4タイル"""
    img = Image.new("RGBA", (SIZE, SIZE), (59, 51, 46, 255))  # #3B332E
    draw = ImageDraw.Draw(img)
    tiles = [
        (8, 8, GLAZE),                     # 青磁
        (53, 8, (237, 230, 214, 255)),     # 白萩 #EDE6D6
        (8, 53, (184, 118, 58, 255)),      # 飴   #B8763A
        (53, 53, (74, 111, 165, 255)),     # 瑠璃 #4A6FA5
    ]
    for x, y, color in tiles:
        draw.rounded_rectangle(
            (x * S, y * S, (x + 39) * S, (y + 39) * S),
            radius=9 * S,
            fill=color,
        )
    return img


def _cubic(p0, p1, p2, p3, steps=24):
    """3次ベジェ曲線を折れ線近似する"""
    pts = []
    for i in range(1, steps + 1):
        t = i / steps
        u = 1 - t
        x = u**3 * p0[0] + 3 * u**2 * t * p1[0] + 3 * u * t**2 * p2[0] + t**3 * p3[0]
        y = u**3 * p0[1] + 3 * u**2 * t * p1[1] + 3 * u * t**2 * p2[1] + t**3 * p3[1]
        pts.append((x, y))
    return pts


def _pot_polygon():
    """壺のシルエット (プレビューSVGのパスを折れ線近似)。100単位座標"""
    pts = [(39, 14), (61, 14), (61, 23)]
    # 右肩: c0,5 15,9 15,29 → (61,23)→(76,52)
    pts += _cubic((61, 23), (61, 28), (76, 32), (76, 52))
    # 胴の下半円: (76,52)→(24,52) を下側経由 (中心(50,52), 半径26)
    for i in range(1, 37):
        theta = math.pi * i / 36
        pts.append((50 + 26 * math.cos(theta), 52 + 26 * math.sin(theta)))
    # 左肩: c0,-20 15,-24 15,-29 → (24,52)→(39,23)
    pts += _cubic((24, 52), (24, 32), (39, 28), (39, 23))
    return [(x * S, y * S) for x, y in pts]


def icon_d() -> Image.Image:
    """案D 釉掛けの壺: 焦茶地に素地色の壺、上部を青磁釉にディップ"""
    img = Image.new("RGBA", (SIZE, SIZE), (64, 56, 47, 255))  # #40382F
    polygon = _pot_polygon()

    # 壺本体
    draw = ImageDraw.Draw(img)
    draw.polygon(polygon, fill=(228, 213, 190, 255))  # #E4D5BE

    # 釉薬領域 (上部44単位 + 垂れ2本) を壺の形でクリップして重ねる
    pot_mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(pot_mask).polygon(polygon, fill=255)

    glaze_region = Image.new("L", (SIZE, SIZE), 0)
    gdraw = ImageDraw.Draw(glaze_region)
    gdraw.rectangle((0, 0, SIZE, 44 * S), fill=255)
    for x, y, w, h in [(43, 20, 10, 38), (60, 20, 8, 30)]:
        gdraw.rounded_rectangle(
            (x * S, y * S, (x + w) * S, (y + h) * S),
            radius=(w / 2) * S,
            fill=255,
        )

    mask = ImageChops.multiply(pot_mask, glaze_region)
    img.paste(Image.new("RGBA", (SIZE, SIZE), GLAZE), mask=mask)
    return img


def main() -> None:
    out_dir = os.path.join(os.path.dirname(__file__), "..", "assets", "icon")
    os.makedirs(out_dir, exist_ok=True)
    for name, icon in [("a", icon_a()), ("b", icon_b()), ("d", icon_d())]:
        path = os.path.join(out_dir, f"app_icon_{name}.png")
        icon.save(path)
        print(f"wrote {path}")
    fg_path = os.path.join(out_dir, "app_icon_adaptive_fg.png")
    Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0)).save(fg_path)
    print(f"wrote {fg_path}")


if __name__ == "__main__":
    main()
