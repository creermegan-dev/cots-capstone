import json,glob,numpy as np
from matplotlib.path import Path
from scipy import ndimage
a=np.load('bathy.npy')
ny,nx=a.shape; LON0,LAT0,D=125.64592148534287,7.203051274183968,8.983152841195215e-05
lon=LON0+(np.arange(nx)+0.5)*D; lat=LAT0-(np.arange(ny)+0.5)*D
lab=np.full((ny,nx),-1,np.int32); names=[]
def burn(g,v):
    for poly in ([g['coordinates']] if g['type']=='Polygon' else g['coordinates']):
        r=np.array(poly[0]); x0,y0=r.min(0); x1,y1=r.max(0)
        if x1<lon[0] or x0>lon[-1] or y1<lat[-1] or y0>lat[0]: continue
        i0=max(0,int((LAT0-y1)/D)); i1=min(ny,int((LAT0-y0)/D)+2); j0=max(0,int((x0-LON0)/D)); j1=min(nx,int((x1-LON0)/D)+2)
        gx,gy=np.meshgrid(lon[j0:j1],lat[i0:i1]); ins=Path(r).contains_points(np.column_stack([gx.ravel(),gy.ravel()])).reshape(i1-i0,j1-j0)
        sub=lab[i0:i1,j0:j1]; sub[ins]=v
for f in sorted(glob.glob('../pjm/prov/*.json')):
    for ft in json.load(open(f))['features']:
        if ft['properties']['adm3_en']=='Island Garden City of Samal': continue
        names.append('OTHER'); burn(ft['geometry'],len(names)-1)
for ft in json.load(open('../pjm/samal/bgysubmuns-municity-1102317000.0.1.json'))['features']:
    names.append(ft['properties']['adm4_en']); burn(ft['geometry'],len(names)-1)
land=lab>=0
l,k=ndimage.label(~land); sz=ndimage.sum(~land,l,range(1,k+1))
sea=np.isin(l,[i+1 for i,s in enumerate(sz) if s>20000])
_,(iy,ix)=ndimage.distance_transform_edt(~land,return_indices=True); lab2=lab.copy(); lab2[(~land)&~sea]=lab[iy,ix][(~land)&~sea]; land=~sea
dist,(iy,ix)=ndimage.distance_transform_edt(sea,return_indices=True); owner=lab2[iy,ix]
np.savez_compressed('grid.npz',lab=lab2,sea=sea,owner=owner,dist=dist)
json.dump(names,open('names.json','w'))
print('ok', {n:names.index(n) for n in ['Tambo','Adecor','Linosutan']})
