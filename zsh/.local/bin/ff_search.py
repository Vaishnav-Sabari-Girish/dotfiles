#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "playwright",
#   "beautifulsoup4",
# ]
# ///

import sys
import re
import json
import subprocess
from urllib.parse import quote_plus
from pathlib import Path
from bs4 import BeautifulSoup


def ensure_playwright_browsers():
    try:
        from playwright.sync_api import sync_playwright
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            browser.close()
    except Exception:
        print("Installing Playwright Chromium (one-time)...", file=sys.stderr)
        subprocess.run(
            [sys.executable, "-m", "playwright", "install", "chromium"],
            check=True,
        )


def fanfiction_search(query: str, max_results: int = 15) -> list[dict]:
    search_url = (
        f"https://www.fanfiction.net/search/"
        f"?keywords={quote_plus(query)}&ready=1&type=story&match=any"
    )

    ensure_playwright_browsers()
    from playwright.sync_api import sync_playwright

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(
            user_agent=(
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/122.0.0.0 Safari/537.36"
            ),
            viewport={"width": 1280, "height": 900},
            locale="en-US",
        )
        page = context.new_page()

        print(f"Loading search page...", file=sys.stderr)
        page.goto(search_url, wait_until="domcontentloaded", timeout=30000)

        # Cookie / consent buttons
        for sel in ['button:has-text("Accept")', 'button:has-text("I agree")', "#L2AGLb"]:
            try:
                page.locator(sel).first.click(timeout=1500)
                page.wait_for_timeout(800)
                break
            except Exception:
                pass

        # Wait for results
        try:
            page.wait_for_selector("a.stitle, #content_wrapper .z-list", timeout=15000)
        except Exception:
            pass

        page.wait_for_timeout(1500)
        html = page.content()
        browser.close()

    soup = BeautifulSoup(html, "html.parser")
    results = []
    seen = set()

    for block in soup.select("div.z-list"):
        a = block.select_one("a.stitle")
        if not a:
            continue

        href = a.get("href", "")
        m = re.search(r"/s/(\d+)", href)
        if not m:
            continue

        story_id = m.group(1)
        url = f"https://www.fanfiction.net/s/{story_id}/1/"
        if url in seen:
            continue
        seen.add(url)

        # --- clean title ---
        for img in a.find_all("img"):
            img.decompose()
        title = a.get_text(" ", strip=True) or "Untitled"
        title = re.sub(r"\s+", " ", title).strip()

        # --- author ---
        author = "Unknown"
        for link in block.select('a[href*="/u/"]'):
            text = link.get_text(" ", strip=True)
            if text:
                author = re.sub(r"\s+", " ", text).strip()
                break

        results.append({"url": url, "title": title, "author": author})
        if len(results) >= max_results:
            break

    # Fallback
    if not results:
        for a in soup.select("a.stitle"):
            href = a.get("href", "")
            m = re.search(r"/s/(\d+)", href)
            if not m:
                continue
            story_id = m.group(1)
            url = f"https://www.fanfiction.net/s/{story_id}/1/"
            if url in seen:
                continue
            seen.add(url)

            for img in a.find_all("img"):
                img.decompose()
            title = a.get_text(" ", strip=True) or "Untitled"
            title = re.sub(r"\s+", " ", title).strip()

            results.append({"url": url, "title": title, "author": "Unknown"})
            if len(results) >= max_results:
                break

    return results


def main():
    if len(sys.argv) < 2:
        print('Usage: ./ff_search.py "search query" [max_results]', file=sys.stderr)
        sys.exit(1)

    query = sys.argv[1]
    max_results = int(sys.argv[2]) if len(sys.argv) > 2 else 15

    results = fanfiction_search(query, max_results)

    out_json = Path("urls.json")
    out_json.write_text(json.dumps(results, indent=2, ensure_ascii=False))
    print(f"Saved {len(results)} results → {out_json}", file=sys.stderr)

    out_txt = Path("urls.txt")
    out_txt.write_text("\n".join(r["url"] for r in results) + ("\n" if results else ""))
    print(f"Also saved URLs → {out_txt}", file=sys.stderr)

    if not results:
        print("No stories found.", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
