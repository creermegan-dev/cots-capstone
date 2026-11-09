import json, math, glob, csv, numpy as np
from matplotlib.path import Path
from scipy import ndimage
from scipy.spatial import cKDTree
import matplotlib; matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import to_rgb
from matplotlib.backends.backend_pdf import PdfPages
ORDER=['City of Panabo','Carmen','City of Tagum','Maco','Mabini','Pantukan','Banaybanay','Lupon','San Isidro','Governor Generoso','Jose Abad Santos','Don Marcelino','Malita','Santa Maria','Malalag','Sulop','Padada','Hagonoy','City of Digos','Santa Cruz','City of Davao','Island Garden City of Samal']
SHORT={m:m.replace('City of ','').replace('Island Garden City of ','') for m in ORDER}; SHORT['City of Davao']='Davao City'; SHORT['City of Panabo']='Panabo City'; SHORT['City of Tagum']='Tagum City'; SHORT['City of Digos']='Digos City'; SHORT['Island Garden City of Samal']='Samal (IGaCoS)'
munis=[]  # (name, psgc, geometry)
for f in sorted(glob.glob('../pjm/nb/*.json'))+sorted(glob.glob('../pjm/prov/*.json')):
    for ft in json.load(open(f))['features']:
        p=ft['properties']; munis.append((p.get('adm3_en') or 'Other province', p.get('adm3_psgc'), ft['geometry']))
psgc={n:c for n,c,_ in munis}
def rings(g): return [g['coordinates'][0]] if g['type']=='Polygon' else [p[0] for p in g['coordinates']]
def bbox_of(g):
    a=np.array([c for r in rings(g) for c in r]); return a[:,0].min(),a[:,0].max(),a[:,1].min(),a[:,1].max()
RF=json.load(open('/mnt/user-data/uploads/COTS-Monitor-Davao-Gulf-20261031152915/Geomorphic-Map/geomorphic.geojson'))['features']
REEF=[]
for ft in RF:
    if ft['properties']['class']=='Deep Lagoon': continue
    for r in rings(ft['geometry']):
        a=np.array(r); REEF.append((a[:,0].min(),a[:,0].max(),a[:,1].min(),a[:,1].max(),a))
print('reef rings',len(REEF))
pal=['#1D9E75','#378ADD','#D4537E','#BA7517','#7F77DD','#639922','#D85A30','#185FA5','#0F6E56','#993C1D','#534AB7','#A32D2D']
GLAT0=6.6; GLON0=125.7; GKX=111320*math.cos(math.radians(6.6)); GKY=110574.0; GRES=30.0
GLOBAL={}; conflicts=0
rows=[]; pdf=PdfPages('/mnt/user-data/outputs/zone_parts_final_A-V.pdf'); partrows=[]; checks=[]; summary=[]
for zi,mname in enumerate(ORDER):
    L=chr(65+zi)
    bg=json.load(open(f'../pjm/bgy/bgysubmuns-municity-{psgc[mname]}.0.1.json'))['features']
    # bbox: whole municipality, but limited to 12 km around its coast later
    bbs=np.array([bbox_of(ft['geometry']) for ft in bg])
    LONMIN,LONMAX,LATMIN,LATMAX=bbs[:,0].min()-0.03,bbs[:,1].max()+0.03,bbs[:,2].min()-0.03,bbs[:,3].max()+0.03
    # one shared grid for the whole gulf (same formula in the app and the database)
    lat0=GLAT0; LON0=GLON0; KX=GKX; KY=GKY; RES=GRES
    proj=lambda c:((c[0]-LON0)*KX,(c[1]-lat0)*KY)
    bx0,by0=proj((LONMIN,LATMIN)); bx1,by1=proj((LONMAX,LATMAX))
    OX=int(math.floor(bx0/RES)); OY=int(math.floor(by0/RES)); OX1=int(math.ceil(bx1/RES)); OY1=int(math.ceil(by1/RES))
    x0=OX*RES; y0=OY*RES; nx=OX1-OX+1; ny=OY1-OY+1; x1=x0+(nx-1)*RES; y1=y0+(ny-1)*RES; xs=x0+np.arange(nx)*RES; ys=y0+np.arange(ny)*RES
    lab=np.full((ny,nx),-1,np.int32); names=[]; codes=[]
    def burn(g,v):
        for r in rings(g):
            ext=np.array([proj(c) for c in r]); bx0,by0=ext.min(0); bx1,by1=ext.max(0)
            if bx1<x0 or bx0>x1 or by1<y0 or by0>y1: continue
            ix0=max(0,int((bx0-x0)/RES)); ix1=min(nx,int((bx1-x0)/RES)+2); iy0=max(0,int((by0-y0)/RES)); iy1=min(ny,int((by1-y0)/RES)+2)
            gx,gy=np.meshgrid(xs[ix0:ix1],ys[iy0:iy1]); ins=Path(ext).contains_points(np.column_stack([gx.ravel(),gy.ravel()]))
            sub=lab[iy0:iy1,ix0:ix1].ravel(); sub[ins]=v; lab[iy0:iy1,ix0:ix1]=sub.reshape(iy1-iy0,ix1-ix0)
    for n,c,g in munis:
        if n==mname: continue
        b=bbox_of(g)
        if b[1]<LONMIN or b[0]>LONMAX or b[3]<LATMIN or b[2]>LATMAX: continue
        names.append('OTHER:'+n); codes.append(c); burn(g,len(names)-1)
    NZ=len(names)
    for ft in bg:
        names.append(ft['properties']['adm4_en']); codes.append(ft['properties']['adm4_psgc']); burn(ft['geometry'],len(names)-1)
    land=lab>=0
    l,k=ndimage.label(~land); sz=ndimage.sum(~land,l,range(1,k+1))
    edge=set(np.unique(np.r_[l[0],l[-1],l[:,0],l[:,-1]]))-{0}
    big=[i+1 for i,s in enumerate(sz) if s*RES*RES>2e6 and (i+1) in edge]  # real sea reaches the map edge; inland gaps do not
    sea=np.isin(l,big)
    _,(gy,gx)=ndimage.distance_transform_edt(~land,return_indices=True)
    hole=(~land)&~sea; lab[hole]=lab[gy,gx][hole]; land=~sea
    _,(iyL,ixL)=ndimage.distance_transform_edt(~land,return_indices=True)
    nearland=lab[iyL,ixL]
    dland=ndimage.distance_transform_edt(~land)
    # open water check (for river/channel flags)
    dsea=ndimage.distance_transform_edt(sea)*RES
    openw=ndimage.binary_dilation(dsea>300,iterations=int(700/RES))
    # contours of the sea mask
    fig0=plt.figure(); cs=plt.contour(np.pad(sea,1).astype(float),levels=[0.5]); segs=[s-1 for s in cs.allsegs[0] if len(s)>=4]; plt.close(fig0)
    zone_items=[]  # (segment kind, seg index, run start, barangay idx, length m, start pt, end pt, flag)
    seginfo=[]
    for si,s in enumerate(segs):
        closed=np.allclose(s[0],s[-1]) and s[:,0].min()>1 and s[:,1].min()>1 and s[:,0].max()<nx-2 and s[:,1].max()<ny-2
        ci=np.clip(np.round(s).astype(int),[0,0],[nx-1,ny-1])
        # vertex label: nearest land cell to the vertex
        vl=nearland[ci[:,1],ci[:,0]].copy(); vl[dland[ci[:,1],ci[:,0]]>1.5]=-2  # bbox edge, not coast
        if not (vl>=NZ).any(): continue
        # orientation: mainland -> sea on the right; island -> land on the right (clockwise)
        d=np.gradient(s,axis=0); nrm=np.column_stack([d[:,1],-d[:,0]]); nrm/=np.linalg.norm(nrm,axis=1,keepdims=True)+1e-9
        p=np.clip(np.round(s+3*nrm).astype(int),[0,0],[nx-1,ny-1]); onc=vl!=-2; right_sea=sea[p[onc,1],p[onc,0]].mean()
        want_sea_right=not closed
        if (right_sea>0.5)!=want_sea_right: s=s[::-1]; vl=vl[::-1]; ci=ci[::-1]
        if closed:  # start at the northernmost point
            st=int(np.argmax(s[:,1])); s=np.vstack([s[st:-1],s[:st+1]]); vl=np.concatenate([vl[st:-1],vl[:st+1]]); ci=np.vstack([ci[st:-1],ci[:st+1]])
        seglen=np.r_[0,np.cumsum(np.hypot(*np.diff(s,axis=0).T))]*RES
        # runs
        runs=[]; a=0
        for i in range(1,len(vl)+1):
            if i==len(vl) or vl[i]!=vl[a]: runs.append([vl[a],a,i-1]); a=i
        if closed and len(runs)>1 and runs[0][0]==runs[-1][0]:
            r=runs.pop(); runs[0]=[r[0],r[1]-len(vl),runs[0][2]]
        seginfo.append((si,closed,len(vl),s,seglen,runs))
    # per barangay: total coast length, its longest run gives position and end points
    best={}
    for si,closed,nv,s,seglen,runs in seginfo:
        for v,a,b in runs:
            if v<NZ: continue
            idx=np.arange(a,b+1)%nv; ln=float(np.sum(np.hypot(*np.diff(s[idx],axis=0).T))*RES)
            e=best.setdefault(v,{'len':0,'run':None,'runlen':-1,'kinds':set()}); e['kinds'].add('Island' if closed else 'Mainland')
            e['len']+=ln
            if ln>e['runlen']: e.update(runlen=ln,run=(si,closed,a,b,nv,s))
    segsize={si:seglen[-1] for si,closed,nv,s,seglen,runs in seginfo}
    def ll(pt): return round((x0+pt[0]*RES)/KX+LON0,5), round((y0+pt[1]*RES)/KY+lat0,5)
    items=[]
    for v,e in best.items():
        if e['len']<60: continue
        si,closed,a,b,nv,s=e['run']
        key=(1 if closed else 0, -segsize[si] if closed else 0, si, a%nv if closed else a)
        cells=(lab==v)&land&ndimage.binary_dilation(sea,structure=np.ones((3,3)))
        frac=float(openw[ndimage.binary_dilation(cells)&sea].mean()) if cells.any() else 0
        items.append((key,v,e,ll(s[a%nv]),ll(s[b%nv]),closed,frac))
    items.sort(key=lambda t:t[0])
    # draw strips
    dist,(iy,ix)=ndimage.distance_transform_edt(sea,return_indices=True); near=lab[iy,ix]; strip=sea&(dist*RES<=500)
    reef=np.zeros((ny,nx),bool)
    for bx0,bx1,by0,by1,a in REEF:
        if bx1<LONMIN or bx0>LONMAX or by1<LATMIN or by0>LATMAX: continue
        ext=np.array([proj(c) for c in a]); ex0,ey0=ext.min(0); ex1,ey1=ext.max(0)
        ix0=max(0,int((ex0-x0)/RES)); ix1=min(nx,int((ex1-x0)/RES)+2); iy0=max(0,int((ey0-y0)/RES)); iy1=min(ny,int((ey1-y0)/RES)+2)
        if ix1<=ix0 or iy1<=iy0: continue
        gx,gy=np.meshgrid(xs[ix0:ix1],ys[iy0:iy1]); ins=Path(ext).contains_points(np.column_stack([gx.ravel(),gy.ravel()])).reshape(iy1-iy0,ix1-ix0)
        reef[iy0:iy1,ix0:ix1]|=ins
    owner=np.where(land,lab,near)   # reef on land polygons keeps that barangay; reef in water -> nearest shore

    LIMIT=1.1; MARGIN=50.0; MINSTRIP=50.0; WIDE=250.0; cell_ha=RES*RES/1e4
    dsh,(sy,sx)=ndimage.distance_transform_edt(sea,return_indices=True); dsh=dsh*RES
    rs=reef&sea
    lr,nr=ndimage.label(rs,structure=np.ones((3,3)))
    ns=np.unique(lr[rs&(dsh<=3*RES)]); fringe=np.isin(lr,ns[ns>0])
    reach=np.zeros((ny,nx)); np.maximum.at(reach,(sy[fringe],sx[fringe]),dsh[fringe])
    reach=ndimage.maximum_filter(reach,size=int(300/RES)|1)
    zone_shore=land&(lab>=NZ)
    dreef=ndimage.distance_transform_edt(~fringe)*RES
    fill=sea&(dsh<=reach[sy,sx]+MARGIN)&(reach[sy,sx]>0)&(dreef<=200)
    strip=sea&(dsh<=MINSTRIP)
    off=ndimage.binary_dilation(rs,iterations=max(1,int(MARGIN/RES)))&sea
    area=(fill|strip|off)&zone_shore[sy,sx]
    area=ndimage.binary_fill_holes(area|land)&sea&zone_shore[sy,sx]
    owner=np.where(land,lab,near)
    wide=rs&((reach[sy,sx]>WIDE)|(~fringe)|(dsh>WIDE))
    partid=np.full((ny,nx),-1,np.int32); pc=0; arearows=[]
    gx_=np.arange(nx)[None,:]; gy_=np.arange(ny)[:,None]; G=max(1,int(round(math.sqrt(LIMIT*1e4)/RES)))
    for j,(key,v,e,sp,ep,closed,frac) in enumerate(items):
        code=f"{L}{j+1}"; m=area&(owner==v); rm=rs&(owner==v); ha=float(rm.sum())*cell_ha
        if not m.any(): arearows.append((code,names[v],codes[v],0,0,0,0,'no water area')); continue
        # coast walk for this barangay
        segs_v=[]
        for si_,cl_,nv_,sg_,sl_,runs_ in seginfo:
            for v_,a_,b_ in runs_:
                if v_!=v: continue
                idx_=np.arange(a_,b_+1)%nv_; segs_v.append(((1 if cl_ else 0),-sl_[-1] if cl_ else 0,si_,a_,sg_[idx_]))
        segs_v.sort(key=lambda t:t[:4])
        if not segs_v or ha==0:
            yy0,xx0=np.where(m); partid[m]=pc; partrows.append((code,code,names[v],0.0,round(float(m.sum())*cell_ha,2),0,f"{round((y0+yy0.mean()*RES)/KY+lat0,5)}, {round((x0+xx0.mean()*RES)/KX+LON0,5)}")); pc+=1
            arearows.append((code,names[v],codes[v],0,round(float(m.sum())*cell_ha,1),1,0,'no reef mapped')); continue
        verts=np.vstack([t[4] for t in segs_v]); tree=cKDTree(verts)
        ry,rx=np.where(rm); _,rk=tree.query(np.column_stack([rx,ry]))
        isw=wide[ry,rx]
        lab_r=np.full(len(ry),-1,np.int64)
        # narrow reef: cut along the coast every 1.1 ha
        nn=np.where(~isw)[0]
        if len(nn):
            o=nn[np.argsort(rk[nn],kind='stable')]
            lab_r[o]=(np.arange(len(o))*cell_ha//LIMIT).astype(np.int64)
        # wide reef: grid squares of about 1.1 ha
        ww=np.where(isw)[0]
        if len(ww):
            gid=(ry[ww]//G)*100000+(rx[ww]//G)
            u,inv=np.unique(gid,return_inverse=True); lab_r[ww]=1000000+inv
        # merge pieces with little reef (< 0.3 ha) into the nearest other piece
        for _ in range(3):
            ids,cnt=np.unique(lab_r,return_counts=True); small=set(ids[cnt*cell_ha<0.3]) if len(ids)>1 else set()
            if not small: break
            keep=~np.isin(lab_r,list(small))
            if not keep.any(): break
            t2=cKDTree(np.column_stack([rx[keep],ry[keep]])); _,q=t2.query(np.column_stack([rx[~keep],ry[~keep]]))
            lab_r[~keep]=lab_r[keep][q]
        # number parts along the coast by their median coast position
        ids=np.unique(lab_r); pos=[np.median(rk[lab_r==i]) for i in ids]; order=np.array(ids)[np.argsort(pos)]
        ren={int(i):k for k,i in enumerate(order)}; pr=np.array([ren[int(i)] for i in lab_r])
        pmap=np.full((ny,nx),-1); pmap[ry,rx]=pr
        _,(qy,qx)=ndimage.distance_transform_edt(~rm,return_indices=True)
        yy,xx=np.where(m); pid=pmap[qy[yy,xx],qx[yy,xx]]
        n=len(order); ngrid=0
        for p in range(n):
            sel=pid==p; partid[yy[sel],xx[sel]]=pc
            rr_=(pr==p); rha=float(rr_.sum())*cell_ha; g=bool(isw[rr_].mean()>0.5); ngrid+=g
            cy_,cx_=yy[sel].mean(),xx[sel].mean()
            partrows.append((f"{code}-{p+1}",code,names[v],round(rha,2),round(float(sel.sum())*cell_ha,2),1 if g else 0,f"{round((y0+cy_*RES)/KY+lat0,5)}, {round((x0+cx_*RES)/KX+LON0,5)}")); pc+=1
        arearows.append((code,names[v],codes[v],round(ha,1),round(float(m.sum())*cell_ha,1),n,ngrid,''))
    # fill any leftover water hole inside the areas with the nearest part
    allp=partid>=0
    hole=ndimage.binary_fill_holes(allp|land)&sea&~allp
    if hole.any():
        _,(hy,hx)=ndimage.distance_transform_edt(~allp,return_indices=True); partid[hole]=partid[hy,hx][hole]
    # zone water right at the shore that is still outside every part -> nearest part
    edgew=sea&(owner>=NZ)&ndimage.binary_dilation(zone_shore,structure=np.ones((3,3)))&(partid<0)
    if edgew.any():
        allp=partid>=0; _,(hy,hx)=ndimage.distance_transform_edt(~allp,return_indices=True); partid[edgew]=partid[hy,hx][edgew]
    # checks
    allp=partid>=0
    holes=int((ndimage.binary_fill_holes(allp|land)&sea&~allp).sum())
    coastgap=int((sea&(owner>=NZ)&ndimage.binary_dilation(zone_shore,structure=np.ones((3,3)))&~allp).sum())
    onland=int((allp&land).sum())
    checks.append((L,SHORT[mname],len(items),sum(r[5] for r in arearows),round(sum(r[3] for r in arearows)),holes,coastgap,onland))
    base_index=len(partrows)-pc   # partrows index of this zone's first part
    yy_,xx_=np.where(allp)
    edge_=np.minimum(np.minimum(yy_,ny-1-yy_),np.minimum(xx_,nx-1-xx_))   # cells deep inside this zone's window are more reliable
    for a_,b_,p_,e_ in zip(yy_+OY,xx_+OX,partid[yy_,xx_],edge_):
        k_=(int(a_),int(b_))
        if k_ in GLOBAL:
            conflicts+=1
            if GLOBAL[k_][1]>=e_: continue
        GLOBAL[k_]=(base_index+int(p_),int(e_))
    np.savez_compressed(f'parts_{L}.npz',OX=OX,OY=OY,partid=partid,owner=owner,lab=lab,x0=x0,y0=y0,RES=RES,KX=KX,KY=KY,LON0=LON0,lat0=lat0)
    # page
    img=np.ones((ny,nx,3))*np.array(to_rgb('#EAF2F8')); img[land]=to_rgb('#E4E2DA'); img[land&(lab>=NZ)]=to_rgb('#D3D1C7')
    for j,(key,v,e,sp,ep,closed,frac) in enumerate(items):
        base=np.array(to_rgb(pal[j%len(pal)])); img[allp&(owner==v)]=0.55*base+0.45
    pe=allp&((ndimage.maximum_filter(partid,3)!=partid)|(ndimage.minimum_filter(np.where(allp,partid,10**8),3)!=partid))
    ow=np.where(allp,owner,-1); ae=allp&((ndimage.maximum_filter(ow,3)!=ow)|(ndimage.minimum_filter(np.where(allp,ow,10**8),3)!=ow))
    img[pe&~ae]=0.85*img[pe&~ae]+0.15; img[ae]=0.55*img[ae]
    fig=plt.figure(figsize=(11.7,8.27),dpi=110); ax=fig.add_axes([0.01,0.02,0.6,0.88])
    ax.imshow(img,origin='lower',interpolation='nearest')
    for j,(key,v,e,sp,ep,closed,frac) in enumerate(items):
        mm=allp&(owner==v)
        if not mm.any(): continue
        l_,k_=ndimage.label(mm); s_=ndimage.sum(mm,l_,range(1,k_+1)); py,px=ndimage.center_of_mass(l_==(np.argmax(s_)+1))
        ax.text(px,py,f"{L}{j+1}",fontsize=6,ha='center',va='center',color='#2C2C2A',fontweight='bold',bbox=dict(boxstyle='round,pad=0.1',fc='white',ec='none',alpha=0.7))
    rr=np.where(allp.any(1))[0]; cc=np.where(allp.any(0))[0]; pad=int(800/RES)
    if len(rr):
        ax.set_xlim(max(0,cc.min()-pad),min(nx,cc.max()+pad)); ax.set_ylim(max(0,rr.min()-pad),min(ny,rr.max()+pad))
    ax.set_xticks([]); ax.set_yticks([])
    c=checks[-1]
    fig.suptitle(f"DRAFT · Zone {L} · {SHORT[mname]}: {c[2]} areas, {c[3]:,} parts of about 1.1 ha reef, {c[4]:,} ha reef",fontsize=11)
    lines=[f"{'Area':<5}{'Barangay':<21}{'Reef ha':>8}{'Parts':>7}"]+[f"{r[0]:<5}{r[1][:20]:<21}{r[3]:>8}{r[5]:>7}{'  !' if r[7] else ''}" for r in arearows]
    fs=6.5 if len(lines)<32 else 5.2
    fig.text(0.63,0.9,"\n".join(lines),fontsize=fs,va='top',family='DejaVu Sans Mono')
    fig.text(0.63,0.04,f"Checks: holes inside areas {c[5]*RES*RES:.0f} m²; shore with no area {c[6]} cells; area on land {c[7]} cells; overlaps: none\nArea = shore to reef edge + 50 m (at least 50 m). Parts: 1.1 ha of reef (Chandler et al. 2023);\nstrips along the coast, grid squares on wide reefs. Faint lines = parts. ! = no reef mapped.\nReef: Allen Coral Atlas (2020) geomorphic, CC BY 4.0. Barangays: NAMRIA/PSA via OCHA COD-AB.",fontsize=6.5,va='bottom')
    pdf.savefig(fig); plt.close(fig)
    rows.extend([dict(zip(['Zone','Town / city','Area code','Barangay','Barangay PSGC','Reef (ha)','Area water (ha)','Parts','Grid parts','Check'],[L,SHORT[mname]]+list(r))) for r in arearows])
    print(c,flush=True)
pdf.close()
with open('final/areas.csv','w',newline='',encoding='utf-8-sig') as f:
    w=csv.DictWriter(f,fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
with open('final/parts.csv','w',newline='',encoding='utf-8-sig') as f:
    w=csv.writer(f); w.writerow(['Part code','Area code','Barangay','Reef (ha)','Water (ha)','Grid square','Centre (lat, lon)']); w.writerows(partrows)
json.dump(checks,open('parts_checks.json','w'))
print('TOTAL parts',len(partrows),'cells',len(GLOBAL),'conflicts',conflicts)
import pickle; GLOBAL={k:v[0] for k,v in GLOBAL.items()}
pickle.dump({'GLOBAL':GLOBAL,'partrows':partrows,'rows':rows,'grid':dict(lat0=GLAT0,lon0=GLON0,kx=GKX,ky=GKY,res=GRES)},open('final/global.pkl','wb'))
