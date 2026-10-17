"""Render GT7 speed dial slipstream backgrounds without running test suites.

python tools/preview-slipstream.py
Uses the actual instrument renderer, drawing doubles and Windows Consolas.
"""
import importlib.util
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('leaderboard_preview', ROOT / 'tools/preview-leaderboard.py')
drawing = importlib.util.module_from_spec(spec)
spec.loader.exec_module(drawing)
preview = drawing.preview


def create_slipstream_harness():
    """Expose the real speed-dial renderer for static and animated previews."""
    lua, harness = drawing.create_drawing_harness()
    lua.execute("""
      local alpha, stack = 1, {}
      local push, pop = ui.pushStyleVarAlpha, ui.popStyleVar
      ui.pushStyleVarAlpha=function(value)
        stack[#stack+1]=alpha; alpha=alpha*value; push(value)
      end
      ui.popStyleVar=function(count)
        for i=1,count do alpha=table.remove(stack) end
        pop(count)
      end
      for name,index in pairs({drawLine=3,drawCircle=3,drawCircleFilled=3,drawRect=3,
          drawRectFilled=3,pathFillConvex=1,pathStroke=1,dwriteDrawText=4,drawImage=4}) do
        local original=ui[name]
        ui[name]=function(...)
          local args={...}; local ink=args[index]
          args[index]=rgbm(ink.r,ink.g,ink.b,ink.mult*alpha)
          original(table.unpack(args))
        end
      end
      previewState={available=true,clock=0,speedText='180',speedValue=180,speedKmh=180,
        speedUnit='km/h',speedGaugeMaximum=320,speedGaugeStep=40,
        gt7SpeedNeedleNormalized=180/320,rpm=5200,rpmDisplayLimiter=8000,rpmGaugeLimiter=8000,
        fuel=30,maxFuel=50,fuelNormalized=0.6,headlights=true,lightsAvailable=true,
        turboBoost=0,turboDisplayMax=1.5,turboAvailable=false,
        slipstream={available=true,intensity=0,source='estimated'}}
      previewRenderer={draw=function(state,settings)
        local Theme=require('src/theme')
        local palette=require('src/general_settings').palette(Theme.get(settings.theme),0.72)
        local scale=settings.previewScale or 1
        local center=vec2(180*scale,180*scale)
        ui.pushDWriteFont(Theme.fonts.utility)
        require('ui/side_instruments').draw(center,scale,state,settings,
          require('src/gt7_retro_layout'),palette,0.72,false,function() return palette.primary end)
        for _,ring in ipairs({{174,4,'metal'},{166,2,'outline'},{158,2,'outlineDim'}}) do
          ui.drawCircle(center,ring[1]*scale,palette[ring[3]],72,ring[2]*scale)
        end
        ui.popDWriteFont()
      end}
    """)
    return lua, harness, lua.globals().previewState, lua.globals().previewRenderer


def main():
    output = ROOT / 'output/slipstream'
    output.mkdir(parents=True, exist_ok=True)
    lua, harness, state, renderer = create_slipstream_harness()
    styles = lua.eval("require('src/gt7_dial_styles')")
    label_font = ImageFont.truetype('C:/Windows/Fonts/consola.ttf', 14)
    for theme, background, ink in (('dark','#121416','#f2dbae'),('light','#e9e4d9','#2e2b26')):
        for mode in ('analog','digital'):
            choices = list(styles.choices(mode,'speed').values())
            sheet = Image.new('RGB',(1080,len(choices)*388),background)
            labels = ImageDraw.Draw(sheet)
            for row, choice in enumerate(choices):
                for column, intensity in enumerate((0,0.5,1)):
                    settings = lua.table_from(dict(theme=theme,speedUnit='km/h',
                        gt7SpeedNeedleMode=mode,gt7SpeedDialStyle=choice.value,
                        gt7SpeedNeedleStyle='b01',gt7SpeedAuxiliaryStyle='original',
                        gt7SlipstreamBackground=True,animateIndicators=False))
                    state.slipstream.intensity = intensity
                    calls = harness['drawRenderer'](renderer,state,settings,lua.table_from([360,360]))
                    image = preview.raster(calls,360,360,background)
                    name = f'{mode}-{choice.value}-{theme}-{column}.png'
                    image.save(output / name)
                    labels.text((column*360+8,row*388+5),
                        f'{choice.label} / {("OFF","MID","MAX")[column]}',font=label_font,fill=ink)
                    sheet.paste(image,(column*360,row*388+28))
            path = output / f'{mode}-{theme}.png'
            sheet.save(path)
            print(path)
            for scale in (0.75,1.25):
                settings.previewScale = scale
                settings.gt7SpeedDialStyle = 'original'
                size = round(360*scale)
                calls = harness['drawRenderer'](renderer,state,settings,lua.table_from([size,size]))
                image = preview.raster(calls,size,size,background)
                image.save(output / f'{mode}-original-{theme}-scale-{scale}.png')
    print('Preview only: no telemetry simulation, test suites or game launch.')


if __name__ == '__main__':
    main()
