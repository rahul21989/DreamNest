#!/usr/bin/env python3
"""
DreamNest – Cultural Template Artwork Downloader
=================================================
Sources tried in order for each template:
  1. Pollinations.ai       – free GET, no account
  2. Stable Horde          – free community AI (slow; skipped if 429)
  3. Wikimedia Commons     – specific known filenames
  4. Commons search        – dynamic search for any matching file
  5. Wikipedia REST API    – article lead image (most reliable fallback)

Usage:
  python3 download_artwork.py           # normal run
  python3 download_artwork.py --force   # re-download everything
"""

import os, json, sys, time, base64, random, urllib.request, urllib.parse

# ── Paths ─────────────────────────────────────────────────────────────────────

ASSETS_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "DreamNest", "Assets.xcassets"
)

# ── Style constants ───────────────────────────────────────────────────────────

FOLK_STYLE = (
    "madhubani pattachitra folk art style, vibrant traditional Indian illustration, "
    "hand-drawn decorative border patterns, rich jewel-tone colors, intricate details, "
    "children's picture book art, warm lighting, no text, no watermark"
)
NEGATIVE = (
    "photograph, realistic photo, 3d render, blurry, low quality, "
    "text, watermark, signature, ugly, dark, scary, western art"
)

# ── Template definitions ──────────────────────────────────────────────────────

TEMPLATES = [
    {
        "id":             "template_bal_krishna",
        "prompt":         f"baby Krishna blue skin playing golden flute, peacock feather crown, cows lotus flowers Vrindavan riverside, {FOLK_STYLE}",
        "commons_files":  ["Raja_Ravi_Varma_-_Krishna_and_Arjun.jpg",
                           "Shri_krishna_and_arjuna.jpg"],
        "commons_search": "krishna painting traditional indian art",
        "wiki_article":   "Krishna",
    },
    {
        "id":             "template_bal_ganesha",
        "prompt":         f"baby Ganesha elephant head holding sweet modak, tiny mouse Mushak, lotus throne, gold ornaments, {FOLK_STYLE}",
        "commons_files":  ["Ganesha_Basohli_miniature_circa_1730_Dubost_p73.jpg",
                           "Ganesha_Ravi_Varma.jpg"],
        "commons_search": "ganesha painting traditional indian miniature",
        "wiki_article":   "Ganesha",
    },
    {
        "id":             "template_bal_hanuman",
        "prompt":         f"young Hanuman monkey god leaping joyfully through clouds, glowing sun, mountains forests, orange gold devotional, {FOLK_STYLE}",
        "commons_files":  ["Hanuman_3.jpg",
                           "Jai_Hanuman.jpg"],
        "commons_search": "hanuman painting traditional indian art",
        "wiki_article":   "Hanuman",
    },
    {
        "id":             "template_panchatantra",
        "prompt":         f"clever monkey in mango tree, crocodile in river below, lush Indian jungle with parrots and peacocks, {FOLK_STYLE}",
        "commons_files":  ["Kalila_wa_Dimna_-_The_Lion_and_the_Ox.jpg"],
        "commons_search": "panchatantra animals fable illustration",
        "wiki_article":   "Panchatantra",
    },
    {
        "id":             "template_jataka",
        "prompt":         f"golden deer by lotus pond in ancient forest, animals gathered, sacred Bodhi tree glowing, compassionate peaceful scene, {FOLK_STYLE}",
        "commons_files":  ["Ajanta_cave_painting.jpg",
                           "Ajanta_Caves_painting.jpg",
                           "Bodhisattva_Padmapani.jpg"],
        "commons_search": "ajanta cave mural buddhist painting india",
        "wiki_article":   "Ajanta Caves",
    },
    {
        "id":             "template_festivals",
        "prompt":         f"Diwali festival glowing clay oil lamps, colorful rangoli, fireworks in night sky, family in traditional clothes, {FOLK_STYLE}",
        "commons_files":  ["Diya_-_an_oil_lamp.jpg",
                           "India_diwali_diya.jpg",
                           "Diwali_Diya.jpg",
                           "Lamps_during_diwali.jpg"],
        "commons_search": "diwali diya oil lamp festival india",
        "wiki_article":   "Diwali",
    },
    {
        "id":             "template_folklore",
        "prompt":         f"wise grandmother telling bedtime stories to children under banyan tree at night, stars moon, fireflies, magical village scene, {FOLK_STYLE}",
        "commons_files":  ["Kalamkari.jpg",
                           "Kalamkari_art.jpg",
                           "Srikalahasti_Kalamkari.jpg"],
        "commons_search": "kalamkari warli madhubani folk painting india",
        "wiki_article":   "Warli painting",
    },
]

# ── Config ────────────────────────────────────────────────────────────────────

HEADERS     = {"User-Agent": "DreamNest/1.0 (educational children app)"}
THUMB_WIDTH = 900
CONTENTS_TEMPLATE = {
    "images": [
        {"idiom": "universal", "scale": "1x"},
        {"idiom": "universal", "scale": "2x"},
        {"idiom": "universal", "scale": "3x"},
    ],
    "info": {"author": "dreamnest-script", "version": 1},
}

# ── Source 1: Pollinations.ai ─────────────────────────────────────────────────

def pollinations_generate(prompt: str) -> bytes | None:
    encoded = urllib.parse.quote(prompt)
    seed    = random.randint(1, 999999)
    url     = (f"https://image.pollinations.ai/prompt/{encoded}"
               f"?width=768&height=1024&nologo=true&seed={seed}")
    try:
        req = urllib.request.Request(url, headers=HEADERS)
        with urllib.request.urlopen(req, timeout=90) as r:
            data = r.read()
        if len(data) > 10_000:
            return data
    except urllib.error.HTTPError as e:
        print(f"HTTP {e.code} ", end="", flush=True)
    except Exception as e:
        print(f"error: {e} ", end="", flush=True)
    return None

# ── Source 2: Stable Horde ────────────────────────────────────────────────────

HORDE_API = "https://stablehorde.net/api/v2"
HORDE_KEY = "0000000000"

def horde_generate(prompt: str) -> bytes | None:
    hdr = {**HEADERS, "apikey": HORDE_KEY, "Content-Type": "application/json"}
    payload = json.dumps({
        "prompt":  f"{prompt} ### {NEGATIVE}",
        "params":  {"sampler_name": "k_euler_a", "cfg_scale": 7,
                    "steps": 25, "width": 768, "height": 1024, "n": 1},
        "models":  [],
        "r2":      False,
        "nsfw":    False,
        "shared":  True,
    }).encode()

    try:
        req = urllib.request.Request(
            f"{HORDE_API}/generate/async",
            data=payload, headers=hdr, method="POST")
        with urllib.request.urlopen(req, timeout=30) as r:
            resp = json.loads(r.read())
        uuid = resp.get("id")
        if not uuid:
            return None
    except urllib.error.HTTPError as e:
        if e.code == 429:
            print("rate-limited ", end="", flush=True)
        else:
            print(f"HTTP {e.code} ", end="", flush=True)
        return None
    except Exception as e:
        print(f"error: {e} ", end="", flush=True)
        return None

    # Poll
    for i in range(96):
        time.sleep(5)
        try:
            with urllib.request.urlopen(
                urllib.request.Request(
                    f"{HORDE_API}/generate/check/{uuid}",
                    headers={**HEADERS, "apikey": HORDE_KEY}),
                timeout=15) as r:
                check = json.loads(r.read())
            if check.get("done"):
                break
            if i % 4 == 0:
                print(f"q#{check.get('queue_position','?')} ~{check.get('wait_time','?')}s… ",
                      end="", flush=True)
        except Exception:
            pass
    else:
        print("timeout ", end="", flush=True)
        return None

    try:
        with urllib.request.urlopen(
            urllib.request.Request(
                f"{HORDE_API}/generate/status/{uuid}",
                headers={**HEADERS, "apikey": HORDE_KEY}),
            timeout=30) as r:
            status = json.loads(r.read())
        gens = status.get("generations", [])
        if gens:
            b64 = gens[0].get("img", "")
            if b64:
                return base64.b64decode(b64)
    except Exception as e:
        print(f"fetch error: {e} ", end="", flush=True)
    return None

# ── Source 3: Wikimedia Commons — specific file ───────────────────────────────

def commons_file_url(filename: str) -> str | None:
    params = urllib.parse.urlencode({
        "action": "query", "titles": f"File:{filename}",
        "prop": "imageinfo", "iiprop": "url",
        "iiurlwidth": THUMB_WIDTH, "format": "json",
    })
    try:
        req = urllib.request.Request(
            f"https://commons.wikimedia.org/w/api.php?{params}", headers=HEADERS)
        with urllib.request.urlopen(req, timeout=20) as r:
            data = json.loads(r.read())
        for page in data.get("query", {}).get("pages", {}).values():
            if page.get("pageid", -1) == -1:
                return None
            info = page.get("imageinfo", [{}])[0]
            return info.get("thumburl") or info.get("url")
    except Exception:
        return None

# ── Source 4: Wikimedia Commons — dynamic search ─────────────────────────────

def commons_search_url(query: str) -> str | None:
    """Full-text search Commons file namespace; return first usable image URL."""
    params = urllib.parse.urlencode({
        "action": "query", "list": "search",
        "srsearch": query, "srnamespace": "6",
        "srlimit": "15", "format": "json",
    })
    try:
        req = urllib.request.Request(
            f"https://commons.wikimedia.org/w/api.php?{params}", headers=HEADERS)
        with urllib.request.urlopen(req, timeout=20) as r:
            data = json.loads(r.read())
        results = data.get("query", {}).get("search", [])
        for result in results:
            title = result.get("title", "")
            if any(title.lower().endswith(ext) for ext in (".jpg", ".jpeg", ".png")):
                filename = title.removeprefix("File:")
                url = commons_file_url(filename)
                if url:
                    return url
    except Exception:
        pass
    return None

# ── Source 5: Wikipedia REST summary API ─────────────────────────────────────

def wikipedia_image_url(article: str) -> str | None:
    """Use the Wikipedia REST summary endpoint — more reliable than pageimages."""
    encoded = urllib.parse.quote(article.replace(" ", "_"))
    url     = f"https://en.wikipedia.org/api/rest_v1/page/summary/{encoded}"
    try:
        req = urllib.request.Request(url, headers=HEADERS)
        with urllib.request.urlopen(req, timeout=20) as r:
            data = json.loads(r.read())
        # Prefer full-size originalimage, fall back to thumbnail
        for key in ("originalimage", "thumbnail"):
            src = data.get(key, {}).get("source")
            if src:
                return src
    except Exception:
        pass
    return None

# ── Asset helpers ─────────────────────────────────────────────────────────────

def ensure_imageset(asset_id: str) -> str:
    folder   = os.path.join(ASSETS_DIR, f"{asset_id}.imageset")
    filename = f"{asset_id}@2x.jpg"
    os.makedirs(folder, exist_ok=True)
    contents = json.loads(json.dumps(CONTENTS_TEMPLATE))
    for img in contents["images"]:
        if img.get("scale") == "2x":
            img["filename"] = filename
    with open(os.path.join(folder, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
    return os.path.join(folder, filename)

def save_bytes(data: bytes, dest: str) -> bool:
    if len(data) < 10_000:
        return False
    with open(dest, "wb") as f:
        f.write(data)
    return True

def download_url(url: str, dest: str) -> bool:
    try:
        req = urllib.request.Request(url, headers=HEADERS)
        with urllib.request.urlopen(req, timeout=60) as r:
            data = r.read()
        return save_bytes(data, dest)
    except Exception:
        return False

# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    force = "--force" in sys.argv

    if not os.path.isdir(ASSETS_DIR):
        print(f"ERROR: Assets.xcassets not found:\n  {ASSETS_DIR}")
        sys.exit(1)

    print("\nDreamNest Artwork Downloader")
    print("Sources: Pollinations → Stable Horde → Commons → Commons search → Wikipedia")
    print("─" * 70)

    failed = []

    for t in TEMPLATES:
        dest = ensure_imageset(t["id"])

        if not force and os.path.exists(dest) and os.path.getsize(dest) > 10_000:
            print(f"  ✓  {t['id']}  (cached — use --force to regenerate)")
            continue

        print(f"\n  ⬇  {t['id']}")
        ok = False

        # 1. Pollinations
        print(f"       🎨 Pollinations… ", end="", flush=True)
        img = pollinations_generate(t["prompt"])
        if img:
            ok = save_bytes(img, dest)
            print(f"✓  ({os.path.getsize(dest)//1024} KB)" if ok else "✗")

        # 2. Stable Horde (skip immediately if last attempt gave 429)
        if not ok:
            print(f"       🤖 Stable Horde… ", end="", flush=True)
            time.sleep(3)   # brief pause to reduce 429 chance
            img = horde_generate(t["prompt"])
            if img:
                ok = save_bytes(img, dest)
                print(f"✓  ({os.path.getsize(dest)//1024} KB)" if ok else "✗")
            else:
                print("✗")

        # 3. Specific Commons files
        if not ok:
            for fname in t.get("commons_files", []):
                label = (fname[:52] + "…") if len(fname) > 52 else fname
                print(f"       Commons: {label} ", end="", flush=True)
                url = commons_file_url(fname)
                if url:
                    ok = download_url(url, dest)
                    print(f"✓  ({os.path.getsize(dest)//1024} KB)" if ok else "✗")
                    if ok:
                        break
                else:
                    print("not found")

        # 4. Commons full-text search
        if not ok and t.get("commons_search"):
            q = t["commons_search"]
            print(f"       Commons search: '{q}'… ", end="", flush=True)
            url = commons_search_url(q)
            if url:
                ok = download_url(url, dest)
                print(f"✓  ({os.path.getsize(dest)//1024} KB)" if ok else "✗")
            else:
                print("no results")

        # 5. Wikipedia REST summary image
        if not ok and t.get("wiki_article"):
            article = t["wiki_article"]
            print(f"       Wikipedia '{article}'… ", end="", flush=True)
            url = wikipedia_image_url(article)
            if url:
                ok = download_url(url, dest)
                print(f"✓  ({os.path.getsize(dest)//1024} KB)" if ok else "✗")
            else:
                print("no image found ✗")

        if not ok:
            print(f"       ✗ all sources failed")
            failed.append(t["id"])

    print()
    print("─" * 70)
    if failed:
        print(f"⚠  {len(failed)} failed: {failed}")
    else:
        print("✅  All artwork ready!  Rebuild the app in Xcode.")
    print()

if __name__ == "__main__":
    main()
