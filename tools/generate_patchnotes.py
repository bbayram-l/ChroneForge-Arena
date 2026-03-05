#!/usr/bin/env python3
"""
generate_patchnotes.py — Convert CHANGELOG.md to BBCode for in-game display.

Extracts the N most recent version sections, converts Markdown formatting to
Godot RichTextLabel BBCode, and writes to data/patchnotes.txt.

Usage:
    python tools/generate_patchnotes.py CHANGELOG.md data/patchnotes.txt
    python tools/generate_patchnotes.py CHANGELOG.md data/patchnotes.txt --sections 3
"""

import re
import sys
import argparse


# ── Colour palette (matches MainMenu.gd) ─────────────────────────────────────
C_VERSION = "#e8941f"   # orange  — version header
C_SECTION = "#ffdd88"   # yellow  — subsection header
C_MUTED   = "#888899"   # grey    — subtitle / date


def md_to_bbcode(md_text: str, max_sections: int = 2) -> str:
    """Convert the N most recent ## sections of CHANGELOG.md to BBCode."""

    # Split on version headers (## [...])
    raw_sections = re.split(r"\n(?=## )", md_text.strip())
    version_sections = [s for s in raw_sections if s.startswith("## ")][:max_sections]

    out: list[str] = []

    for section in version_sections:
        lines = section.split("\n")
        for line in lines:
            stripped = line.strip()

            # ── Skip table rows and horizontal rules ─────────────────────────
            if stripped.startswith("|") or re.match(r"^-{3,}$", stripped):
                continue

            # ── H1: project title — skip ──────────────────────────────────────
            if line.startswith("# ") and not line.startswith("## "):
                continue

            # ── H2: ## [v0.9.1] — Balance Pass — 2026-03-06 ─────────────────
            if line.startswith("## "):
                text = line[3:].strip()
                # Remove Markdown link brackets: [v0.9.1] → v0.9.1
                text = re.sub(r"\[([^\]]+)\](?:\([^)]*\))?", r"\1", text)
                out.append(f"[color={C_VERSION}][b]{text}[/b][/color]")
                continue

            # ── H3: ### New Features ─────────────────────────────────────────
            if line.startswith("### "):
                out.append(f"[color={C_SECTION}]{line[4:].strip()}[/color]")
                continue

            # ── Bullet: - item or * item ─────────────────────────────────────
            if re.match(r"^[-*] ", line):
                text = _inline(line[2:])
                # Continuation lines (indented follow-ons) stay as-is below
                out.append(f"• {text}")
                continue

            # ── Indented continuation of a bullet ────────────────────────────
            if line.startswith("  ") and stripped:
                out.append(f"  {_inline(stripped)}")
                continue

            # ── Blank line ───────────────────────────────────────────────────
            if not stripped:
                out.append("")
                continue

            # ── Normal paragraph line ────────────────────────────────────────
            out.append(_inline(line))

        # Blank line between sections
        out.append("")

    # Trim trailing blank lines
    while out and out[-1] == "":
        out.pop()

    return "\n".join(out)


def _inline(text: str) -> str:
    """Convert inline Markdown spans to BBCode."""
    # **bold** or __bold__
    text = re.sub(r"\*\*(.+?)\*\*", r"[b]\1[/b]", text)
    text = re.sub(r"__(.+?)__",     r"[b]\1[/b]", text)
    # `code` → bold (no monospace tag needed for patchnotes)
    text = re.sub(r"`(.+?)`",       r"[b]\1[/b]", text)
    # *italic* or _italic_ — just leave as-is (optional)
    return text


# ── CLI ───────────────────────────────────────────────────────────────────────

def main() -> None:
    parser = argparse.ArgumentParser(description="CHANGELOG.md → Godot BBCode patchnotes")
    parser.add_argument("input",    help="Path to CHANGELOG.md")
    parser.add_argument("output",   help="Path to write patchnotes.txt")
    parser.add_argument("--sections", type=int, default=2,
                        help="Number of version sections to include (default: 2)")
    args = parser.parse_args()

    with open(args.input, "r", encoding="utf-8") as f:
        md = f.read()

    bbcode = md_to_bbcode(md, args.sections)

    with open(args.output, "w", encoding="utf-8") as f:
        f.write(bbcode)

    print(f"[patchnotes] wrote {args.output} ({len(bbcode)} chars, "
          f"{args.sections} version sections)")


if __name__ == "__main__":
    main()
