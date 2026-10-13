"""Packages build/web (Godot's Web export) into build/vercel for static hosting.

Vercel rejects very large single files, so index.pck is split into ~45 MB parts
named after its hash (so they can be cached forever) and a small loader in
index.html joins them back together when Godot fetches index.pck. Also adds the
social-preview tags and a loading caption.

    python tools/make_vercel.py
    cd build/vercel && vercel deploy --prod --yes --archive=tgz
"""
import hashlib
import json
import pathlib
import shutil

ROOT = pathlib.Path(__file__).resolve().parent.parent
WEB = ROOT / "build" / "web"
OUT = ROOT / "build" / "vercel"
PART = 45 * 1024 * 1024
COPY = ["index.html", "index.js", "index.wasm", "index.audio.worklet.js",
        "index.audio.position.worklet.js", "index.icon.png", "index.apple-touch-icon.png", "index.png"]

CAPTION_CSS = """
#lh-caption {
	position: absolute;
	left: 0; right: 0; bottom: 6%;
	text-align: center;
	font: 15px/1.5 system-ui, -apple-system, "Segoe UI", sans-serif;
	color: #cfd8e6;
	padding: 0 16px;
}
"""

CAPTION_JS = """					const cap = document.getElementById('lh-caption');
					if (cap) {
						cap.textContent = current >= total
							? 'Building the garden… this can take up to a minute, the page may look frozen. Hang tight!'
							: 'Downloading the garden… ' + Math.round(current / 1048576) + ' / ' + Math.round(total / 1048576) + ' MB';
					}
"""


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for f in OUT.iterdir():
        if f.is_file():
            f.unlink()
    for name in COPY:
        shutil.copy2(WEB / name, OUT / name)
    shutil.copy2(ROOT / "screenshots" / "01_arrival_bridge.png", OUT / "preview.png")

    pck = (WEB / "index.pck").read_bytes()
    tag = hashlib.sha1(pck).hexdigest()[:8]
    parts = 0
    for i in range(0, len(pck), PART):
        (OUT / f"index.{tag}.pck.part{parts}").write_bytes(pck[i:i + PART])
        parts += 1

    head = (ROOT / "tools" / "vercel_head.html").read_text(encoding="utf-8")
    head = head.replace("__PARTS__", str(parts)).replace("'index.pck.part", f"'index.{tag}.pck.part")
    html = (OUT / "index.html").read_text(encoding="utf-8")
    html = html.replace("<title>Lantern Hollow</title>\n", "<title>Lantern Hollow</title>\n" + head, 1)
    html = html.replace("</style>", CAPTION_CSS + "</style>", 1)
    html = html.replace('<progress id="status-progress"></progress>',
                        '<progress id="status-progress"></progress>\n\t\t\t<div id="lh-caption">Loading Lantern Hollow…</div>', 1)
    anchor = "statusProgress.max = total;\n"
    assert anchor in html, "Godot's index.html changed; update make_vercel.py"
    html = html.replace(anchor, anchor + CAPTION_JS, 1)
    (OUT / "index.html").write_text(html, encoding="utf-8")

    # Ask the browser for the dedicated GPU on two-GPU laptops.
    js = (OUT / "index.js").read_text(encoding="utf-8")
    js = js.replace("powerPreference:webglPowerPreferences[powerPreference]", 'powerPreference:"high-performance"')
    (OUT / "index.js").write_text(js, encoding="utf-8")

    (OUT / "vercel.json").write_text(json.dumps({"headers": [
        {"source": "/(.*).pck.part(.*)", "headers": [
            {"key": "Cache-Control", "value": "public, max-age=31536000, immutable"},
            {"key": "Content-Type", "value": "application/octet-stream"}]},
        {"source": "/index.wasm", "headers": [
            {"key": "Cache-Control", "value": "public, max-age=3600, must-revalidate"},
            {"key": "Content-Type", "value": "application/wasm"}]},
    ]}, indent=2), encoding="utf-8")
    # Never publish the Vercel CLI's local token/link files.
    (OUT / ".vercelignore").write_text(".env*\n.gitignore\n.vercel\n", encoding="utf-8")
    print(f"build/vercel ready: {parts} data parts ({tag}), {len(pck) / 1e6:.0f} MB")


if __name__ == "__main__":
    main()
