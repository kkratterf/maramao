# Temporary: list freely licensed cat videos/GIFs on Wikimedia Commons.
import json, urllib.request, urllib.parse, sys
API = "https://commons.wikimedia.org/w/api.php"
UA = {"User-Agent": "MaramaoSiteMedia/1.0 (https://github.com/kkratterf/maramao)"}
def q(params):
    params = dict(params, format="json", formatversion="2")
    req = urllib.request.Request(API + "?" + urllib.parse.urlencode(params), headers=UA)
    return json.load(urllib.request.urlopen(req, timeout=60))
roots = sys.argv[1:] or ["Category:Videos of cats", "Category:Animated GIFs of cats"]
seen_cats, files = set(), {}
def walk(cat, depth):
    if cat in seen_cats or depth > 2: return
    seen_cats.add(cat)
    cont = {}
    while True:
        r = q(dict(action="query", list="categorymembers", cmtitle=cat, cmlimit="500", cmtype="file|subcat", **cont))
        for m in r["query"]["categorymembers"]:
            if m["ns"] == 14: walk(m["title"], depth + 1)
            else: files.setdefault(m["title"], cat)
        if "continue" not in r: break
        cont = {"cmcontinue": r["continue"]["cmcontinue"]}
for c in roots: walk(c, 0)
for term in ["cat keyboard", "cat laptop", "cat computer", "cat laser", "cat sleeping", "kitten playing", "cat yawning", "cat stretching", "cat walking", "kittens", "cat box", "cat window", "cat paw", "cat grooming", "cat jumping", "cat toy"]:
    for ft in ("filetype:video", "filetype:gif"):
        try:
            r = q(dict(action="query", list="search", srnamespace="6", srsearch=term + " " + ft, srlimit="100"))
            for m in r["query"]["search"]: files.setdefault(m["title"], "search:" + term)
        except Exception as e: print("search fail", term, e, file=sys.stderr)
print("categories", len(seen_cats), "files", len(files), file=sys.stderr)
titles = list(files)
out = []
for i in range(0, len(titles), 50):
    r = q(dict(action="query", titles="|".join(titles[i:i+50]), prop="imageinfo",
               iiprop="url|size|mime|extmetadata|mediatype", iiextmetadatafilter="LicenseShortName|Artist|ObjectName|ImageDescription"))
    for p in r["query"]["pages"]:
        ii = (p.get("imageinfo") or [{}])[0]
        md = ii.get("extmetadata", {})
        g = lambda k: (md.get(k, {}).get("value") or "")
        lic = g("LicenseShortName")
        if ii.get("mediatype") not in ("VIDEO",) and ii.get("mime") != "image/gif": continue
        out.append(dict(t=p["title"], cat=files[p["title"]], lic=lic, mime=ii.get("mime"), w=ii.get("width"), h=ii.get("height"),
                        size=ii.get("size"), dur=ii.get("duration"), artist=__import__("re").sub("<[^>]+>", "", g("Artist"))[:60],
                        desc=__import__("re").sub("<[^>]+>", "", g("ImageDescription"))[:110].replace("\n", " ")))
ok = [o for o in out if any(k in o["lic"].lower() for k in ("cc0", "public domain", "pd", "cc by")) and 1 <= (o["dur"] or 3) <= 90]
ok.sort(key=lambda o: (o["lic"], o["t"]))
import io, contextlib
buf = io.StringIO()
for o in ok:
    print(file=buf, *[f'{o["lic"]:<14}|{o["mime"]}|{o["w"]}x{o["h"]}|{(o["dur"] or 0):.0f}s|{(o["size"] or 0)//1024}KB|{o["t"]}|{o["artist"]}|{o["desc"]}'])
open(".media/report.txt", "w").write(buf.getvalue())
print("total ok", len(ok), "of", len(out), file=sys.stderr)
