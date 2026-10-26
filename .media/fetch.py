# Temporary: download the picked Commons clips and cut them into small muted loops.
# pick.txt lines: slug|File:Title|start seconds|length seconds|crop (w:h:x:y in source px, optional)
import json, os, re, subprocess, urllib.request, urllib.parse
API = "https://commons.wikimedia.org/w/api.php"
UA = {"User-Agent": "MaramaoSiteMedia/1.0 (https://github.com/kkratterf/maramao)"}
os.makedirs("site/media", exist_ok=True)
credits = []
for line in open(".media/pick.txt"):
    line = line.strip()
    if not line or line.startswith("#"): continue
    parts = line.split("|") + [""] * 5
    slug, title, start, length, crop = [p.strip() for p in parts[:5]]
    width = 960 if slug == "hero" else 640
    r = json.load(urllib.request.urlopen(urllib.request.Request(API + "?" + urllib.parse.urlencode(dict(
        action="query", titles=title, prop="imageinfo", iiprop="url|extmetadata", format="json", formatversion="2")), headers=UA), timeout=60))
    ii = r["query"]["pages"][0]["imageinfo"][0]
    md = ii["extmetadata"]
    strip = lambda k: re.sub(r"\s+", " ", re.sub("<[^>]+>", "", md.get(k, {}).get("value", ""))).strip()
    src = f"/tmp/{slug}.src"
    with urllib.request.urlopen(urllib.request.Request(ii["url"], headers=UA), timeout=300) as resp, open(src, "wb") as f:
        f.write(resp.read())
    vf = (f"crop={crop}," if crop else "") + f"scale={width}:-2:flags=lanczos,fps=24,format=yuv420p"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-ss", start or "0", "-t", length or "5", "-i", src, "-an", "-vf", vf,
                    "-c:v", "libx264", "-preset", "veryslow", "-crf", "30", "-profile:v", "high", "-movflags", "+faststart",
                    f"site/media/{slug}.mp4"], check=True)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", f"site/media/{slug}.mp4", "-frames:v", "1", "-q:v", "6",
                    f"site/media/{slug}.jpg"], check=True)
    credits.append(dict(slug=slug, title=title, page=ii["descriptionurl"], artist=strip("Artist"),
                        license=strip("LicenseShortName"), licenseUrl=md.get("LicenseUrl", {}).get("value", "")))
    print(slug, os.path.getsize(f"site/media/{slug}.mp4") // 1024, "KB", credits[-1]["license"], credits[-1]["artist"])
json.dump(credits, open(".media/credits.json", "w"), indent=2, ensure_ascii=False)
