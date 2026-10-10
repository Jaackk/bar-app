#!/usr/bin/env python3
"""Review-only monitor for the drinks menus linked by the official Hove page.

Never writes app catalogue data, recipes, stock counts or a reviewed baseline
implicitly. A byte change means "review needed", not "a recipe has changed".
Only --accept-baseline promotes a successful check after a human/source review.
"""
import argparse
import hashlib
import json
import os
from datetime import datetime, timezone
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urljoin, urlparse
from urllib.request import Request, build_opener, HTTPRedirectHandler

SOURCE = "https://www.rockwater.uk/hove/"
HOSTS = {"www.rockwater.uk", "rockwater.uk"}
LABELS = ("drinks menu", "pub menu", "bar shack", "coffee shack")
MAX_BYTES = 20 * 1024 * 1024


def official(url):
    p = urlparse(url)
    return p.scheme == "https" and p.hostname in HOSTS and not p.username


class OfficialRedirects(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if not official(newurl):
            raise ValueError("Source redirected outside the official HTTPS website")
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def fetch(url, limit=MAX_BYTES):
    if not official(url):
        raise ValueError("Only official Rockwater HTTPS sources are allowed")
    request = Request(url, headers={"User-Agent": "BAR-menu-review/1.0", "Accept-Encoding": "identity"})
    with build_opener(OfficialRedirects()).open(request, timeout=25) as response:
        data = response.read(limit + 1)
        if len(data) > limit:
            raise ValueError("Source exceeds the review download limit")
        return data, response.geturl(), dict(response.headers)


class MenuLinks(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links = []
        self.href = None
        self.parts = []

    def handle_starttag(self, tag, attrs):
        if tag == "a":
            self.href = dict(attrs).get("href")
            self.parts = []

    def handle_data(self, data):
        if self.href is not None:
            self.parts.append(data)

    def handle_endtag(self, tag):
        if tag == "a" and self.href is not None:
            label = " ".join(" ".join(self.parts).split())
            self.links.append((label, urljoin(SOURCE, self.href)))
            self.href = None


def menu_links(html):
    parser = MenuLinks()
    parser.feed(html)
    result = {}
    for label, url in parser.links:
        key = label.casefold().replace("’", "'")
        if any(term in key for term in LABELS) and urlparse(url).path.lower().endswith(".pdf"):
            if not official(url):
                raise ValueError(f"Menu link needs source review: {label}")
            result[(key, url)] = {"label": label, "url": url}
    if not any("drinks menu" in key for key, _ in result):
        raise ValueError("The main Drinks Menu PDF link was not found; review the website structure")
    return sorted(result.values(), key=lambda x: (x["label"].casefold(), x["url"]))


def outlet(row):
    label = row.get("label", "").casefold()
    if "coffee shack" in label:
        return "hove-coffee-shack-linked"
    if "bar shack" in label:
        return "hove-bar-shack-linked"
    if "pub" in label:
        return "hove-pub"
    return "hove-main"


def document_text(data):
    try:
        import fitz
    except ImportError:
        return {"textStatus": "extractor-unavailable; compare retained PDF visually"}
    with fitz.open(stream=data, filetype="pdf") as pdf:
        lines = [" ".join(line.split()) for page in pdf for line in page.get_text().splitlines() if line.strip()]
        return {"textStatus": "extracted" if lines else "image-only; visual review required", "textLines": lines,
                "textSHA256": hashlib.sha256("\n".join(lines).encode()).hexdigest(), "pages": len(pdf)}


def differences(baseline, current):
    # One PDF can legitimately be linked by two outlets; don't collapse them by URL.
    old = {(outlet(r), r["url"]): r for r in baseline["menus"]}
    new = {(outlet(r), r["url"]): r for r in current["menus"]}
    changed = []
    for key in sorted(old.keys() & new.keys()):
        if old[key]["sha256"] != new[key]["sha256"]:
            before, after = old[key], new[key]
            entry = {"before": before, "after": after}
            if "textLines" in before and "textLines" in after:
                entry["addedTextCandidates"] = sorted(set(after["textLines"]) - set(before["textLines"]))
                entry["removedTextCandidates"] = sorted(set(before["textLines"]) - set(after["textLines"]))
                entry["reviewNote"] = "Text differences may be additions, removals, renames or layout changes. Review the actual outlet PDF; no recipe or stock update is approved."
            changed.append(entry)
    return {
        "added": [new[u] for u in sorted(new.keys() - old.keys())],
        "removed": [old[u] for u in sorted(old.keys() - new.keys())],
        "changed": changed,
    }


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    os.replace(tmp, path)


def check(destination, accept=False):
    destination.mkdir(parents=True, exist_ok=True)
    baseline_path = destination / "reviewed-baseline.json"
    report = {"checkedAt": datetime.now(timezone.utc).isoformat(), "source": SOURCE,
              "scope": "Published Hove drinks, Pub and Shack menu documents; not physical inventory.",
              "menus": [], "errors": [], "status": "checking"}
    try:
        html, _, _ = fetch(SOURCE, 4 * 1024 * 1024)
        links = menu_links(html.decode("utf-8", errors="replace"))
        for link in links:
            try:
                data, final_url, headers = fetch(link["url"])
                if not data.startswith(b"%PDF-"):
                    raise ValueError("Expected a PDF; received another document or challenge page")
                digest = hashlib.sha256(data).hexdigest()
                target = destination / "documents" / f"{digest}.pdf"
                target.parent.mkdir(exist_ok=True)
                if not target.exists():
                    target.write_bytes(data)
                lower_headers = {k.lower(): v for k, v in headers.items()}
                report["menus"].append({**link, "outlet": outlet(link), **document_text(data), "resolvedURL": final_url, "sha256": digest,
                                         "bytes": len(data), "lastModified": lower_headers.get("last-modified"),
                                         "document": f"documents/{digest}.pdf"})
            except Exception as exc:
                report["errors"].append({"url": link["url"], "message": str(exc)})
    except Exception as exc:
        report["errors"].append({"url": SOURCE, "message": str(exc)})
    if report["errors"]:
        report["status"] = "check-failed"
    elif baseline_path.exists():
        try:
            delta = differences(json.loads(baseline_path.read_text(encoding="utf-8")), report)
            report["differences"] = delta
            report["status"] = "review-needed" if any(delta.values()) else "unchanged"
        except (ValueError, KeyError, TypeError) as exc:
            report["errors"].append({"file": str(baseline_path), "message": f"Baseline could not be compared: {exc}"})
            report["status"] = "check-failed"
    else:
        report["status"] = "baseline-needed"
    if accept and not report["errors"]:
        write_json(baseline_path, report)
        report["baselineAccepted"] = True
    write_json(destination / "latest-check.json", report)
    print(json.dumps({"status": report["status"], "menus": len(report["menus"]), "errors": report["errors"],
                      "baselineAccepted": report.get("baselineAccepted", False),
                      "report": str(destination / "latest-check.json")}, indent=2))
    return 2 if report["errors"] else 0


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--state-dir", type=Path, required=True, help="Local evidence directory, outside shipped app data")
    parser.add_argument("--accept-baseline", action="store_true", help="Explicitly mark a successful source check reviewed")
    args = parser.parse_args()
    raise SystemExit(check(args.state_dir.resolve(), args.accept_baseline))
