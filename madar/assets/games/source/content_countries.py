"""Capitals & Flags content, written for Madar.

COUNTRIES: every UN member state (193) and the two UN observer states
(Holy See, State of Palestine): ISO 3166-1 alpha-2 code, Arabic / English
short names, capital (Arabic / English), other capitals or seats, continent
(UN M49 grouping, with Central America and the Caribbean under North
America), status and review notes.

FLAGS: a code-drawable specification per state – NO images. Units: x is a
fraction of the flag width (0 = hoist / left edge), y a fraction of the
height (0 = top); radii, stroke and band widths are fractions of the HEIGHT.
Flags are never mirrored for right-to-left layouts. Emblems and coats of
arms are approximated by simple shapes (disc, oval, shield, eagle, bird,
crown, tree). See lib/features/cinema/rules/words/geo/flag_spec.dart for the
element types.
"""

import math

# ----------------------------------------------------------------- helpers


def flag(w, h, *parts):
    k = h / w  # height units -> width fraction
    out = []
    for p in parts:
        if callable(p):
            p = p(k)
        if isinstance(p, list):
            out.extend(p)
        else:
            out.append(p)
    return {'ratio': [w, h], 'e': out}


def r4(v):
    return round(v, 4)


def FILL(c):
    return {'t': 'fill', 'c': c}


def H(*c, w=None):
    e = {'t': 'hs', 'c': list(c)}
    if w:
        e['w'] = list(w)
    return e


def V(*c, w=None):
    e = {'t': 'vs', 'c': list(c)}
    if w:
        e['w'] = list(w)
    return e


def R(c, x, y, w, h):
    return {'t': 'rect', 'c': c, 'x': r4(x), 'y': r4(y), 'w': r4(w), 'h': r4(h)}


def P(c, *pts, sw=None):
    e = {'t': 'poly', 'c': c, 'p': [[r4(x), r4(y)] for x, y in pts]}
    if sw:
        e['sw'] = sw
    return e


def C(c, x, y, r):
    return {'t': 'circle', 'c': c, 'x': r4(x), 'y': r4(y), 'r': r4(r)}


def RING(c, x, y, r, ir):
    return {'t': 'ring', 'c': c, 'x': r4(x), 'y': r4(y), 'r': r4(r), 'ir': r4(ir)}


def CR(c, x, y, r, dx, ir, dy=0.0):
    """Crescent: disc (x, y, r) minus disc of radius ir whose centre is offset
    by (dx, dy) HEIGHT units from (x, y)."""
    return {'t': 'crescent', 'c': c, 'x': r4(x), 'y': r4(y), 'r': r4(r), 'dx': r4(dx), 'dy': r4(dy), 'ir': r4(ir)}


def S(c, x, y, r, n=5, ir=0.382, rot=0):
    e = {'t': 'star', 'c': c, 'x': r4(x), 'y': r4(y), 'r': r4(r)}
    if n != 5:
        e['n'] = n
    if ir != 0.382:
        e['ir'] = r4(ir)
    if rot:
        e['rot'] = r4(rot)
    return e


def SUN(c, x, y, r, n, ir=0.6, rot=0):
    """Rays (a star of n points) plus a central disc of radius r*ir."""
    e = {'t': 'sun', 'c': c, 'x': r4(x), 'y': r4(y), 'r': r4(r), 'n': n, 'ir': r4(ir)}
    if rot:
        e['rot'] = r4(rot)
    return e


def PENTA(c, x, y, r, sw):
    """Interlaced pentagram outline (Morocco, Ethiopia)."""
    return {'t': 'pentagram', 'c': c, 'x': r4(x), 'y': r4(y), 'r': r4(r), 'sw': r4(sw)}


def CROSS(c, x, y, w):
    """Full-width / full-height cross; bars centred at x (vertical) and y
    (horizontal), thickness w (height units)."""
    return {'t': 'cross', 'c': c, 'x': r4(x), 'y': r4(y), 'w': r4(w)}


def PLUS(c, x, y, s, w):
    """Greek cross of overall size s and arm thickness w (height units)."""
    return {'t': 'plus', 'c': c, 'x': r4(x), 'y': r4(y), 's': r4(s), 'w': r4(w)}


def SALTIRE(c, w):
    return {'t': 'saltire', 'c': c, 'w': r4(w)}


def B(c, x1, y1, x2, y2, w):
    """Straight band of thickness w (height units) between two points."""
    return {'t': 'band', 'c': c, 'x1': r4(x1), 'y1': r4(y1), 'x2': r4(x2), 'y2': r4(y2), 'w': r4(w)}


def UJ(x=0.0, y=0.0, w=1.0, h=1.0):
    return {'t': 'uj', 'x': r4(x), 'y': r4(y), 'w': r4(w), 'h': r4(h)}


def T(c, x, y, s, v):
    return {'t': 'text', 'c': c, 'x': r4(x), 'y': r4(y), 's': r4(s), 'v': v}


def EM(c, x, y, r, shape='disc'):
    return {'t': 'emblem', 'c': c, 'x': r4(x), 'y': r4(y), 'r': r4(r), 'shape': shape}


def WHEEL(c, x, y, r, n, sw):
    return {'t': 'wheel', 'c': c, 'x': r4(x), 'y': r4(y), 'r': r4(r), 'n': n, 'sw': r4(sw)}


def star_ring(c, cx, cy, rad, count, r, start=-90.0, n=5, point_out=False):
    """`count` stars on a circle of radius `rad` (height units) around
    (cx, cy); returns a ratio-dependent element list."""
    def build(k):
        out = []
        for i in range(count):
            a = math.radians(start + 360.0 * i / count)
            x = cx + rad * math.cos(a) * k
            y = cy + rad * math.sin(a)
            rot = (math.degrees(a) + 90) if point_out else 0
            out.append(S(c, x, y, r, n=n, rot=rot))
        return out
    return build


def star_arc(c, cx, cy, rad, count, r, a0, a1, n=5):
    def build(k):
        out = []
        for i in range(count):
            a = math.radians(a0 + (a1 - a0) * i / max(1, count - 1))
            out.append(S(c, cx + rad * math.cos(a) * k, cy + rad * math.sin(a), r, n=n))
        return out
    return build


def star_toward(c, x, y, r, tx, ty):
    """A star whose upper point aims at (tx, ty) (China's small stars)."""
    def build(k):
        ang = math.degrees(math.atan2((tx - x) / k, -(ty - y)))
        return S(c, x, y, r, rot=ang)
    return build


def stars_grid_us(c):
    def build(k):
        out = []
        canton_h = 7 / 13
        canton_w = 0.76 * k  # 0.76 of the height, in width units
        for row in range(9):
            cols = 6 if row % 2 == 0 else 5
            for col in range(cols):
                gx = (2 * col + (1 if row % 2 == 0 else 2)) / 12.0
                gy = (row + 1) / 10.0
                out.append(S(c, gx * canton_w, gy * canton_h, 0.0308))
        return out
    return build


def maple_leaf(c, cx, cy, s):
    pts = [(0, -0.95), (0.13, -0.72), (0.26, -0.8), (0.22, -0.38), (0.45, -0.6), (0.5, -0.47), (0.72, -0.52),
           (0.64, -0.28), (0.78, -0.22), (0.45, 0.05), (0.5, 0.16), (0.06, 0.1), (0.06, 0.55), (-0.06, 0.55),
           (-0.06, 0.1), (-0.5, 0.16), (-0.45, 0.05), (-0.78, -0.22), (-0.64, -0.28), (-0.72, -0.52), (-0.5, -0.47),
           (-0.45, -0.6), (-0.22, -0.38), (-0.26, -0.8), (-0.13, -0.72)]

    def build(k):
        return P(c, *[(cx + px * s * k, cy + py * s) for px, py in pts])
    return build


def trident(c, cx, cy, s):
    pts = [(-0.06, 0.9), (-0.06, 0.1), (-0.42, 0.1), (-0.5, -0.6), (-0.4, -0.25), (-0.12, -0.25), (-0.12, -0.55),
           (0, -0.8), (0.12, -0.55), (0.12, -0.25), (0.4, -0.25), (0.5, -0.6), (0.42, 0.1), (0.06, 0.1), (0.06, 0.9)]

    def build(k):
        return P(c, *[(cx + px * s * k, cy + py * s) for px, py in pts])
    return build


def serrated(c, base, tip, points):
    """Hoist band with `points` triangular serrations (Bahrain, Qatar)."""
    pts = [(0, 0), (base, 0)]
    for i in range(points):
        pts.append((tip, (i + 0.5) / points))
        pts.append((base, (i + 1) / points))
    pts.append((0, 1))
    return P(c, *pts)


def tri_band(c, apex_x, y0, y1):
    """Part of the downward triangle (0,0)-(1,0)-(apex_x,1) between y0 and y1."""
    def at(y):
        return (apex_x * y, 1 - (1 - apex_x) * y)
    (l0, r0), (l1, r1) = at(y0), at(y1)
    return P(c, (l0, y0), (r0, y0), (r1, y1), (l1, y1))


def rot_rect(c, cx, cy, w, h, deg):
    def build(k):
        a = math.radians(deg)
        out = []
        for dx, dy in ((-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2)):
            x = dx * math.cos(a) - dy * math.sin(a)
            y = dx * math.sin(a) + dy * math.cos(a)
            out.append((cx + x * k, cy + y))
        return P(c, *out)
    return build


def half_disc(c, cx, cy, r, deg, segs=24):
    def build(k):
        pts = []
        for i in range(segs + 1):
            a = math.radians(deg + 180.0 * i / segs)
            pts.append((cx + r * math.cos(a) * k, cy + r * math.sin(a)))
        return P(c, *pts)
    return build


def arc_band(c, cx, cy, r, w, a0, a1, segs=24):
    def build(k):
        outer, inner = [], []
        for i in range(segs + 1):
            a = math.radians(a0 + (a1 - a0) * i / segs)
            outer.append((cx + (r + w / 2) * math.cos(a) * k, cy + (r + w / 2) * math.sin(a)))
            inner.append((cx + (r - w / 2) * math.cos(a) * k, cy + (r - w / 2) * math.sin(a)))
        return P(c, *(outer + inner[::-1]))
    return build


def rays(c, cx, cy, targets, w):
    """Triangular rays from the centre to edge points (North Macedonia)."""
    out = []
    for (tx, ty) in targets:
        out.append(B(c, cx, cy, tx, ty, w))
    return out


def stripes(colors, n):
    return H(*[colors[i % len(colors)] for i in range(n)])


# ------------------------------------------------------------------ colours
WHITE, BLACK = '#FFFFFF', '#000000'
RED, GREEN, YELLOW, BLUE = '#CE1126', '#007A3D', '#FCD116', '#0038A8'
GOLD = '#F1BF00'

# (iso, ar, en, capital_ar, capital_en, continent, status, flag, extras)
# extras: alt=[(ar, en), ...], disputed=True, note='...'
COUNTRIES = [
    # ================================================================ Africa
    ('DZ', 'الجزائر', 'Algeria', 'الجزائر', 'Algiers', 'africa', 'member',
     flag(3, 2, V('#006233', WHITE), CR('#D21034', 0.5, 0.5, 0.25, 0.0625, 0.2), lambda k: S('#D21034', 0.5 + 0.12 * k, 0.5, 0.125, rot=-18)), {}),
    ('AO', 'أنغولا', 'Angola', 'لواندا', 'Luanda', 'africa', 'member',
     flag(3, 2, H('#CC092F', BLACK), RING('#FFCB00', 0.5, 0.5, 0.25, 0.19), S('#FFCB00', 0.46, 0.42, 0.07),
          B('#FFCB00', 0.42, 0.66, 0.6, 0.36, 0.06)), {}),
    ('BJ', 'بنين', 'Benin', 'بورتو نوفو', 'Porto-Novo', 'africa', 'member',
     flag(3, 2, R('#008751', 0, 0, 0.4, 1), R('#FCD116', 0.4, 0, 0.6, 0.5), R('#E8112D', 0.4, 0.5, 0.6, 0.5)),
     {'alt': [('كوتونو', 'Cotonou')], 'note': 'Porto-Novo is the official capital; Cotonou is the seat of government.'}),
    ('BW', 'بوتسوانا', 'Botswana', 'غابورون', 'Gaborone', 'africa', 'member',
     flag(3, 2, H('#75AADB', WHITE, BLACK, WHITE, '#75AADB', w=[9, 1, 4, 1, 9])), {}),
    ('BF', 'بوركينا فاسو', 'Burkina Faso', 'واغادوغو', 'Ouagadougou', 'africa', 'member',
     flag(3, 2, H('#EF2B2D', '#009E49'), S('#FCD116', 0.5, 0.5, 0.17)), {}),
    ('BI', 'بوروندي', 'Burundi', 'جيتيغا', 'Gitega', 'africa', 'member',
     flag(5, 3, FILL('#CE1126'), P('#1EB53A', (0, 0), (0.5, 0.5), (0, 1)), P('#1EB53A', (1, 0), (0.5, 0.5), (1, 1)),
          SALTIRE(WHITE, 0.15), C(WHITE, 0.5, 0.5, 0.3), star_ring('#CE1126', 0.5, 0.5, 0.13, 3, 0.07, n=6)),
     {'alt': [('بوجمبورا', 'Bujumbura')], 'note': 'Gitega became the political capital in 2019; Bujumbura remains the economic capital.'}),
    ('CV', 'الرأس الأخضر', 'Cabo Verde', 'برايا', 'Praia', 'africa', 'member',
     flag(5, 3, H('#003893', WHITE, '#CF2027', WHITE, '#003893', w=[6, 1, 1, 1, 3]),
          star_ring('#F7D116', 0.375, 0.5833, 0.23, 10, 0.045)), {}),
    ('CM', 'الكاميرون', 'Cameroon', 'ياوندي', 'Yaoundé', 'africa', 'member',
     flag(3, 2, V('#007A5E', '#CE1126', '#FCD116'), S('#FCD116', 0.5, 0.5, 0.15)), {}),
    ('CF', 'جمهورية أفريقيا الوسطى', 'Central African Republic', 'بانغي', 'Bangui', 'africa', 'member',
     flag(5, 3, H('#003082', WHITE, '#289728', '#FFCE00'), R('#D21034', 0.4375, 0, 0.125, 1), S('#FFCE00', 0.125, 0.125, 0.1)), {}),
    ('TD', 'تشاد', 'Chad', 'نجامينا', "N'Djamena", 'africa', 'member',
     flag(3, 2, V('#002664', '#FECB00', '#C60C30')), {}),
    ('KM', 'جزر القمر', 'Comoros', 'موروني', 'Moroni', 'africa', 'member',
     flag(5, 3, H('#FFC61E', WHITE, '#CE1126', '#3A75C4'), P('#3D8E33', (0, 0), (0.35, 0.5), (0, 1)),
          CR(WHITE, 0.1, 0.5, 0.18, 0.07, 0.16), lambda k: [S(WHITE, 0.1 + 0.05 * k, 0.5 + dy, 0.03) for dy in (-0.105, -0.035, 0.035, 0.105)]), {}),
    ('CG', 'جمهورية الكونغو', 'Republic of the Congo', 'برازافيل', 'Brazzaville', 'africa', 'member',
     flag(3, 2, FILL('#FBDE4A'), P('#009543', (0, 0), (0.6667, 0), (0, 1)), P('#DC241F', (1, 0), (1, 1), (0.3333, 1))), {}),
    ('CD', 'جمهورية الكونغو الديمقراطية', 'Democratic Republic of the Congo', 'كينشاسا', 'Kinshasa', 'africa', 'member',
     flag(4, 3, FILL('#007FFF'), B('#F7D618', 0, 1, 1, 0, 0.32), B('#CE1021', 0, 1, 1, 0, 0.22), S('#F7D618', 0.2, 0.25, 0.18)), {}),
    ('CI', 'ساحل العاج', "Côte d'Ivoire", 'ياموسوكرو', 'Yamoussoukro', 'africa', 'member',
     flag(3, 2, V('#F77F00', WHITE, '#009E60')),
     {'alt': [('أبيدجان', 'Abidjan')], 'note': 'Yamoussoukro is the official capital; Abidjan is the economic capital.'}),
    ('DJ', 'جيبوتي', 'Djibouti', 'جيبوتي', 'Djibouti', 'africa', 'member',
     flag(3, 2, H('#6AB2E7', '#12AD2B'), P(WHITE, (0, 0), (0.45, 0.5), (0, 1)), S('#D7141A', 0.17, 0.5, 0.12)), {}),
    ('EG', 'مصر', 'Egypt', 'القاهرة', 'Cairo', 'africa', 'member',
     flag(3, 2, H('#CE1126', WHITE, BLACK), EM('#C09300', 0.5, 0.5, 0.15, 'eagle')),
     {'note': 'Government ministries have moved to the New Administrative Capital; Cairo remains the capital.'}),
    ('GQ', 'غينيا الاستوائية', 'Equatorial Guinea', 'سيوداد دي لا باز', 'Ciudad de la Paz', 'africa', 'member',
     flag(3, 2, H('#3E9A00', WHITE, '#E32118'), P('#0073CE', (0, 0), (0.2, 0.5), (0, 1)), EM('#9E9E9E', 0.5, 0.5, 0.13, 'shield')),
     {'alt': [('مالابو', 'Malabo')], 'review': True,
      'note': 'The move of the capital from Malabo to Ciudad de la Paz was decreed in January 2026 – verify before shipping.'}),
    ('ER', 'إريتريا', 'Eritrea', 'أسمرة', 'Asmara', 'africa', 'member',
     flag(2, 1, FILL('#EA0437'), P('#12AD2B', (0, 0), (1, 0), (1, 0.5)), P('#4189DD', (0, 1), (1, 1), (1, 0.5)),
          RING('#FFC726', 0.25, 0.5, 0.28, 0.24), B('#FFC726', 0.25, 0.78, 0.25, 0.3, 0.04)), {}),
    ('SZ', 'إسواتيني', 'Eswatini', 'مباباني', 'Mbabane', 'africa', 'member',
     flag(3, 2, H('#3E5EB9', '#FFD900', '#B10C0C', '#FFD900', '#3E5EB9', w=[3, 1, 8, 1, 3]),
          B('#FFD900', 0.15, 0.5, 0.85, 0.5, 0.03), EM(WHITE, 0.5, 0.5, 0.2, 'oval'), half_disc(BLACK, 0.5, 0.5, 0.2, 90)),
     {'alt': [('لوبامبا', 'Lobamba')], 'note': 'Mbabane is the administrative capital; Lobamba the royal and legislative capital.'}),
    ('ET', 'إثيوبيا', 'Ethiopia', 'أديس أبابا', 'Addis Ababa', 'africa', 'member',
     flag(2, 1, H('#078930', '#FCDD09', '#DA121A'), C('#0F47AF', 0.5, 0.5, 0.25), PENTA('#FCDD09', 0.5, 0.5, 0.2, 0.03)), {}),
    ('GA', 'الغابون', 'Gabon', 'ليبرفيل', 'Libreville', 'africa', 'member',
     flag(4, 3, H('#009E60', '#FCD116', '#3A75C4')), {}),
    ('GM', 'غامبيا', 'Gambia', 'بانجول', 'Banjul', 'africa', 'member',
     flag(3, 2, H('#CE1126', WHITE, '#0C1C8C', WHITE, '#3A7728', w=[6, 1, 4, 1, 6])), {}),
    ('GH', 'غانا', 'Ghana', 'أكرا', 'Accra', 'africa', 'member',
     flag(3, 2, H('#CE1126', '#FCD116', '#006B3F'), S(BLACK, 0.5, 0.5, 0.17)), {}),
    ('GN', 'غينيا', 'Guinea', 'كوناكري', 'Conakry', 'africa', 'member',
     flag(3, 2, V('#CE1126', '#FCD116', '#009460')), {}),
    ('GW', 'غينيا بيساو', 'Guinea-Bissau', 'بيساو', 'Bissau', 'africa', 'member',
     flag(2, 1, H('#FCD116', '#009E49'), R('#CE1126', 0, 0, 0.3333, 1), S(BLACK, 0.1667, 0.5, 0.15)), {}),
    ('KE', 'كينيا', 'Kenya', 'نيروبي', 'Nairobi', 'africa', 'member',
     flag(3, 2, H(BLACK, WHITE, '#BB0000', WHITE, '#006600', w=[6, 1, 6, 1, 6]),
          B(WHITE, 0.36, 0.85, 0.64, 0.15, 0.025), B(WHITE, 0.36, 0.15, 0.64, 0.85, 0.025), EM('#BB0000', 0.5, 0.5, 0.3, 'oval'),
          EM(BLACK, 0.5, 0.5, 0.12, 'oval')), {}),
    ('LS', 'ليسوتو', 'Lesotho', 'ماسيرو', 'Maseru', 'africa', 'member',
     flag(3, 2, H('#00209F', WHITE, '#009543', w=[3, 4, 3]), P(BLACK, (0.5, 0.33), (0.56, 0.52), (0.62, 0.62), (0.38, 0.62), (0.44, 0.52))), {}),
    ('LR', 'ليبيريا', 'Liberia', 'مونروفيا', 'Monrovia', 'africa', 'member',
     flag(19, 10, stripes(['#BF0A30', WHITE], 11), lambda k: [R('#002868', 0, 0, 5 / 11 * k, 5 / 11), S(WHITE, 2.5 / 11 * k, 2.5 / 11, 0.15)]), {}),
    ('LY', 'ليبيا', 'Libya', 'طرابلس', 'Tripoli', 'africa', 'member',
     flag(2, 1, H('#E70013', BLACK, '#239E46', w=[1, 2, 1]), CR(WHITE, 0.48, 0.5, 0.15, 0.04, 0.12), lambda k: S(WHITE, 0.48 + 0.16 * k, 0.5, 0.07, rot=-90)), {}),
    ('MG', 'مدغشقر', 'Madagascar', 'أنتاناناريفو', 'Antananarivo', 'africa', 'member',
     flag(3, 2, H('#FC3D32', '#007E3A'), R(WHITE, 0, 0, 0.3333, 1)), {}),
    ('MW', 'مالاوي', 'Malawi', 'ليلونغوي', 'Lilongwe', 'africa', 'member',
     flag(3, 2, H(BLACK, '#CE1126', '#339E35'), SUN('#CE1126', 0.5, 0.36, 0.2, 31, 0.55)), {}),
    ('ML', 'مالي', 'Mali', 'باماكو', 'Bamako', 'africa', 'member',
     flag(3, 2, V('#14B53A', '#FCD116', '#CE1126')), {}),
    ('MR', 'موريتانيا', 'Mauritania', 'نواكشوط', 'Nouakchott', 'africa', 'member',
     flag(3, 2, H('#D01C1F', '#00A95C', '#D01C1F', w=[3, 14, 3]), CR('#FFD700', 0.5, 0.45, 0.22, 0, 0.2, dy=-0.07),
          S('#FFD700', 0.5, 0.36, 0.08)), {}),
    ('MU', 'موريشيوس', 'Mauritius', 'بورت لويس', 'Port Louis', 'africa', 'member',
     flag(3, 2, H('#EA2839', '#1A206D', '#FFD500', '#00A551')), {}),
    ('MA', 'المغرب', 'Morocco', 'الرباط', 'Rabat', 'africa', 'member',
     flag(3, 2, FILL('#C1272D'), PENTA('#006233', 0.5, 0.48, 0.24, 0.035)), {}),
    ('MZ', 'موزمبيق', 'Mozambique', 'مابوتو', 'Maputo', 'africa', 'member',
     flag(3, 2, H('#007168', WHITE, BLACK, WHITE, '#FCE100', w=[5, 1, 5, 1, 5]), P('#D21034', (0, 0), (0.43, 0.5), (0, 1)),
          S('#FCE100', 0.15, 0.5, 0.18), EM(WHITE, 0.15, 0.52, 0.06, 'disc')), {}),
    ('NA', 'ناميبيا', 'Namibia', 'ويندهوك', 'Windhoek', 'africa', 'member',
     flag(3, 2, FILL('#009543'), P('#003580', (0, 0), (1, 0), (0, 1)), B(WHITE, 0, 1, 1, 0, 0.36), B('#D21034', 0, 1, 1, 0, 0.26),
          SUN('#FFCE00', 0.18, 0.27, 0.17, 12, 0.55)), {}),
    ('NE', 'النيجر', 'Niger', 'نيامي', 'Niamey', 'africa', 'member',
     flag(7, 6, H('#E05206', WHITE, '#0DB02B'), C('#E05206', 0.5, 0.5, 0.12)), {}),
    ('NG', 'نيجيريا', 'Nigeria', 'أبوجا', 'Abuja', 'africa', 'member',
     flag(2, 1, V('#008751', WHITE, '#008751')), {}),
    ('RW', 'رواندا', 'Rwanda', 'كيغالي', 'Kigali', 'africa', 'member',
     flag(3, 2, H('#00A1DE', '#FAD201', '#20603D', w=[2, 1, 1]), SUN('#FAD201', 0.83, 0.25, 0.15, 24, 0.55)), {}),
    ('ST', 'ساو تومي وبرينسيب', 'São Tomé and Príncipe', 'ساو تومي', 'São Tomé', 'africa', 'member',
     flag(2, 1, H('#12AD2B', '#FFCE00', '#12AD2B', w=[2, 3, 2]), P('#D21034', (0, 0), (0.25, 0.5), (0, 1)),
          S(BLACK, 0.5, 0.5, 0.15), S(BLACK, 0.75, 0.5, 0.15)), {}),
    ('SN', 'السنغال', 'Senegal', 'داكار', 'Dakar', 'africa', 'member',
     flag(3, 2, V('#00853F', '#FDEF42', '#E31B23'), S('#00853F', 0.5, 0.5, 0.16)), {}),
    ('SC', 'سيشل', 'Seychelles', 'فيكتوريا', 'Victoria', 'africa', 'member',
     flag(2, 1, P('#003F87', (0, 1), (0, 0), (0.3333, 0)), P('#FCD856', (0, 1), (0.3333, 0), (0.6667, 0)),
          P('#D62828', (0, 1), (0.6667, 0), (1, 0), (1, 0.3333)), P(WHITE, (0, 1), (1, 0.3333), (1, 0.6667)),
          P('#007A3D', (0, 1), (1, 0.6667), (1, 1))), {}),
    ('SL', 'سيراليون', 'Sierra Leone', 'فريتاون', 'Freetown', 'africa', 'member',
     flag(3, 2, H('#1EB53A', WHITE, '#0072C6')), {}),
    ('SO', 'الصومال', 'Somalia', 'مقديشو', 'Mogadishu', 'africa', 'member',
     flag(3, 2, FILL('#4189DD'), S(WHITE, 0.5, 0.5, 0.23)), {}),
    ('ZA', 'جنوب أفريقيا', 'South Africa', 'بريتوريا', 'Pretoria', 'africa', 'member',
     flag(3, 2, H('#E03C31', '#001489'), B(WHITE, 0, 0, 0.42, 0.5, 0.34), B(WHITE, 0, 1, 0.42, 0.5, 0.34), R(WHITE, 0.4, 0.33, 0.6, 0.34),
          B('#007749', 0, 0, 0.42, 0.5, 0.2), B('#007749', 0, 1, 0.42, 0.5, 0.2), R('#007749', 0.4, 0.4, 0.6, 0.2),
          P('#FFB81C', (0, 0.12), (0.36, 0.5), (0, 0.88)), P(BLACK, (0, 0.2), (0.29, 0.5), (0, 0.8))),
     {'alt': [('كيب تاون', 'Cape Town'), ('بلومفونتين', 'Bloemfontein')],
      'note': 'Three capitals: Pretoria (executive), Cape Town (legislative), Bloemfontein (judicial).'}),
    ('SS', 'جنوب السودان', 'South Sudan', 'جوبا', 'Juba', 'africa', 'member',
     flag(2, 1, H(BLACK, WHITE, '#DA121A', WHITE, '#078930', w=[6, 1, 6, 1, 6]), P('#0F47AF', (0, 0), (0.43, 0.5), (0, 1)),
          S('#FCDD09', 0.14, 0.5, 0.13, rot=-18)), {}),
    ('SD', 'السودان', 'Sudan', 'الخرطوم', 'Khartoum', 'africa', 'member',
     flag(2, 1, H('#D21034', WHITE, BLACK), P('#007229', (0, 0), (0.3333, 0.5), (0, 1))),
     {'note': 'Khartoum is the constitutional capital; during the war the government has worked from Port Sudan.'}),
    ('TZ', 'تنزانيا', 'Tanzania', 'دودوما', 'Dodoma', 'africa', 'member',
     flag(3, 2, FILL('#00A3DD'), P('#1EB53A', (0, 0), (1, 0), (0, 1)), B('#FCD116', 0, 1, 1, 0, 0.36), B(BLACK, 0, 1, 1, 0, 0.26)),
     {'alt': [('دار السلام', 'Dar es Salaam')], 'note': 'Dodoma is the official capital; Dar es Salaam the largest city.'}),
    ('TG', 'توغو', 'Togo', 'لومي', 'Lomé', 'africa', 'member',
     flag(5, 3, H('#006A4E', '#FFCE00', '#006A4E', '#FFCE00', '#006A4E'), lambda k: [R('#D21034', 0, 0, 0.6 * k, 0.6), S(WHITE, 0.3 * k, 0.3, 0.18)]), {}),
    ('TN', 'تونس', 'Tunisia', 'تونس', 'Tunis', 'africa', 'member',
     flag(3, 2, FILL('#E70013'), C(WHITE, 0.5, 0.5, 0.25), CR('#E70013', 0.5, 0.5, 0.19, 0.05, 0.15), lambda k: S('#E70013', 0.5 + 0.05 * k, 0.5, 0.1, rot=-90)), {}),
    ('UG', 'أوغندا', 'Uganda', 'كمبالا', 'Kampala', 'africa', 'member',
     flag(3, 2, H(BLACK, '#FCDC04', '#D90000', BLACK, '#FCDC04', '#D90000'), C(WHITE, 0.5, 0.5, 0.23), EM('#9CA69C', 0.5, 0.5, 0.17, 'bird')), {}),
    ('ZM', 'زامبيا', 'Zambia', 'لوساكا', 'Lusaka', 'africa', 'member',
     flag(3, 2, FILL('#198A00'), R('#DE2010', 0.75, 0.375, 0.0833, 0.625), R(BLACK, 0.8333, 0.375, 0.0833, 0.625),
          R('#EF7D00', 0.9167, 0.375, 0.0833, 0.625), EM('#EF7D00', 0.875, 0.2, 0.12, 'eagle')), {}),
    ('ZW', 'زيمبابوي', 'Zimbabwe', 'هراري', 'Harare', 'africa', 'member',
     flag(2, 1, H('#006400', '#FFD200', '#D40000', BLACK, '#D40000', '#FFD200', '#006400'), P(BLACK, (0, 0), (0.45, 0.5), (0, 1)),
          P(WHITE, (0, 0.03), (0.42, 0.5), (0, 0.97)), S('#D40000', 0.13, 0.5, 0.17), EM('#FFD200', 0.13, 0.5, 0.1, 'bird')), {}),
    # ================================================================== Asia
    ('AF', 'أفغانستان', 'Afghanistan', 'كابل', 'Kabul', 'asia', 'member',
     flag(3, 2, V(BLACK, '#BE0000', '#007A36'), RING(WHITE, 0.5, 0.5, 0.22, 0.19), EM(WHITE, 0.5, 0.5, 0.12, 'disc')),
     {'review': True, 'note': 'Drawn as the tricolour still used at the United Nations; the authorities in Kabul use a white flag with the shahada.'}),
    ('AM', 'أرمينيا', 'Armenia', 'يريفان', 'Yerevan', 'asia', 'member',
     flag(2, 1, H('#D90012', '#0033A0', '#F2A800')), {}),
    ('AZ', 'أذربيجان', 'Azerbaijan', 'باكو', 'Baku', 'asia', 'member',
     flag(2, 1, H('#00B5E2', '#EF3340', '#509E2F'), CR(WHITE, 0.47, 0.5, 0.15, 0.04, 0.125), lambda k: S(WHITE, 0.47 + 0.14 * k, 0.5, 0.07, n=8, ir=0.5)), {}),
    ('BH', 'البحرين', 'Bahrain', 'المنامة', 'Manama', 'asia', 'member',
     flag(5, 3, FILL('#CE1126'), serrated(WHITE, 0.25, 0.4, 5)), {}),
    ('BD', 'بنغلاديش', 'Bangladesh', 'دكا', 'Dhaka', 'asia', 'member',
     flag(5, 3, FILL('#006A4E'), C('#F42A41', 0.45, 0.5, 0.3333)), {}),
    ('BT', 'بوتان', 'Bhutan', 'تيمفو', 'Thimphu', 'asia', 'member',
     flag(3, 2, FILL('#FF4E12'), P('#FFD520', (0, 0), (1, 0), (0, 1)), B(WHITE, 0.25, 0.72, 0.75, 0.28, 0.14), C(WHITE, 0.72, 0.3, 0.09)), {}),
    ('BN', 'بروناي', 'Brunei', 'بندر سري بكاوان', 'Bandar Seri Begawan', 'asia', 'member',
     flag(2, 1, FILL('#F7E017'), P(WHITE, (0, 0.12), (0, 0.3), (1, 0.88), (1, 0.7)), P(BLACK, (0, 0.3), (0, 0.46), (1, 1.04), (1, 0.88)),
          EM('#CF1126', 0.5, 0.5, 0.25, 'shield')), {}),
    ('KH', 'كمبوديا', 'Cambodia', 'بنوم بنه', 'Phnom Penh', 'asia', 'member',
     flag(3, 2, H('#032EA1', '#E00025', '#032EA1', w=[1, 2, 1]),
          P(WHITE, (0.33, 0.66), (0.33, 0.5), (0.38, 0.45), (0.42, 0.45), (0.44, 0.36), (0.47, 0.36), (0.5, 0.3),
            (0.53, 0.36), (0.56, 0.36), (0.58, 0.45), (0.62, 0.45), (0.67, 0.5), (0.67, 0.66))), {}),
    ('CN', 'الصين', 'China', 'بكين', 'Beijing', 'asia', 'member',
     flag(3, 2, FILL('#EE1C25'), S('#FFFF00', 0.1667, 0.25, 0.15),
          star_toward('#FFFF00', 0.3333, 0.1, 0.05, 0.1667, 0.25), star_toward('#FFFF00', 0.4, 0.2, 0.05, 0.1667, 0.25),
          star_toward('#FFFF00', 0.4, 0.35, 0.05, 0.1667, 0.25), star_toward('#FFFF00', 0.3333, 0.45, 0.05, 0.1667, 0.25)), {}),
    ('CY', 'قبرص', 'Cyprus', 'نيقوسيا', 'Nicosia', 'asia', 'member',
     flag(3, 2, FILL(WHITE), P('#D57800', (0.28, 0.42), (0.36, 0.34), (0.48, 0.35), (0.6, 0.3), (0.73, 0.26), (0.66, 0.36),
                              (0.62, 0.46), (0.5, 0.5), (0.4, 0.5), (0.32, 0.48)),
          arc_band('#4E5B31', 0.5, 0.62, 0.14, 0.03, 20, 160)), {}),
    ('GE', 'جورجيا', 'Georgia', 'تبليسي', 'Tbilisi', 'asia', 'member',
     flag(3, 2, FILL(WHITE), CROSS('#FF0000', 0.5, 0.5, 0.2),
          lambda k: [PLUS('#FF0000', x, y, 0.16, 0.05) for x, y in ((0.25, 0.225), (0.75, 0.225), (0.25, 0.775), (0.75, 0.775))]), {}),
    ('IN', 'الهند', 'India', 'نيودلهي', 'New Delhi', 'asia', 'member',
     flag(3, 2, H('#FF9933', WHITE, '#138808'), WHEEL('#000080', 0.5, 0.5, 0.14, 24, 0.012)), {}),
    ('ID', 'إندونيسيا', 'Indonesia', 'جاكرتا', 'Jakarta', 'asia', 'member',
     flag(3, 2, H('#CE1126', WHITE)),
     {'alt': [('نوسانتارا', 'Nusantara')], 'review': True,
      'note': 'The capital is legally moving to Nusantara; until the presidential decree takes effect Jakarta remains the capital.'}),
    ('IR', 'إيران', 'Iran', 'طهران', 'Tehran', 'asia', 'member',
     flag(7, 4, H('#239F40', WHITE, '#DA0000'), EM('#DA0000', 0.5, 0.5, 0.12, 'disc')), {}),
    ('IQ', 'العراق', 'Iraq', 'بغداد', 'Baghdad', 'asia', 'member',
     flag(3, 2, H('#CE1126', WHITE, BLACK), T('#007A3D', 0.5, 0.5, 0.2, 'الله أكبر')), {}),
    ('IL', 'إسرائيل', 'Israel', 'القدس', 'Jerusalem', 'asia', 'member',
     flag(11, 8, FILL(WHITE), R('#0038B8', 0, 0.1, 1, 0.15), R('#0038B8', 0, 0.75, 1, 0.15),
          lambda k: [P('#0038B8', (0.5, 0.33), (0.5 + 0.147 * k, 0.585), (0.5 - 0.147 * k, 0.585), sw=0.025),
                     P('#0038B8', (0.5, 0.67), (0.5 + 0.147 * k, 0.415), (0.5 - 0.147 * k, 0.415), sw=0.025)]),
     {'disputed': True,
      'note': 'The status of Jerusalem is disputed and not recognised by the UN; most embassies are in Tel Aviv. Excluded from capital questions.'}),
    ('JP', 'اليابان', 'Japan', 'طوكيو', 'Tokyo', 'asia', 'member',
     flag(3, 2, FILL(WHITE), C('#BC002D', 0.5, 0.5, 0.3)), {}),
    ('JO', 'الأردن', 'Jordan', 'عمّان', 'Amman', 'asia', 'member',
     flag(2, 1, H(BLACK, WHITE, '#007A3D'), P('#CE1126', (0, 0), (0.5, 0.5), (0, 1)), S(WHITE, 0.16, 0.5, 0.08, n=7, ir=0.45)), {}),
    ('KZ', 'كازاخستان', 'Kazakhstan', 'أستانا', 'Astana', 'asia', 'member',
     flag(2, 1, FILL('#00AFCA'), SUN('#FEC50C', 0.5, 0.4, 0.2, 32, 0.55), EM('#FEC50C', 0.5, 0.66, 0.13, 'eagle'),
          R('#FEC50C', 0.03, 0, 0.035, 1)), {}),
    ('KW', 'الكويت', 'Kuwait', 'الكويت', 'Kuwait City', 'asia', 'member',
     flag(2, 1, H('#007A3D', WHITE, '#CE1126'), P(BLACK, (0, 0), (0.25, 0.3333), (0.25, 0.6667), (0, 1))), {}),
    ('KG', 'قيرغيزستان', 'Kyrgyzstan', 'بيشكيك', 'Bishkek', 'asia', 'member',
     flag(5, 3, FILL('#E8112D'), SUN('#FFEF00', 0.5, 0.5, 0.32, 40, 0.58), C('#E8112D', 0.5, 0.5, 0.14),
          RING('#FFEF00', 0.5, 0.5, 0.14, 0.11), arc_band('#FFEF00', 0.5, 0.36, 0.14, 0.02, 45, 135),
          arc_band('#FFEF00', 0.5, 0.64, 0.14, 0.02, -135, -45)), {}),
    ('LA', 'لاوس', 'Laos', 'فيينتيان', 'Vientiane', 'asia', 'member',
     flag(3, 2, H('#CE1126', '#002868', '#CE1126', w=[1, 2, 1]), C(WHITE, 0.5, 0.5, 0.2)), {}),
    ('LB', 'لبنان', 'Lebanon', 'بيروت', 'Beirut', 'asia', 'member',
     flag(3, 2, H('#ED1C24', WHITE, '#ED1C24', w=[1, 2, 1]), EM('#00A651', 0.5, 0.5, 0.23, 'tree')), {}),
    ('MY', 'ماليزيا', 'Malaysia', 'كوالالمبور', 'Kuala Lumpur', 'asia', 'member',
     flag(2, 1, stripes(['#CC0001', WHITE], 14), R('#010066', 0, 0, 0.5, 8 / 14), CR('#FFCC00', 0.2, 0.2857, 0.22, 0.05, 0.19),
          S('#FFCC00', 0.32, 0.2857, 0.16, n=14, ir=0.4)),
     {'note': 'Putrajaya is the administrative centre; Kuala Lumpur is the capital.'}),
    ('MV', 'جزر المالديف', 'Maldives', 'ماليه', 'Malé', 'asia', 'member',
     flag(3, 2, FILL('#D21034'), R('#007E3A', 0.1667, 0.25, 0.6667, 0.5), CR(WHITE, 0.5, 0.5, 0.17, 0.05, 0.15)), {}),
    ('MN', 'منغوليا', 'Mongolia', 'أولان باتور', 'Ulaanbaatar', 'asia', 'member',
     flag(2, 1, V('#C4272F', '#015197', '#C4272F'), C('#F9CF02', 0.1667, 0.33, 0.07), P('#F9CF02', (0.14, 0.25), (0.1667, 0.18), (0.193, 0.25)),
          R('#F9CF02', 0.12, 0.45, 0.093, 0.03), C('#F9CF02', 0.1667, 0.58, 0.07), R('#F9CF02', 0.12, 0.7, 0.093, 0.03),
          R('#F9CF02', 0.1, 0.4, 0.015, 0.4), R('#F9CF02', 0.218, 0.4, 0.015, 0.4)), {}),
    ('MM', 'ميانمار', 'Myanmar', 'نايبيداو', 'Naypyidaw', 'asia', 'member',
     flag(3, 2, H('#FECB00', '#34B233', '#EA2839'), S(WHITE, 0.5, 0.55, 0.36)), {}),
    ('NP', 'نيبال', 'Nepal', 'كاتماندو', 'Kathmandu', 'asia', 'member',
     flag(100, 122, P('#003893', (0, 0), (0.96, 0.47), (0.36, 0.47), (1, 1), (0, 1)),
          P('#DC143C', (0.04, 0.05), (0.86, 0.44), (0.28, 0.44), (0.9, 0.965), (0.04, 0.965)),
          CR(WHITE, 0.25, 0.3, 0.1, 0, 0.1, dy=-0.05), S(WHITE, 0.25, 0.33, 0.06, n=16, ir=0.6),
          SUN(WHITE, 0.25, 0.75, 0.12, 12, 0.6)),
     {'note': 'The only non-rectangular national flag.'}),
    ('KP', 'كوريا الشمالية', 'North Korea', 'بيونغ يانغ', 'Pyongyang', 'asia', 'member',
     flag(2, 1, H('#024FA2', WHITE, '#ED1C27', WHITE, '#024FA2', w=[6, 1, 17, 1, 6]), C(WHITE, 0.35, 0.5, 0.24), S('#ED1C27', 0.35, 0.5, 0.23)), {}),
    ('OM', 'عُمان', 'Oman', 'مسقط', 'Muscat', 'asia', 'member',
     flag(2, 1, H(WHITE, '#DB161B', '#008000'), R('#DB161B', 0, 0, 0.25, 1), EM(WHITE, 0.125, 0.18, 0.12, 'shield')), {}),
    ('PK', 'باكستان', 'Pakistan', 'إسلام آباد', 'Islamabad', 'asia', 'member',
     flag(3, 2, FILL('#01411C'), R(WHITE, 0, 0, 0.25, 1), CR(WHITE, 0.625, 0.5, 0.3, 0.08, 0.26, dy=-0.06),
          lambda k: S(WHITE, 0.625 + 0.12 * k, 0.38, 0.1, rot=40)), {}),
    ('PH', 'الفلبين', 'Philippines', 'مانيلا', 'Manila', 'asia', 'member',
     flag(2, 1, H('#0038A8', '#CE1126'), P(WHITE, (0, 0), (0.433, 0.5), (0, 1)), SUN('#FCD116', 0.15, 0.5, 0.16, 8, 0.45),
          S('#FCD116', 0.05, 0.1, 0.05), S('#FCD116', 0.05, 0.9, 0.05), S('#FCD116', 0.37, 0.5, 0.05, rot=90)), {}),
    ('QA', 'قطر', 'Qatar', 'الدوحة', 'Doha', 'asia', 'member',
     flag(28, 11, FILL('#8A1538'), serrated(WHITE, 0.2857, 0.3571, 9)), {}),
    ('SA', 'السعودية', 'Saudi Arabia', 'الرياض', 'Riyadh', 'asia', 'member',
     flag(3, 2, FILL('#006C35'), T(WHITE, 0.5, 0.38, 0.15, 'لا إله إلا الله محمد رسول الله'),
          R(WHITE, 0.25, 0.68, 0.46, 0.035), P(WHITE, (0.71, 0.66), (0.75, 0.6975), (0.71, 0.735)), R(WHITE, 0.26, 0.64, 0.015, 0.11)), {}),
    ('SG', 'سنغافورة', 'Singapore', 'سنغافورة', 'Singapore', 'asia', 'member',
     flag(3, 2, H('#EF3340', WHITE), CR(WHITE, 0.2, 0.25, 0.17, 0.06, 0.16), star_ring(WHITE, 0.25, 0.25, 0.09, 5, 0.035)), {}),
    ('KR', 'كوريا الجنوبية', 'South Korea', 'سول', 'Seoul', 'asia', 'member',
     flag(3, 2, FILL(WHITE), C('#CD2E3A', 0.5, 0.5, 0.25), half_disc('#0047A0', 0.5, 0.5, 0.25, 33.7),
          lambda k: [C('#CD2E3A', 0.5 - 0.104 * k, 0.43, 0.125), C('#0047A0', 0.5 + 0.104 * k, 0.57, 0.125)],
          rot_rect(BLACK, 0.2, 0.22, 0.25, 0.14, -56.3), rot_rect(BLACK, 0.8, 0.22, 0.25, 0.14, 56.3),
          rot_rect(BLACK, 0.2, 0.78, 0.25, 0.14, 56.3), rot_rect(BLACK, 0.8, 0.78, 0.25, 0.14, -56.3)), {}),
    ('LK', 'سريلانكا', 'Sri Lanka', 'سري جاياواردنابورا كوتي', 'Sri Jayawardenepura Kotte', 'asia', 'member',
     flag(2, 1, FILL('#FFBE29'), R('#00534E', 0.03, 0.06, 0.1, 0.88), R('#FF5B00', 0.15, 0.06, 0.1, 0.88),
          R('#8D153A', 0.28, 0.06, 0.69, 0.88), EM('#FFBE29', 0.62, 0.5, 0.3, 'shield')),
     {'alt': [('كولومبو', 'Colombo')], 'note': 'Sri Jayawardenepura Kotte is the legislative capital; Colombo the commercial capital.'}),
    ('SY', 'سوريا', 'Syria', 'دمشق', 'Damascus', 'asia', 'member',
     flag(3, 2, H('#007A3D', WHITE, BLACK), S('#CE1126', 0.3, 0.5, 0.11), S('#CE1126', 0.5, 0.5, 0.11), S('#CE1126', 0.7, 0.5, 0.11)),
     {'note': 'Green-white-black flag with three red stars, adopted officially in 2025.'}),
    ('TJ', 'طاجيكستان', 'Tajikistan', 'دوشنبه', 'Dushanbe', 'asia', 'member',
     flag(2, 1, H('#CC0000', WHITE, '#006600', w=[2, 3, 2]), EM('#F8C300', 0.5, 0.52, 0.09, 'crown'),
          star_arc('#F8C300', 0.5, 0.52, 0.17, 7, 0.028, 200, 340)), {}),
    ('TH', 'تايلاند', 'Thailand', 'بانكوك', 'Bangkok', 'asia', 'member',
     flag(3, 2, H('#A51931', WHITE, '#2D2A4A', WHITE, '#A51931', w=[1, 1, 2, 1, 1])), {}),
    ('TL', 'تيمور الشرقية', 'Timor-Leste', 'ديلي', 'Dili', 'asia', 'member',
     flag(2, 1, FILL('#DC241F'), P('#FFC72C', (0, 0), (0.5, 0.5), (0, 1)), P(BLACK, (0, 0), (0.3333, 0.5), (0, 1)),
          S(WHITE, 0.12, 0.5, 0.14, rot=-30)), {}),
    ('TR', 'تركيا', 'Türkiye', 'أنقرة', 'Ankara', 'asia', 'member',
     flag(3, 2, FILL('#E30A17'), CR(WHITE, 0.3333, 0.5, 0.25, 0.0625, 0.2), lambda k: S(WHITE, 0.3333 + 0.36 * k, 0.5, 0.125, rot=-90)), {}),
    ('TM', 'تركمانستان', 'Turkmenistan', 'عشق آباد', 'Ashgabat', 'asia', 'member',
     flag(3, 2, FILL('#00843D'), R('#D22630', 0.09, 0, 0.16, 1), CR(WHITE, 0.36, 0.2, 0.12, 0.04, 0.11),
          star_ring(WHITE, 0.44, 0.2, 0.08, 5, 0.025)), {}),
    ('AE', 'الإمارات العربية المتحدة', 'United Arab Emirates', 'أبوظبي', 'Abu Dhabi', 'asia', 'member',
     flag(2, 1, H('#00732F', WHITE, BLACK), R('#FF0000', 0, 0, 0.25, 1)), {}),
    ('UZ', 'أوزبكستان', 'Uzbekistan', 'طشقند', 'Tashkent', 'asia', 'member',
     flag(2, 1, H('#0099B5', '#CE1126', WHITE, '#CE1126', '#1EB53A', w=[10, 1, 10, 1, 10]), CR(WHITE, 0.12, 0.16, 0.12, 0.04, 0.11),
          lambda k: [S(WHITE, 0.2 + i * 0.05, 0.08 + j * 0.08, 0.025) for j in range(3) for i in range(5) if i >= 2 - j]), {}),
    ('VN', 'فيتنام', 'Vietnam', 'هانوي', 'Hanoi', 'asia', 'member',
     flag(3, 2, FILL('#DA251D'), S('#FFFF00', 0.5, 0.5, 0.3)), {}),
    ('YE', 'اليمن', 'Yemen', 'صنعاء', "Sana'a", 'asia', 'member',
     flag(3, 2, H('#CE1126', WHITE, BLACK)),
     {'alt': [('عدن', 'Aden')], 'note': "Sana'a is the constitutional capital; the recognised government sits in Aden."}),
    ('PS', 'فلسطين', 'Palestine', 'القدس', 'Jerusalem', 'asia', 'observer',
     flag(2, 1, H(BLACK, WHITE, '#007A3D'), P('#CE1126', (0, 0), (0.3333, 0.5), (0, 1))),
     {'alt': [('رام الله', 'Ramallah')], 'disputed': True,
      'note': 'UN observer state. Declared capital: (East) Jerusalem; administrative centre: Ramallah. Excluded from capital questions.'}),
    # ================================================================ Europe
    ('AL', 'ألبانيا', 'Albania', 'تيرانا', 'Tirana', 'europe', 'member',
     flag(7, 5, FILL('#E41E20'), EM(BLACK, 0.5, 0.5, 0.36, 'eagle')), {}),
    ('AD', 'أندورا', 'Andorra', 'أندورا لا فيلا', 'Andorra la Vella', 'europe', 'member',
     flag(10, 7, V('#10069F', '#FEDD00', '#D50032', w=[8, 9, 8]), EM('#C7A240', 0.5, 0.5, 0.2, 'shield')), {}),
    ('AT', 'النمسا', 'Austria', 'فيينا', 'Vienna', 'europe', 'member',
     flag(3, 2, H('#ED2939', WHITE, '#ED2939')), {}),
    ('BY', 'بيلاروس', 'Belarus', 'مينسك', 'Minsk', 'europe', 'member',
     flag(2, 1, H('#C8313E', '#4AA657', w=[2, 1]), R(WHITE, 0, 0, 0.11, 1),
          lambda k: [P('#C8313E', (0.055, y - 0.06), (0.09, y), (0.055, y + 0.06), (0.02, y)) for y in (0.1, 0.3, 0.5, 0.7, 0.9)]), {}),
    ('BE', 'بلجيكا', 'Belgium', 'بروكسل', 'Brussels', 'europe', 'member',
     flag(15, 13, V(BLACK, '#FDDA24', '#EF3340')), {}),
    ('BA', 'البوسنة والهرسك', 'Bosnia and Herzegovina', 'سراييفو', 'Sarajevo', 'europe', 'member',
     flag(2, 1, FILL('#002395'), P('#FECB00', (0.27, 0), (0.73, 0), (0.73, 1)),
          lambda k: [S(WHITE, 0.22 + i * 0.058, 0.05 + i * 0.11, 0.05) for i in range(9)]), {}),
    ('BG', 'بلغاريا', 'Bulgaria', 'صوفيا', 'Sofia', 'europe', 'member',
     flag(5, 3, H(WHITE, '#00966E', '#D62612')), {}),
    ('HR', 'كرواتيا', 'Croatia', 'زغرب', 'Zagreb', 'europe', 'member',
     flag(2, 1, H('#FF0000', WHITE, '#171796'), R('#FF0000', 0.43, 0.3, 0.14, 0.4),
          lambda k: [R(WHITE, 0.43 + i * 0.028, 0.3 + j * 0.08, 0.028, 0.08) for i in range(5) for j in range(5) if (i + j) % 2 == 1]), {}),
    ('CZ', 'التشيك', 'Czechia', 'براغ', 'Prague', 'europe', 'member',
     flag(3, 2, H(WHITE, '#D7141A'), P('#11457E', (0, 0), (0.5, 0.5), (0, 1))), {}),
    ('DK', 'الدنمارك', 'Denmark', 'كوبنهاغن', 'Copenhagen', 'europe', 'member',
     flag(37, 28, FILL('#C8102E'), CROSS(WHITE, 14 / 37, 0.5, 4 / 28)), {}),
    ('EE', 'إستونيا', 'Estonia', 'تالين', 'Tallinn', 'europe', 'member',
     flag(11, 7, H('#0072CE', BLACK, WHITE)), {}),
    ('FI', 'فنلندا', 'Finland', 'هلسنكي', 'Helsinki', 'europe', 'member',
     flag(18, 11, FILL(WHITE), CROSS('#002F6C', 6.5 / 18, 0.5, 3 / 11)), {}),
    ('FR', 'فرنسا', 'France', 'باريس', 'Paris', 'europe', 'member',
     flag(3, 2, V('#002395', WHITE, '#ED2939')), {}),
    ('DE', 'ألمانيا', 'Germany', 'برلين', 'Berlin', 'europe', 'member',
     flag(5, 3, H(BLACK, '#DD0000', '#FFCE00')), {}),
    ('GR', 'اليونان', 'Greece', 'أثينا', 'Athens', 'europe', 'member',
     flag(3, 2, stripes(['#0D5EAF', WHITE], 9), lambda k: [R('#0D5EAF', 0, 0, 5 / 9 * k, 5 / 9), R(WHITE, 2 / 9 * k, 0, 1 / 9 * k, 5 / 9),
                                                          R(WHITE, 0, 2 / 9, 5 / 9 * k, 1 / 9)]), {}),
    ('HU', 'المجر', 'Hungary', 'بودابست', 'Budapest', 'europe', 'member',
     flag(2, 1, H('#CE2939', WHITE, '#477050')), {}),
    ('IS', 'آيسلندا', 'Iceland', 'ريكيافيك', 'Reykjavík', 'europe', 'member',
     flag(25, 18, FILL('#02529C'), CROSS(WHITE, 9 / 25, 0.5, 4 / 18), CROSS('#DC1E35', 9 / 25, 0.5, 2 / 18)), {}),
    ('IE', 'أيرلندا', 'Ireland', 'دبلن', 'Dublin', 'europe', 'member',
     flag(2, 1, V('#169B62', WHITE, '#FF883E')), {}),
    ('IT', 'إيطاليا', 'Italy', 'روما', 'Rome', 'europe', 'member',
     flag(3, 2, V('#009246', WHITE, '#CE2B37')), {}),
    ('LV', 'لاتفيا', 'Latvia', 'ريغا', 'Riga', 'europe', 'member',
     flag(2, 1, H('#9E3039', WHITE, '#9E3039', w=[2, 1, 2])), {}),
    ('LI', 'ليختنشتاين', 'Liechtenstein', 'فادوز', 'Vaduz', 'europe', 'member',
     flag(5, 3, H('#002B7F', '#CE1126'), EM('#FFD83D', 0.22, 0.25, 0.14, 'crown')), {}),
    ('LT', 'ليتوانيا', 'Lithuania', 'فيلنيوس', 'Vilnius', 'europe', 'member',
     flag(5, 3, H('#FDB913', '#006A44', '#C1272D')), {}),
    ('LU', 'لوكسمبورغ', 'Luxembourg', 'لوكسمبورغ', 'Luxembourg', 'europe', 'member',
     flag(5, 3, H('#EF3340', WHITE, '#00A3E0')), {}),
    ('MT', 'مالطا', 'Malta', 'فاليتا', 'Valletta', 'europe', 'member',
     flag(3, 2, V(WHITE, '#CF142B'), PLUS('#A7A7A7', 0.12, 0.16, 0.18, 0.06)), {}),
    ('MD', 'مولدوفا', 'Moldova', 'كيشيناو', 'Chișinău', 'europe', 'member',
     flag(2, 1, V('#0046AE', '#FFD200', '#CC092F'), EM('#B07E1A', 0.5, 0.5, 0.2, 'eagle')), {}),
    ('MC', 'موناكو', 'Monaco', 'موناكو', 'Monaco', 'europe', 'member',
     flag(5, 4, H('#CE1126', WHITE)), {}),
    ('ME', 'الجبل الأسود', 'Montenegro', 'بودغوريتسا', 'Podgorica', 'europe', 'member',
     flag(2, 1, FILL('#D3AE3B'), R('#C40308', 0.025, 0.05, 0.95, 0.9), EM('#D3AE3B', 0.5, 0.5, 0.3, 'eagle')), {}),
    ('NL', 'هولندا', 'Netherlands', 'أمستردام', 'Amsterdam', 'europe', 'member',
     flag(3, 2, H('#AE1C28', WHITE, '#21468B')),
     {'alt': [('لاهاي', 'The Hague')], 'note': 'Amsterdam is the constitutional capital; the government sits in The Hague.'}),
    ('MK', 'مقدونيا الشمالية', 'North Macedonia', 'سكوبيه', 'Skopje', 'europe', 'member',
     flag(2, 1, FILL('#CE2028'), rays('#F8E92E', 0.5, 0.5, [(0, 0), (0.5, 0), (1, 0), (1, 0.5), (1, 1), (0.5, 1), (0, 1), (0, 0.5)], 0.14),
          C('#CE2028', 0.5, 0.5, 0.17), C('#F8E92E', 0.5, 0.5, 0.14)), {}),
    ('NO', 'النرويج', 'Norway', 'أوسلو', 'Oslo', 'europe', 'member',
     flag(22, 16, FILL('#BA0C2F'), CROSS(WHITE, 8 / 22, 0.5, 4 / 16), CROSS('#00205B', 8 / 22, 0.5, 2 / 16)), {}),
    ('PL', 'بولندا', 'Poland', 'وارسو', 'Warsaw', 'europe', 'member',
     flag(8, 5, H(WHITE, '#DC143C')), {}),
    ('PT', 'البرتغال', 'Portugal', 'لشبونة', 'Lisbon', 'europe', 'member',
     flag(3, 2, V('#046A38', '#DA291C', w=[2, 3]), RING('#FFE900', 0.4, 0.5, 0.25, 0.2), EM(WHITE, 0.4, 0.5, 0.14, 'shield'),
          EM('#DA291C', 0.4, 0.5, 0.11, 'shield')), {}),
    ('RO', 'رومانيا', 'Romania', 'بوخارست', 'Bucharest', 'europe', 'member',
     flag(3, 2, V('#002B7F', '#FCD116', '#CE1126')), {}),
    ('RU', 'روسيا', 'Russia', 'موسكو', 'Moscow', 'europe', 'member',
     flag(3, 2, H(WHITE, '#0039A6', '#D52B1E')), {}),
    ('SM', 'سان مارينو', 'San Marino', 'سان مارينو', 'San Marino', 'europe', 'member',
     flag(4, 3, H(WHITE, '#5EB6E4'), EM('#5EB6E4', 0.5, 0.5, 0.2, 'shield'), EM('#F1BF31', 0.5, 0.32, 0.07, 'crown')), {}),
    ('RS', 'صربيا', 'Serbia', 'بلغراد', 'Belgrade', 'europe', 'member',
     flag(3, 2, H('#C6363C', '#0C4076', WHITE), EM('#C6363C', 0.36, 0.48, 0.24, 'shield'), EM(WHITE, 0.36, 0.48, 0.14, 'eagle')), {}),
    ('SK', 'سلوفاكيا', 'Slovakia', 'براتيسلافا', 'Bratislava', 'europe', 'member',
     flag(3, 2, H(WHITE, '#0B4EA2', '#EE1C25'), EM(WHITE, 0.35, 0.5, 0.27, 'shield'), EM('#EE1C25', 0.35, 0.5, 0.24, 'shield'),
          PLUS(WHITE, 0.35, 0.44, 0.22, 0.04), PLUS(WHITE, 0.35, 0.5, 0.16, 0.04)), {}),
    ('SI', 'سلوفينيا', 'Slovenia', 'ليوبليانا', 'Ljubljana', 'europe', 'member',
     flag(2, 1, H(WHITE, '#0000FF', '#FF0000'), EM('#FF0000', 0.27, 0.33, 0.17, 'shield'), EM('#0000FF', 0.27, 0.33, 0.15, 'shield'),
          P(WHITE, (0.23, 0.4), (0.27, 0.3), (0.31, 0.4))), {}),
    ('ES', 'إسبانيا', 'Spain', 'مدريد', 'Madrid', 'europe', 'member',
     flag(3, 2, H('#AA151B', '#F1BF00', '#AA151B', w=[1, 2, 1]), EM('#AA151B', 0.3, 0.5, 0.18, 'shield'), EM('#F1BF00', 0.3, 0.35, 0.06, 'crown')), {}),
    ('SE', 'السويد', 'Sweden', 'ستوكهولم', 'Stockholm', 'europe', 'member',
     flag(8, 5, FILL('#006AA7'), CROSS('#FECC02', 6 / 16, 0.5, 0.2)), {}),
    ('CH', 'سويسرا', 'Switzerland', 'برن', 'Bern', 'europe', 'member',
     flag(1, 1, FILL('#DA291C'), PLUS(WHITE, 0.5, 0.5, 0.625, 0.1875)),
     {'note': 'Bern is the federal city (seat of the federal authorities).'}),
    ('UA', 'أوكرانيا', 'Ukraine', 'كييف', 'Kyiv', 'europe', 'member',
     flag(3, 2, H('#0057B7', '#FFD700')), {}),
    ('GB', 'المملكة المتحدة', 'United Kingdom', 'لندن', 'London', 'europe', 'member',
     flag(2, 1, UJ()), {}),
    ('VA', 'الفاتيكان', 'Vatican City', 'مدينة الفاتيكان', 'Vatican City', 'europe', 'observer',
     flag(1, 1, V('#FFE000', WHITE), B('#F1BF00', 0.62, 0.35, 0.88, 0.7, 0.05), B('#C8C8C8', 0.88, 0.35, 0.62, 0.7, 0.05),
          EM('#F1BF00', 0.75, 0.3, 0.08, 'crown')),
     {'note': 'UN observer (the Holy See).'}),
    # ======================================================== North America
    ('AG', 'أنتيغوا وباربودا', 'Antigua and Barbuda', 'سانت جونز', "St. John's", 'north_america', 'member',
     flag(3, 2, FILL('#CE1126'), tri_band(WHITE, 0.5, 0, 1), tri_band(BLACK, 0.5, 0, 0.45), SUN('#FCD116', 0.5, 0.45, 0.2, 16, 0.5),
          tri_band('#0072C6', 0.5, 0.45, 0.66)), {}),
    ('BS', 'جزر البهاما', 'Bahamas', 'ناساو', 'Nassau', 'north_america', 'member',
     flag(2, 1, H('#00778B', '#FFC72C', '#00778B'), P(BLACK, (0, 0), (0.433, 0.5), (0, 1))), {}),
    ('BB', 'باربادوس', 'Barbados', 'بريدجتاون', 'Bridgetown', 'north_america', 'member',
     flag(3, 2, V('#00267F', '#FFC726', '#00267F'), trident(BLACK, 0.5, 0.5, 0.4)), {}),
    ('BZ', 'بليز', 'Belize', 'بلموبان', 'Belmopan', 'north_america', 'member',
     flag(5, 3, H('#CE1126', '#003F87', '#CE1126', w=[1, 8, 1]), C(WHITE, 0.5, 0.5, 0.33), RING('#1E7B34', 0.5, 0.5, 0.3, 0.26),
          EM('#6B4F2B', 0.5, 0.5, 0.16, 'shield')), {}),
    ('CA', 'كندا', 'Canada', 'أوتاوا', 'Ottawa', 'north_america', 'member',
     flag(2, 1, V('#FF0000', WHITE, '#FF0000', w=[1, 2, 1]), maple_leaf('#FF0000', 0.5, 0.52, 0.42)), {}),
    ('CR', 'كوستاريكا', 'Costa Rica', 'سان خوسيه', 'San José', 'north_america', 'member',
     flag(5, 3, H('#002B7F', WHITE, '#CE1126', WHITE, '#002B7F', w=[1, 1, 2, 1, 1]), EM(WHITE, 0.3, 0.5, 0.12, 'oval')), {}),
    ('CU', 'كوبا', 'Cuba', 'هافانا', 'Havana', 'north_america', 'member',
     flag(2, 1, H('#002A8F', WHITE, '#002A8F', WHITE, '#002A8F'), P('#CF142B', (0, 0), (0.433, 0.5), (0, 1)), S(WHITE, 0.144, 0.5, 0.14)), {}),
    ('DM', 'دومينيكا', 'Dominica', 'روزو', 'Roseau', 'north_america', 'member',
     flag(2, 1, FILL('#006B3F'), CROSS('#FCD116', 0.47, 0.44, 0.07), CROSS(BLACK, 0.5, 0.5, 0.07), CROSS(WHITE, 0.53, 0.56, 0.07),
          C('#D41C30', 0.5, 0.5, 0.25), EM('#9461C9', 0.5, 0.5, 0.12, 'bird'), star_ring('#006B3F', 0.5, 0.5, 0.2, 10, 0.03)), {}),
    ('DO', 'جمهورية الدومينيكان', 'Dominican Republic', 'سانتو دومينغو', 'Santo Domingo', 'north_america', 'member',
     flag(8, 5, FILL(WHITE), R('#002D62', 0, 0, 0.44, 0.42), R('#CE1126', 0.56, 0, 0.44, 0.42), R('#CE1126', 0, 0.58, 0.44, 0.42),
          R('#002D62', 0.56, 0.58, 0.44, 0.42), EM('#008A3E', 0.5, 0.5, 0.1, 'shield')), {}),
    ('SV', 'السلفادور', 'El Salvador', 'سان سلفادور', 'San Salvador', 'north_america', 'member',
     flag(16, 9, H('#0047AB', WHITE, '#0047AB'), EM('#D4AF37', 0.5, 0.5, 0.13, 'disc')), {}),
    ('GD', 'غرينادا', 'Grenada', 'سانت جورجز', "St. George's", 'north_america', 'member',
     flag(5, 3, FILL('#CE1126'), P('#FCD116', (0.083, 0.14), (0.917, 0.14), (0.5, 0.5)), P('#FCD116', (0.083, 0.86), (0.917, 0.86), (0.5, 0.5)),
          P('#007A5E', (0.083, 0.14), (0.5, 0.5), (0.083, 0.86)), P('#007A5E', (0.917, 0.14), (0.5, 0.5), (0.917, 0.86)),
          C('#CE1126', 0.5, 0.5, 0.12), S('#FCD116', 0.5, 0.5, 0.09),
          lambda k: [S('#FCD116', x, y, 0.05) for x in (0.3, 0.5, 0.7) for y in (0.07, 0.93)], EM('#FCD116', 0.2, 0.5, 0.06, 'oval')), {}),
    ('GT', 'غواتيمالا', 'Guatemala', 'غواتيمالا', 'Guatemala City', 'north_america', 'member',
     flag(8, 5, V('#4997D0', WHITE, '#4997D0'), RING('#3A7728', 0.5, 0.5, 0.18, 0.15), EM('#3A7728', 0.5, 0.5, 0.1, 'bird')), {}),
    ('HT', 'هايتي', 'Haiti', 'بورت أو برنس', 'Port-au-Prince', 'north_america', 'member',
     flag(5, 3, H('#00209F', '#D21034'), R(WHITE, 0.35, 0.3, 0.3, 0.4), EM('#016A16', 0.5, 0.5, 0.14, 'tree')), {}),
    ('HN', 'هندوراس', 'Honduras', 'تيغوسيغالبا', 'Tegucigalpa', 'north_america', 'member',
     flag(2, 1, H('#00BCE4', WHITE, '#00BCE4'),
          lambda k: [S('#00BCE4', 0.5 + dx * k, 0.5 + dy, 0.045) for dx, dy in ((0, 0), (-0.2, -0.08), (-0.2, 0.08), (0.2, -0.08), (0.2, 0.08))]), {}),
    ('JM', 'جامايكا', 'Jamaica', 'كينغستون', 'Kingston', 'north_america', 'member',
     flag(2, 1, P('#009B3A', (0, 0), (1, 0), (0.5, 0.5)), P('#009B3A', (0, 1), (1, 1), (0.5, 0.5)),
          P(BLACK, (0, 0), (0.5, 0.5), (0, 1)), P(BLACK, (1, 0), (0.5, 0.5), (1, 1)), SALTIRE('#FFB81C', 0.13)), {}),
    ('MX', 'المكسيك', 'Mexico', 'مكسيكو سيتي', 'Mexico City', 'north_america', 'member',
     flag(7, 4, V('#006847', WHITE, '#CE1126'), EM('#8C6E3F', 0.5, 0.5, 0.17, 'eagle')), {}),
    ('NI', 'نيكاراغوا', 'Nicaragua', 'ماناغوا', 'Managua', 'north_america', 'member',
     flag(5, 3, H('#0067C6', WHITE, '#0067C6'), RING('#C8A200', 0.5, 0.5, 0.12, 0.1), P('#0067C6', (0.5, 0.41), (0.56, 0.54), (0.44, 0.54))), {}),
    ('PA', 'بنما', 'Panama', 'بنما', 'Panama City', 'north_america', 'member',
     flag(3, 2, FILL(WHITE), R('#DA121A', 0.5, 0, 0.5, 0.5), R('#072357', 0, 0.5, 0.5, 0.5), S('#072357', 0.25, 0.25, 0.1), S('#DA121A', 0.75, 0.75, 0.1)), {}),
    ('KN', 'سانت كيتس ونيفيس', 'Saint Kitts and Nevis', 'باستير', 'Basseterre', 'north_america', 'member',
     flag(3, 2, FILL('#CE1126'), P('#009E49', (0, 0), (1, 0), (0, 1)), B('#FCD116', 0, 1, 1, 0, 0.36), B(BLACK, 0, 1, 1, 0, 0.26),
          lambda k: [S(WHITE, 0.36, 0.64, 0.08, rot=-34), S(WHITE, 0.64, 0.36, 0.08, rot=-34)]), {}),
    ('LC', 'سانت لوسيا', 'Saint Lucia', 'كاستريس', 'Castries', 'north_america', 'member',
     flag(2, 1, FILL('#66CCFF'), P(WHITE, (0.5, 0.1), (0.79, 0.9), (0.21, 0.9)), P(BLACK, (0.5, 0.19), (0.74, 0.9), (0.26, 0.9)),
          P('#FCD116', (0.5, 0.5), (0.79, 0.9), (0.21, 0.9))), {}),
    ('VC', 'سانت فينسنت والغرينادين', 'Saint Vincent and the Grenadines', 'كينغزتاون', 'Kingstown', 'north_america', 'member',
     flag(3, 2, V('#002674', '#FCD116', '#009E60', w=[1, 2, 1]),
          lambda k: [P('#009E60', (x, y - 0.12), (x + 0.06 * k, y), (x, y + 0.12), (x - 0.06 * k, y)) for x, y in ((0.4, 0.34), (0.6, 0.34), (0.5, 0.6))]), {}),
    ('TT', 'ترينيداد وتوباغو', 'Trinidad and Tobago', 'بورت أوف سبين', 'Port of Spain', 'north_america', 'member',
     flag(5, 3, FILL('#DA1A35'), B(WHITE, 0, 0, 1, 1, 0.42), B(BLACK, 0, 0, 1, 1, 0.3)), {}),
    ('US', 'الولايات المتحدة', 'United States', 'واشنطن', 'Washington, D.C.', 'north_america', 'member',
     flag(19, 10, stripes(['#B22234', WHITE], 13), lambda k: R('#3C3B6E', 0, 0, 0.76 * k, 7 / 13), stars_grid_us(WHITE)), {}),
    # ======================================================== South America
    ('AR', 'الأرجنتين', 'Argentina', 'بوينس آيرس', 'Buenos Aires', 'south_america', 'member',
     flag(8, 5, H('#74ACDF', WHITE, '#74ACDF'), SUN('#F6B40E', 0.5, 0.5, 0.14, 32, 0.55)), {}),
    ('BO', 'بوليفيا', 'Bolivia', 'سوكري', 'Sucre', 'south_america', 'member',
     flag(22, 15, H('#D52B1E', '#F9E300', '#007934')),
     {'alt': [('لاباز', 'La Paz')], 'note': 'Sucre is the constitutional capital; La Paz is the seat of government.'}),
    ('BR', 'البرازيل', 'Brazil', 'برازيليا', 'Brasília', 'south_america', 'member',
     flag(10, 7, FILL('#009C3B'), P('#FFDF00', (0.085, 0.5), (0.5, 0.12), (0.915, 0.5), (0.5, 0.88)), C('#002776', 0.5, 0.5, 0.25),
          arc_band(WHITE, 0.42, 0.9, 0.5, 0.035, -78, -40),
          lambda k: [S(WHITE, 0.5 + dx * k, 0.5 + dy, 0.018) for dx, dy in ((-0.1, 0.08), (0.02, 0.12), (0.1, 0.06), (0.06, 0.16), (-0.04, 0.17), (0.14, 0.12), (-0.14, 0.02), (0.0, 0.03))]), {}),
    ('CL', 'تشيلي', 'Chile', 'سانتياغو', 'Santiago', 'south_america', 'member',
     flag(3, 2, H(WHITE, '#D52B1E'), lambda k: [R('#0039A6', 0, 0, 0.5 * k, 0.5), S(WHITE, 0.25 * k, 0.25, 0.1)]), {}),
    ('CO', 'كولومبيا', 'Colombia', 'بوغوتا', 'Bogotá', 'south_america', 'member',
     flag(3, 2, H('#FCD116', '#003893', '#CE1126', w=[2, 1, 1])), {}),
    ('EC', 'الإكوادور', 'Ecuador', 'كيتو', 'Quito', 'south_america', 'member',
     flag(2, 1, H('#FFDD00', '#034EA2', '#ED1C24', w=[2, 1, 1]), EM('#6B8E23', 0.5, 0.5, 0.17, 'oval'), EM('#8C6E3F', 0.5, 0.34, 0.07, 'eagle')), {}),
    ('GY', 'غيانا', 'Guyana', 'جورجتاون', 'Georgetown', 'south_america', 'member',
     flag(5, 3, FILL('#009E49'), P(WHITE, (0, 0), (1, 0.5), (0, 1)), P('#FCD116', (0, 0.04), (0.96, 0.5), (0, 0.96)),
          P(BLACK, (0, 0), (0.5, 0.5), (0, 1)), P('#CE1126', (0, 0.05), (0.46, 0.5), (0, 0.95))), {}),
    ('PY', 'باراغواي', 'Paraguay', 'أسونسيون', 'Asunción', 'south_america', 'member',
     flag(5, 3, H('#D52B1E', WHITE, '#0038A8'), RING('#4E8C2B', 0.5, 0.5, 0.12, 0.1), S('#FEDF00', 0.5, 0.5, 0.05)), {}),
    ('PE', 'بيرو', 'Peru', 'ليما', 'Lima', 'south_america', 'member',
     flag(3, 2, V('#D91023', WHITE, '#D91023')), {}),
    ('SR', 'سورينام', 'Suriname', 'باراماريبو', 'Paramaribo', 'south_america', 'member',
     flag(3, 2, H('#377E3F', WHITE, '#B40A2D', WHITE, '#377E3F', w=[2, 1, 4, 1, 2]), S('#ECC81D', 0.5, 0.5, 0.2)), {}),
    ('UY', 'الأوروغواي', 'Uruguay', 'مونتيفيديو', 'Montevideo', 'south_america', 'member',
     flag(3, 2, stripes([WHITE, '#0038A8'], 9), lambda k: [R(WHITE, 0, 0, 5 / 9 * k, 5 / 9), SUN('#FCD116', 2.5 / 9 * k, 2.5 / 9, 0.2, 16, 0.5)]), {}),
    ('VE', 'فنزويلا', 'Venezuela', 'كاراكاس', 'Caracas', 'south_america', 'member',
     flag(3, 2, H('#FFCC00', '#00247D', '#CF142B'), star_arc(WHITE, 0.5, 0.7, 0.3, 8, 0.035, 200, 340)), {}),
    # =============================================================== Oceania
    ('AU', 'أستراليا', 'Australia', 'كانبرا', 'Canberra', 'oceania', 'member',
     flag(2, 1, FILL('#012169'), UJ(0, 0, 0.5, 0.5), S(WHITE, 0.25, 0.75, 0.15, n=7, ir=0.47),
          S(WHITE, 0.75, 0.8333, 0.07, n=7, ir=0.47), S(WHITE, 0.6333, 0.4208, 0.07, n=7, ir=0.47),
          S(WHITE, 0.75, 0.1667, 0.07, n=7, ir=0.47), S(WHITE, 0.8653, 0.3708, 0.07, n=7, ir=0.47), S(WHITE, 0.8, 0.5292, 0.04)), {}),
    ('FJ', 'فيجي', 'Fiji', 'سوفا', 'Suva', 'oceania', 'member',
     flag(2, 1, FILL('#68BFE5'), UJ(0, 0, 0.5, 0.5), EM(WHITE, 0.75, 0.5, 0.28, 'shield'), EM('#CE1126', 0.75, 0.36, 0.08, 'disc')), {}),
    ('KI', 'كيريباتي', 'Kiribati', 'تاراوا الجنوبية', 'South Tarawa', 'oceania', 'member',
     flag(2, 1, H('#CE1126', '#003F87'), SUN('#FCD116', 0.5, 0.55, 0.24, 17, 0.5), R('#003F87', 0, 0.55, 1, 0.45),
          R(WHITE, 0, 0.63, 1, 0.06), R(WHITE, 0, 0.76, 1, 0.06), R(WHITE, 0, 0.89, 1, 0.06), EM('#FCD116', 0.5, 0.22, 0.12, 'bird')), {}),
    ('MH', 'جزر مارشال', 'Marshall Islands', 'ماجورو', 'Majuro', 'oceania', 'member',
     flag(19, 10, FILL('#003893'), P(WHITE, (0, 1), (1, 0), (1, 0.12)), P('#DD7500', (0, 1), (1, 0.12), (1, 0.24)),
          S(WHITE, 0.2, 0.3, 0.2, n=24, ir=0.45)), {}),
    ('FM', 'ميكرونيسيا', 'Micronesia', 'باليكير', 'Palikir', 'oceania', 'member',
     flag(19, 10, FILL('#75B2DD'), lambda k: [S(WHITE, 0.5 + dx * k, 0.5 + dy, 0.08) for dx, dy in ((0, -0.25), (0.25, 0), (0, 0.25), (-0.25, 0))]), {}),
    ('NR', 'ناورو', 'Nauru', 'يارين', 'Yaren', 'oceania', 'member',
     flag(2, 1, FILL('#002B7F'), R('#FFC61E', 0, 0.46, 1, 0.08), S(WHITE, 0.25, 0.73, 0.12, n=12, ir=0.5)),
     {'note': 'Nauru has no official capital; government offices are in Yaren District.'}),
    ('NZ', 'نيوزيلندا', 'New Zealand', 'ويلينغتون', 'Wellington', 'oceania', 'member',
     flag(2, 1, FILL('#00247D'), UJ(0, 0, 0.5, 0.5),
          lambda k: [S(WHITE, x, y, r + 0.012) for x, y, r in ((0.75, 0.2167, 0.06), (0.6667, 0.4333, 0.06), (0.8333, 0.4, 0.05), (0.75, 0.8, 0.07))],
          lambda k: [S('#CC142B', x, y, r) for x, y, r in ((0.75, 0.2167, 0.06), (0.6667, 0.4333, 0.06), (0.8333, 0.4, 0.05), (0.75, 0.8, 0.07))]), {}),
    ('PW', 'بالاو', 'Palau', 'نغيرولمود', 'Ngerulmud', 'oceania', 'member',
     flag(8, 5, FILL('#0099FF'), C('#FFDE00', 0.45, 0.5, 0.3)), {}),
    ('PG', 'بابوا غينيا الجديدة', 'Papua New Guinea', 'بورت مورسبي', 'Port Moresby', 'oceania', 'member',
     flag(4, 3, FILL('#CE1126'), P(BLACK, (0, 0), (1, 1), (0, 1)), EM('#FCD116', 0.68, 0.3, 0.16, 'bird'),
          lambda k: [S(WHITE, x, y, r) for x, y, r in ((0.25, 0.4, 0.05), (0.18, 0.62, 0.05), (0.32, 0.6, 0.05), (0.25, 0.85, 0.05), (0.28, 0.7, 0.03))]), {}),
    ('WS', 'ساموا', 'Samoa', 'آبيا', 'Apia', 'oceania', 'member',
     flag(2, 1, FILL('#CE1126'), R('#002B7F', 0, 0, 0.5, 0.5),
          lambda k: [S(WHITE, x, y, r) for x, y, r in ((0.25, 0.08, 0.05), (0.15, 0.24, 0.05), (0.33, 0.21, 0.05), (0.25, 0.4, 0.06), (0.29, 0.29, 0.03))]), {}),
    ('SB', 'جزر سليمان', 'Solomon Islands', 'هونيارا', 'Honiara', 'oceania', 'member',
     flag(2, 1, FILL('#215B33'), P('#0051BA', (0, 0), (1, 0), (0, 1)), B('#FCD116', 0, 1, 1, 0, 0.1),
          lambda k: [S(WHITE, x, y, 0.06) for x, y in ((0.08, 0.12), (0.26, 0.12), (0.08, 0.38), (0.26, 0.38), (0.17, 0.25))]), {}),
    ('TO', 'تونغا', 'Tonga', 'نوكوالوفا', "Nuku'alofa", 'oceania', 'member',
     flag(2, 1, FILL('#C10000'), R(WHITE, 0, 0, 0.4, 0.5), PLUS('#C10000', 0.2, 0.25, 0.36, 0.1)), {}),
    ('TV', 'توفالو', 'Tuvalu', 'فونافوتي', 'Funafuti', 'oceania', 'member',
     flag(2, 1, FILL('#009FCA'), UJ(0, 0, 0.5, 0.5),
          lambda k: [S('#FFCE00', x, y, 0.045) for x, y in ((0.55, 0.75), (0.62, 0.9), (0.66, 0.6), (0.72, 0.8), (0.78, 0.55), (0.8, 0.35),
                                                           (0.88, 0.5), (0.9, 0.15), (0.94, 0.3))]), {}),
    ('VU', 'فانواتو', 'Vanuatu', 'بورت فيلا', 'Port Vila', 'oceania', 'member',
     flag(5, 3, H('#D21034', '#009543'), P(BLACK, (0, 0), (0.42, 0.5), (0, 1)), R(BLACK, 0.3, 0.42, 0.7, 0.16),
          B('#FDCE12', 0, 0.02, 0.43, 0.5, 0.05), B('#FDCE12', 0, 0.98, 0.43, 0.5, 0.05), R('#FDCE12', 0.42, 0.475, 0.58, 0.05),
          RING('#FDCE12', 0.14, 0.5, 0.11, 0.08)), {}),
]
