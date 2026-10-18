"""Render the 16 implemented GT7 auxiliary families from their Lua draw calls.

python tools/preview-gt7-mini-dials.py --reference assets/gt7-mini-dials-reference.jpg
The optional reference must be the original 4x4 sheet shown in the design brief.
Without it, exports the implementations and review fixtures, without inventing
or relabeling an approximation of the reference as an original crop.
"""
from pathlib import Path
import argparse
import importlib.util
import os
from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('preview', ROOT / 'tools/preview-instruments.py')
preview = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preview)
OUTPUT = ROOT / 'output/gt7-mini-dials'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference', type=Path)
    args = parser.parse_args()
    os.chdir(ROOT)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    reference = args.reference or ROOT / 'assets/gt7-mini-dials-reference.jpg'
    source = Image.open(reference).convert('RGB') if reference.is_file() else None
    lua, harness = preview.create_harness()
    lua.execute('''
      miniProfiles=require('src/mini_dial_profiles')
      miniRenderer={draw=function(state,options)
        local C=require('src/theme').get(options.theme)
        local L=require('ui/instrument_illumination').resolve(C,options.theme,options.light)
        local Channels=require('ui/auxiliary_dial_styles')
        local Mini=require('ui/mini_dial')
        local content={left=options.kind=='boost' and '-0.5' or 'E',
          right=options.kind=='boost' and '1.5' or 'F',label=options.available and
            (options.kind=='boost' and 'BOOST' or 'FUEL') or 'N/A',
          icon=options.kind=='boost' and require('ui/side_instruments').boostIcon or require('ui/side_instruments').fuelIcon}
        Mini.draw(options.id,vec2(85,72),1,options.digital,Channels.channel({
          kind=options.kind,available=options.available,value=options.value,
          needleValue=options.value,zero=options.kind=='boost' and 0.25 or 0,
          warning=options.kind=='boost' and 0.925 or 0.15,
          lowInk=options.kind=='fuel' and options.value<0.15 and C.red or nil
        },C,L),C,L,content)
      end}
    ''')
    face = ImageFont.truetype(str(preview.FONT), 18)
    title_face = ImageFont.truetype(str(preview.FONT.with_name('consolab.ttf')), 30)
    small = ImageFont.truetype(str(preview.FONT), 14)
    profiles = [p for _, p in lua.globals().miniProfiles.choices.items()]

    def render(id, digital, theme='dark', kind='fuel', value=0.6, available=True, light=0):
        if digital==1 and lua.globals().miniProfiles.get(id)['digital']==False:
            picture=Image.new('RGB',(170,132),'#121416' if theme=='dark' else '#f2eee6')
            ImageDraw.Draw(picture).text((10,45),'SOLO ANALOGICO',font=small,
                fill='#969c9e' if theme=='dark' else '#555555')
            return picture
        options = lua.table_from(dict(id=id, digital=digital, theme=theme,
            kind=kind, value=value, available=available, light=light))
        calls = harness['drawRenderer'](lua.globals().miniRenderer, harness['state'], options, lua.table_from((170,132)))
        return preview.raster(calls,170,132,'#121416' if theme=='dark' else '#f2eee6')

    tile_w, tile_h = (660 if source else 450), 260
    sheet = Image.new('RGB',(tile_w*4,128+tile_h*4),'#121416')
    draw = ImageDraw.Draw(sheet)
    draw.text((24,18),'GT7 / 16 MINI DIAL FAMILIES',font=title_face,fill='#efe5ce')
    draw.text((24,60),'Referencia + analogico + digital' if source else 'Analogico + digital / referencia original pendiente',font=face,fill='#bdb6a6')
    draw.text((24,88),'Combustible 60% | tema oscuro | luz apagada | renders de geometria Lua, no capturas del juego',font=small,fill='#969c9e')
    for index, choice in enumerate(profiles):
        row,col=divmod(index,4)
        x,y=col*tile_w,row*tile_h+128
        draw.line((x+12,y,x+tile_w-12,y),fill='#343a3d',width=1)
        draw.text((x+16,y+12),choice['label'],font=face,fill='#efe5ce')
        parts=[]
        if source:
            # Coordinates of the original 612x551 attachment, scaled to its file.
            cx,cy=(112,242,371,500)[col],(98,227,356,486)[row]
            box=tuple(round(v*s) for v,s in zip((cx-55,cy-55,cx+55,cy+55),
                (source.width/612,source.height/551)*2))
            crop=ImageOps.contain(source.crop(box),(176,154),Image.Resampling.LANCZOS)
            original=Image.new('RGB',(200,155),'white')
            original.paste(crop,((200-crop.width)//2,(155-crop.height)//2))
            parts.append(('REFERENCIA',original))
        for mode,digital in (('ANALOGICO',0),('DIGITAL',1)):
            picture=render(choice['value'],digital)
            filename=OUTPUT/f"{choice['value']}-{mode.lower()}.png"
            if digital==1 and lua.globals().miniProfiles.get(choice['value'])['digital']==False:
                filename.unlink(missing_ok=True)
            else:
                picture.save(filename)
            parts.append((mode,picture.resize((200,155),Image.Resampling.LANCZOS)))
        for part,(label,picture) in enumerate(parts):
            px=x+16+part*214
            sheet.paste(picture,(px,y+48))
            draw.text((px,y+215),label,font=small,fill='#aab0b1')
    destination=OUTPUT/('reference-analog-digital.png' if source else 'analog-digital.png')
    sheet.save(destination)

    # Review at native size: opposite themes, lighting, warnings, pressure and
    # missing data. Each tile uses exactly 170x132 design pixels, no enlargement.
    scenarios=(('Light','light','fuel',0.6,True,0),('Backlight','dark','fuel',0.6,True,1),
        ('Reserve','dark','fuel',0.08,True,0),('Full','dark','fuel',1,True,0),('Vacuum','dark','boost',0.1,True,0),
        ('Boost','dark','boost',0.98,True,0),('No data','dark','fuel',0,False,0))
    review=Image.new('RGB',(16*170,70+len(scenarios)*156*2),'#121416')
    rd=ImageDraw.Draw(review)
    for col,choice in enumerate(profiles):
        rd.text((col*170+8,12),choice['label'].split(' - ')[0],font=face,fill='#efe5ce')
    for row,(name,theme,kind,value,available,light) in enumerate(scenarios):
        for digital in (0,1):
            y=50+(row*2+digital)*156
            for col,choice in enumerate(profiles):
                review.paste(render(choice['value'],digital,theme,kind,value,available,light),(col*170,y+20))
                rd.text((col*170+6,y),f'{name} / {"A" if digital==0 else "D"}',font=small,fill='#aab0b1')
    review.save(OUTPUT/'native-size-review.png')
    # Integration fixtures are actual complete HUD renders, not recompositions.
    state=harness['state']
    for key,value in dict(available=True,fuel=30,maxFuel=50,fuelNormalized=0.6,
        fuelNeedleNormalized=0.6,turboAvailable=True,turboBoost=0.7,turboDisplayMax=1.5,
        boostNeedleNormalized=0.7/1.5,lightsAvailable=True,headlights=False,
        speedText='139',speedValue=139,rpmText='5200',rpm=5200,
        rpmGaugeNormalized=0.65,rpmWarning=False,rpmRedline=False).items():
        state[key]=value
    for mode,main in (('analog','original'),('digital','orbit')):
        state['gt7Instruments']=None
        options=lua.table_from(dict(theme='dark',gt7SpeedNeedleMode=mode,gt7RpmNeedleMode=mode,
            gt7SpeedDialStyle=main,gt7RpmDialStyle=main,gt7SpeedAuxiliaryStyle='mini_f1c2',
            gt7RpmAuxiliaryStyle='mini_f4c3'))
        calls=harness['draw']('classic',options,state)
        preview.raster(calls).save(OUTPUT/f'hud-{mode}.png')
        state['hybrid']=lua.table_from(dict(powerKw=-38,needle=-0.55,charge=0.84))
        preview.raster(harness['draw']('classic',options,state)).save(OUTPUT/f'hybrid-{mode}.png')
        state['hybrid']=None
    # These crops come from the composed HUD, so primary face layers and the
    # main hand are present when checking whether E/F remain visible.
    legibility=Image.new('RGB',(4*340,8*168+44),'#121416')
    ld=ImageDraw.Draw(legibility)
    ld.text((12,10),'E/F / COMPOSED GT7 HUD / ANALOG + DIGITAL',font=face,fill='#efe5ce')
    for index,choice in enumerate(profiles):
        row,col=divmod(index,4)
        for digital,mode in enumerate(('analog','digital')):
            x,y=col*340,row*336+44+digital*168
            if digital and lua.globals().miniProfiles.get(choice['value'])['digital']==False:
                picture=render(choice['value'],1)
            else:
                options=lua.table_from(dict(theme='dark',gt7SpeedNeedleMode=mode,gt7RpmNeedleMode=mode,
                    gt7SpeedDialStyle='original',gt7RpmDialStyle='original',
                    gt7SpeedAuxiliaryStyle=choice['value'],gt7RpmAuxiliaryStyle=choice['value']))
                state['gt7Instruments']=None
                picture=preview.raster(harness['draw']('classic',options,state)).crop((90,290,260,426))
            legibility.paste(picture,(x+164,y+24))
            ld.text((x+8,y+40),choice['label'].split(' - ')[0],font=face,fill='#efe5ce')
            ld.text((x+8,y+66),mode.upper(),font=small,fill='#969c9e')
    legibility.save(OUTPUT/'hud-label-review.png')
    print(f'Exported {destination.relative_to(ROOT)} and native-size / HUD / hybrid reviews')


if __name__=='__main__':
    main()
