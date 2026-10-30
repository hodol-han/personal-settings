"""Convert the ASD-STE100 Issue 9 PDF into ste100.md and dictionary.json.

Dictionary body pages (footer label 2-1-*) go to dictionary.json. All other pages
go to ste100.md with one heading per page label, so rules can be cited.
"""

import json
import re
import sys
from pathlib import Path

import pdfplumber

POS = r"(?:n|v|adj|adv|prep|conj|pron|art|prefix|TN|TV)"
HEAD_RE = re.compile(rf"^(?P<word>.+?)\s*\((?P<pos>{POS}(?:\s*/\s*{POS})*)\)\s*,?\s*(?P<rest>.*)$")
LABEL_RE = re.compile(r"Page (\d+-\d+-[0-9A-Z]+|[A-Z]+-\d+|[ivxlc]+)\b")
OTHER_MEANINGS = "For other meanings, use:"


def page_label(page):
    words = [w for w in page.extract_words() if w["top"] > page.height - 80]
    match = LABEL_RE.search(" ".join(w["text"] for w in words))
    return match.group(1) if match else None


def header_edges(page):
    """Column left edges from the header row. Used when a row has no border to read."""
    header = [w for w in page.extract_words() if 55 < w["top"] < 90]
    edges = []
    for name in ("Word", "Approved", "STE", "Non-STE"):
        hits = [w["x0"] for w in header if w["text"] == name]
        if not hits:
            raise ValueError(f"page header has no {name!r} column")
        edges.append(min(hits) - 4)
    return edges


def border_edges(page, top):
    """Column left edges from the cell borders on the line at `top`.

    The table borders move between pages and between rows, so read them per row.
    """
    # A border can be split into short segments, so cluster all segments on the line.
    xs = sorted(r["x0"] for r in page.rects if r["height"] < 2 and abs(r["top"] - top) < 2)
    edges = []
    for x in xs:
        if not edges or x - edges[-1][-1] > 20:
            edges.append([x])
        else:
            edges[-1].append(x)
    lefts = [cluster[0] for cluster in edges if cluster[0] < page.width - 80]
    return lefts if len(lefts) == 4 else None


def column_of(x0, edges):
    return sum(1 for edge in edges[1:] if x0 >= edge - 1)


def rules(page, x_edge):
    tops = set()
    for r in page.rects:
        if r["height"] < 2 and 100 < r["width"] < 140 and abs(r["x0"] - x_edge) <= 12:
            tops.add(round(r["top"]))
    return sorted(tops)


def lines_in(words, top, bottom):
    rows = {}
    for w in words:
        if top <= w["top"] < bottom:
            key = round(w["top"] / 3)
            rows.setdefault(key, []).append(w)
    return [sorted(rows[k], key=lambda w: w["x0"]) for k in sorted(rows)]


def cell_text(words, edges, column, top, bottom):
    out = []
    for line in lines_in(words, top, bottom):
        text = " ".join(w["text"] for w in line if column_of(w["x0"], edges) == column)
        if text:
            out.append(text)
    return " ".join(out).strip()


def body_bounds(page):
    header = [r["top"] for r in page.rects if r["width"] > 400 and r["top"] < 150]
    top = (max(header) if header else 90) + 2
    return top, page.height - 80


def is_blank(page, top, bottom):
    words = [w["text"] for w in page.extract_words() if top <= w["top"] < bottom]
    return " ".join(words) in ("", "Blank Page")


def dictionary_rows(page):
    """Yield (column0_text, starts_entry, [subrow, ...]) for each table row on one page."""
    top, bottom = body_bounds(page)
    words = page.extract_words()
    fallback = header_edges(page)
    entry_tops = [t for t in rules(page, fallback[0]) if top < t < bottom]
    sub_tops = rules(page, fallback[2])
    bounds = [top] + entry_tops + [bottom]
    for i, (start, end) in enumerate(zip(bounds, bounds[1:])):
        if end - start < 4:
            continue
        # The first row on a page has the header line above it: read the next border.
        edges = border_edges(page, start if i else end) or fallback
        cuts = [start] + [t for t in sub_tops if start < t < end] + [end]
        subrows = []
        for a, b in zip(cuts, cuts[1:]):
            cells = [cell_text(words, edges, c, a, b) for c in (1, 2, 3)]
            if any(cells):
                subrows.append(cells)
        head = cell_text(words, edges, 0, start, end)
        if head or subrows:
            yield head, i > 0, subrows


def new_entry(head, starts_entry, label, pdf_page):
    """Make an entry from a headword cell, or return None for a continuation cell.

    A row with its own top border always starts an entry, also without a part of speech
    (for example a phrase headword). The first row on a page can continue the last entry.
    """
    match = HEAD_RE.match(head)
    if match:
        word, pos, forms = match.group("word").strip(), match.group("pos"), match.group("rest")
    elif starts_entry:
        word, pos, forms = head.strip(), "", ""
    else:
        return None
    return {
        "word": word,
        "pos": pos.replace(" ", ""),
        "approved": word == word.upper() and any(ch.isalpha() for ch in word),
        "forms": forms.strip(),
        "senses": [],
        "page": label,
        "pdf_page": pdf_page,
    }


def new_sense(key, text):
    return {key: text, "ste_examples": [], "non_ste_examples": []}


def add_senses(entry, subrows):
    """Add one sense per sub-row. A sub-row with no meaning adds examples to the last sense.

    In an approved entry, the sub-rows after "For other meanings, use:" are alternatives.
    """
    for col1, col2, col3 in subrows:
        if OTHER_MEANINGS in col1:
            before, after = (part.strip() for part in col1.split(OTHER_MEANINGS, 1))
            if before and after:
                entry["senses"].append(new_sense("meaning", before))
            if before and not after:
                col1 = before
                entry["_alternatives_next"] = True
            else:
                col1 = after
                entry["_alternatives"] = True
        elif col1 and entry.pop("_alternatives_next", False):
            entry["_alternatives"] = True
        if col1 or not entry["senses"]:
            alternative = not entry["approved"] or entry.get("_alternatives", False)
            key = "alternative" if alternative else "meaning"
            entry["senses"].append(new_sense(key, col1))
        sense = entry["senses"][-1]
        if col2:
            sense["ste_examples"].append(col2)
        if col3:
            sense["non_ste_examples"].append(col3)


def parse_dictionary(pages):
    entries = []
    for pdf_page, page, label in pages:
        for head, starts_entry, subrows in dictionary_rows(page):
            entry = new_entry(head, starts_entry, label, pdf_page) if head else None
            if entry is None and entries:
                if head:
                    entries[-1]["forms"] = f'{entries[-1]["forms"]} {head}'.strip()
                add_senses(entries[-1], subrows)
                continue
            if entry is None:
                raise ValueError(f"page {label}: row without a headword: {head!r}")
            add_senses(entry, subrows)
            entries.append(entry)
    for entry in entries:
        entry.pop("_alternatives_next", None)
        entry.pop("_alternatives", None)
    return entries


def page_markdown(page, label, pdf_page):
    if label:
        # Crop away the running title (top) and the page label and date (bottom).
        page = page.within_bbox((0, 55, page.width, page.height - 80))
    body = [ln.rstrip() for ln in (page.extract_text() or "").splitlines()]
    heading = f"## Page {label} (PDF page {pdf_page})" if label else f"## PDF page {pdf_page}"
    return heading + "\n\n" + "\n".join(body).strip() + "\n"


def convert(pdf_path, out_dir):
    dictionary_pages, markdown = [], []
    with pdfplumber.open(pdf_path) as pdf:
        for number, page in enumerate(pdf.pages, start=1):
            label = page_label(page)
            # Blank pages between dictionary letters stay in ste100.md as page headings.
            if label and label.startswith("2-1-") and not is_blank(page, *body_bounds(page)):
                dictionary_pages.append((number, page, label))
            else:
                markdown.append(page_markdown(page, label, number))
        entries = parse_dictionary(dictionary_pages)
    title = "# ASD-STE100 Simplified Technical English, Issue 9\n\n"
    note = "Dictionary pages (2-1-*) are in `dictionary.json`.\n\n"
    (out_dir / "ste100.md").write_text(title + note + "\n".join(markdown), encoding="utf-8")
    text = json.dumps(entries, ensure_ascii=False, indent=1)
    (out_dir / "dictionary.json").write_text(text + "\n", encoding="utf-8")
    return len(entries), len(markdown)


def main():
    if len(sys.argv) != 3:
        sys.exit("usage: extract.py <ASD-STE100_ISSUE9.pdf> <output-dir>")
    count, pages = convert(Path(sys.argv[1]), Path(sys.argv[2]))
    print(f"dictionary entries: {count}; markdown pages: {pages}")


if __name__ == "__main__":
    main()
