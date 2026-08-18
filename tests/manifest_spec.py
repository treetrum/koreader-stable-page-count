import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

manifest = json.loads((ROOT / "manifest.json").read_text())
release_manifest = json.loads((ROOT / ".release-please-manifest.json").read_text())

assert manifest["schema_version"] == "1"
assert manifest["repo"]["url"] == "https://zenpm.treetrum.com/"
assert len(manifest["packages"]) == 1

package = manifest["packages"][0]
assert package["id"] == "koreader-stable-page-count"
assert package["version"] == release_manifest["."]
assert package["platforms"] == ["koreader"]
assert package["plugin_module"] == "pagecount"
assert package["source_asset"] == "pagecount.koplugin.zip"
assert package["readme_url"] == "README.md"
assert package["screenshots"] == ["docs/images/page-count-dialog.png"]
assert package["assets"] == [
    {
        "arch": "any",
        "asset": "pagecount.koplugin.zip",
        "url": "https://github.com/treetrum/koreader-stable-page-count/releases/latest/download/pagecount.koplugin.zip",
        "size": "",
    }
]

print("ZenPM manifest tests passed")
