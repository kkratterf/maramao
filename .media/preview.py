# Temporary: contact sheets (12 frames with timestamps) for candidate clips.
import json, os, subprocess, urllib.request, urllib.parse
from PIL import Image, ImageDraw
API = "https://commons.wikimedia.org/w/api.php"
UA = {"User-Agent": "MaramaoSiteMedia/1.0 (https://github.com/kkratterf/maramao)"}
os.makedirs(".media/sheets", exist_ok=True)
for i, title in enumerate(l.strip() for l in open(".media/preview.txt") if l.strip()):
    try:
        r = json.load(urllib.request.urlopen(urllib.request.Request(API + "?" + urllib.parse.urlencode(dict(
            action="query", titles=title, prop="imageinfo", iiprop="url|size", format="json", formatversion="2")), headers=UA), timeout=60))
        ii = r["query"]["pages"][0]["imageinfo"][0]
        src = "/tmp/src"
        with urllib.request.urlopen(urllib.request.Request(ii["url"], headers=UA), timeout=600) as resp, open(src, "wb") as f:
            f.write(resp.read())
        dur = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", src], capture_output=True, text=True).stdout.strip() or 10)
        tiles = []
        for k in range(12):
            t = dur * (k + 0.5) / 12
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-ss", f"{t:.2f}", "-i", src, "-frames:v", "1", "-vf", "scale=320:-2", "/tmp/f.png"], check=True)
            im = Image.open("/tmp/f.png").convert("RGB"); d = ImageDraw.Draw(im)
            d.rectangle([0, 0, 70, 22], fill="black"); d.text((5, 5), f"{t:.1f}s", fill="white")
            tiles.append(im)
        w, h = tiles[0].size
        sheet = Image.new("RGB", (w * 4, h * 3 + 30), "white")
        ImageDraw.Draw(sheet).text((8, 8), f"{i:02d} {title}  dur={dur:.1f}s  {ii['width']}x{ii['height']}", fill="black")
        for k, im in enumerate(tiles): sheet.paste(im, ((k % 4) * w, 30 + (k // 4) * h))
        sheet.save(f".media/sheets/{i:02d}.jpg", quality=70)
        print("ok", i, title)
    except Exception as e:
        print("FAIL", i, title, e)
