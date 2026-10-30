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
# A note that leads in the senses after it, which are alternatives (a "For ..., use:" note).
USE_NOTE_RE = re.compile(r"(?:For [^,.]+,|You can) use:")
# ste100.md: a gap wider than COLUMN_GAP points (or 0.4 of the text height for large text)
# starts a new column; one character is about CHAR_WIDTH points wide.
COLUMN_GAP = 4
CHAR_WIDTH = 5
# Symbol font characters in the Unicode private use area, for example the degree sign.
SYMBOL_CHARS = str.maketrans({"\uf02e": ".", "\uf057": "\u03a9", "\uf0b0": "\u00b0",
                              "\uf0b2": "\u2033"})
# Marks a hyphen at the end of a line until resolve_hyphens decides if it is a word hyphen.
SOFT_HYPHEN = "\u00ad"


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


def join_lines(texts):
    """Join the lines of a cell. Mark a hyphen at a line end, which can be a line break."""
    out = ""
    for text in texts:
        if re.search(r"[A-Za-z]-$", out) and text[:1].isalpha():
            out = out[:-1] + SOFT_HYPHEN + text
        else:
            out = f"{out} {text}" if out else text
    return out


def cell_lines(words, edges, column, top, bottom):
    """Return (x0, top, text) for each line of one cell."""
    out = []
    for line in lines_in(words, top, bottom):
        cell = [w for w in line if column_of(w["x0"], edges) == column]
        if cell:
            out.append((cell[0]["x0"], cell[0]["top"], " ".join(w["text"] for w in cell)))
    return out


def cell_text(words, edges, column, top, bottom):
    return join_lines(text for _, _, text in cell_lines(words, edges, column, top, bottom))


def help_icons(page):
    """Positions (x, top) of the Help (light bulb) symbols on a page.

    The bulb base is drawn as short lines, about 5.3 points wide and less than 1 point high.
    """
    icons = []
    for r in page.rects:
        if 5 < r["width"] < 6 and r["height"] < 1:
            if not any(abs(r["x0"] - x) < 1 and abs(r["top"] - y) < 6 for x, y in icons):
                icons.append((r["x0"], r["top"]))
    return icons


def help_flags(lines, icons):
    """Mark the lines of one cell that are help notes.

    A help note starts 24 points right of its symbol. It is a run of lines at that indent
    with normal line spacing, and one line of the run is near the height of the symbol.
    """
    def at_indent(x0):
        return any(abs(x0 - x - 24) <= 3 for x, _ in icons)

    def near_icon(x0, top):
        return any(abs(x0 - x - 24) <= 3 and -20 <= top - y <= 12 for x, y in icons)

    flags = [False] * len(lines)
    i = 0
    while i < len(lines):
        if not at_indent(lines[i][0]):
            i += 1
            continue
        j = i
        while j + 1 < len(lines) and at_indent(lines[j + 1][0]):
            if lines[j + 1][1] - lines[j][1] > 14:
                break
            j += 1
        if any(near_icon(x0, top) for x0, top, _ in lines[i : j + 1]):
            flags[i : j + 1] = [True] * (j + 1 - i)
        i = j + 1
    return flags


def segments(lines, icons):
    """Split the lines of one cell into ordered ("main" | "help", text) segments."""
    groups = []
    for (_, _, text), is_help in zip(lines, help_flags(lines, icons)):
        kind = "help" if is_help else "main"
        if groups and groups[-1][0] == kind:
            groups[-1][1].append(text)
        else:
            groups.append((kind, [text]))
    # A "For ..., use:" note without a symbol is also a help segment.
    split = []
    for kind, texts in groups:
        text = join_lines(texts)
        note = USE_NOTE_RE.search(text) if kind == "main" else None
        if note:
            before, after = text[: note.start()].strip(), text[note.end() :].strip()
            split += [("main", before), ("help", note.group()), ("main", after)]
        else:
            split.append((kind, text))
    return [(kind, text) for kind, text in split if text]


def body_bounds(page):
    header = [r["top"] for r in page.rects if r["width"] > 400 and r["top"] < 150]
    top = (max(header) if header else 90) + 2
    return top, page.height - 80


def is_blank(page, top, bottom):
    words = [w["text"] for w in page.extract_words() if top <= w["top"] < bottom]
    return " ".join(words) in ("", "Blank Page")


def dictionary_rows(page):
    """Yield (column0_text, column0_help, starts_entry, [subrow, ...]) for each table row.

    A subrow is [column1_segments, column2_text, column3_text].
    """
    top, bottom = body_bounds(page)
    words = page.extract_words()
    icons = help_icons(page)
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
        head, head_help, starts_entry, subrows = "", [], i > 0, []
        for a, b in zip(cuts, cuts[1:]):
            # The word cell can have a help note, for example about the verb forms.
            col0 = segments(cell_lines(words, edges, 0, a, b), icons)
            sub_head = join_lines(text for kind, text in col0 if kind == "main")
            # Some entry borders are not in the PDF (2-1-L9 LONGITUDINAL). A headword with
            # a part of speech below a sub-row border starts an entry.
            if subrows and HEAD_RE.match(sub_head):
                yield head, head_help, starts_entry, subrows
                head, head_help, starts_entry, subrows = "", [], True, []
            head = join_lines([t for t in (head, sub_head) if t])
            head_help += [text for kind, text in col0 if kind == "help"]
            col1 = segments(cell_lines(words, edges, 1, a, b), icons)
            cells = [col1] + [cell_text(words, edges, c, a, b) for c in (2, 3)]
            if any(cells):
                subrows.append(cells)
        if head or head_help or subrows:
            yield head, head_help, starts_entry, subrows


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
    # Words in brackets can be lowercase in an approved headword, for example "MATT (or MATTE)".
    bare = re.sub(r"\([^)]*\)", "", word)
    return {
        "word": word,
        "pos": pos.replace(" ", ""),
        "approved": bare == bare.upper() and any(ch.isalpha() for ch in bare),
        "forms": forms.strip(),
        "help": [],
        "senses": [],
        "page": label,
        "pdf_page": pdf_page,
    }


def new_sense(key, text, help_notes):
    return {key: text, "help": help_notes, "ste_examples": [], "non_ste_examples": []}


def sense_key(entry):
    alternative = not entry["approved"] or entry.get("_alternatives", False)
    return "alternative" if alternative else "meaning"


def add_senses(entry, subrows):
    """Add the senses of each sub-row. Examples go to the last sense.

    A main segment starts a sense. A help note goes to the next sense in the same cell, or
    to the last sense. A sub-row with only help notes is a sense without text. The senses
    after a "For ..., use:" note are alternatives, and the note goes to the next sense.
    The general note for other meanings is not kept.
    """
    for col1, col2, col3 in subrows:
        pending, has_main = [], any(kind == "main" for kind, _ in col1)
        for kind, text in col1:
            if kind == "help" and USE_NOTE_RE.fullmatch(text):
                entry["_alternatives"] = True
                if text != OTHER_MEANINGS:
                    entry.setdefault("_notes", []).append(text)
            elif kind == "help":
                pending.append(text)
            else:
                notes = entry.pop("_notes", [])
                entry["senses"].append(new_sense(sense_key(entry), text, notes + pending))
                pending = []
        if (pending and not has_main) or not entry["senses"]:
            entry["senses"].append(new_sense(sense_key(entry), "", pending))
        else:
            entry["senses"][-1]["help"].extend(pending)
        sense = entry["senses"][-1]
        if col2:
            sense["ste_examples"].append(col2)
        if col3:
            sense["non_ste_examples"].append(col3)


def parse_dictionary(pages):
    entries = []
    for pdf_page, page, label in pages:
        for head, head_help, starts_entry, subrows in dictionary_rows(page):
            entry = new_entry(head, starts_entry, label, pdf_page) if head else None
            if entry is None and entries:
                if head:
                    entries[-1]["forms"] = f'{entries[-1]["forms"]} {head}'.strip()
                entries[-1]["help"] += head_help
                add_senses(entries[-1], subrows)
                continue
            if entry is None:
                raise ValueError(f"page {label}: row without a headword: {head!r}")
            entry["help"] += head_help
            add_senses(entry, subrows)
            entries.append(entry)
    for entry in entries:
        entry.pop("_alternatives", None)
        entry["senses"][-1]["help"].extend(entry.pop("_notes", []))
    return resolve_hyphens(entries)


def resolve_hyphens(entries):
    """Remove a line-break hyphen if a word in the dictionary continues across it.

    For example ELECTROMAG-/NETICALLY becomes ELECTROMAGNETICALLY (ELECTROMAGNETIC is
    known), and double-/sided stays.
    """
    text = json.dumps(entries, ensure_ascii=False)
    known = {w.lower() for w in re.findall(r"[A-Za-z]+", text.replace(SOFT_HYPHEN, " "))}

    def join(match):
        first, second = match.groups()
        joined = (first + second).lower()
        if any(joined[:end] in known for end in range(len(first) + 2, len(joined) + 1)):
            return first + second
        return f"{first}-{second}"

    return json.loads(re.sub(rf"([A-Za-z]+){SOFT_HYPHEN}([A-Za-z]+)", join, text))


def underlines(line, rules):
    """The thin lines drawn across the lower part of the words of one line.

    An underline starts at the start of a word and stops in or just after a word (marks such
    as a comma can be outside it). A table border starts before the text by the cell padding.
    """
    low = min(w["top"] + 0.6 * (w["bottom"] - w["top"]) for w in line)
    bottom = max(w["bottom"] for w in line)
    return [
        r for r in rules
        if low <= r["top"] <= bottom + 1.5
        and any(abs(r["x0"] - w["x0"]) <= 1 for w in line)
        and any(w["x0"] < r["x1"] <= w["x1"] + 3.5 for w in line)
    ]


def underline_of(word, lines):
    """The index of the underline below the word, or None."""
    middle = (word["x0"] + word["x1"]) / 2
    return next((i for i, r in enumerate(lines) if r["x0"] <= middle <= r["x1"]), None)


def render_line(words, rules, left):
    """Join the words of one line. Underlined words are in <u></u>.

    After a wide gap a word goes to its column position, so table columns stay apart.
    """
    out, underline, x1 = "", None, None
    rules = underlines(words, rules)
    for w in words:
        # Words under the same line are one underlined run.
        marked = underline_of(w, rules)
        if underline is not None and marked != underline:
            out += "</u>"
        tag = "<u>" if marked is not None and marked != underline else ""
        gap = w["x0"] - (left if x1 is None else x1)
        column = round((w["x0"] - left) / CHAR_WIDTH)
        if gap > max(COLUMN_GAP, 0.4 * (w["bottom"] - w["top"])):
            spaces = max(2, column - len(out) - len(tag))
        else:
            spaces = int(x1 is not None)
        out += " " * spaces + tag + w["text"]
        underline, x1 = marked, w["x1"]
    return out + ("</u>" if underline is not None else "")


def page_text(page):
    words = sorted(page.extract_words(), key=lambda w: (w["top"], w["x0"]))
    rules = [o for o in page.rects + page.lines if o["height"] < 1.25 and o["width"] < 450]
    lines = []
    for w in words:
        if lines and w["top"] - lines[-1][0]["top"] <= 3:
            lines[-1].append(w)
        else:
            lines.append([w])
    left = min((w["x0"] for w in words), default=0)
    return [render_line(sorted(line, key=lambda w: w["x0"]), rules, left) for line in lines]


def page_markdown(page, label, pdf_page):
    if label:
        # Crop away the running title (top) and the page label and date (bottom).
        page = page.within_bbox((0, 55, page.width, page.height - 80))
    body = [ln.rstrip() for ln in page_text(page)]
    heading = f"## Page {label} (PDF page {pdf_page})" if label else f"## PDF page {pdf_page}"
    return heading + "\n\n" + "\n".join(body).strip("\n") + "\n"


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
    text = (title + note + "\n".join(markdown)).translate(SYMBOL_CHARS)
    (out_dir / "ste100.md").write_text(text, encoding="utf-8")
    text = json.dumps(entries, ensure_ascii=False, indent=1).translate(SYMBOL_CHARS)
    (out_dir / "dictionary.json").write_text(text + "\n", encoding="utf-8")
    return len(entries), len(markdown)


def main():
    if len(sys.argv) != 3:
        sys.exit("usage: extract.py <ASD-STE100_ISSUE9.pdf> <output-dir>")
    count, pages = convert(Path(sys.argv[1]), Path(sys.argv[2]))
    print(f"dictionary entries: {count}; markdown pages: {pages}")


if __name__ == "__main__":
    main()
