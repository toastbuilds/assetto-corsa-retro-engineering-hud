-- Digital concept coordinates in the standalone dial's 620px design space.
local M = {}
M.choices = {
  {value='original',label='Original'},
  {value='bridge',label='1 · Bridge'},
  {value='column',label='2 · Column'},
  {value='radial',label='3 · Radial'},
  {value='offset',label='4 · Offset'},
  {value='orbit',label='6 · Orbit'}
}
M.layouts = {
  bridge={number=1,rpm={310,293,245,-160,-20},rpmText={310,190},
    speed={225,313,88},gear={440,313,92},speedLabel=true,gearLabel=true,
    panels={{225,308,246,133},{440,308,170,133}},
    pedals={{190,454,38,64},{310,454,38,64},{430,454,38,64}},
    turns={{101,418},{519,418}},steering={310,233,55},aux={310,390},
    statuses={{196,522},{273,522},{350,522},{427,522}},warning={483,501},flag={137,501}},
  column={number=2,rpm={310,267,223,150,30},rpmText={310,400},
    speed={310,299,85},gear={310,156,130},speedLabel=true,gearLabel=true,
    panels={{310,230,173,320}},
    pedals={{153,252,34,158},{310,451,110,10},{467,252,34,158}},
    turns={{76,314},{544,314}},steering={310,220,51},aux={310,361},
    statuses={{207,527},{278,548},{349,548},{420,527}},warning={424,366},flag={196,366}},
  radial={number=3,rpm={310,307,243,-165,-15},rpmText={310,172},
    speed={310,358,63},gear={310,280,85},gearLabel=true,core={310,310,112},
    pedals={{112,343,38,83},{310,473,157,15},{508,343,38,83}},
    turns={{100,414},{520,414}},steering={310,410,42},aux={310,444},
    statuses={{192,508},{270,537},{350,537},{428,508}},warning={455,473},flag={165,473}},
  offset={number=4,rpmBar={441,307,32,237},rpmText={441,154},
    speed={235,254,105},gear={235,386,87},speedLabel=true,gearLabel=true,
    panels={{235,246,245,157},{235,385,188,117}},
    pedals={{187,478,56,27},{310,478,56,27},{433,478,56,27}},
    turns={{94,444},{526,444}},steering={235,140,62},aux={235,441},
    statuses={{207,527},{278,548},{349,548},{420,527}},warning={486,491},flag={135,491}},
  orbit={number=6,rpm={310,296,203,-180,0},rpmText={310,84},
    speed={310,275,69},gear={310,394,65},speedLabel=true,gearLabel=true,core={310,316,115},
    pedals={{310,300,211,129,168},{310,477,157,15},{310,300,211,12,51}},
    turns={{72,275},{548,275}},steering={310,167,46},aux={310,449},
    statuses={{190,519},{270,548},{350,548},{430,519}},warning={455,492},flag={165,492}}
}
for id,l in pairs(M.layouts) do
  l.id=id
  if l.rpm then
    l.rpmSegments={}
    local r=l.rpm
    for i=1,32 do
      local a=math.rad(r[4]+(r[5]-r[4])*(i-0.91)/32)
      local b=math.rad(r[4]+(r[5]-r[4])*(i-0.09)/32)
      local points={{r[1]+r[3]*math.cos(a),r[2]+r[3]*math.sin(a)},
        {r[1]+r[3]*math.cos(b),r[2]+r[3]*math.sin(b)},
        {r[1]+(r[3]-27)*math.cos(b),r[2]+(r[3]-27)*math.sin(b)},
        {r[1]+(r[3]-27)*math.cos(a),r[2]+(r[3]-27)*math.sin(a)}}
      if r[5]<r[4] then points={points[4],points[3],points[2],points[1]} end
      l.rpmSegments[i]=points
    end
  end
end
function M.get(value) return M.layouts[value] end
function M.normalize(value) return M.layouts[value] and value or 'original' end
return M
