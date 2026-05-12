"""Pre-render MiLuAssistantDesktop Chinese documentation to a static HTML file.

Usage:
    python scripts/build-docs.py <markdown_file> <output_dir>

The script reads the all-in-one markdown, applies MiLuAssistantDesktop branding, renders
it to HTML with the same styles/TOC/scroll-spy as the backend, and writes
the result to <output_dir>/milu-docs-zh.html.  Images referenced by the
markdown are expected in an ``images/`` subdirectory next to the markdown
source; they are copied as-is into <output_dir>/images/.
"""

from __future__ import annotations

import os
import re
import shutil
import sys
from pathlib import Path

try:
    from markdown_it import MarkdownIt
except ImportError:
    sys.exit(
        "markdown-it-py is required.  Install it with:\n"
        "  pip install markdown-it-py"
    )

# ── Markdown renderer (mirrors _app.py) ──────────────────────────────────

md_renderer = (
    MarkdownIt("commonmark", {"html": True, "linkify": True})
    .enable("table")
    .enable("strikethrough")
)

def rebrand(text: str) -> str:
    placeholder = "\x00URL\x00"
    urls: list[str] = []

    def _save(m: re.Match[str]) -> str:
        urls.append(m.group(0))
        return f"{placeholder}{len(urls) - 1}{placeholder}"

    protected = re.sub(r"https?://[^\s\)\]\>\"\']+", _save, text)
    protected = (
        protected.replace("CoPaw-Flash", "MiLu-Flash")
        .replace("CoPaw", "MiLu")
        .replace("copaw", "milu")
    )

    def _restore(m: re.Match[str]) -> str:
        return urls[int(m.group(1))]

    return re.sub(
        rf"{re.escape(placeholder)}(\d+){re.escape(placeholder)}",
        _restore,
        protected,
    )


def extract_toc(text: str) -> list[dict]:
    toc: list[dict] = []
    current: dict | None = None
    in_overview = True
    link_pat = re.compile(r"- \[(.+?)]\(#(.+?)\)")

    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith("## "):
            title = line[3:].strip()
            if title == "项目介绍":
                in_overview = False
                break
            if in_overview:
                current = {"category": title, "children": []}
                toc.append(current)
                continue
        if in_overview and current is not None:
            m = link_pat.match(line)
            if m:
                current["children"].append({"title": m.group(1), "id": m.group(2)})
    return toc


def add_lazy_loading(html: str) -> str:
    return re.sub(
        r"<img(?![^>]*\bloading=)([^>]*)>",
        r'<img loading="lazy" decoding="async"\1>',
        html,
    )


def render_sections(text: str, toc: list[dict]) -> str:
    text = re.sub(
        r'^(<a\s+id="([^"]+)"\s*>\s*</a>)\s*\n+(## .+)',
        r"\3\n\1",
        text,
        flags=re.MULTILINE,
    )
    anchor_by_title: dict[str, str] = {}
    for m in re.finditer(
        r'^(## .+?)\s*\n\s*<a\s+id="([^"]+)"', text, flags=re.MULTILINE
    ):
        anchor_by_title[m.group(1)[3:].strip()] = m.group(2)

    parts = re.split(r"(?=^##\s+)", text, flags=re.MULTILINE)
    sections: list[str] = []
    main_started = False

    for idx, part in enumerate(parts):
        stripped = part.strip()
        if not stripped:
            continue
        rendered = md_renderer.render(stripped)
        section_title = ""
        if idx > 0:
            lines = stripped.splitlines()
            if lines:
                section_title = lines[0][3:].strip() if lines[0].startswith("## ") else ""
                aid = anchor_by_title.get(section_title)
                if aid:
                    rendered = re.sub(
                        r"<h2>",
                        f'<h2 id="{aid}" class="docs-heading">',
                        rendered,
                        count=1,
                    )
        rendered = add_lazy_loading(rendered)
        if section_title == "项目介绍":
            main_started = True

        if idx == 0:
            css_class = "docs-section docs-section-intro"
        elif not main_started:
            css_class = "docs-section docs-section-overview"
        else:
            css_class = "docs-section"
        sections.append(f"<section class='{css_class}'>{rendered}</section>")

    return "".join(sections)


def build_html(toc: list[dict], rendered: str) -> str:
    toc_html = "".join(
        (
            "<li class='docs-toc-group'>"
            f"<span class='docs-toc-group-title'>{g['category']}</span>"
            "<ul class='docs-toc-sublist'>"
            + "".join(
                f"<li class='docs-toc-item'><a href='#{c['id']}' class='docs-toc-link'>{c['title']}</a></li>"
                for c in g["children"]
            )
            + "</ul></li>"
        )
        for g in toc
    )

    css = (
        ":root{color-scheme:light}"
        "html{scroll-behavior:auto}"
        "body{max-width:1400px;margin:24px auto;padding:0 20px;"
        "font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,'Helvetica Neue',Arial,sans-serif;"
        "line-height:1.7;color:#222;background:#fff}"
        ".docs-layout{display:grid;grid-template-columns:260px minmax(0,1fr);gap:40px;align-items:start}"
        ".docs-sidebar{position:sticky;top:20px;max-height:calc(100vh - 40px);overflow:auto;"
        "padding:20px 16px;border-right:1px solid #e5e7eb;background:#fff}"
        ".docs-sidebar-title{margin:0 0 16px;font-size:13px;font-weight:700;color:#888;"
        "text-transform:uppercase;letter-spacing:.06em}"
        ".docs-toc{list-style:none;padding:0;margin:0}"
        ".docs-toc-group{margin:0 0 18px}"
        ".docs-toc-group-title{display:block;font-size:12px;font-weight:700;color:#999;"
        "text-transform:uppercase;letter-spacing:.05em;padding:0 8px 4px;margin-bottom:4px}"
        ".docs-toc-item{margin:0}"
        ".docs-toc-link{display:block;color:#4a5568;text-decoration:none;font-size:14px;font-weight:500;"
        "padding:5px 8px;border-radius:6px;border-left:3px solid transparent;"
        "transition:color .15s,background .15s,border-color .15s}"
        ".docs-toc-link:hover{color:#2f5fd7;background:#f0f4ff}"
        ".docs-toc-link-active{color:#1f4ed8;background:#eaf1ff;border-left-color:#3b82f6;font-weight:600}"
        ".docs-toc-sublist{list-style:none;padding:0;margin:0}"
        ".docs-main{min-width:0;padding-bottom:48px}"
        ".docs-mobile-toc{display:none;margin:0 0 20px;padding:12px 14px;border:1px solid #e5e7eb;"
        "border-radius:12px;background:#fafafa}"
        ".docs-mobile-toc summary{cursor:pointer;font-weight:600}"
        ".docs-mobile-toc .docs-toc{margin-top:10px}"
        ".docs-section{margin:0 0 28px;content-visibility:auto;contain-intrinsic-size:auto 500px}"
        ".docs-section-intro{display:none}"
        ".docs-section-overview{display:none}"
        ".docs-heading{scroll-margin-top:24px}"
        "h2{font-size:1.6em;border-bottom:1px solid #eaecef;padding-bottom:.3em;margin-top:1.5em}"
        "h3{font-size:1.3em;margin-top:1.3em}"
        "img{max-width:100%;height:auto;display:block;margin:14px 0}"
        "a{color:#2f5fd7;text-decoration:none}a:hover{text-decoration:underline}"
        "code{background:#f4f4f4;padding:2px 5px;border-radius:4px;font-size:.9em}"
        "pre{background:#f6f8fa;padding:16px;border-radius:8px;overflow:auto;font-size:.9em}"
        "pre code{background:none;padding:0}"
        "table{border-collapse:collapse;width:auto;margin:16px 0;font-size:.95em}"
        "thead{background:#f6f8fa}"
        "th{font-weight:600;text-align:left;padding:10px 16px;border:1px solid #d0d7de}"
        "td{padding:10px 16px;border:1px solid #d0d7de}"
        "tr:nth-child(even){background:#fafbfc}"
        "blockquote{border-left:4px solid #dfe2e5;margin:16px 0;padding:0 16px;color:#6a737d}"
        "@media (max-width: 980px){.docs-layout{grid-template-columns:1fr}"
        ".docs-sidebar{display:none}.docs-mobile-toc{display:block}}"
    )

    js = (
        "(function(){"
        "var links=[].slice.call(document.querySelectorAll('.docs-toc-link'));"
        "var byId={};"
        "links.forEach(function(a){var h=a.getAttribute('href')||'';if(h[0]==='#')byId[h.slice(1)]=a;});"
        "var prev=null;"
        "function setActive(id){"
        "if(prev)prev.classList.remove('docs-toc-link-active');"
        "var a=byId[id];if(a){a.classList.add('docs-toc-link-active');a.scrollIntoView({block:'nearest',behavior:'auto'});prev=a;}}"
        "var headings=[].slice.call(document.querySelectorAll('h2.docs-heading'));"
        "var cur=headings.length?headings[0].id:'';"
        "var clickLock=0;"
        "var rafId=0;"
        "function spy(){"
        "if(clickLock)return;"
        "var top=window.scrollY||document.documentElement.scrollTop;"
        "var best='';"
        "for(var i=headings.length-1;i>=0;i--){"
        "if(headings[i].offsetTop<=top+80){best=headings[i].id;break;}}"
        "if(!best&&headings.length)best=headings[0].id;"
        "if(best&&best!==cur){cur=best;setActive(cur);}}"
        "window.addEventListener('scroll',function(){if(!rafId)rafId=requestAnimationFrame(function(){rafId=0;spy();});},{passive:true});"
        "links.forEach(function(a){"
        "a.addEventListener('click',function(e){"
        "e.preventDefault();"
        "var id=a.getAttribute('href').slice(1);"
        "var el=document.getElementById(id);"
        "if(!el)return;"
        "clickLock=1;cur=id;setActive(id);"
        "el.scrollIntoView({block:'start',behavior:'auto'});"
        "setTimeout(function(){clickLock=0;},150);"
        "history.replaceState(null,'','#'+id);"
        "});});"
        "if(location.hash)cur=location.hash.slice(1);"
        "setActive(cur);"
        "spy();"
        "})();"
    )

    return (
        "<!doctype html><html><head><meta charset='utf-8'/>"
        "<meta name='viewport' content='width=device-width, initial-scale=1'/>"
        "<title>MiLuAssistantDesktop</title>"
        f"<style>{css}</style></head><body>"
        "<div class='docs-layout'>"
        "<aside class='docs-sidebar'>"
        "<h2 class='docs-sidebar-title'>MiLuAssistantDesktop Docs</h2>"
        f"<ul class='docs-toc'>{toc_html}</ul>"
        "</aside>"
        "<main class='docs-main'>"
        "<details class='docs-mobile-toc'><summary>目录</summary>"
        f"<ul class='docs-toc'>{toc_html}</ul>"
        "</details>"
        + rendered
        + "</main></div>"
        f"<script>{js}</script>"
        "</body></html>"
    )


def main() -> None:
    if len(sys.argv) < 3:
        sys.exit(f"Usage: {sys.argv[0]} <markdown_file> <output_dir>")

    md_path = Path(sys.argv[1])
    out_dir = Path(sys.argv[2])

    if not md_path.is_file():
        sys.exit(f"Markdown file not found: {md_path}")

    print(f"[build-docs] Reading {md_path}")
    text = md_path.read_text(encoding="utf-8", errors="replace")
    text = rebrand(text)

    print("[build-docs] Extracting TOC")
    toc = extract_toc(text)

    print("[build-docs] Rendering sections")
    rendered = render_sections(text, toc)

    print("[build-docs] Building HTML")
    html = build_html(toc, rendered)

    out_dir.mkdir(parents=True, exist_ok=True)
    html_path = out_dir / "milu-docs-zh.html"
    html_path.write_text(html, encoding="utf-8")
    print(f"[build-docs] Written {html_path}  ({len(html):,} bytes)")

    # Copy images directory if present
    src_images = md_path.parent / "images"
    dst_images = out_dir / "images"
    if src_images.is_dir():
        if dst_images.exists():
            shutil.rmtree(dst_images)
        shutil.copytree(src_images, dst_images)
        img_count = sum(1 for _ in dst_images.rglob("*") if _.is_file())
        img_size = sum(f.stat().st_size for f in dst_images.rglob("*") if f.is_file())
        print(
            f"[build-docs] Copied {img_count} images ({img_size / 1024 / 1024:.1f} MB)"
        )

    print("[build-docs] Done!")


if __name__ == "__main__":
    main()
