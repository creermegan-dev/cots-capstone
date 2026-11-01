import pickle, json, csv, math, numpy as np
from collections import defaultdict
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt

D = pickle.load(open('final/global.pkl', 'rb'))
G = D['GLOBAL']; P = D['partrows']; grid = D['grid']
lat0, lon0, kx, ky, res = grid['lat0'], grid['lon0'], grid['kx'], grid['ky'], grid['res']

def to_ll(ix, iy):
    return (round(ix * res / kx + lon0, 6), round(iy * res / ky + lat0, 6))

# ---- 1. parts table with stable ids -------------------------------------------------
zone_of = {}
for r in D['rows']:
    zone_of[r['Area code']] = r
# drop parts that lost every cell to a neighbouring zone, then renumber parts inside each area
cnt = defaultdict(int)
for p in G.values():
    cnt[p] += 1
keep = [i for i in range(len(P)) if cnt[i] > 0]
dropped = [P[i][0] for i in range(len(P)) if cnt[i] == 0]
remap = {old: new for new, old in enumerate(keep)}
G = {k: remap[v] for k, v in G.items()}
newP = []; seen = defaultdict(int)
for i in keep:
    code, area, brgy, reef, water, gridsq, centre = P[i]
    if '-' in code:
        seen[area] += 1; code = f"{area}-{seen[area]}"
    newP.append((code, area, brgy, reef, water, gridsq, centre))
P = newP
print('dropped empty parts:', dropped)
parts = []
for i, (code, area, brgy, reef, water, gridsq, centre) in enumerate(P):
    a = zone_of[area]
    part_no = int(code.split('-')[1]) if '-' in code else 0
    lat, lon = [float(x) for x in centre.split(',')]
    parts.append(dict(idx=i, code=code, zone=a['Zone'], town=a['Town / city'], area_code=area,
                      barangay=brgy, psgc=a['Barangay PSGC'], part_no=part_no,
                      name=(f"{code} · {brgy} Part {part_no}" if part_no else f"{code} · {brgy}"),
                      reef_ha=reef, water_ha=water, grid_square=gridsq, lat=lat, lon=lon))

# ---- 2. lookup as runs along each grid row ----------------------------------------
cells = sorted(G.items())
runs = []
for (iy, ix), p in cells:
    if runs and runs[-1][0] == iy and runs[-1][2] == ix - 1 and runs[-1][3] == p:
        runs[-1][2] = ix
    else:
        runs.append([iy, ix, ix, p])
# check: decoding the runs gives back every cell
dec = {}
for iy, a, b, p in runs:
    for ix in range(a, b + 1):
        dec[(iy, ix)] = p
assert dec == G, 'run table does not match the cells'
cells_per_part = defaultdict(int)
for p in G.values():
    cells_per_part[p] += 1
missing = [parts[i]['code'] for i in range(len(parts)) if cells_per_part[i] == 0]

# ---- 3. outlines (simplified) per part and per area --------------------------------
def rdp(pts, eps):
    if len(pts) < 3:
        return pts
    a, b = pts[0], pts[-1]
    ab = b - a; n = np.hypot(*ab)
    q = pts - a
    d = np.abs(ab[0] * q[:, 1] - ab[1] * q[:, 0]) / n if n > 0 else np.hypot(q[:, 0], q[:, 1])
    i = int(np.argmax(d))
    if d[i] > eps and 0 < i < len(pts) - 1:
        return np.vstack([rdp(pts[:i + 1], eps)[:-1], rdp(pts[i:], eps)])
    return np.vstack([a, b])

def outline(cellset, eps=0.6):
    ys = np.array([c[0] for c in cellset]); xs = np.array([c[1] for c in cellset])
    y0, x0 = ys.min() - 2, xs.min() - 2
    m = np.zeros((ys.max() - y0 + 3, xs.max() - x0 + 3))
    m[ys - y0, xs - x0] = 1
    fig = plt.figure(); cs = plt.contour(m, levels=[0.5]); segs = cs.allsegs[0]; plt.close(fig)
    polys = []
    for s in segs:
        if len(s) < 4:
            continue
        if np.allclose(s[0], s[-1]):
            k = len(s) // 2; s = np.vstack([rdp(s[:k + 1], eps)[:-1], rdp(s[k:], eps)])
        else:
            s = rdp(s, eps)
        if len(s) < 4:
            continue
        polys.append([list(to_ll(x + x0, y + y0)) for x, y in s])
    return polys

by_part = defaultdict(list)
for k, p in G.items():
    by_part[p].append(k)
part_feats = []
for i, pt in enumerate(parts):
    polys = outline(by_part[i]) if by_part[i] else []
    part_feats.append({'type': 'Feature', 'properties': {'code': pt['code'], 'area': pt['area_code'], 'zone': pt['zone']},
                       'geometry': {'type': 'MultiPolygon', 'coordinates': [[p] for p in polys]}})
by_area = defaultdict(list)
for i, pt in enumerate(parts):
    by_area[pt['area_code']].extend(by_part[i])
area_feats = []
for code, cl in by_area.items():
    pt = next(p for p in parts if p['area_code'] == code)
    area_feats.append({'type': 'Feature', 'properties': {'code': code, 'barangay': pt['barangay'], 'zone': pt['zone'], 'town': pt['town']},
                       'geometry': {'type': 'MultiPolygon', 'coordinates': [[p] for p in outline(cl, eps=1.0)]}})

# ---- write --------------------------------------------------------------------------
with open('final/parts_final.csv', 'w', newline='', encoding='utf-8-sig') as f:
    w = csv.DictWriter(f, fieldnames=list(parts[0].keys())); w.writeheader(); w.writerows(parts)
with open('final/area_lookup_runs.csv', 'w', newline='') as f:
    w = csv.writer(f); w.writerow(['iy', 'ix_start', 'ix_end', 'part_idx']); w.writerows(runs)
json.dump({'type': 'FeatureCollection', 'features': part_feats}, open('final/parts_outlines.geojson', 'w'), separators=(',', ':'))
json.dump({'type': 'FeatureCollection', 'features': area_feats}, open('final/areas_outlines.geojson', 'w'), separators=(',', ':'))
spec = {
    'version': 'cots-davao-gulf-v2',
    'grid': {'formula': 'x = (lon - 125.7) * kx; y = (lat - 6.6) * ky; ix = round(x / 30); iy = round(y / 30)',
             'lat0': lat0, 'lon0': lon0, 'kx': kx, 'ky': ky, 'cell_m': res},
    'allowance_m': 15, 'margin_m': 50, 'part_reef_ha': 1.1,
    'counts': {'zones': len({p['zone'] for p in parts}), 'areas': len(by_area), 'parts': len(parts),
               'cells': len(G), 'runs': len(runs), 'parts_without_cells': len(missing)},
    'sources': ['Allen Coral Atlas (2020) geomorphic map, CC BY 4.0, doi.org/10.5281/zenodo.3833242',
                'Barangay boundaries: NAMRIA/PSA via OCHA COD-AB (faeldon/philippines-json-maps, PSGC 3Q 2026)',
                'Part size: Chandler et al. (2023) Sci Rep 13:19306'],
}
json.dump(spec, open('final/spec.json', 'w'), indent=1)
print(json.dumps(spec['counts']), 'missing:', missing[:10])
