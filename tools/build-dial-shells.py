"""Author deterministic, layered instrument shells from the runtime geometry.

python tools/build-dial-shells.py
Requires Pillow, NumPy and Lupa. This builds new UI art, not edits to concept
images. No markings, telemetry, lamps or needles are baked into these assets.
"""
from pathlib import Path
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageChops
from lupa.lua52 import LuaRuntime

ROOT = Path(__file__).resolve().parent.parent
SIZE, SCALE = 1240, 2
OUT = ROOT / 'assets/dial_variants'
Y, X = np.mgrid[0:SIZE, 0:SIZE].astype(float) / SCALE
R = np.hypot(X - 310, Y - 304)
NOISE = np.random.default_rng(615).normal(0, 0.6, (SIZE, SIZE))


def material(light=False, metal=False, screen=False):
    shade = (218 if light else 24) + (304-Y) * (0.025 if light else 0.015)
    shade = shade + 8*np.exp(-((X-230)**2+(Y-125)**2)/40000) + NOISE
    if screen:
        shade = (236 if light else 10) + NOISE * 0.3
    if metal:
        shade = (170 if light else 48) + 22*np.sin((X+Y)/200) + 11*np.cos(R/3)
        shade = shade + np.sin(Y*6)*1.6 + NOISE
    rgb = np.stack((shade+1, shade+1, shade), axis=2)
    return Image.fromarray(np.uint8(np.clip(rgb, 0, 255)), 'RGB').convert('RGBA')


def mask(shape, data):
    m = Image.new('L', (SIZE, SIZE))
    d = ImageDraw.Draw(m)
    if shape == 'circle':
        x, y, r = data
        d.ellipse(tuple(round(v*SCALE) for v in (x-r, y-r, x+r, y+r)), fill=255)
    elif shape == 'round':
        x, y, w, h, radius = data
        d.rounded_rectangle(tuple(round(v*SCALE) for v in (x-w/2, y-h/2, x+w/2, y+h/2)),
                            radius=round(radius*SCALE), fill=255)
    else:
        d.polygon([(round(x*SCALE), round(y*SCALE)) for x, y in data], fill=255)
    return m


def surface(canvas, m, texture, light, bevel=True):
    if bevel:
        shadow = Image.new('RGBA', canvas.size, (0, 0, 0, 0))
        shadow.putalpha(m.filter(ImageFilter.GaussianBlur(4*SCALE)).point(lambda a: round(a*0.7)))
        canvas.alpha_composite(shadow)
    tile = texture.copy()
    tile.putalpha(m)
    canvas.alpha_composite(tile)
    if bevel:
        edge = ImageChops.subtract(m, m.filter(ImageFilter.MinFilter(9)))
        tint = Image.new('RGBA', canvas.size, (145, 145, 140, 255) if light else (65, 66, 63, 255))
        tint.putalpha(edge)
        canvas.alpha_composite(tint)
        edge = ImageChops.subtract(m, m.filter(ImageFilter.MinFilter(3)))
        tint = Image.new('RGBA', canvas.size, (92, 94, 91, 255) if light else (5, 6, 5, 255))
        tint.putalpha(edge)
        canvas.alpha_composite(tint)


def circle(canvas, x, y, radius, color, width=1):
    ImageDraw.Draw(canvas).ellipse(tuple(round(v*SCALE) for v in (x-radius,y-radius,x+radius,y+radius)),
                                  outline=color,width=max(1,round(width*SCALE)))


def panel(canvas, points, textures, light):
    surface(canvas, mask('polygon',points), textures['face'],light)


def screen(canvas, x, y, w, h, textures, light, gear=False):
    surface(canvas,mask('round',(x,y,w,h,13)),textures['screen'],light)
    color = (174,120,36,255) if light else (217,168,62,255)
    if gear:
        ImageDraw.Draw(canvas).rounded_rectangle(tuple(round(v*SCALE) for v in (x-w/2+2,y-h/2+2,x+w/2-2,y+h/2-2)),
                                                radius=11*SCALE,outline=color,width=2)


def shells(layout, light):
    textures = {name: material(light,metal=name=='metal',screen=name=='screen') for name in ('face','metal','screen')}
    back = Image.new('RGBA',(SIZE,SIZE))
    outer = mask('circle',(310,304,292))
    surface(back,outer,textures['metal'],light,False)
    surface(back,mask('circle',(310,304,268)),textures['face'],light)
    for radius,color,width in ((290,(9,10,9,255),3),(285,(126,129,124,255),1),
                               (279,(11,13,11,255),5),(273,(98,102,96,255),1),
                               (266,(6,7,6,255),3),(261,(61,64,59,255),1)):
        circle(back,310,304,radius,color,width)
    # Subtle brushed highlights remain texture; RPM bands are runtime geometry.
    r=layout['rpm']
    if layout['id'] in ('fan','spoke'):
        # Radial face sectors create the fan's instrument relief.
        cx,cy,rr = r[1],r[2],r[3]-5
        for i in range(9):
            a=math.radians(-183+i*186/9)
            b=math.radians(-183+(i+1)*186/9)
            points=[(cx+96*math.cos(a),cy+96*math.sin(a))]
            points += [(cx+rr*math.cos(a+(b-a)*j/16),cy+rr*math.sin(a+(b-a)*j/16)) for j in range(17)]
            points += [(cx+96*math.cos(b),cy+96*math.sin(b))]
            tile=textures['face'].point(lambda v: min(255,v+3*(i%2)))
            surface(back,mask('polygon',points),tile,light,True)
    if layout['id']=='concentric':
        # This opening shows the game scene, not a painted silver ring.
        back.putalpha(ImageChops.subtract(back.getchannel('A'),mask('circle',(310,304,176))))
    if layout['id']=='shelf':
        ink=(167,169,161,255) if light else (56,59,54,255)
        for radius in (165,160,83):
            circle(back,r[1],r[2],radius,ink,1)
    if layout['id']=='spoke':
        surface(back,mask('circle',(310,300,60)),textures['metal'],light)
        surface(back,mask('circle',(310,300,49)),textures['screen'],light)
        circle(back,310,300,58,(110,113,104,255),2)
        circle(back,310,300,47,(72,75,68,255),1)

    front=Image.new('RGBA',(SIZE,SIZE))
    name=layout['id']
    if name=='shelf':
        panel(front,[(48,368),(572,368),(549,428),(517,480),(103,480),(71,428)],textures,light)
    elif name=='fan':
        panel(front,[(409,350),(565,351),(552,439),(522,483),(415,479),(397,405)],textures,light)
    elif name=='concentric':
        surface(front,mask('circle',(310,334,99)),textures['screen'],light)
        circle(front,310,334,99,(67,70,64,255),3)
        circle(front,310,334,90,(88,89,80,255),1)
    elif name=='spoke':
        # Recessed perforated side panels, bounded by the spokes.
        for points in ([(81,418),(199,432),(225,512),(177,546),(122,523)],
                       [(421,432),(539,418),(498,523),(443,546),(395,512)]):
            m=mask('polygon',points)
            tile=textures['face'].copy()
            d=ImageDraw.Draw(tile)
            for yy in range(405,550,8):
                for xx in range(75,550,8):
                    x=(xx+(4 if yy%16 else 0))*SCALE
                    y=yy*SCALE
                    d.ellipse((x-2,y-2,x+2,y+2),fill=(8,9,8,255) if not light else (120,123,118,255))
            surface(front,m,tile,light)
        panel(front,[(273,520),(347,520),(365,579),(255,579)],textures,light)
        # The central hub stays dynamic, above the static foreground spokes.

    speed,gear,aux=layout['speed'],layout['gear'],layout['aux']
    if name=='shelf':
        screen(front,speed[1],speed[2]+10,158,104,textures,light)
    if name!='spoke':
        screen(front,gear[1],gear[2],90 if name!='fan' else 75,86 if name!='fan' else 65,textures,light,True)
    if layout['auxStyle']=='screen' and name=='shelf':
        screen(front,aux[1],aux[2],aux[3]+18,aux[4]+10,textures,light)
    # Clip all artwork to the physical dial; external canvas is genuine alpha.
    back.putalpha(ImageChops.multiply(back.getchannel('A'),outer))
    front.putalpha(ImageChops.multiply(front.getchannel('A'),outer))
    return back,front


def main():
    os.chdir(ROOT)
    lua=LuaRuntime()
    catalog=lua.execute("return require('src/dial_variants')")
    OUT.mkdir(parents=True,exist_ok=True)
    for name,layout in catalog['layouts'].items():
        for theme in ('dark','light'):
            for layer,image in zip(('back','front'),shells(layout,theme=='light')):
                image.save(OUT/f'{name}_{theme}_{layer}.png',optimize=True)
    print('Exported 16 transparent 1240px shell layers to assets/dial_variants')


if __name__=='__main__':
    main()
