"""Stage 9: export the 3 Samal sites (app map files, lookup runs, outlines, migration rows).

Input: final site masks on the Allen Coral Atlas bathymetry grid (10 m pixels, WGS84).
Output (folder out/): assets/map/{parts,areas,part_outlines}.json + lookup.bin (same format as Stage 6),
zone_maps/samal_sites/{spec.json, samal_sites.geojson, site_lookup_runs.csv}, and sites_rows.sql.
The 30 m lookup grid is the same one the database and app already use:
  x = (lon - 125.7) * kx; y = (lat - 6.6) * ky; ix = round(x / 30); iy = round(y / 30).
A 30 m cell belongs to a site when at least half of its 10 m pixels are in the site.
"""
import json, os, struct, numpy as np
from collections import defaultdict
import matplotlib; matplotlib.use('Agg'); import matplotlib.pyplot as plt

LON0, LAT0, D = 125.64592148534287, 7.203051274183968, 8.983152841195215e-05
GLAT0, GLON0, KX, KY, CELL = 6.6, 125.7, 110582.25626663613, 110574.0, 30.0
VERSION = 'cots-samal-sites-v1'
SITES = [  # code, number, barangay, PSGC, mask file
    ('S1', 1, 'Tambo', '1102317045', 'final_site1.npy'),
    ('S2', 2, 'Adecor', '1102317001', 'final2_site2.npy'),
    ('S3', 3, 'Linosutan', '1102317022', 'final_site3.npy'),
]
TOWN = 'Island Garden City of Samal'
os.makedirs('out', exist_ok=True)

masks = [np.load(s[4]) for s in SITES]
ny, nx = masks[0].shape
plat = LAT0 - (np.arange(ny) + 0.5) * D
plon = LON0 + (np.arange(nx) + 0.5) * D
assert not (masks[0] & masks[1]).any() and not (masks[1] & masks[2]).any() and not (masks[0] & masks[2]).any()

# ---- 30 m cells ------------------------------------------------------------------
cells = {}
for si, m in enumerate(masks):
    ys, xs = np.where(m)
    iy = np.round((plat[ys] - GLAT0) * KY / CELL).astype(int)
    ix = np.round((plon[xs] - GLON0) * KX / CELL).astype(int)
    inside = defaultdict(int)
    for k in zip(iy.tolist(), ix.tolist()):
        inside[k] += 1
    # pixels per cell over all pixels (site or not) in the same bounding box
    y0, y1, x0, x1 = ys.min() - 5, ys.max() + 6, xs.min() - 5, xs.max() + 6
    gy, gx = np.meshgrid(np.arange(y0, y1), np.arange(x0, x1), indexing='ij')
    aiy = np.round((plat[gy.ravel()] - GLAT0) * KY / CELL).astype(int)
    aix = np.round((plon[gx.ravel()] - GLON0) * KX / CELL).astype(int)
    total = defaultdict(int)
    for k in zip(aiy.tolist(), aix.tolist()):
        total[k] += 1
    for k, n in inside.items():
        if 2 * n >= total[k]:
            assert k not in cells
            cells[k] = si

runs = []
for (iy, ix), p in sorted(cells.items()):
    if runs and runs[-1][0] == iy and runs[-1][2] == ix - 1 and runs[-1][3] == p:
        runs[-1][2] = ix
    else:
        runs.append([iy, ix, ix, p])
dec = {}
for iy, a, b, p in runs:
    for ix in range(a, b + 1):
        dec[(iy, ix)] = p
assert dec == cells

# ---- outlines from the 10 m masks (simplified) -------------------------------------
def rdp(pts, eps):
    if len(pts) < 3:
        return pts
    a, b = pts[0], pts[-1]
    ab = b - a; n = np.hypot(*ab); q = pts - a
    d = np.abs(ab[0] * q[:, 1] - ab[1] * q[:, 0]) / n if n > 0 else np.hypot(q[:, 0], q[:, 1])
    i = int(np.argmax(d))
    if d[i] > eps and 0 < i < len(pts) - 1:
        return np.vstack([rdp(pts[:i + 1], eps)[:-1], rdp(pts[i:], eps)])
    return np.vstack([a, b])

def outline(m, eps=0.8):  # eps in 10 m pixels
    ys, xs = np.where(m)
    y0, x0 = ys.min() - 2, xs.min() - 2
    sub = np.zeros((ys.max() - y0 + 3, xs.max() - x0 + 3)); sub[ys - y0, xs - x0] = 1
    fig = plt.figure(); cs = plt.contour(sub, levels=[0.5]); segs = cs.allsegs[0]; plt.close(fig)
    rings = []
    for s in segs:
        if len(s) < 4:
            continue
        k = len(s) // 2
        s = np.vstack([rdp(s[:k + 1], eps)[:-1], rdp(s[k:], eps)])
        if len(s) < 4:
            continue
        flat = []
        for x, y in s:
            flat += [round(LAT0 - (y + y0 + 0.5) * D, 6), round(LON0 + (x + x0 + 0.5) * D, 6)]
        rings.append(flat)
    rings.sort(key=len, reverse=True)
    return rings

parts, areas, outlines, feats, rows = [], [], [], [], []
for si, ((code, no, brgy, psgc, _), m) in enumerate(zip(SITES, masks)):
    ha = round(m.sum() * 0.01, 1)
    # centre: a point inside the site (the 30 m cell nearest the mask's mean position)
    ys, xs = np.where(m); cy, cx = ys.mean(), xs.mean()
    j = np.argmin((ys - cy) ** 2 + (xs - cx) ** 2)
    lat, lon = round(float(plat[ys[j]]), 6), round(float(plon[xs[j]]), 6)
    rings = outline(m)
    name = f'Site {no} · {brgy}'
    parts.append([code, code, brgy, 0, ha, lat, lon, 0, psgc, name])
    areas.append({'code': code, 'zone': 'SAMAL', 'barangay': brgy, 'rings': rings})
    outlines.append(rings)
    feats.append({'type': 'Feature', 'properties': {'code': code, 'name': name, 'barangay': brgy, 'psgc': psgc, 'hectares': ha},
                  'geometry': {'type': 'Polygon' if len(rings) == 1 else 'MultiPolygon',
                               'coordinates': ([[[r[i + 1], r[i]] for i in range(0, len(r), 2)] for r in rings[:1]]
                                               if len(rings) == 1 else
                                               [[[[r[i + 1], r[i]] for i in range(0, len(r), 2)]] for r in rings])}})
    rows.append((code, name, brgy, psgc, ha, lat, lon, no))
    print(code, name, ha, 'ha', 'cells', sum(1 for v in cells.values() if v == si), 'rings', len(rings), 'centre', lat, lon)

# zone: Samal, outline = all site rings, hull = biggest ring
all_lat = [p[5] for p in parts]; all_lon = [p[6] for p in parts]
zone = {'code': 'SAMAL', 'label': 'Samal', 'town': TOWN, 'hull': outlines[0][0],
        'centre': [round(sum(all_lat) / 3, 5), round(sum(all_lon) / 3, 5)],
        'outline': [r for o in outlines for r in o]}
meta = {'version': VERSION, 'grid': {'lat0': GLAT0, 'lon0': GLON0, 'kx': KX, 'ky': KY, 'cell': CELL},
        'allowance_m': 15.0, 'zones': [zone], 'parts': parts}
os.makedirs('out/assets/map', exist_ok=True); os.makedirs('out/zone_maps/samal_sites', exist_ok=True)
json.dump(meta, open('out/assets/map/parts.json', 'w'), separators=(',', ':'), ensure_ascii=False)
json.dump(areas, open('out/assets/map/areas.json', 'w'), separators=(',', ':'), ensure_ascii=False)
json.dump(outlines, open('out/assets/map/part_outlines.json', 'w'), separators=(',', ':'))
with open('out/assets/map/lookup.bin', 'wb') as f:
    for r in runs:
        f.write(struct.pack('<4i', *r))
json.dump({'type': 'FeatureCollection', 'features': feats}, open('out/zone_maps/samal_sites/samal_sites.geojson', 'w'),
          separators=(',', ':'), ensure_ascii=False)
with open('out/zone_maps/samal_sites/site_lookup_runs.csv', 'w') as f:
    f.write('iy,ix_start,ix_end,site_code\n')
    for iy, a, b, p in runs:
        f.write(f'{iy},{a},{b},{SITES[p][0]}\n')
spec = {'version': VERSION, 'zone': 'Samal (one zone)', 'sites': [dict(code=r[0], name=r[1], barangay=r[2], psgc=r[3], hectares=r[4]) for r in rows],
        'grid': {'formula': 'x = (lon - 125.7) * kx; y = (lat - 6.6) * ky; ix = round(x / 30); iy = round(y / 30)',
                 'lat0': GLAT0, 'lon0': GLON0, 'kx': KX, 'ky': KY, 'cell_m': CELL},
        'allowance_m': 15, 'drop_off_depth_m': 7, 'site3_widened_m': 300,
        'counts': {'cells': len(cells), 'runs': len(runs)},
        'sources': ['Allen Coral Atlas (2020), Bathymetry - composite depth (10 m), CC BY 4.0, doi.org/10.5281/zenodo.3833242',
                    'Barangay boundaries: NAMRIA/PSA via OCHA COD-AB (faeldon/philippines-json-maps, PSGC 3Q 2026)'],
        'confirmed': 'Site lines confirmed by the project expert on 2026-11-04 (Adecor patch connected afterwards).'}
json.dump(spec, open('out/zone_maps/samal_sites/spec.json', 'w'), indent=1, ensure_ascii=False)
json.dump({'rows': rows, 'runs': [[a, b, c, SITES[p][0]] for a, b, c, p in runs]}, open('out/rows.json', 'w'), ensure_ascii=False)
print('cells', len(cells), 'runs', len(runs))
