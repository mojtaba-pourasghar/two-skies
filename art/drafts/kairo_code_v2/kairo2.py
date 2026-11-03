import sys; sys.path.insert(0,'.')
from pix import *
P=dict(
 skinL=hx('f6d2ac'),skin=hx('e0a77f'),skinD=hx('b97a5e'),
 hairL=hx('6b5a8a'),hair=hx('3f3156'),hairD=hx('231a36'),
 scL=hx('ffa253'),sc=hx('ee6b2d'),scD=hx('b3401f'),
 jkL=hx('5e5c86'),jk=hx('403e62'),jkD=hx('2a2845'),
 pn=hx('2c2a48'),ol=hx('15122a'),
 mod=hx('4cc9ff'),seam=hx('f6f0e4'),beltM=hx('ffa253'))
T=lambda a,b,c:(P[a],P[b],P[c])
SK=T('skinL','skin','skinD'); HR=T('hairL','hair','hairD'); SC=T('scL','sc','scD')
JK=T('jkL','jk','jkD'); PN=(P['jk'],P['pn'],P['ol'])
WARM={P[k] for k in ('skinL','skin','skinD','scL','sc','scD','beltM')}
def front():
    c=Canvas()
    # legs
    c.shape(rect(12,29,15,35),PN); c.shape(rect(17,29,20,35),PN)
    # boots with lighter cuff
    c.shape(rect(11,35,15,38),(P['jkL'],P['pn'],P['ol'])); c.shape(rect(17,35,21,38),(P['jkL'],P['pn'],P['ol']))
    for x in list(range(11,16))+list(range(17,22)): c.put(x,35,P['jk'])
    # torso: undershirt + open jacket
    c.shape(rect(11,18,21,28),JK)
    c.shape(rect(15,19,17,27),(P['jk'],P['jkD'],P['jkD']),flat=True)       # undershirt gap
    for y in range(19,28): c.put(15,y,P['jkL']) if y%3==0 else None
    c.put(14,24,P['jkD']); c.put(18,22,P['jkD']); c.put(13,26,P['jkD']); c.put(19,25,P['jkD'])  # folds
    for y in range(20,28): c.put(11,y,P['sc'])                              # orange trim left
    for y in range(20,28): c.put(21,y,P['scD'])                             # trim right
    # belt
    for x in range(11,22): c.put(x,28,P['beltM'] if x in (15,16,17) else P['ol'])
    # arms
    c.shape(rect(8,19,10,27),JK); c.shape(rect(22,19,24,27),JK)
    c.put(8,19,P['jkL']); c.put(9,19,P['jkL'])
    # gloves
    for (x0,x1) in ((8,10),(22,24)):
        c.shape(rect(x0,27,x1,29),(P['jkL'],P['jkD'],P['jkD']))
    # hack bracer on viewer-right forearm
    for y in range(23,27):
        for x in (22,23,24): c.put(x,y,P['mod'] if x==23 else P['jkD'])
    c.put(23,24,P['seam'])
    # scarf: wrap + tail on right
    c.shape(rect(11,17,21,19),SC)
    c.shape(rect(19,19,23,24),SC); c.put(22,25,P['sc']); c.put(23,26,P['scD'])
    for x in range(12,21,2): c.put(x,18,P['seam'])
    # head
    c.shape(ell(16,11,4.9,5.3),SK)
    c.shape(rect(10,11,11,13),SK); c.shape(rect(21,11,22,13),SK)              # ears
    # hair: spiky mass
    c.shape(ell(16,6.2,5.6,3.4),HR)
    spikes=[(10,6),(9,8),(11,4),(13,2),(15,1),(17,1),(19,2),(21,4),(22,7),(22,9)]
    for (x,y) in spikes:
        for dx,dy in ((0,0),(0,1),(1,0)): c.put(x+dx,y+dy,P['hair'])
    for (x,y) in [(12,3),(14,2),(16,1),(18,2),(11,5),(13,4),(15,3)]: c.put(x,y,P['hairL'])
    for (x,y) in [(10,9),(11,10),(21,10),(22,11),(19,5),(20,6)]: c.put(x,y,P['hairD'])
    # fringe with gap
    for x in (12,13,15,17,18,20): c.put(x,9,P['hair'])
    for x in (13,19): c.put(x,10,P['hair'])
    # eyes: dark top row + white spark
    for (x,y) in [(13,12),(14,12),(18,12),(19,12)]: c.put(x,y,P['ol'])
    for (x,y) in [(13,13),(18,13)]: c.put(x,y,P['seam'])
    for (x,y) in [(14,13),(19,13)]: c.put(x,y,P['hair'])
    c.put(16,14,P['skinD']); c.put(15,16,P['skinD']); c.put(16,16,P['skinD'])
    c.outline(P['scD'],P['ol'],WARM)
    return c
if __name__=='__main__':
    import os
    out='../out'; f=front(); im=f.img(); cols=set(f.px.values()); print('colors',len(cols))
    im.save(out+'/kairo2_front.png')
    big=Image.new('RGBA',(W*12,H*12),hx('5f8f4a')+(255,)); big.alpha_composite(im.resize((W*12,H*12),Image.NEAREST)); big.save(out+'/kairo2_preview.png')
