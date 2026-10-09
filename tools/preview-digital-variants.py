"""Preview the five digital Lua dial renderers with simulated telemetry."""
from pathlib import Path
import argparse
import importlib.util
import os
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parent.parent
spec=importlib.util.spec_from_file_location('instrument_preview',ROOT/'tools/preview-instruments.py')
preview=importlib.util.module_from_spec(spec)
spec.loader.exec_module(preview)


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--theme',choices=('dark','light'),default='dark')
    parser.add_argument('--size',type=int,default=620)
    parser.add_argument('--scale',type=float,default=1)
    parser.add_argument('--aux',choices=('turbo','fuel','electric','off'),default='turbo')
    parser.add_argument('--lights-off',action='store_true')
    parser.add_argument('--alerts',action='store_true')
    parser.add_argument('--background-opacity',type=float,default=0.72)
    parser.add_argument('--app-root',type=Path,default=ROOT,
                        help='Actual app directory for CSP-style absolute image lookup')
    parser.add_argument('--background',default='#e8e8e4',help='Scene color visible through transparent openings')
    parser.add_argument('--compare',action='store_true',help='Pair actual renders with the five digital concept references')
    args=parser.parse_args()
    os.chdir(ROOT)
    out=ROOT/'output/digital-variants'
    out.mkdir(parents=True,exist_ok=True)
    lua,h=preview.create_harness()
    lua.globals().__dirname=str(args.app_root.resolve())
    lua.globals().io.fileExists=lambda name: Path(name).is_file()
    state=h['state']
    for key,value in dict(available=True,speedText='139',speedUnit='km/h',gearText='2',
            rpmText='5200',rpm=5200,rpmDisplayLimiter=8000,rpmGaugeLimiter=8000,
            analogNeedleNormalized=0.65,rpmGaugeNormalized=0.65,rpmWarningFraction=0.86,
            rpmRedlineFraction=0.96,turboAvailable=True,turboBoost=0.7,turboDisplayMax=1.5,
            fuel=30,maxFuel=50,fuelNormalized=0.6,brake=0.32,throttle=0.72,clutch=0.2,
            steeringInput=-0.2,steeringAngle=-18,tcLevel=2,absLevel=3,tcSupported=True,
            absSupported=True,lightsAvailable=True,headlights=not args.lights_off,highBeams=False,
            tcActive=True,absActive=True,pitLimiter=False,pitLane=False,
            clock=0.05,leftIndicator=True,rightIndicator=True,hazardLights=True,
            raceFlagType=2 if args.alerts else 0,handbrake=1 if args.alerts else 0,
            rpmWarning=args.alerts,rpmRedline=args.alerts).items():
        state[key]=value
    if args.aux=='electric':
        state['hybrid']=lua.table_from(dict(charge=0.84,powerKw=-38,needle=-0.55,recoveryKw=100,maximumKw=150))
    sheet=Image.new('RGB',(args.size*3,args.size*2+64),'#e8e8e4')
    comparison=Image.new('RGB',(2040,760),'#e8e8e4') if args.compare else None
    reference=Image.open(ROOT/'assets/Futuristic Racing HUD Dashboard Concept Board.png') if args.compare else None
    labels=ImageDraw.Draw(sheet)
    font=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',16)
    for i,name in enumerate(('bridge','column','radial','offset','orbit')):
        options=lua.table_from(dict(instrumentMode='digital',digitalVariant=name,
            analogAuxiliaryMode=args.aux,analogNeedleStyle='a01',hudScale=args.scale,
            theme=args.theme,backgroundOpacity=args.background_opacity))
        calls=h['drawDial'](options,state,lua.table_from((args.size,args.size)))
        image=preview.raster(calls,args.size,args.size,background=args.background)
        image.save(out/f'{name}-{args.theme}-{args.aux}-{args.size}.png')
        x,y=(i%3)*args.size,(i//3)*(args.size+32)
        sheet.paste(image,(x,y+32))
        labels.text((x+12,y+7),f'{(1,2,3,4,6)[i]}  {name}',font=font,fill='#333333')
        if comparison is not None:
            cx,cy=(i%3)*680,(i//3)*380
            # Align physical bezels, rather than the concept board's uneven
            # cell margins, so scale/position differences are meaningful.
            bounds=((46,23,515,489),(540,24,1000,489),(1032,19,1500,491),
                    (47,502,518,969),(532,503,1000,967),(1030,501,1499,966))
            crop=reference.crop(bounds[(0,1,2,3,5)[i]])
            comparison.paste(crop.resize((340,340),Image.Resampling.LANCZOS),(cx,cy+32))
            physical=args.size*args.scale/620
            ox=(args.size-620*physical)/2
            oy=ox-10*physical
            bezel=(ox+18*physical,oy+12*physical,ox+602*physical,oy+596*physical)
            comparison.paste(image.crop(bezel).resize((340,340),Image.Resampling.LANCZOS),(cx+340,cy+32))
            cd=ImageDraw.Draw(comparison)
            cd.text((cx+12,cy+8),f'{(1,2,3,4,6)[i]}  REFERENCIA',font=font,fill='#333333')
            cd.text((cx+352,cy+8),f'{(1,2,3,4,6)[i]}  RENDER LUA',font=font,fill='#333333')
    target=out/f'five-{args.theme}-{args.aux}-{args.size}.png'
    sheet.save(target)
    if comparison is not None:
        comparison.save(out/f'comparison-{args.theme}-{args.aux}.png')
    print(target)


if __name__=='__main__':
    main()
