import random, json, os, sys
from collections import deque
W,H=30,17
# ---------- level specs: id -> (view, [archetype list], tags) ----------
# view: j side, s topdown, t combined(two worlds). archetypes: run,plat,hall,puz,arena,calm,tower(=tower+drop)
L={}
def lv(ch,n,view,arch,tags=()): L[(ch,n)]=(view,arch,list(tags))
# ch2
lv(2,1,'s',['calm','calm','calm','calm'],['pickup3','gap'])
lv(2,2,'s',['calm','puz','puz','calm'],['push'])
lv(2,3,'s',['calm','calm','puz','calm','calm'],['seed','toxic'])
lv(2,4,'s',['calm','hall','hall','puz','calm'],['lumi','trap'])
lv(2,5,'s',['calm','arena','arena','calm'],['farm'])
lv(2,6,'s',['calm','arena','arena','arena','arena','calm'],['night'])
lv(2,7,'j',['run','hall','puz','plat','hall','plat'],['hack','vent','digits'])
lv(2,8,'t',['puz','puz','puz','plat','puz','puz'],['coop'])
lv(2,9,'s',['calm','puz','hall','puz','puz','puz'],['crystal'])
lv(2,10,'s',['arena','arena','arena'],['storm'])
# ch3
lv(3,1,'j',['run','hall','plat','hall','run','plat'],['emp','conveyor'])
lv(3,2,'j',['run','hall','puz','hall','plat','hall','run'],['hack','vent'])
lv(3,3,'s',['calm','hall','hall','calm','hall','hall','calm'],['group','toxic'])
lv(3,4,'j',['run','hall','hall','plat','hall','run','plat'],['radiation'])
lv(3,5,'j',['run','hall','hall','plat','hall','puz','plat','run'],['press','laser'])
lv(3,6,'s',['calm','calm','puz','calm','calm'],['build'])
lv(3,7,'s',['arena','arena','arena','arena','calm','calm'],['night'])
lv(3,8,'t',['puz','puz','hall','puz','plat','puz'],['coop'])
lv(3,9,'t',['run','plat','run','plat','run'],['fast'])
lv(3,10,'t',['arena','arena','arena'],['boss'])
# ch4
lv(4,1,'t',['puz','puz','calm','puz'],['coop'])
lv(4,2,'s',['calm','plat','plat','plat','plat','plat','plat'],['wind'])
lv(4,3,'j',['run','hall','plat','hall','hall','plat','run'],['hook','mirror'])
lv(4,4,'s',['calm','hall','hall','hall','hall','calm'],['sleepers'])
lv(4,5,'t',['puz','puz','puz','hall','puz','calm'],['coop'])
lv(4,6,'s',['calm','plat','plat','plat','plat','plat','plat'],['wind','lumi'])
lv(4,7,'s',['calm','puz','puz','calm'],['keys'])
lv(4,8,'j',['run','hall','hall','plat','hall','run','plat','hall'],['adaptive'])
lv(4,9,'t',['puz','puz','puz','puz','calm'],['coop','riddle'])
lv(4,10,'t',['arena','arena','arena','arena'],['boss'])
# ch5
lv(5,1,'s',['calm','plat','plat','plat','plat','calm'],['crane'])
lv(5,2,'s',['arena','arena','arena','calm'],['night'])
lv(5,3,'j',['run','hall','hall','plat','hall','run','plat'],['hook','emp'])
lv(5,4,'t',['puz','puz','hall','puz','calm'],['coop'])
lv(5,5,'j',['run','plat','hall','plat','run','plat','hall'],['decoy'])
lv(5,6,'s',['calm','calm','puz','calm','calm'],['house'])
lv(5,7,'t',['run','hall','puz','plat','hall','puz','plat'],['floor'])
lv(5,8,'s',['calm','calm','calm'],['talk'])
# ch6
lv(6,1,'t',['arena','arena','arena','calm','arena','calm'],['night','link'])
lv(6,2,'t',['run','hall','plat','hall','puz','plat','hall'],['hook','link'])
lv(6,3,'s',['calm','calm','calm','calm'],['council'])
lv(6,4,'s',['calm','calm','calm','calm','calm'],['hub'])
lv(6,5,'j',['run','hall','hall','plat','hall','run','hall'],['deephack'])
lv(6,6,'s',['calm','hall','hall','puz','hall','calm'],['food'])
lv(6,7,'s',['calm','hall','puz','hall','puz','calm'],['spy'])
lv(6,8,'t',['arena','arena','arena','arena','arena','arena'],['fast'])
lv(6,9,'j',['run','hall','puz','hall','puz','hall','plat','hall'],['deephack'])
lv(6,10,'j',['run','hall','plat','puz','hall','plat','hall'],['code'])
# ch7
for n,t in zip(range(1,11),[['conveyor','choice'],['laser','emp','choice'],['talk'],['wind','hook','choice'],['deephack','choice'],['pity','choice'],['adaptive','choice'],['logs','choice'],['letter'],['boss','choice']]):
    v={1:'j',2:'j',3:'s',4:'j',5:'j',6:'t',7:'j',8:'j',9:'s',10:'t'}[n]
    a={1:['run','hall','plat','hall','run','plat','hall','calm'],2:['run','hall','hall','plat','hall','run','plat','calm'],3:['calm','calm','calm'],4:['run','plat','plat','hall','plat','plat','hall','calm'],5:['run','hall','puz','hall','puz','hall','plat','calm'],6:['calm','calm','puz'],7:['run','hall','hall','plat','hall','run','plat','calm'],8:['puz','puz','puz','puz','puz','puz','calm'],9:['calm','calm','calm'],10:['arena','arena','plat','arena','calm']}[n]
    lv(7,n,v,a,t)
# ch8
lv(8,1,'t',['arena','arena','arena','calm','calm','calm'],['night'])
lv(8,2,'j',['run','plat','hall','plat','run','plat','hall','plat','run','calm'],['decoyred'])
lv(8,3,'j',['run','hall','hall','plat','hall','calm'],['laser'])
lv(8,4,'t',['run','plat','puz','hall','puz','calm'],['plant','hook'])
lv(8,5,'t',['run','hall','plat','hall','puz','calm'],['shift'])
lv(8,6,'s',['calm','puz','puz','calm'],['memory'])
lv(8,7,'s',['calm'],['pillars'])
lv(8,8,'t',['calm','calm','calm'],['final'])

# ---------- grid helpers ----------
def new():
    g=[['.']*W for _ in range(H)]
    for c in range(W):
        for r in (0,1,14,15,16): g[r][c]='#'
    for r in range(H): g[r][0]=g[r][W-1]='#'
    return g
def box(g,c0,c1,r0,r1,ch='#'):
    for r in range(r0,r1+1):
        for c in range(c0,c1+1):
            if 0<=r<H and 0<=c<W: g[r][c]=ch
def opening(g,col,rows):
    for r in rows: g[r][col]='.'
LOW=(12,13); HIGH=(2,3)
SOLID=set('#~D')
def solid(g,c,r,opened=False):
    if not(0<=c<W and 0<=r<H): return True
    ch=g[r][c]
    if ch=='D' and opened: return False
    return ch in SOLID
def find(g,ch):
    return [(c,r) for r in range(H) for c in range(W) if g[r][c]==ch]

# ---------- validation ----------
WALLJ=[False]
def reach_side(g,starts,opened):
    UP,HS=4,6
    Hs=find(g,'H')
    seen=set(); q=deque()
    for st in starts:
        k=(st[0],st[1],0,0); seen.add(k); q.append(k)
    cells=set()
    def push(k):
        if k[1]>=14 or k[1]<0: return
        if k not in seen: seen.add(k); q.append(k)
    while q:
        c,r,up,h=q.popleft()
        grounded=solid(g,c,r+1,opened) and up==0
        if grounded:
            cells.add((c,r))
            for dc in (-1,1):
                if not solid(g,c+dc,r,opened) and 0<=c+dc<W: push((c+dc,r,0,0))
            push((c,r,UP,HS))
            for (hc,hr) in Hs:
                if abs(c-hc)<=6 and hr<r:
                    for c2 in range(max(1,hc-6),min(W-1,hc+7)):
                        for r2 in range(2,14):
                            if not solid(g,c2,r2,opened) and solid(g,c2,r2+1,opened): push((c2,r2,0,0))
        else:
            if up>0 and not solid(g,c,r-1,opened): push((c,r-1,up-1,h))
            for dc in (-1,1):
                if h>0 and 0<=c+dc<W and not solid(g,c+dc,r,opened): push((c+dc,r,up,h-1))
            if not solid(g,c,r+1,opened): push((c,r+1,0,h))
    return cells
def solvable_side(g,entry_row,exit_rows,need):
    cells=reach_side(g,[(1,entry_row)],False)
    for ch in need:
        for (c,r) in find(g,ch):
            if (c,r) not in cells: return False
    cells2=reach_side(g,list(cells),True)
    return any((28,r) in cells2 for r in exit_rows)
def solvable_top(g,start,exit_rows,need):
    def bfs(opened):
        seen={start}; q=deque([start])
        while q:
            c,r=q.popleft()
            for dc,dr in((1,0),(-1,0),(0,1),(0,-1)):
                n=(c+dc,r+dr)
                if n in seen: continue
                if not(0<=n[0]<W and 0<=n[1]<H): continue
                if solid(g,n[0],n[1],opened): continue
                seen.add(n); q.append(n)
        return seen
    s0=bfs(False)
    for ch in need:
        for p in find(g,ch):
            if p not in s0: return False
    s1=bfs(True)
    return any((29,r) in s1 for r in exit_rows)

# ---------- room archetypes ----------
def put(g,c,r,ch):
    if g[r][c]=='.': g[r][c]=ch
def coins(g,rng,k,rows=(9,12),cols=(5,25)):
    n=0;t=0
    while n<k and t<200:
        t+=1
        c=rng.randint(*cols); r=rng.randint(*rows)
        if g[r][c]=='.': g[r][c]='o'; n+=1
def room_side(kind,rng,entry,exit_,tags,d,first=False,last=False):
    g=new()
    low_e = entry==LOW; low_x= exit_==LOW
    opening(g,0,entry); opening(g,W-1,exit_)
    req=[]
    if low_e: pass
    else: box(g,1,5,4,4)  # entry ledge at row 4 (under rows 2,3)
    if not low_x: box(g,24,28,4,4)
    if kind=='tower':
        # ledges rise from low entry to high exit
        rows=[10,7,4]; x=rng.choice([0,1])
        cols=[(8,12),(16,20),(22,26)]
        if x: cols=[(22,26),(16,20),(22,26)]; cols=[(8,12),(15,19),(22,26)]
        for (c0,c1),r in zip(cols,rows): box(g,c0,c1,r,r)
        if 'wind' in tags: put(g,14,6,'r')
        for c0,c1 in cols[:2]: pass
        coins(g,rng,3,(5,12),(6,24))
        # exit ledge handled
    elif kind=='drop':
        rows=[6,9,12]
        cols=[(8,12),(15,19),(21,25)]
        for (c0,c1),r in zip(cols,rows): box(g,c0,c1,r,r)
        coins(g,rng,3,(5,11),(6,24))
    elif kind in('run','plat','hall','puz','arena','calm'):
        # floor pits (only in side)
        c=7; pits=[]
        npits={'run':2+d//2,'plat':2,'hall':1,'puz':1,'arena':0,'calm':0}[kind]
        for i in range(npits):
            w=rng.randint(2,min(4,2+d))
            if c+w+4>=W-3: break
            c+=rng.randint(2,4)
            pits.append((c,c+w-1)); c+=w+2
        for (a,b) in pits:
            box(g,a,b,14,16,'.')
            if kind in('plat',) and rng.random()<0.6:
                box(g,a,b,11,11)  # stepping platform over pit
        # spikes
        ns={'run':2,'plat':1,'hall':3,'puz':1,'arena':0,'calm':0}[kind]
        tries=0
        while ns and tries<60:
            tries+=1
            c=rng.randint(8,26)
            if g[13][c]=='.' and g[14][c]=='#' and all(g[13][x]=='.' for x in(c-1,c+1)) and not any(a-1<=c<=b+1 for a,b in pits):
                g[13][c]='^'; ns-=1
        # platform steps
        if kind in('plat','hall','run'):
            for _ in range(rng.randint(1,2)):
                c0=rng.randint(7,22); r=rng.choice([10,11]); box(g,c0,c0+2,r,r)
        # hall lasers/drones
        if kind=='hall':
            for _ in range(2):
                c=rng.randint(9,24); put(g,c,rng.choice([6,7,8]),'L')
            put(g,rng.randint(12,22),13,'n')
        if kind=='arena':
            for c in(8,12,17,21): put(g,c,13,'M')
        coins(g,rng,rng.randint(3,5),(7,12),(5,26))
        if 'hook' in tags and kind in('plat','run') and pits:
            a,b=pits[0]
            box(g,a,b,14,16,'.')
            # widen to 6 and put hook above
            a2=max(5,a-1); b2=min(26,a2+5)
            box(g,a2,b2,14,16,'.'); put(g,(a2+b2)//2,4,'H')
        if 'hack' in tags and kind=='puz': put(g,rng.randint(10,20),13,'T')
        if kind=='puz':
            # door + key puzzle: key on raised ledge, door before exit
            box(g,22,23,2,13)  # wall
            g[12][22]=g[13][22]='D'; g[12][23]=g[13][23]='D'
            box(g,12,16,9,9); put(g,14,8,'K')
            box(g,10,11,12,12)  # step
            req=['K']
    return g,req
def room_top(kind,rng,tags,d):
    g=new()
    opening(g,0,LOW); opening(g,W-1,LOW)
    # free-form: top-down uses full area rows 2..13 plus 14? only 2..13 and floor ring is wall
    for r in (14,15,16):
        for c in range(1,W-1): g[r][c]='.'
    box(g,1,28,0,1,'#')
    # clear border for top-down: rows 14-16 now playable ground => bottom wall at 16
    box(g,0,29,16,16,'#')
    for r in range(14,16):
        g[r][0]='#';g[r][29]='#'
    # obstacles
    nb={'calm':3,'hall':5,'puz':4,'arena':2,'plat':6}[kind]
    for _ in range(nb):
        w=rng.randint(2,4); h=rng.randint(2,3)
        c=rng.randint(4,24); r=rng.randint(3,12)
        if c<=3 or r in(12,13) and c<5: continue
        box(g,c,c+w-1,r,r+h-1)
    for r in LOW:
        for c in range(1,5): g[r][c]='.'
        for c in range(25,29): g[r][c]='.'
    req=[]
    if kind=='puz':
        box(g,22,23,2,15); 
        for r in (12,13): g[r][22]=g[r][23]='D'
        # make door the only way: wall column 22-23 full height rows 2..15 except door rows
        put(g,rng.randint(6,18),rng.randint(3,6),'K'); req=['K']
        # ensure K in free cell
    if kind=='plat':
        # narrow bridges/gaps shown as walls with openings (wind rooms)
        for c in(10,18):
            box(g,c,c+1,2,15)
            for r in rng.choice([(5,6),(9,10),(12,13)]):
                g[r][c]=g[r][c+1]='.'
        put(g,rng.randint(12,16),rng.randint(3,12),'r')
    if kind=='arena':
        for c in(7,12,17,22): put(g,c,rng.randint(4,11),'M')
    if kind=='hall':
        for _ in range(3): put(g,rng.randint(8,24),rng.randint(3,12),'n')
    for _ in range(rng.randint(3,5)): put(g,rng.randint(4,26),rng.randint(3,12),'o')
    return g,req

def make_level(ch,n,view,arch,tags):
    seed=ch*1000+n*10
    for attempt in range(60):
        rng=random.Random(seed+attempt)
        rooms=[]; cur=LOW; ok=True; d=0
        pending=list(arch)
        i=0
        total=len(arch)
        while pending:
            k=pending.pop(0)
            d=min(4,i*4//max(1,total))
            last=not pending
            if view=='s' or (view=='t' and False):
                g,req=room_top(k,rng,tags,d)
                ent=LOW; ex=LOW
                rows_need=req
                ok=solvable_top(g,(1,13),LOW,req)
            else:
                use_tower = (k=='plat' and view in('j','t') and rng.random()<0.25 and len(pending)>=1 and cur==LOW)
                if cur==HIGH:
                    g,req=room_side('drop',rng,HIGH,LOW,tags,d)
                    ex=LOW; ent=HIGH
                    ok=solvable_side(g,3,LOW,[])
                    pending.insert(0,k)  # keep intended room next
                elif use_tower:
                    g,req=room_side('tower',rng,LOW,HIGH,tags,d)
                    ent=LOW; ex=HIGH; ok=solvable_side(g,13,HIGH,[])
                    cur=HIGH
                else:
                    g,req=room_side(k,rng,LOW,LOW,tags,d)
                    ent=LOW; ex=LOW; ok=solvable_side(g,13,LOW,req)
            if not ok: break
            if ex==HIGH: cur=HIGH
            else: cur=LOW
            rooms.append((k if cur!=HIGH or not use_tower else 'tower',g,ent,ex,req))
            i+=1
        else:
            if cur==HIGH:
                # finish with a drop room
                g,req=room_side('drop',rng,HIGH,LOW,tags,3)
                if not solvable_side(g,3,LOW,[]): continue
                rooms.append(('drop',g,HIGH,LOW,[]))
            if ok: return rooms
    return None


OBJ={
 "Y":{"type":"salvage","id_prefix":"piece"},"N":{"type":"pushable_block"},"S":{"type":"soil_patch"},"V":{"type":"toxic_plant"},
 "u":{"type":"hidden_trap","reveal_by":"lumi_light"},"Z":{"type":"spawn_gate"},"z":{"type":"shelter"},"W":{"type":"world_switch_button"},
 "C":{"type":"crystal_block","needs":"crystal_breaker"},"e":{"type":"emp_drone","emp_vulnerable":True},"c":{"type":"conveyor","speed":48},
 "p":{"type":"press","on":1.0,"off":1.0},"F":{"type":"safe_marker"},"R":{"type":"radiation_zone","counter_rate":1.0},"B":{"type":"build_spot"},
 "m":{"type":"mirror_decoy"},"G":{"type":"guardian_statue","wake_on_noise":True},"a":{"type":"adaptive_guard","patterns":3},
 "q":{"type":"crane_platform"},"j":{"type":"decoy_shortcut","cost":"nexa"},"h":{"type":"diary_table"},"f":{"type":"electric_floor"},
 "t":{"type":"npc"},"y":{"type":"food_item","fake":False},"w":{"type":"scan_beam"},"x":{"type":"false_track"},"k":{"type":"keypad","digits":4},
 "Q":{"type":"choice_pillar","modes":["destroy","rewrite"]},"l":{"type":"log_item","order":0},"i":{"type":"memory_image"},
 "E":{"type":"red_lever","effect":"nexa_-10"},"U":{"type":"council_seat"},"A":{"type":"scanner_gate"},"7":{"type":"letter"},
 "4":{"type":"digit_drone","digit":4},"1":{"type":"digit_drone","digit":1},"9":{"type":"digit_drone","digit":9},"s":{"type":"lumi_spawn"}}
# tag -> list of (symbol, count, room-selector)
PLACE={
 'pickup3':[('Y',1,'r0'),('Y',1,'r1'),('Y',1,'r2')],'push':[('N',2,'all')],'seed':[('S',3,'all'),('V',2,'mid')],
 'toxic':[('V',3,'all'),('F',3,'all')],'lumi':[('s',1,'first'),('u',3,'hall')],'trap':[('u',3,'hall')],'farm':[('S',4,'arena'),('t',1,'first')],
 'night':[('Z',2,'arena')],'digits':[('4',1,'r2'),('1',1,'r2'),('9',1,'r2')],'coop':[('W',1,'puz')],'crystal':[('C',3,'puz')],
 'storm':[('r',2,'all'),('z',2,'all')],'emp':[('e',2,'hall')],'conveyor':[('c',4,'run')],'press':[('p',2,'hall')],'laser':[('L',2,'hall')],
 'group':[('t',2,'first')],'radiation':[('R',2,'hall')],'build':[('B',4,'all')],'mirror':[('m',2,'hall')],'sleepers':[('G',4,'hall')],
 'keys':[('K',1,'puz')],'adaptive':[('a',1,'hall')],'crane':[('q',2,'plat')],'decoy':[('j',1,'plat')],'house':[('h',1,'last')],
 'floor':[('f',4,'hall')],'talk':[('t',3,'first')],'council':[('U',5,'first')],'hub':[('Y',6,'all'),('t',3,'all')],'deephack':[('T',2,'hall'),('w',2,'hall')],
 'food':[('y',3,'hall')],'spy':[('x',3,'hall')],'code':[('k',1,'last')],'choice':[('Q',1,'last')],'logs':[('l',4,'puz')],'memory':[('i',2,'puz')],
 'pillars':[('Q',2,'first')],'shift':[('a',2,'hall')],'plant':[('T',1,'puz')],'final':[('Q',1,'last')],'decoyred':[('E',1,'mid')],'letter':[('7',1,'last')],
 'wind':[('r',2,'plat')],'hack':[('T',1,'hall')],'link':[('W',1,'puz')],'pity':[('t',1,'first')],'boss':[('Z',2,'arena')],'gap':[],'vent':[],'radio':[],
 'fast':[],'riddle':[('k',1,'last')],'laser2':[]}
def free_cells(g,view):
    if view=='s':
        cells=[(c,r) for r in range(2,16) for c in range(2,28) if g[r][c]=='.' and not (r in LOW and (c<5 or c>24))]
        return cells
    st=reach_side(g,[(1,13)],False)|reach_side(g,[(1,3)],False)
    return [(c,r) for (c,r) in st if 2<=c<=27 and g[r][c]=='.' and (r<13 or not (c<4 or c>25)) ]
def decorate(rooms,tags,view,rng):
    n=len(rooms)
    for tg in tags:
        for (sym,cnt,sel) in PLACE.get(tg,[]):
            idxs=[]
            for i,(k,g,ent,ex,req) in enumerate(rooms):
                if sel=='all' or sel==k or (sel=='first' and i==0) or (sel=='last' and i==n-1) or (sel=='mid' and i==n//2) or (sel==f'r{i}'):
                    idxs.append(i)
            if not idxs and sel in('hall','puz','arena','plat','run') : idxs=[n//2]
            for i in idxs:
                g=rooms[i][1]
                cs=free_cells(g,view)
                if view!='s' and sym in('L','e','n'): cs=[(c,r) for (c,r) in cs if r<13]
                rng.shuffle(cs)
                for (c,r) in cs[:cnt]:
                    g[r][c]=sym
    return rooms

def finish(rooms,ch,n,view,tags):
    out=[]
    for i,(k,g,ent,ex,req) in enumerate(rooms):
        # markers
        if i==0:
            # player start
            g[13][1]='P'
            if view in('j','t') and ch>=2 or True: g[12][1]='I' if view!='s' else g[12][1]
        if i==len(rooms)-1:
            r=13 if ex==LOW else 3
            g[r][27]='X'
        out.append((k,[''.join(r) for r in g],ent,ex))
    return out
def objects_for(tags,view):
    o={"o":{"type":"coin"},"^":{"type":"spike"},"L":{"type":"laser","dir":"down","on":1.2,"off":1.2,"phase":0.0},
       "n":{"type":"drone","patrol":4},"X":{"type":"exit"},"P":{"type":"start_ilara" if view!='j' else "start_kairo"},"I":{"type":"start_other"},
       "K":{"type":"key","color":"blue"},"D":{"type":"door","key":"blue"},"T":{"type":"hack_terminal"},"M":{"type":"tower_slot"},
       "H":{"type":"hook_point","range":6},"r":{"type":"wind_zone","dir":"right","strength":1.0}}
    return o
if __name__=='__main__':
    outdir=sys.argv[1]; os.makedirs(outdir,exist_ok=True)
    txt=[];fails=[]
    tot=0
    for (ch,n),(view,arch,tags) in sorted(L.items()):
        rooms=make_level(ch,n,view,arch,tags)
        if rooms is None: fails.append((ch,n)); continue
        decorate(rooms,tags,view,random.Random(ch*100+n)); rr=finish(rooms,ch,n,view,tags)
        tot+=len(rr)
        data={"id":f"ch{ch}_l{n}","title_key":f"ch{ch}_l{n}_title","view":{"j":"side","s":"topdown","t":"combined"}[view],
              "tags":tags,"par_time":len(rr)*18+10,"companion":view=='s',
              "rooms":[{"id":f"r{i+1}","kind":k,"entry":"low" if ent==LOW else "high","exit":"low" if ex==LOW else "high","tiles":t,
                        "exits":{"right":f"r{i+2}"} if i<len(rr)-1 else {"level_end":True}} for i,(k,t,ent,ex) in enumerate(rr)],
              "objects":{**objects_for(tags,view),**{k:v for k,v in OBJ.items() if any(k in ''.join(t) for (_,t,_,_) in rr)}}}
        json.dump(data,open(f"{outdir}/ch{ch}_l{n}.json",'w'),ensure_ascii=False,indent=1)
        txt.append(f"## ch{ch}_l{n} ({data['view']}, {len(rr)} rooms) tags={','.join(tags)}")
        for i,(k,t,ent,ex) in enumerate(rr):
            txt.append(f"R{i+1} [{k}]"); txt.extend(t); txt.append('')
    open(f"{outdir}/all_rooms.txt",'w').write('\n'.join(txt))
    print('levels',len(L),'built',len(L)-len(fails),'rooms',tot,'fails',fails)
