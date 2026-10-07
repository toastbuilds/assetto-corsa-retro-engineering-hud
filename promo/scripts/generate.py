"""Reproducible promotion exports, executing the original Lua renderers.

python promo/scripts/generate.py --stills
python promo/scripts/generate.py --motion
python promo/scripts/generate.py --validate
No product sources are modified. All time steps are fixed at 1/60 second.
"""
from pathlib import Path
import argparse, hashlib, importlib.util, json, math, os, shutil, subprocess, time
from PIL import Image, ImageDraw, ImageFont, ImageChops

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'promo'
SCRIPTS = OUT / 'scripts'
BG = '#121416'
FPS = 60
FONTS = {}
GLYPHS = {}

def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m

preview = load('promo_existing_preview', ROOT / 'tools/preview-instruments.py')
model = load('promo_demo', SCRIPTS / 'demo_state.py')

def font(size, bold=False):
    key = (max(1, round(size)), bold)
    if key not in FONTS:
        FONTS[key] = ImageFont.truetype('C:/Windows/Fonts/consolab.ttf' if bold else str(preview.FONT), key[0])
    return FONTS[key]

def to_lua(lua, value):
    if isinstance(value, dict): return lua.table_from({k: to_lua(lua,v) for k,v in value.items()})
    if isinstance(value, (list,tuple)): return lua.table_from([to_lua(lua,v) for v in value])
    return value

def raster(calls, size, factor=2, background=BG):
    """Replay original primitives, with nested alpha, real font weight and clips."""
    width,height=size; canvas=Image.new('RGB',(round(width*factor),round(height*factor)),background)
    draw=ImageDraw.Draw(canvas,'RGBA'); clips=[]
    def xy(p): return (round(p['x']*factor),round(p['y']*factor))
    def rgba(c): return tuple(max(0,min(255,round(c[k]*255))) for k in ('r','g','b','mult'))
    for _,c in calls.items():
        kind=c['kind']
        if kind=='clip_push': clips.append((canvas.copy(),(*xy(c['a']),*xy(c['b'])))); continue
        if kind=='clip_pop':
            base,box=clips.pop(); base.paste(canvas.crop(box),box[:2]); canvas=base; draw=ImageDraw.Draw(canvas,'RGBA'); continue
        if kind=='rect_multicolor':
            a,b=xy(c['a']),xy(c['b']); colors=[rgba(c['colors'][i]) for i in range(1,5)]
            # Bilinear authored CSP four-corner colour, including alpha.
            tile=Image.new('RGBA',(max(1,b[0]-a[0]),max(1,b[1]-a[1])))
            td=ImageDraw.Draw(tile)
            for y in range(tile.height):
                ty=y/max(1,tile.height-1)
                left=[colors[0][i]*(1-ty)+colors[3][i]*ty for i in range(4)]
                right=[colors[1][i]*(1-ty)+colors[2][i]*ty for i in range(4)]
                for x in range(tile.width):
                    tx=x/max(1,tile.width-1); td.point((x,y),tuple(round(left[i]*(1-tx)+right[i]*tx) for i in range(4)))
            canvas.paste(tile,a,tile); continue
        color=rgba(c['color']); thick=max(1,round((c['thickness'] or 1)*factor))
        if kind=='text':
            key=(c['text'],round(c['size']*factor),str(c['font']),color)
            if key not in GLYPHS:
                face=font(key[1],'Bold' in key[2]); left,top,right,bottom=face.getbbox(key[0],anchor='lt')
                tile=Image.new('RGBA',(max(1,right-left),max(1,bottom-top)))
                ImageDraw.Draw(tile).text((-left,-top),key[0],font=face,fill=color,anchor='lt')
                GLYPHS[key]=(tile,left,top)
            tile,left,top=GLYPHS[key]; x,y=xy(c['a']); canvas.paste(tile,(x+left,y+top),tile)
        elif kind in ('circle','circle_fill','arc'):
            x,y=xy(c['a']); r=c['radius']*factor; box=(round(x-r),round(y-r),round(x+r),round(y+r))
            if kind=='circle_fill': draw.ellipse(box,fill=color)
            elif kind=='circle': draw.ellipse(box,outline=color,width=thick)
            else: draw.arc(box,math.degrees(c['startAngle']),math.degrees(c['endAngle']),fill=color,width=thick)
        elif kind=='line': draw.line([xy(c['a']),xy(c['b'])],fill=color,width=thick)
        elif kind in ('rect','rect_fill'):
            draw.rounded_rectangle((*xy(c['a']),*xy(c['b'])),radius=(c['rounding'] or 0)*factor,
                fill=color if kind=='rect_fill' else None,outline=color if kind=='rect' else None,width=thick)
        elif kind in ('path','polygon','compound_path'):
            if kind=='compound_path':
                points=[]
                for _,part in c['commands'].items():
                    if part['kind']=='line': points.append(xy(part['a']))
                    else:
                        n=max(16,round(abs(part['endAngle']-part['startAngle'])*part['radius']*factor/2))
                        for i in range(n+1):
                            a=part['startAngle']+(part['endAngle']-part['startAngle'])*i/n
                            points.append((round((part['a']['x']+math.cos(a)*part['radius'])*factor),round((part['a']['y']+math.sin(a)*part['radius'])*factor)))
                filled=c['fill']
            else: points=[xy(p) for _,p in c['points'].items()]; filled=kind=='polygon'
            if filled: draw.polygon(points,fill=color)
            elif points:
                if c['closed']: points.append(points[0])
                draw.line(points,fill=color,width=thick,joint='curve')
        else: raise ValueError('Unsupported primitive: '+kind)
    assert not clips
    if len(GLYPHS)>4000: GLYPHS.clear()
    return canvas

class Harness:
    def __init__(self, panels=False):
        self.lua,self.h=preview.create_harness(); lua=self.lua
        bridge=lua.execute((SCRIPTS/'panels.lua').read_text(encoding='utf8'))
        lua.globals().nativeMeasureText=lambda text,size,desc: lua.globals().vec2(font(size*3,'Bold' in desc).getlength(text)/3,size)
        self.rec=bridge['installRecorder']()
        lua.globals().promoRecorder=self.rec
        lua.execute('''
          local module=require('ui/side_instruments'); local original=module.draw
          module.draw=function(center,scale,state,settings,layout,C,backdrop,rpm,rpmColor)
            local first=promoRecorder.count()+1
            original(center,scale,state,settings,layout,C,backdrop,rpm,rpmColor)
            local key=rpm and 'rpm' or 'speed'
            promoSideRanges=promoSideRanges or {}; promoSideRanges[key]={first=first,last=promoRecorder.count(),center=center}
          end
        ''')
        lua.execute('''
          function promoTranslate(records,dx,dy)
            local offset=vec2(dx,dy)
            for _,c in ipairs(records) do
              if c.a then c.a=c.a+offset end
              if c.b then c.b=c.b+offset end
              if c.points then for i,p in ipairs(c.points) do c.points[i]=p+offset end end
              if c.commands then for _,p in ipairs(c.commands) do p.a=p.a+offset end end
            end
            return records
          end
          demoSim={raceFlagType=0}; demoGrid={}
          ac.getSim=function() return demoSim end
          ac.getCarID=function() return 'retro_promo_gt3' end
          ac.iterateCars=function() return ipairs(demoGrid) end
          package.loaded['src/telemetry']=nil
          promoTelemetry=require('src/telemetry'); promoInstruments=require('src/instrument_state')
          promoState=promoTelemetry.new(); promoOptions=require('src/gt7_settings').current()
          ui.time=function() return promoState.clock end
          function promoStep(car,dt)
            local mode=promoOptions.instrumentMode; promoOptions.instrumentMode='gt7_retro'
            promoTelemetry.update(promoState,dt,promoOptions,car)
            promoOptions.instrumentMode=mode; promoInstruments.update(promoState,promoOptions,dt)
          end
        ''')
        self.state=lua.globals().promoState; self.options=lua.globals().promoOptions
        for k,v in dict(hudScale=.72,opacity=1,backgroundOpacity=.72,theme='dark',instrumentMode='analog',speedUnit='km/h',
            analogNeedleStyle='a01',analogAuxiliaryMode='auto',showSteering=True,showClutch=True,showLights=True,
            showTcAbsLevels=True,gt7SpeedNeedleMode='analog',gt7RpmNeedleMode='analog',gt7SpeedNeedleStyle='b01',
            gt7RpmNeedleStyle='b01',gt7LowerPanelMode='limit',debug=False).items(): self.options[k]=v
        self.panels=None
        if panels:
            lua.globals().nativeTrack=to_lua(lua,json.loads((SCRIPTS/'track.json').read_text()))
            self.panels=bridge['new'](self.rec)
        self.base=model.DemoState(duration=1000,lights_on=999)
        self.time=0

    def step(self, values=None, dt=1/FPS):
        self.time+=dt
        f=self.base.sample(self.time); f.update(values or {})
        lua=self.lua; car=to_lua(lua,f); car.index=0
        car.position=to_lua(lua,dict(x=0,z=0)); car.look=to_lua(lua,dict(x=0,z=1)); car.aabbSize=to_lua(lua,dict(x=1.9,z=4.6))
        car.damage=to_lua(lua,{i:f['damage'].get(k,0) for i,k in enumerate(('front','rear','left','right'))})
        wheels={}
        for i in range(4):
            temp=f.get('tyreTemperatures',[f['tyreTemperature']]*4)[i]
            wheels[i]=dict(tyreCoreTemperature=temp,tyreMiddleTemperature=temp+.7,tyreInsideTemperature=temp+2,
                tyreOutsideTemperature=temp-2,tyreOptimumTemperature=80,tyreWear=f['tyreWear'],tyreDirty=.02,
                tyreGrain=0,tyreBlister=0,tyreFlatSpot=0,suspensionDamage=0,isBlown=False,
                tyrePressure=f.get('tyrePressure',26.5),angularSpeed=100)
            if f.get('wheelSlip') is not None:
                wheels[i].update(load=f.get('wheelLoad',3200),tyreSlip=f['wheelSlip'])
        car.wheels=to_lua(lua,wheels)
        lua.globals().demoGrid=to_lua(lua,[dict(index=1,isConnected=True,position=dict(x=-f.get('radarX',20),z=-1),aabbSize=dict(x=1.9,z=4.6))])
        lua.globals().demoSim.raceFlagType=f['raceFlagType']
        lua.globals().promoStep(car,dt)
        if f.get('electricKw') is not None:
            physics=to_lua(lua,dict(isAvailable=True,wheels={i:dict(electricTorque=f['electricKw']*2.5) for i in range(4)}))
            lua.eval("require('src/hybrid').update")(self.state,car,dt,physics)
        if self.panels:
            lua.globals().demoFrame=to_lua(lua,f); self.panels['step'](self.time,dt)
        return f

    def draw(self, kind='gt7', preset='classic', factor=2, size=None):
        lua=self.lua
        if self.panels and kind in ('relative','board','circuit','delta_native','timer_native','laps_native','inputs_native'):
            calls=self.panels['draw'](kind); dim=self.panels['sizes'][kind]; native=(dim[1],dim[2])
        else:
            native=size or ((620,620) if kind=='dial' else (640,560) if kind=='condition' else (1560,500) if preset=='outer_pedals' else (1440,500))
            self.rec['reset'](*native)
            if kind=='dial': self.h['drawDial'](self.options,self.state,to_lua(lua,native))
            elif kind=='condition': lua.eval("require('ui/car_condition').draw")(self.state,self.options)
            else:
                options=self.options
                if preset!='classic':
                    options=to_lua(lua,dict(self.options.items()))
                    for key,value in lua.eval("require('src/gt7_retro_layout').preset")(preset,self.options).items(): options[key]=value
                self.h['draw'](preset,options,self.state,to_lua(lua,native))
            calls=self.rec['calls']()
            if kind in ('rpm','speed'):
                bounds=lua.globals().promoSideRanges[kind]; end=bounds['last']
                # Include the authored bezel calls immediately after the component.
                while end<len(calls):
                    c=calls[end+1]
                    if c['kind']!='circle' or abs(c['a']['x']-bounds['center']['x'])>.001: break
                    end+=1
                calls=to_lua(lua,[calls[i] for i in range(bounds['first'],end+1)])
                x=0 if kind=='speed' else 1084
                calls=lua.globals().promoTranslate(calls,-x,-76)
                return raster(calls,(356,364),factor)
        if factor>=3: factor=max(factor,math.ceil(1080/min(native)))
        return raster(calls,native,factor)

def padded(picture, minimum=1080):
    minimum=max(minimum,1024)
    scale=minimum/min(picture.size)
    # Image was internally rasterized at 3x; final export uses that resolution.
    image=picture.resize((round(picture.width*scale),round(picture.height*scale)),Image.Resampling.LANCZOS)
    margin=round(minimum*.04); result=Image.new(picture.mode,(image.width+margin*2,image.height+margin*2),(0,0,0,0) if picture.mode=='RGBA' else BG)
    result.paste(image,(margin,margin)); return result

def sheet(items,path,columns=3,width=2560):
    cellw=width//columns; cellh=round(cellw*.87); rows=math.ceil(len(items)/columns)
    image=Image.new('RGB',(width,rows*cellh),BG); draw=ImageDraw.Draw(image)
    for i,(label,picture) in enumerate(items):
        pic=picture.copy(); pic.thumbnail((cellw-50,cellh-95),Image.Resampling.LANCZOS)
        x=(i%columns)*cellw+(cellw-pic.width)//2; y=(i//columns)*cellh+20+(cellh-95-pic.height)//2
        label_size=min(32,max(14,round(32*(cellw-50)/max(cellw-50,font(32).getlength(label)))))
        image.paste(pic,(x,y)); draw.text(((i%columns)*cellw+25,(i//columns+1)*cellh-52),label,font=font(label_size),fill='#f2dbae')
    path.parent.mkdir(parents=True,exist_ok=True); image.save(path)

def digest():
    return {p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
        for d in ('src','ui','modules','free-edition','assets') for p in sorted((ROOT/d).rglob('*')) if p.is_file()}

def save(image,path,records,**meta):
    path=OUT/path; path.parent.mkdir(parents=True,exist_ok=True); image.save(path)
    records.append(dict(path=path.relative_to(OUT).as_posix(),width=image.width,height=image.height,**meta))
    print(path.relative_to(OUT),flush=True)

def fixture(h, **values):
    data=dict(rpm=5200,speedKmh=139,gear=3,gas=.7,brake=0,fuel=30,turboBoost=.7,headlightsActive=False,steer=0)
    data.update(values)
    for _ in range(180): h.step(data)
    return data

def inventory():
    h=Harness(); config=h.lua.eval("require('src/instrument_config')")
    rows=[
        ('Dial','independent','analog / digital','idle, shift, redline, lights, flags, pedals, TC/ABS, pits','dial_*'),
        ('GT7','classic / modern / outer_pedals / steering_dial','independent analog / digital side dials','speed, RPM, gear, steering, radar, flags, status','gt7_*'),
        ('Speedometer + fuel','GT7 left','analog / digital','minimum, medium, maximum; fuel reserve <15%; fuel slosh','speedometer_*'),
        ('Tachometer + auxiliary','GT7 right','analog / digital','idle, 86% warning, 96% redline, shift','tachometer_*'),
        ('Turbo','dial auxiliary / GT7','analog / digital','estimated vacuum -0.5 bar, partial, full >=90%','turbo_*'),
        ('AERO','GT7 without turbo/hybrid; standalone forced Turbo without turbo','analog / digital GT7; analog standalone','visual speed² fallback / measured coefficient CL / inferred downforce kN','aero_*'),
        ('Hybrid','dial auxiliary / GT7; measured kW / ERS fallback','analog / digital GT7; analog independent','CHG/PWR, battery SOC, fallback charge recovery','hybrid_*'),
        ('Needles','24 A01-D06 + fixed subNeedle','analog','same 5200 RPM, identical scale/lights','needles/individual/*; subNeedle.png'),
        ('Pedals / steering','classic / modern; inner / outer; line / graduated / dial','GT7 + Dial','ABS white brake caps, TC red accelerator caps; clutch','gt7_*; controls'),
        ('Radar','arcs / classic_lights / modern_bars / column_3 / column_9','GT7','left / right; proximity blink; flag priority','radar_*'),
        ('Flags','classic_lights / modern_strips / column_3 / column_9','GT7 + Dial','yellow / blue / white / green / red / checkered','flag_*'),
        ('Lower panel','limit / ffb / pedal_history / invisible','GT7; classic / modern / wide frame','grip-limit alerts; FFB needle; five-second pedal traces','lower_*'),
        ('Condition','general / uniform / surface; life / pressure / temperature','digital readouts','wear, cold / optimum / hot; core / surface / blend; pressure current / delta; damage; detail','condition_*'),
        ('Relative','all classes / same class','table','gaps; lap markers; pits; weather; sectors','relative_*'),
        ('Leaderboard','Practice / Qualify / Race; General / Class sectors','table 3-10 rows','sectors; position changes; fuel estimate; pit state','leaderboard_*'),
        ('Map','full / mini heading / mini fixed; dots / surface; selected / all numbers','map','player, leader, lapped; off-track warning; caution','map_*'),
        ('Delta','full / minimized / barOnly; six timing references','digital bar','negative / positive delta; sector; notifications','delta_*'),
        ('Timer','current / lap result','digital','valid / invalid, final lap, pit; result transition','timer_*'),
        ('Laps','current + history','digital','progress, pit, faster / slower / invalid laps; row transition','laps_*'),
        ('Telemetry','auto / left / right; expanded / collapsed','digital graphs','throttle, brake, clutch, FFB, optional handbrake','telemetry_*'),
    ]
    text='# Retro HUD — inventario y checklist\n\nAuditoría previa al render. Las casillas se completan después de ejecutar y validar los assets. Premium es la edición activa; Free tiene un GT7 Classic propio. No existen diales independientes de temperatura de motor, presión de aceite o voltaje: presión y temperatura corresponden a neumáticos; batería a híbridos. Assets conceptuales en assets/ no se publican como instrumentos.\n\n| Cobertura | Instrumento | Variante | Modos | Estados interesantes | Animado | Assets previstos |\n|---|---|---|---|---|---|---|\n'
    for name,var,mode,states,assets in rows: text+=f'| [ ] | {name} | {var} | {mode} | {states} | Sí | {assets} |\n'
    text+='\n## Agujas del catálogo real\n\n'
    for _,key in config['needleOrder'].items(): text+=f'- [ ] `{key}` — {config["needleNames"][key]}\n'
    text+='- [ ] `subNeedle` — miniaguja fija fuel/boost (no seleccionable)\n\n## Configuraciones y comportamiento\n\nTemas dark/light; km/h/mph; psi/bar/kPa; C/F. Opacidad global y fondo, escalado uniforme; indicadores, luces, dirección y clutch se pueden ocultar. Respuesta original por resortes de RPM/velocidad/turbo/fuel; fuel incorpora slosh; luces GT7 ease-out 220 ms, mezcla de modos 150 ms; intermitentes, radar, flags y redline parpadean según el reloj original. No se combinan todos los productos cartesianos de configuraciones: se captura cada variante discreta y casos representativos de ajustes continuos.\n\n## Configuración completa leída del proyecto\n\n'
    sources=sorted(set(list((ROOT/'src').glob('*settings.lua'))+list((ROOT/'modules').rglob('*settings.lua'))+[ROOT/'modules/relative/main.lua']))
    for p in sources:
        lines=p.read_text(encoding='utf-8-sig').splitlines()
        interesting=[line.strip() for line in lines if any(x in line for x in ('value=', 'value =',' = ac.storage',' = false',' = true','modeChoices','minimum','maximum'))]
        text+=f'### `{p.relative_to(ROOT).as_posix()}`\n\n```lua\n'+'\n'.join(interesting)+'\n```\n\n'
    (OUT/'INVENTORY.md').write_text(text,encoding='utf8')
    (OUT/'source-audit.json').write_text(json.dumps(digest(),indent=2),encoding='utf8')

def stills():
    records=[]; overview=[]; analog=[]; digital=[]; h=Harness(); config=h.lua.eval("require('src/instrument_config')")
    for mode in ('analog','digital'):
        h.options.instrumentMode=mode; fixture(h)
        image=padded(h.draw('dial',factor=4)); save(image,Path(f'instruments/{mode}/dial_{mode}.png'),records,instrument='Dial',mode=mode)
        overview.append(('Dial '+mode,image)); (analog if mode=='analog' else digital).append(('Dial '+mode,image))
        for level,rpm in [('idle',900),('mid',4000),('warning',7100),('redline',7850)]:
            fixture(h,rpm=rpm,speedKmh=0 if level=='idle' else 139)
            save(padded(h.draw('dial',factor=4)),Path(f'instruments/{mode}/dial_{level}.png'),records,instrument='Dial',state=level)
    for preset in ('classic','modern','outer_pedals','steering_dial'):
        for mode in ('analog','digital'):
            h.options.gt7SpeedNeedleMode=h.options.gt7RpmNeedleMode=mode; fixture(h)
            image=padded(h.draw(preset=preset,factor=4),minimum=900)
            save(image,Path(f'instruments/{mode}/gt7_{preset}.png'),records,instrument='GT7',preset=preset,mode=mode)
            (analog if mode=='analog' else digital).append((preset+' '+mode,image))
            if preset=='classic': overview.append(('GT7 '+mode,image))
    # Crop original classic drawing in its native coordinates, with generous borders.
    def side(which):
        return padded(h.draw('speed' if which=='speedometer' else 'rpm',factor=4),minimum=1080)
    for mode in ('analog','digital'):
        h.options.gt7SpeedNeedleMode=h.options.gt7RpmNeedleMode=mode
        for level,fraction in [('minimum',0),('mid',.5),('high',.75),('maximum',.98)]:
            fixture(h,rpm=max(900,round(fraction*8000)),speedKmh=round(fraction*320),fuel=max(3,50*(1-fraction)),turboBoost=1.5*fraction)
            for which in ('speedometer','tachometer'):
                save(side(which),Path(f'instruments/{mode}/{which}_{level}.png'),records,instrument=which,state=level)
        for theme in ('dark','light'):
            h.options.theme=theme
            for lights in (False,True):
                fixture(h,headlightsActive=lights)
                for which in ('speedometer','tachometer'):
                    save(side(which),Path(f'lighting/{which}_{mode}_{theme}/lights_{"on" if lights else "off"}.png'),records,instrument=which,lights=lights)
        h.options.theme='dark'
    for which in ('speedometer','tachometer'):
        a=Image.open(OUT/f'instruments/analog/{which}_mid.png'); d=Image.open(OUT/f'instruments/digital/{which}_mid.png')
        sheet([('Analog',a),('Digital',d)],OUT/f'instruments/comparisons/{which}_analog_vs_digital.png',2)
    sheet([(m,Image.open(OUT/f'instruments/{m}/dial_{m}.png')) for m in ('analog','digital')],OUT/'instruments/comparisons/dial_analog_vs_digital.png',2)
    needles=[]; h.options.gt7SpeedNeedleMode=h.options.gt7RpmNeedleMode='analog'; fixture(h)
    for _,key in config['needleOrder'].items():
        h.options.gt7RpmNeedleStyle=key; image=side('tachometer')
        save(image,Path(f'needles/individual/{key}.png'),records,instrument='needle',needle=key)
        needles.append((config['needleNames'][key],image))
    sheet(needles,OUT/'needles/needles_overview.png',4,3840)
    h.options.gt7RpmNeedleStyle='b01'
    save(side('tachometer'),Path('needles/individual/subNeedle.png'),records,instrument='fixed auxiliary needle')
    for mode in ('analog','digital'):
        h.options.gt7SpeedNeedleMode=h.options.gt7RpmNeedleMode=mode
        for label,extra in [('vacuum',dict(turboBoost=0,gas=0)),('partial',dict(turboBoost=.65)),('maximum',dict(turboBoost=1.5))]:
            fixture(h,**extra); save(side('tachometer'),Path(f'instruments/{mode}/turbo_{label}.png'),records,instrument='Turbo',state=label)
        for label,power in [('regeneration',-80),('zero',0),('partial',60),('maximum',150)]:
            fixture(h,kersPresent=True,kersCharge=.72,turboCount=0,electricKw=power)
            save(side('tachometer'),Path(f'instruments/{mode}/hybrid_{label}.png'),records,instrument='Hybrid',state=label)
        fixture(h,kersPresent=True,kersCharge=.72,turboCount=0,kersInput=.7)
        save(side('tachometer'),Path(f'instruments/{mode}/hybrid_ers_fallback.png'),records,instrument='Hybrid',state='ERS fallback')
    h.options.instrumentMode='analog'
    for aux in ('auto','turbo','electric','fuel','off'):
        h.options.analogAuxiliaryMode=aux; fixture(h,kersPresent=True,kersCharge=.72,electricKw=120)
        save(padded(h.draw('dial',factor=4)),Path(f'instruments/analog/dial_auxiliary_{aux}.png'),records,instrument='Dial auxiliary',variant=aux)
    h.options.analogAuxiliaryMode='auto'
    # Independent configuration choices, one varying setting per capture.
    variants={'gt7SpeedStyle':['classic','modern','large'],'gt7GearStyle':['classic','modern','high'],
        'gt7SteeringStyle':['classic','modern','dial'],'gt7PedalPosition':['inner','outer'],'gt7PedalStyle':['classic','modern'],
        'gt7RadarPresentation':['arcs','classic_lights','modern_bars','column_3','column_9'],
        'gt7FlagPresentation':['classic_lights','modern_strips','column_3','column_9'],
        'gt7LowerPanelMode':['limit','ffb','pedal_history','invisible'],'gt7LowerFrameStyle':['classic','modern','wide']}
    for key,values in variants.items():
        before=h.options[key]
        for value in values:
            h.options[key]=value; fixture(h,radarX=2.8 if 'Radar' in key else 20,raceFlagType=2 if 'Flag' in key else 0,steer=110)
            save(padded(h.draw(factor=3),minimum=800),Path(f'instruments/variants/{key}_{value}.png'),records,instrument='GT7 configuration',setting=key,variant=value)
        h.options[key]=before
    for label,extra in [('assists',dict(absInAction=True,tractionControlInAction=True,brake=.9,gas=.9)),
        ('pit',dict(isInPit=True,manualPitsSpeedLimiterEnabled=True)),('damage',dict(engineLifeLeft=100,gearboxDamage=.7)),
        ('indicators',dict(hazardLights=True)),('reverse',dict(gear=-1)),('neutral',dict(gear=0))]:
        fixture(h,**extra); save(padded(h.draw(factor=3),800),Path(f'instruments/variants/status_{label}.png'),records,instrument='status',state=label)
    h.options.gt7FlagPresentation='modern_strips'
    for flag,name in [(0,'green'),(2,'yellow'),(3,'slippery'),(4,'red'),(5,'black'),(6,'white'),(9,'mechanical'),(10,'split'),(12,'blue'),(13,'checkered'),(16,'purple')]:
        fixture(h,raceFlagType=flag); save(padded(h.draw(factor=3),800),Path(f'instruments/variants/flag_{name}.png'),records,instrument='flag',flag=flag)
    fixture(h); h.options.numericMetric='life'; h.options.lifeTextSize=24; h.options.lifeTextWeight='Regular'; h.options.legendMode='temperature'; h.options.temperatureDisplay='general'
    condition_items=[]
    for theme in ('dark','light'):
        h.options.theme=theme
        for metric,readouts in [('life',['remaining']),('pressure',['current','delta']),('temperature',['core','surface','blend'])]:
            for readout in readouts:
                h.options.numericMetric=metric; h.options.pressureReadout=readout; h.options.temperatureReadout=readout
                for i,w in h.state.condition.wheels.items():
                    w.pressure=26.2+i*.2; w.idealPressure=26.5; w.optimumTemperatureMin=75; w.optimumTemperatureMax=85
                image=padded(h.draw('condition',factor=3))
                save(image,Path(f'instruments/digital/condition_{metric}_{readout}_{theme}.png'),records,instrument='Condition',variant=readout)
                if theme=='dark': condition_items.append((metric+' '+readout,image))
        for temp,label in [(50,'cold'),(80,'optimal'),(110,'hot')]:
            fixture(h,tyreTemperature=temp); h.options.numericMetric='temperature'; h.options.temperatureReadout='core'
            save(padded(h.draw('condition',factor=3)),Path(f'instruments/digital/condition_{label}_{theme}.png'),records,instrument='Condition',state=label)
    h.options.theme='dark'; overview.append(('Condition',condition_items[0][1])); digital.append(('Condition',condition_items[0][1]))
    sheet(condition_items,OUT/'overview/condition_readouts.png',3)
    p=Harness(panels=True); fixture(p)
    names={'relative':'relative','board':'leaderboard','circuit':'map','delta_native':'delta','timer_native':'timer','laps_native':'laps','inputs_native':'telemetry'}
    for key,name in names.items():
        image=padded(p.draw(key,factor=3),1080 if key=='circuit' else 700)
        save(image,Path(f'instruments/digital/{name}_default.png'),records,instrument=name)
        overview.append((name,image)); digital.append((name,image))
    for mode in ('full','mini'):
        for orient in ('heading','fixed') if mode=='mini' else ('fixed',):
            for bg in ('dots','surface'):
                settings=p.lua.eval("require('modules/map/src/settings').values"); settings.mode=mode; settings.miniOrientation=orient; settings.backgroundMode=bg
                image=padded(p.draw('circuit',factor=3)); save(image,Path(f'instruments/digital/map_{mode}_{orient}_{bg}.png'),records,instrument='Map',variant=mode+' '+orient+' '+bg)
    for arrangement,expanded in [('left',True),('right',True),('auto',True),('left',False)]:
        settings=p.lua.eval("require('modules/telemetry/src/settings').values"); settings.layout=arrangement; settings.graphExpanded=expanded
        save(padded(p.draw('inputs_native',factor=3),700),Path(f'instruments/digital/telemetry_{arrangement}_{"expanded" if expanded else "collapsed"}.png'),records,instrument='Telemetry',variant=arrangement)
    for label,extra in [('invalid',dict(isLapValid=False)),('final_lap',dict(finalLap=True)),('pit',dict(isInPit=True))]:
        fixture(p,**extra); save(padded(p.draw('timer_native',factor=3),700),Path(f'instruments/digital/timer_{label}.png'),records,instrument='Timer',state=label)
    sheet(overview,OUT/'overview/all_instruments.png',3,3840); sheet(analog,OUT/'overview/analog_instruments.png',2,3840); sheet(digital,OUT/'overview/digital_instruments.png',3,3840)
    sheet([(f'{which} {mode} {lamp}',Image.open(OUT/f'lighting/{which}_{mode}_dark/lights_{lamp}.png'))
        for which in ('speedometer','tachometer') for mode in ('analog','digital') for lamp in ('off','on')],OUT/'overview/lighting_comparison.png',4,3840)
    (OUT/'stills-manifest.json').write_text(json.dumps(records,indent=2),encoding='utf8')

def encoder():
    candidates=[shutil.which('ffmpeg'),str(ROOT/'brag-output-2026-10-02-115847/composition/node_modules/ffmpeg-static/ffmpeg.exe')]
    exe=next((p for p in candidates if p and Path(p).is_file()),None)
    if not exe: raise RuntimeError('Install ffmpeg and put it on PATH')
    return exe

def motion_values(t,kind):
    # Closed, realistic eight-second demonstration with one change of gear.
    def lerp(points):
        for (a,x),(b,y) in zip(points,points[1:]):
            if t<=b: return x+(y-x)*max(0,(t-a)/(b-a))
        return points[-1][1]
    rpm=lerp([(0,1600),(.7,1600),(3.4,7900),(3.65,7900),(3.95,5100),(5.1,6900),(7.1,1600),(8,1600)])
    speed=lerp([(0,30),(.7,30),(3.7,105),(5.1,150),(7.1,30),(8,30)])
    gas=0 if t<.7 or t>5.1 else (.1 if 3.65<t<3.95 else min(.85,(t-.7)/.4*.85))
    values=dict(rpm=rpm,speedKmh=speed,gear=2 if t<3.8 or t>=6.7 else 3,gas=gas,
        brake=.6 if 5.1<t<6.9 else 0,turboBoost=max(0,gas*1.5),fuel=30,
        steer=90*math.sin(2*math.pi*t/8),headlightsActive=False,radarX=20)
    if kind=='lights': values.update(rpm=5200,speedKmh=139,gear=3,gas=.7,brake=0,turboBoost=.7,headlightsActive=2<t<5.5,steer=0)
    if kind=='hybrid':
        power=lerp([(0,0),(.8,0),(1.6,-80),(2.6,-80),(3.2,0),(4.1,60),(5.2,150),(5.8,150),(7,0),(8,0)])
        values.update(kersPresent=True,kersCharge=.7,turboCount=0,electricKw=power)
    if kind=='fuel': values.update(fuel=30,acceleration={'x':math.sin(t*2*math.pi/8)*1.2,'y':0,'z':math.cos(t*2*math.pi/8)*.8})
    if kind=='controls': values.update(hazardLights=.7<t<7,radarX=3 if 1<t<6 else 20,raceFlagType=2 if 2<t<5 else 0,
        absInAction=5.4<t<6.1,tractionControlInAction=4.2<t<4.7)
    if kind=='condition': values.update(tyreTemperature=80+2*math.sin(t*2*math.pi/8),tyreWear=.1)
    if kind=='mode_transition': values.update(rpm=5200,speedKmh=139,gear=3,gas=.7,brake=0,turboBoost=.7,steer=0)
    if kind=='turbo':
        boost=lerp([(0,0),(.8,0),(2,.65),(3.5,1.5),(4.6,1.5),(6,0),(8,0)])
        values.update(rpm=5200,speedKmh=139,gear=3,gas=.1 if t<.8 or t>6 else .9,
            brake=0,turboBoost=boost,steer=0)
    if kind=='aero': values.update(turboCount=0,aeroLiftFront=.7,aeroLiftRear=1.1)
    if kind=='limit': values.update(wheelSlip=.2+.75*math.sin(math.pi*t/8)**2)
    if kind=='battery': values.update(kersPresent=True,kersCharge=.7+.01*math.sin(math.pi*t/8)**2,turboCount=0,kersInput=.5 if 4<t<6 else 0,kersCharging=.7<t<3)
    if kind=='timing':
        time_ms=129645+t*1000 if t<3 else (t-3)*1000
        values.update(lap=8 if t<3 else 9,currentLapTimeMs=time_ms,lapProgress=time_ms/132645,
            transitionStartedAt=6 if t>=3 else None,
            lapHistory=[dict(number=8,time=132645,status='session_best'),dict(number=7,time=133210,status='slower'),dict(number=6,time=132910,status='slower')] if t>=3 else None)
        if 3<t<6: values['result']=dict(time=132645,delta=-565,status='session_best',valid=True)
    if kind=='delta':
        values.update(delta=.4*math.cos(2*math.pi*t/8),speedDelta=5*math.sin(2*math.pi*t/8))
        if t>2: values['notification1']=dict(kind='lap',createdAt=5,lapNumber=7,lapTime=132645,lapDelta=-565,valid=True)
    if kind=='map': values.update(wheelsOutside=4 if 2<t<5 else 0)
    return values

def transparent(calls,size,factor=3):
    """Recover straight alpha from the same exact calls over black and white.

    Both backgrounds are composited by the existing primitive adapter; no
    chroma key, masking, removal of product surfaces or palette edits.
    """
    import numpy as np
    black=np.asarray(raster(calls,size,factor,'#000000')).astype(np.float32)/255
    white=np.asarray(raster(calls,size,factor,'#ffffff')).astype(np.float32)/255
    alpha=np.clip(1-(white-black).mean(axis=2),0,1)
    color=np.clip(black/np.maximum(alpha[:,:,None],1/255),0,1)
    return Image.fromarray(np.rint(np.dstack((color,alpha))*255).astype(np.uint8))

def extras():
    records=json.loads((OUT/'stills-manifest.json').read_text()); h=Harness()
    h.options.speedUnit='km/h'; h.options.temperatureUnit='C'; h.options.pressureUnit='psi'
    def export(name,kind='gt7',**meta):
        im=padded(h.draw(kind,factor=4),1080 if kind in ('dial','rpm','speed','condition') else 800)
        save(im,Path(name),records,**meta); return im
    for theme in ('dark','light'):
        h.options.theme=theme
        for mode in ('analog','digital'):
            h.options.instrumentMode=mode; h.options.gt7SpeedNeedleMode=h.options.gt7RpmNeedleMode=mode
            for on in (False,True):
                fixture(h,headlightsActive=on)
                export(f'lighting/dial_{mode}_{theme}/lights_{"on" if on else "off"}.png','dial',instrument='Dial',lights=on)
            fixture(h)
            export(f'instruments/{mode}/gt7_classic_{theme}_kmh.png',instrument='GT7',theme=theme,unit='km/h')
    h.options.theme='dark'; h.options.instrumentMode='analog'; h.options.gt7SpeedNeedleMode=h.options.gt7RpmNeedleMode='analog'
    fixture(h)
    mini=h.draw('rpm',factor=4).crop((100*4,207*4,260*4,355*4))
    save(padded(mini),Path('needles/individual/subNeedle.png'),records,instrument='fixed fuel/boost mini needle')
    for theme in ('dark','light'):
        h.options.theme=theme
        for display in ('general','uniform','surface'):
            h.options.temperatureDisplay=display; h.options.numericMetric='temperature'; h.options.temperatureReadout='blend'; h.options.legendMode='temperature'
            fixture(h,tyreTemperatures=[68,80,92,108])
            export(f'instruments/digital/condition_zones_{display}_{theme}.png','condition',instrument='Condition',variant=display)
        for legend in ('temperature','grip','none'):
            h.options.legendMode=legend; fixture(h)
            export(f'instruments/digital/condition_legend_{legend}_{theme}.png','condition',instrument='Condition',variant=legend)
    h.options.theme='dark'; h.options.legendMode='temperature'; h.options.temperatureDisplay='general'
    for metric,unitkey,units in [('pressure','pressureUnit',['psi','bar','kPa']),('temperature','temperatureUnit',['C','F'])]:
        h.options.numericMetric=metric; h.options.pressureReadout='current'; h.options.temperatureReadout='core'
        for unit in units:
            h.options[unitkey]=unit; fixture(h)
            export(f'instruments/digital/condition_units_{unit}.png','condition',instrument='Condition',unit=unit)
    # Detail window is an actual callback emitted by Condition, outside its main surface.
    h.lua.execute('''
      ac.getUI=function() return {windowSize=vec2(1920,1080)} end
      ui.transparentWindow=function(id,pos,size,noPadding,inputs,content) promoDetail={size=size,content=content} end
    ''')
    h.options.keepDetailsOpen=True; fixture(h); h.draw('condition')
    detail=h.lua.globals().promoDetail
    if detail:
        w,hh=round(detail['size']['x']),round(detail['size']['y']); h.rec['reset'](w,hh)
        h.lua.globals().ui.pushDWriteFont(h.lua.eval("require('src/theme').fonts.utility")); detail['content'](); h.lua.globals().ui.popDWriteFont()
        save(padded(raster(h.rec['calls'](),(w,hh),3),900),Path('instruments/digital/condition_detail.png'),records,instrument='Condition detail')
    h.options.keepDetailsOpen=False
    # Continuous options: neutral + each extreme, without geometry edits.
    for key,values in {'gt7DialScale':[.75,1,1.25],'gt7DialSpacing':[0,160],'gt7IndicatorScale':[.65,1,1.5]}.items():
        old=h.options[key]
        for value in values:
            h.options[key]=value; fixture(h); export(f'instruments/variants/{key}_{value}.png',instrument='GT7 scale',setting=key,value=value)
        h.options[key]=old
    h.options.gt7SpeedNeedleMode='analog'; h.options.gt7RpmNeedleMode='digital'; fixture(h)
    export('instruments/comparisons/gt7_mixed_modes.png',instrument='GT7 mixed modes')
    h.options.gt7RpmNeedleMode='analog'
    for mode in ('analog','digital'):
        h.options.instrumentMode=mode; fixture(h,kersPresent=True,turboCount=0,kersCharge=.85,electricKw=-80)
        export(f'instruments/{mode}/dial_hybrid_regeneration.png','dial',instrument='Dial hybrid')
    # Transparent replays of the actual component surfaces.
    fixture(h); h.options.instrumentMode='analog'
    for kind,name,size in [('dial','dial_analog',(620,620)),('gt7','gt7_analog',(1440,500))]:
        h.draw(kind,factor=1); im=transparent(h.rec['calls'](),size,3)
        save(padded(im,1080 if kind=='dial' else 800),Path(f'instruments/transparent/{name}.png'),records,instrument=name,alpha='straight RGBA')
    p=Harness(panels=True); fixture(p)
    for theme in ('dark','light'):
        p.panels['theme'](theme)
        for kind,name in [('relative','relative'),('board','leaderboard'),('circuit','map'),('delta_native','delta'),('timer_native','timer'),('laps_native','laps'),('inputs_native','telemetry')]:
            save(padded(p.draw(kind,factor=3),700),Path(f'instruments/digital/{name}_{theme}.png'),records,instrument=name,theme=theme)
    p.panels['theme']('dark')
    for session,label in [(1,'practice'),(2,'qualify'),(3,'race')]:
        p.panels.session.type=session; fixture(p)
        save(padded(p.draw('board',factor=3),700),Path(f'instruments/digital/leaderboard_{label}.png'),records,instrument='Leaderboard',session=label)
    for reference in ('General','Class'):
        p.panels.leaderSettings.sectorReference=reference; fixture(p)
        save(padded(p.draw('board',factor=3),700),Path(f'instruments/digital/leaderboard_sectors_{reference}.png'),records,instrument='Leaderboard',variant=reference)
    for rows in (3,10):
        p.panels.leaderSettings.maxRows=rows; fixture(p)
        save(padded(p.draw('board',factor=3),700),Path(f'instruments/digital/leaderboard_rows_{rows}.png'),records,instrument='Leaderboard',rows=rows)
    for mode,label in [(0,'all_classes'),(1,'same_class')]:
        p.panels.relativeSettings.mode=mode; fixture(p)
        save(padded(p.draw('relative',factor=3),700),Path(f'instruments/digital/relative_{label}.png'),records,instrument='Relative',variant=label)
    for mode in ('full','minimized','barOnly'):
        p.panels.deltaSettings.minimized=mode=='minimized'; p.panels.deltaSettings.barOnly=mode=='barOnly'
        fixture(p,delta=-.27)
        save(padded(p.draw('delta_native',factor=3),700),Path(f'instruments/digital/delta_{mode}.png'),records,instrument='Delta',variant=mode)
    p.panels.deltaSettings.minimized=p.panels.deltaSettings.barOnly=False
    for reference in ('SESSION LAP','SESSION OPTIMAL','FASTEST LAP','FASTEST OPTIMAL','PREVIOUS LAP','MULTIPLAYER LAP'):
        fixture(p,deltaMode=reference)
        save(padded(p.draw('delta_native',factor=3),700),Path(f'instruments/digital/delta_reference_{reference.lower().replace(" ","_")}.png'),records,instrument='Delta reference',variant=reference)
    for status in ('session_best','personal_best','slower','invalid'):
        fixture(p,result=dict(time=132110,delta=-535 if 'best' in status else 400,status=status,valid=status!='invalid'))
        save(padded(p.draw('timer_native',factor=3),700),Path(f'instruments/digital/timer_result_{status}.png'),records,instrument='Timer result',status=status)
    settings=p.lua.eval("require('modules/map/src/settings').values")
    for numbers in ('selected','all'):
        settings.numberMode=numbers; fixture(p)
        save(padded(p.draw('circuit',factor=3)),Path(f'instruments/digital/map_numbers_{numbers}.png'),records,instrument='Map',numbers=numbers)
    settings.backgroundMode='surface'; fixture(p,raceFlagType=2)
    save(padded(p.draw('circuit',factor=3)),Path('instruments/digital/map_caution.png'),records,instrument='Map',state='caution')
    # Free uses its shipped Lua files, in an isolated runtime.
    free=Harness(); fixture(free); free.lua.execute("package.loaded['src/gt7_retro_layout']=nil; package.loaded['src/theme']=nil; package.path='./free-edition/?.lua;'..package.path")
    free_renderer=free.lua.execute((ROOT/'free-edition/ui/gt7_retro.lua').read_text(encoding='utf8'))
    for mode in ('analog','digital'):
        free.options.gt7SpeedNeedleMode=free.options.gt7RpmNeedleMode=mode; fixture(free)
        free.rec['reset'](1440,500); free.h['drawRenderer'](free_renderer,free.state,free.options,to_lua(free.lua,(1440,500)))
        save(padded(raster(free.rec['calls'](),(1440,500),3),800),Path(f'instruments/{mode}/gt7_free_classic.png'),records,instrument='GT7 Free',mode=mode)
    (OUT/'stills-manifest.json').write_text(json.dumps(records,indent=2),encoding='utf8')

def motion(selected=None,manifest_name='motion-manifest.json'):
    manifest_path=OUT/Path(manifest_name).name
    ff=encoder(); records=json.loads(manifest_path.read_text()) if manifest_path.exists() else []
    shots=[('tachometer_analog','rpm','analog','drive'),('tachometer_digital','rpm','digital','drive'),
        ('speedometer_analog','speed','analog','drive'),('speedometer_digital','speed','digital','drive'),
        ('turbo_analog','rpm','analog','turbo'),('turbo_digital','rpm','digital','turbo'),
        ('dial_analog','dial','analog','drive'),('dial_digital','dial','digital','drive'),
        ('gt7_analog','gt7','analog','drive'),('gt7_digital','gt7','digital','drive'),
        ('backlighting_analog','gt7','analog','lights'),('backlighting_digital','gt7','digital','lights'),
        ('hybrid_analog','rpm','analog','hybrid'),('hybrid_digital','rpm','digital','hybrid'),
        ('fuel_slosh','speed','analog','fuel'),('controls_radar_flags','gt7','analog','controls'),
        ('analog_digital_transition','gt7','analog','mode_transition'),('condition_temperature','condition','digital','condition')]
    shots += [('hybrid_standalone','dial','analog','hybrid'),('hybrid_battery_recovery','rpm','analog','battery'),
        ('aero_analog','rpm','analog','aero'),('aero_digital','rpm','digital','aero'),
        ('grip_limit','gt7','analog','limit'),('ffb','gt7','analog','drive')]
    shots += [('gt7_modern','gt7','analog','drive'),('gt7_outer_pedals','gt7','analog','drive'),('gt7_steering_dial','gt7','analog','drive')]
    shots += [('timer_result_transition','timer_native','digital','timing'),('laps_transition','laps_native','digital','timing'),
        ('delta_notifications','delta_native','digital','delta'),('map_offtrack','circuit','digital','map')]
    shots += [(name,key,'digital','drive') for key,name in [('relative','relative'),('board','leaderboard'),('circuit','map'),('delta_native','delta'),('timer_native','timer'),('laps_native','laps'),('inputs_native','telemetry')]]
    for name,kind,mode,behavior in shots:
        if selected and name not in selected: continue
        ispanel=kind in ('relative','board','circuit','delta_native','timer_native','laps_native','inputs_native')
        h=Harness(panels=ispanel); h.options.instrumentMode=mode; h.options.gt7SpeedNeedleMode=h.options.gt7RpmNeedleMode=mode
        h.options.numericMetric='temperature'; h.options.temperatureReadout='core'; h.options.temperatureDisplay='general'; h.options.legendMode='temperature'
        h.options.gt7LowerPanelMode='pedal_history' if name in ('controls_radar_flags','gt7_analog','gt7_digital') else 'limit'
        if name=='ffb': h.options.gt7LowerPanelMode='ffb'
        if behavior=='hybrid':
            h.step(dict(motion_values(0,behavior),electricKw=150))
            h.step(dict(motion_values(0,behavior),electricKw=-80))
        for _ in range(180): h.step(motion_values(0,behavior))
        output=OUT/f'videos/{name}.mp4'; output.parent.mkdir(exist_ok=True)
        proc=subprocess.Popen([ff,'-y','-v','error','-f','rawvideo','-pix_fmt','rgb24','-s','1920x1080','-r','60','-i','pipe:0',
            '-an','-c:v','libx264','-preset','fast','-crf','17','-pix_fmt','yuv420p','-threads','2','-movflags','+faststart',str(output)],stdin=subprocess.PIPE)
        samples=[]; contacts=[]; started=time.monotonic()
        try:
            for i in range(480):
                t=i/FPS; values=motion_values(t,behavior)
                if behavior=='mode_transition': h.options.gt7SpeedNeedleMode=h.options.gt7RpmNeedleMode='digital' if 2<t<5.5 else 'analog'
                h.step(values)
                preset={'gt7_modern':'modern','gt7_outer_pedals':'outer_pedals','gt7_steering_dial':'steering_dial'}.get(name,'classic')
                pic=h.draw(kind,preset=preset,factor=4 if kind in ('rpm','speed') else 2); pic.thumbnail((1780,980),Image.Resampling.LANCZOS)
                # Rerasterized native calls at 2x then uniformly resized. No stretching.
                canvas=Image.new('RGB',(1920,1080),BG); canvas.paste(pic,((1920-pic.width)//2,(1080-pic.height)//2)); proc.stdin.write(canvas.tobytes())
                if i in (0,60,150,220,280,350,420,479):
                    contacts.append((f'{t:.2f} s',canvas.copy())); samples.append(dict(frame=i,rpm=h.state.rpm,speed=h.state.speedValue,gear=h.state.gearText,
                        needle=h.state.gt7RpmNeedleNormalized,light=h.state.gt7Instruments.light,hybridPower=h.state.hybrid.powerKw if h.state.hybrid else None))
                if i%120==0: print(f'{name}: {i}/480 ({time.monotonic()-started:.1f}s)',flush=True)
            proc.stdin.close()
            if proc.wait()!=0: raise RuntimeError('ffmpeg failed')
        except BaseException: proc.kill(); proc.wait(); raise
        gif=OUT/f'gifs/{name}.gif'; gif.parent.mkdir(exist_ok=True)
        subprocess.run([ff,'-y','-v','error','-i',str(output),'-filter_complex',
            'fps=30,scale=960:540:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a',
            '-loop','0',str(gif)],check=True)
        sheet(contacts,OUT/f'validation/{name}_contact.png',4,2560)
        records=[r for r in records if r['path']!=output.relative_to(OUT).as_posix()]
        records.append(dict(path=output.relative_to(OUT).as_posix(),gif=gif.relative_to(OUT).as_posix(),width=1920,height=1080,fps=60,gifFps=30,duration=8,frames=480,samples=samples,
            loop='Closed main driving cycle; auxiliary scales/history can retain observed maxima; clocks and timing events restart.'))
        manifest_path.write_text(json.dumps(records,indent=2),encoding='utf8')

def validate():
    ff=encoder(); checks=[]; (OUT/'validation').mkdir(exist_ok=True)
    for p in sorted(OUT.rglob('*.png')):
        im=Image.open(p); im.verify(); checks.append(dict(path=p.relative_to(OUT).as_posix(),ok=True))
    for p in sorted((OUT/'videos').glob('*.mp4')):
        result=subprocess.run([ff,'-v','error','-i',str(p),'-progress','pipe:1','-nostats','-f','null','-'],capture_output=True)
        if result.returncode or result.stderr: raise RuntimeError(result.stderr.decode())
        frames=[int(line.split('=')[1]) for line in result.stdout.decode().splitlines() if line.startswith('frame=')]
        assert frames and frames[-1]==480,(p,frames)
        checks.append(dict(path=p.relative_to(OUT).as_posix(),decoded=True,frames=frames[-1]))
    for p in sorted((OUT/'gifs').glob('*.gif')):
        im=Image.open(p); frames=im.n_frames
        for i in range(frames): im.seek(i); im.load()
        checks.append(dict(path=p.relative_to(OUT).as_posix(),decodedFrames=frames,durationMs=sum(_gif_durations(p))))
    before=json.loads((OUT/'source-audit.json').read_text()); assert digest()==before,'Product sources changed'
    (OUT/'validation/results.json').write_text(json.dumps(checks,indent=2),encoding='utf8')
    print(f'Validated {len(checks)} files; product digest unchanged',flush=True)

def _gif_durations(path):
    im=Image.open(path)
    for i in range(im.n_frames): im.seek(i); yield im.info.get('duration',0)

if __name__=='__main__':
    os.chdir(ROOT); OUT.mkdir(exist_ok=True)
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--inventory',action='store_true'); parser.add_argument('--stills',action='store_true'); parser.add_argument('--extras',action='store_true'); parser.add_argument('--motion',action='store_true'); parser.add_argument('--validate',action='store_true'); parser.add_argument('--shot',action='append'); parser.add_argument('--manifest',default='motion-manifest.json')
    args=parser.parse_args()
    if args.inventory: inventory()
    if args.stills: stills()
    if args.extras: extras()
    if args.motion: motion(args.shot,args.manifest)
    if args.validate: validate()
    if not any((args.inventory,args.stills,args.extras,args.motion,args.validate)): inventory(); stills(); extras(); motion(); validate()
