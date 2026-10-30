"""Convert the ASD-STE100 Issue 9 PDF into ste100.md and dictionary.json.

Dictionary body pages (footer label 2-1-*) go to dictionary.json. All other pages
go to ste100.md with one heading per page label, so rules can be cited.
"""

import json
import re
import sys
from pathlib import Path

import pdfplumber

POS = r"(?:n|v|adj|adv|prep|conj|pron|art|TN|TV)"
HEAD_RE = re.compile(rf"^(?P<word>.+?)\s*\((?P<pos>{POS}(?:\s*/\s*{POS})*)\)\s*,?\s*(?P<rest>.*)$")
LABEL_RE = re.compile(r"Page (\d+-\d+-[0-9A-Z]+)")


def page_label(page):
    words = [w for w in page.extract_words() if w["top"] > page.height - 80]
    match = LABEL_RE.search(" ".join(w["text"] for w in words))
    return match.group(1) if match else None


def column_edges(page):
    """Left edges of the four table columns, from the header row of the page.

    The columns move between odd and even pages, so read them on each page.
    """
    header = [w for w in page.extract_words() if 55 < w["top"] < 90]
    names = ("Word", "Approved", "STE", "Non-STE")
    edges = []
    for name in names:
        hits = [w["x0"] for w in header if w["text"] == name]
        if not hits:
            raise ValueError(f"page header has no {name!r} column")
        edges.append(min(hits) - 4)
    return edges


def column_of(x0, edges):
    return sum(1 for edge in edges[1:] if x0 >= edge)


def rules(page, x_edge):
    tops = set()
    for r in page.rects:
        if r["height"] < 2 and 100 < r["width"] < 140 and abs(r["x0"] - x_edge) <= 5:
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


def dictionary_rows(page):
    """Yield (column0_text, [subrow, ...]) for each table row on one page."""
    words = page.extract_words()
    top, bottom = body_bounds(page)
    edges = column_edges(page)
    entry_tops = [t for t in rules(page, edges[0]) if top < t < bottom]
    sub_tops = rules(page, edges[2])
    bounds = [top] + entry_tops + [bottom]
    for start, end in zip(bounds, bounds[1:]):
        if end - start < 4:
            continue
        cuts = [start] + [t for t in sub_tops if start < t < end] + [end]
        subrows = []
        for a, b in zip(cuts, cuts[1:]):
            cells = [cell_text(words, edges, c, a, b) for c in (1, 2, 3)]
            if any(cells):
                subrows.append(cells)
        head = cell_text(words, edges, 0, start, end)
        if head or subrows:
            yield head, subrows


def new_entry(head, label, pdf_page):
    match = HEAD_RE.match(head)
    if not match:
        return None
    word = match.group("word").strip()
    return {
        "word": word,
        "pos": match.group("pos").replace(" ", ""),
        "approved": word == word.upper() and any(ch.isalpha() for ch in word),
        "forms": match.group("rest").strip(),
        "senses": [],
        "page": label,
        "pdf_page": pdf_page,
    }


def add_senses(entry, subrows):
    """Add one sense per sub-row. A sub-row with no meaning adds examples to the last sense."""
    key = "meaning" if entry["approved"] else "alternative"
    for col1, col2, col3 in subrows:
        if col1 or not entry["senses"]:
            entry["senses"].append({key: col1, "ste_examples": [], "non_ste_examples": []})
        sense = entry["senses"][-1]
        if col2:
            sense["ste_examples"].append(col2)
        if col3:
            sense["non_ste_examples"].append(col3)


def parse_dictionary(pages):
    entries = []
    for pdf_page, page, label in pages:
        for head, subrows in dictionary_rows(page):
            entry = new_entry(head, label, pdf_page) if head else None
            if entry is None and entries:
                if head:
                    entries[-1]["forms"] = f'{entries[-1]["forms"]} {head}'.strip()
                add_senses(entries[-1], subrows)
                continue
            if entry is None:
                raise ValueError(f"page {label}: row without a headword: {head!r}")
            add_senses(entry, subrows)
            entries.append(entry)
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
            if label and label.startswith("2-1-"):
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
