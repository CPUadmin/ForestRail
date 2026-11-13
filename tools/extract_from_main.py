# -*- coding: utf-8 -*-
"""T7 (splitting main.gd): move a run of functions [START_FUNC, END_FUNC) from ForestRail/scripts/main.gd
into a RefCounted helper that works through `canvas` (main.gd), the way cab_art.gd and control_art.gd were made.

usage:
  python tools/extract_from_main.py START_FUNC END_FUNC out_file.gd ConstName accessor "header line 1|header line 2" [--dry]

--dry prints the report only: which functions need a thin wrapper in main.gd (used elsewhere), which are internal,
which names are shadowed by locals, and UNKNOWN names (not local, not a member of main.gd, not a known global):
every UNKNOWN must be checked by hand (an engine method of Node2D/CanvasItem used without `self` must go to ENGINE).
The block must not declare members (var/const) between its functions: move them out first.
"""
import io, re, os, glob, sys

START_F, END_F, OUT, CONST, ACC, HEADER = sys.argv[1:7]
DRY = "--dry" in sys.argv
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..", "ForestRail").replace("\\", "/") + "/"
R = ROOT + "scripts/"
raw = io.open(R + "main.gd", encoding="utf-8", newline="").read()
nl = "\r\n" if "\r\n" in raw else "\n"
text = raw.replace("\r\n", "\n")
lines = text.split("\n")


def idx(name):
    for i, l in enumerate(lines):
        if re.match(r"(static )?func " + name + r"\(", l):
            return i
    raise KeyError(name)


START = idx(START_F)
END = idx(END_F)
# the comment lines right above START_F go with the block; the ones right above END_F stay in main.gd
while START > 0 and lines[START - 1].startswith("#"):
    START -= 1
e = END
while e > START and (lines[e - 1].startswith("#") or lines[e - 1].strip() == ""):
    e -= 1
END = e
block = lines[START:END]

members = {}
for l in lines[:START] + lines[END:]:
    m = re.match(r"^(?:@\w+(?:\([^)]*\))?\s+)*(?:static\s+)?(var|const|func|enum|signal)\s+([A-Za-z_]\w*)", l)
    if m:
        members[m.group(2)] = m.group(1)

block_funcs = {}
for l in block:
    if re.match(r"(static )?func ", l):
        m = re.match(r"(?:static )?func\s+(\w+)\((.*?)\)\s*(->\s*[\w\[\], ]+)?:\s*(.*)$", l)
        assert m, l
        block_funcs[m.group(1)] = (m.group(2), (m.group(3) or "").strip(), l)
bad_members = [l for l in block if re.match(r"^(@\w+\s+)*(var|const|signal|enum)\s", l)]

ENGINE = set("""draw_style_box draw_line draw_string draw_circle draw_arc draw_rect draw_colored_polygon draw_set_transform_matrix
draw_polygon draw_polyline draw_texture_rect draw_texture_rect_region get_global_mouse_position draw_texture draw_multiline
draw_multiline_colors draw_set_transform draw_primitive draw_string_outline add_child remove_child get_viewport_rect get_viewport
get_tree queue_redraw get_node get_node_or_null has_node is_inside_tree get_canvas_item get_local_mouse_position create_tween
get_children get_child get_child_count""".split())
KEYWORDS = set("""if elif else for while match in and or not var const func return pass break continue true false null self as is
await class extends static void super when int float bool PI TAU INF NAN""".split())
GLOBALS = set("""abs absf absi acos asin atan atan2 ceil ceilf ceili clamp clampf clampi cos deg_to_rad exp floor floorf floori fmod
fposmod lerp lerpf lerp_angle log max maxf maxi min minf mini pow randf randf_range randi randi_range range remap round roundf
roundi sign signf sin smoothstep sqrt tan tanh snappedf snapped wrapf wrapi str print push_error push_warning rad_to_deg posmod
move_toward inverse_lerp len typeof is_equal_approx is_zero_approx ease pingpong is_instance_valid weakref instance_from_id
var_to_str str_to_var hash""".split())


def scan_string(line, i):
    q = line[i]
    j = i + 1
    while j < len(line) and line[j] != q:
        if line[j] == "\\":
            j += 1
        j += 1
    return j + 1


def strip_sc(line):
    out = []
    i = 0
    while i < len(line):
        c = line[i]
        if c == "#":
            break
        if c in "\"'":
            i = scan_string(line, i)
            out.append(" ")
            continue
        out.append(c)
        i += 1
    return "".join(out)


def func_locals(fl):
    loc = set()
    m = re.match(r"(?:static )?func\s+\w+\((.*?)\)", fl[0])
    for part in m.group(1).split(","):
        part = part.strip()
        if part:
            loc.add(re.match(r"\w+", part).group(0))
    for l in fl:
        s = strip_sc(l)
        for mm in re.finditer(r"\b(?:var|const)\s+(\w+)", s):
            loc.add(mm.group(1))
        for mm in re.finditer(r"\bfor\s+(\w+)\s+in", s):
            loc.add(mm.group(1))
        for mm in re.finditer(r"func\s*\w*\s*\(([^)]*)\)", s):
            for part in mm.group(1).split(","):
                part = part.strip()
                if part:
                    loc.add(re.match(r"\w+", part).group(0))
    return loc


unknown = {}
stats = {"used": set(), "shadow": set()}


def convert_line(line, loc):
    out = []
    i = 0
    n = len(line)
    while i < n:
        c = line[i]
        if c == "#":
            out.append(line[i:])
            break
        if c in "\"'":
            j = scan_string(line, i)
            out.append(line[i:j])
            i = j
            continue
        if c.isdigit():
            j = i
            while j < n and (line[j].isalnum() or line[j] in "._"):
                j += 1
            out.append(line[i:j])
            i = j
            continue
        if c.isalpha() or c == "_":
            j = i
            while j < n and (line[j].isalnum() or line[j] == "_"):
                j += 1
            name = line[i:j]
            prev = line[i - 1] if i > 0 else ""
            nxt = line[j:].lstrip()[:1]
            if prev in ".$@":
                out.append(name)
            elif name in loc or name in KEYWORDS or name in block_funcs:
                if name in loc and (name in members or name in ENGINE):
                    stats["shadow"].add(name)
                out.append(name)
            elif name in ENGINE or name in members:
                out.append("canvas." + name)
                stats["used"].add(name)
            else:
                if name not in GLOBALS and not name[0].isupper() and nxt != ":":
                    unknown[name] = unknown.get(name, 0) + 1
                out.append(name)
            i = j
            continue
        out.append(c)
        i += 1
    return "".join(out)


funcs = []
cur = None
pre = []
for l in block:
    if re.match(r"(static )?func ", l):
        cur = [l]
        funcs.append((pre, cur))
        pre = []
    elif cur is not None:
        cur.append(l)
    else:
        pre.append(l)
parts = []
for pre_lines, f in funcs:
    loc = func_locals(f)
    f2 = [convert_line(l, loc) for l in f]
    if f2[0].startswith("static "):
        f2[0] = f2[0][len("static "):]
    parts.append("\n".join(pre_lines + f2))
out_body = "\n".join(parts)

files = glob.glob(ROOT + "**/*.gd", recursive=True) + glob.glob(ROOT + "../tools/**/*.py", recursive=True)
main_wo = "\n".join(lines[:START] + lines[END:])
outside = {}
for name in block_funcs:
    pat = re.compile(r"\b" + name + r"\b")
    where = []
    for p in files:
        p = p.replace("\\", "/")
        if p.endswith("scripts/main.gd"):
            t = main_wo
        elif p.endswith("scripts/" + OUT) or p.endswith("tools/extract_from_main.py"):
            continue
        else:
            t = io.open(p, encoding="utf-8", newline="").read()
        c = len(pat.findall(t))
        if c:
            where.append((os.path.basename(p), c))
    outside[name] = where

print("block lines", END - START, "funcs", len(block_funcs), "first line", START + 1)
print("need wrapper:", [n for n in block_funcs if outside[n]])
print("internal only:", [n for n in block_funcs if not outside[n]])
print("shadowed (a local has the name of a member):", sorted(stats["shadow"]))
print("UNKNOWN:", sorted(unknown.items()))
if bad_members:
    print("MEMBERS INSIDE BLOCK (move them out first):", bad_members)
for n in block_funcs:
    if re.search(r"[\"']" + n + r"[\"']", text):
        print("STRING REF to", n)
if DRY or bad_members:
    sys.exit(0 if DRY else 1)

header = ["extends RefCounted"] + ["# " + h for h in HEADER.split("|")] + [
    "", "var canvas = null   # main.gd: it holds the model, the settings and the shared state", "",
    "func _init(owner_canvas) -> void:", "\tcanvas = owner_canvas", ""]
io.open(R + OUT, "w", encoding="utf-8", newline="").write(("\n".join(header) + "\n" + out_body + "\n").replace("\n", nl))
wr = []
for name, (params, ret, headline) in block_funcs.items():
    if not outside[name]:
        continue
    args = [re.match(r"\w+", p.strip()).group(0) for p in params.split(",") if p.strip()]
    call = "%s().%s(%s)" % (ACC, name, ", ".join(args))
    hl = headline.replace("static func", "func")
    body = ("\t" + call) if ret.replace(" ", "") in ("->void", "") and ret != "" else ("\treturn " + call)
    if ret == "":
        body = "\treturn " + call
    wr.append(hl + "\n" + body)
extra = "var %s_cache = null\nfunc %s():\n\tif %s_cache == null: %s_cache = %s.new(self)\n\treturn %s_cache\n\n" % (
    ACC, ACC, ACC, ACC, CONST, ACC)
t2 = "\n".join(lines[:START] + (extra + "\n\n".join(wr)).split("\n") + [""] + lines[END:])
anchor = "const CabArt = preload(\"res://scripts/cab_art.gd\")"
assert t2.count(anchor) == 1
t2 = t2.replace(anchor, anchor + "\nconst %s = preload(\"res://scripts/%s\")" % (CONST, OUT))
io.open(R + "main.gd", "w", encoding="utf-8", newline="").write(t2.replace("\n", nl))
print("written", OUT)
