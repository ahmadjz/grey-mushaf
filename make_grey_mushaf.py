"""Build a single greyed-out mushaf PDF from the KFGQPC 1441 Illustrator pages.

Every page keeps its Illustrator layers as optional-content groups:
Ornament(s), "Header & Marks & Page No.", "Aya No." and the verse text
("Quran Text"; a few pages call it "QuranText" or "Layer 1"). All ink is
CMYK black. We repaint the text layer light grey, except for surah names
sitting inside the title boxes. The light-green spot fills of the other
layers (frame, title boxes, aya circles) become thin black outlines, which
read far better than pale green on an e-ink screen.

Surah title boxes are the wide, short spot-colour fills of the ornament
layer; text is kept black when its centre falls inside one of them.

usage: python make_grey_mushaf.py <dir with NNN___Hafs39__DM.ai> <out.pdf> [--grey 0.18] [--outline 0.6]
"""
import argparse
import glob
import math
import os
import re
import sys

import pikepdf

TEXT_LAYERS = {"quran text", "qurantext", "layer 1"}
NAME = re.compile(r"(\d{3})___Hafs39__DM\.ai$")
# W/W* (clip) sit between a path and its painting operator, so they are buffered with it
PATH_OPS = {"m", "l", "c", "v", "y", "re", "h", "W", "W*"}
PAINT_OPS = {"f", "F", "f*", "B", "B*", "b", "b*", "S", "s", "n"}
FILL_OPS = PAINT_OPS - {"S", "s", "n"}
IDENTITY = (1, 0, 0, 1, 0, 0)


def mul(m, n):
    """Matrix product m x n for PDF 6-tuples (apply m, then n)."""
    a, b, c, d, e, f = m
    A, B, C, D, E, F = n
    return (a * A + b * C, a * B + b * D, c * A + d * C, c * B + d * D, e * A + f * C + E, e * B + f * D + F)


def path_bbox(path, ctm):
    pts = []
    for operands, op in path:
        nums = [float(x) for x in operands]
        if str(op) == "re":
            x, y, w, h = nums
            nums = [x, y, x + w, y + h, x, y + h, x + w, y]
        pts += zip(nums[0::2], nums[1::2])
    if not pts:
        return None
    a, b, c, d, e, f = ctm
    xs = [a * x + c * y + e for x, y in pts]
    ys = [b * x + d * y + f for x, y in pts]
    return min(xs), min(ys), max(xs), max(ys)


DEVICE_SPACES = {"/DeviceCMYK", "/DeviceGray", "/DeviceRGB"}


def walk(stream, state, on_fill, on_do, layer_test=None):
    """Re-emit a content stream, tracking CTM, fill ink and (optionally) text-layer nesting.

    state is (ctm, ink) where ink is "black", "spot" or "other".
    on_fill(path, op, state, in_layer) returns [(colour instructions, sub-path[, paint op])],
    each painted with the given operator (default: the original one).
    on_do(name, state, in_layer) is called for every XObject drawn.
    """
    ctm, ink = state
    out, path, stack, depth = [], [], [], []
    for operands, op in stream:
        o = str(op)
        in_layer = layer_test is None or any(depth)
        if o == "BDC":
            depth.append(layer_test is not None and layer_test(operands))
        elif o == "BMC":
            depth.append(False)
        elif o == "EMC":
            depth.pop()
        elif o == "q":
            stack.append((ctm, ink))
        elif o == "Q":
            ctm, ink = stack.pop() if stack else (ctm, ink)
        elif o == "cm":
            ctm = mul(tuple(float(x) for x in operands), ctm)
        elif o == "cs":
            ink = "other" if str(operands[0]) in DEVICE_SPACES else "spot"
        elif o in ("k", "g", "rg"):
            black = [float(x) for x in operands] in ([0, 0, 0, 1], [0])
            ink = "black" if black else "other"
        elif o in ("sc", "scn") and ink == "black":
            ink = "other"
        elif o == "Do":
            on_do(str(operands[0]), (ctm, ink), in_layer)
        if o in PATH_OPS:
            path.append((operands, op))
            continue
        if o in PAINT_OPS and path:
            pieces = on_fill(path, o, (ctm, ink), in_layer)
            for colour, part, *paint in pieces:
                if colour:  # q/Q so the new colour never leaks into later drawing
                    out.append(pikepdf.ContentStreamInstruction([], pikepdf.Operator("q")))
                out += colour
                out += [pikepdf.ContentStreamInstruction(a, b) for a, b in part]
                out.append(pikepdf.ContentStreamInstruction(operands, paint[0] if paint else op))
                if colour:
                    out.append(pikepdf.ContentStreamInstruction([], pikepdf.Operator("Q")))
            path = []
            continue
        out.append(pikepdf.ContentStreamInstruction(operands, op))
    out += [pikepdf.ContentStreamInstruction(a, b) for a, b in path]
    return out


def visit(obj, resources, state, on_fill, layer_test=None, write=None, uses=None, inside=True):
    """Walk a page or form and every form it draws; write=pdf saves the rewritten streams.

    uses, if given, collects (form objgen, drawn inside the layer) for every form.
    """
    nested = []
    out = walk(pikepdf.parse_content_stream(obj), state, on_fill,
               lambda name, st, in_layer: nested.append((name, st, in_layer)), layer_test)
    for name, (ctm, ink), in_layer in nested:
        form = resources.XObject[name]
        if form.get("/Subtype") != "/Form":
            continue
        # once inside a text-layer form, everything it draws is text
        child_inside = inside and in_layer
        if uses is not None:
            uses.append((form.objgen, child_inside))
        if write is not None and not child_inside:
            continue  # never rewrite forms outside the layer being changed
        matrix = tuple(float(x) for x in form.get("/Matrix", IDENTITY))
        visit(form, form.get("/Resources", resources), (mul(matrix, ctm), ink), on_fill,
              None, write, uses, child_inside)
    if write is not None:
        unparsed = pikepdf.unparse_content_stream(out)
        if isinstance(obj, pikepdf.Page):
            obj.Contents = write.make_stream(unparsed)
        else:
            obj.write(unparsed)


def subpaths(path):
    """Split a compound path at each moveto / rectangle."""
    sub = []
    for item in path:
        if str(item[1]) in ("m", "re") and sub:
            yield sub
            sub = []
        sub.append(item)
    if sub:
        yield sub


def title_boxes(page):
    """Rectangles of the spot-colour surah title boxes, in page coordinates.

    A box is either its own fill or, on the first two pages, a cut-out in the
    green background, so every piece of a compound spot fill is considered.
    """
    boxes = []

    def collect(path, op, state, in_layer):
        if state[1] == "spot" and op in FILL_OPS:
            for sub in subpaths(path):
                box = path_bbox(sub, state[0])
                if box and 60 < box[2] - box[0] < 350 and 12 < box[3] - box[1] < 70:
                    boxes.append(box)
        return [([], path)]

    visit(page, page.Resources, (IDENTITY, "other"), collect)
    return boxes


def grey_page(pdf, page, grey):
    """Grey the text layer except surah names; return counts of grey and title fills."""
    props = page.Resources.Properties
    layer_of = {str(k): str(props[k].get("/Name", "")).strip().lower() for k in props.keys()}

    def is_text_layer(operands):
        return operands[0] == "/OC" and layer_of.get(str(operands[1])) in TEXT_LAYERS

    boxes = title_boxes(page)
    counts = {"grey": 0, "title": 0, "surahs": count_titles(boxes)}
    grey_k = pikepdf.ContentStreamInstruction([0, 0, 0, grey], pikepdf.Operator("k"))
    black_k = pikepdf.ContentStreamInstruction([0, 0, 0, 1], pikepdf.Operator("k"))

    def in_title(subpath, ctm):
        x0, y0, x1, y1 = path_bbox(subpath, ctm)
        for b in boxes:
            overlaps = x0 < b[2] and x1 > b[0] and y0 < b[3] and y1 > b[1]
            inside = b[0] <= x0 and x1 <= b[2] and b[1] <= y0 and y1 <= b[3]
            if overlaps and not inside:
                # a contour crossing a box edge could end up apart from its holes
                raise ValueError(f"text crosses a surah title box edge near {round(x0)},{round(y0)}")
            if inside:
                return True
        return False

    def on_fill(path, op, state, in_layer):
        ctm, ink = state
        if not in_layer or ink != "black" or op not in FILL_OPS:
            return [([], path)]
        # A page's text is one compound path; split it at each moveto so the
        # surah names can keep their ink. Letter holes sit inside their letter,
        # so they land in the same group and the fill rule still holds.
        title, rest = [], []
        for sub in subpaths(path):
            (title if in_title(sub, ctm) else rest).extend(sub)
        counts["title"] += bool(title)
        counts["grey"] += bool(rest)
        return [(c, p) for c, p in (([black_k], title), ([grey_k], rest)) if p]

    uses = []
    visit(page, page.Resources, (IDENTITY, "other"), lambda p, *_: [([], p)], is_text_layer, uses=uses)
    shared = {g for g, inside in uses if inside} & {g for g, inside in uses if not inside}
    if shared:
        raise ValueError(f"form drawn both inside and outside the text layer: {shared}")
    visit(page, page.Resources, (IDENTITY, "other"), on_fill, is_text_layer, write=pdf)
    if counts["grey"] == 0:
        raise ValueError("no black fills found in the text layer")
    return counts


def outline_spot(pdf, page, width):
    """Turn spot-colour fills outside the text layer into black outlines; return how many."""
    props = page.Resources.Properties
    layer_of = {str(k): str(props[k].get("/Name", "")).strip().lower() for k in props.keys()}

    def is_other_layer(operands):
        return operands[0] == "/OC" and layer_of.get(str(operands[1])) not in TEXT_LAYERS

    stroke = [
        pikepdf.ContentStreamInstruction([0, 0, 0, 1], pikepdf.Operator("K")),
        pikepdf.ContentStreamInstruction([width], pikepdf.Operator("w")),
        pikepdf.ContentStreamInstruction([1], pikepdf.Operator("j")),
    ]
    count = [0]

    def on_fill(path, op, state, in_layer):
        if not in_layer or state[1] != "spot" or op not in FILL_OPS:
            return [([], path)]
        # q/Q would end a clip early, and a scaled CTM would change the stroke width
        if any(str(o) in ("W", "W*") for _, o in path) or state[0][:4] != IDENTITY[:4]:
            raise ValueError("unexpected clipped or scaled spot fill; outline would be wrong")
        count[0] += 1
        return [(stroke, path, pikepdf.Operator("S"))]

    visit(page, page.Resources, (IDENTITY, "other"), on_fill, is_other_layer, write=pdf)
    return count[0]


SURAHS = """الفاتحة البقرة آل_عمران النساء المائدة الأنعام الأعراف الأنفال التوبة يونس هود يوسف
الرعد إبراهيم الحجر النحل الإسراء الكهف مريم طه الأنبياء الحج المؤمنون النور الفرقان الشعراء
النمل القصص العنكبوت الروم لقمان السجدة الأحزاب سبأ فاطر يس الصافات ص الزمر غافر فصلت الشورى
الزخرف الدخان الجاثية الأحقاف محمد الفتح الحجرات ق الذاريات الطور النجم القمر الرحمن الواقعة
الحديد المجادلة الحشر الممتحنة الصف الجمعة المنافقون التغابن الطلاق التحريم الملك القلم الحاقة
المعارج نوح الجن المزمل المدثر القيامة الإنسان المرسلات النبأ النازعات عبس التكوير الانفطار
المطففين الانشقاق البروج الطارق الأعلى الغاشية الفجر البلد الشمس الليل الضحى الشرح التين العلق
القدر البينة الزلزلة العاديات القارعة التكاثر العصر الهمزة الفيل قريش الماعون الكوثر الكافرون النصر
المسد الإخلاص الفلق الناس""".split()
SURAHS = [name.replace("_", " ") for name in SURAHS]
JUZ_PAGES = [1, 22, 42, 62, 82, 102, 121, 142, 162, 182, 201, 222, 242, 262, 282,
             302, 322, 342, 362, 382, 402, 422, 442, 462, 482, 502, 522, 542, 562, 582]


def count_titles(boxes):
    """Each title box is found twice (outer and inner outline); count distinct rows."""
    rows = []
    for b in boxes:
        cy = (b[1] + b[3]) / 2
        if all(abs(cy - r) > 10 for r in rows):
            rows.append(cy)
    return len(rows)


def add_bookmarks(book, surah_pages):
    """surah_pages: page index (0-based) for each surah, in order."""
    with book.open_outline() as outline:
        surahs = pikepdf.OutlineItem("السور", surah_pages[0])
        for i, (name, page) in enumerate(zip(SURAHS, surah_pages), 1):
            surahs.children.append(pikepdf.OutlineItem(f"{i}. {name}", page))
        juz = pikepdf.OutlineItem("الأجزاء", JUZ_PAGES[0] - 1)
        for i, page in enumerate(JUZ_PAGES, 1):
            juz.children.append(pikepdf.OutlineItem(f"الجزء {i}", page - 1))
        outline.root.extend([surahs, juz])


def fraction(s):
    v = float(s)
    if not (math.isfinite(v) and 0 < v < 1):
        raise argparse.ArgumentTypeError("must be between 0 and 1")
    return v


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("src_dir")
    ap.add_argument("out")
    ap.add_argument("--grey", type=fraction, default=0.18, help="text ink, 0=white 1=black")
    ap.add_argument("--outline", type=float, default=0.6,
                    help="frame/box/circle outline width in pt; 0 keeps the green fills")
    ap.add_argument("--pages", help="comma-separated page numbers, repeats allowed (for samples)")
    args = ap.parse_args()

    by_number = {}
    for f in glob.glob(os.path.join(args.src_dir, "*.ai")):
        m = NAME.search(f)
        if m:
            by_number[int(m.group(1))] = f
    numbers = [int(x) for x in args.pages.split(",")] if args.pages else list(range(1, 605))
    missing = [n for n in numbers if n not in by_number]
    if missing:
        sys.exit(f"missing pages: {missing[:10]}")

    book = pikepdf.new()
    sources = []  # stream data is copied lazily, so keep sources open until save
    surah_pages = []
    for index, number in enumerate(numbers):
        src = pikepdf.open(by_number[number])
        sources.append(src)
        if len(src.pages) != 1:
            sys.exit(f"page {number}: expected one page")
        counts = grey_page(src, src.pages[0], args.grey)
        if counts["surahs"] and not counts["title"]:
            sys.exit(f"page {number}: surah title box found but its name was not kept dark")
        surah_pages += [index] * counts["surahs"]
        if args.outline > 0 and not outline_spot(src, src.pages[0], args.outline):
            sys.exit(f"page {number}: no frame found to outline")
        book.pages.append(src.pages[0])
        print(f"{number:03d} grey={counts['grey']} title={counts['title']} surahs={counts['surahs']}", flush=True)
    if not args.pages:
        if len(surah_pages) != len(SURAHS):
            sys.exit(f"found {len(surah_pages)} surah titles, expected {len(SURAHS)}")
        add_bookmarks(book, surah_pages)
    book.docinfo["/Title"] = "مصحف المدينة – نسخة للكتابة"
    book.save(args.out, compress_streams=True, object_stream_mode=pikepdf.ObjectStreamMode.generate)
    print(f"{len(numbers)} pages -> {args.out}")


if __name__ == "__main__":
    main()
