-- Digital concept coordinates in the standalone dial's 620px design space.
local M = {}
M.choices = {
  {value='original',label='Original'},
  {value='bridge',label='1 · Bridge'},
  {value='column',label='2 · Column'},
  {value='radial',label='3 · Radial'},
  {value='offset',label='4 · Offset'},
  {value='core_capsule',label='5D · Core Capsule'},
  {value='halo',label='6D · Halo'},
  {value='orbit',label='6 · Orbit'}
}
M.layouts = {
  halo={number='6D',haloRpm=true,cleanPerimeter=true,hideRpmNumbers=true,
    rpm={310,304,234,-220,40},rpmText={310,158},speed={310,285,128},gear={310,439,50},
    core={310,421,40},steeringRing=true,
    pedals={{310,304,144,136,175},{310,499,84,6},{310,304,144,44,5}},
    barePedals=true,pedalCaptions=false,pedalArcWidth=6,
    edgeAux={{310,304,164,135,205},{310,304,164,45,-25}},
    edgeIcons={{190,451},{430,451}},edgeReadings={{174,478},{446,478}},
    statuses={{236,351},{236,395},{384,351},{384,395}},iconStatuses=true,roundStatuses=true,statusSize={36,36},
    warning={348,539},flag={270,539}},
  bridge={number=1,rpm={310,293,245,-160,-20},rpmText={310,190},
    speed={225,302,80},gear={440,302,82},speedLabel=true,gearLabel=true,
    panels={{225,298,246,122},{440,298,170,122}},
    pedals={{190,434,38,50},{310,434,38,50},{430,434,38,50}},
    turns={{101,418},{519,418}},steering={310,225,146},graduatedSteering=true,aux={310,379},
    statuses={{196,522},{273,522},{350,522},{427,522}},warning={461,482},flag={159,482}},
  column={number=2,cleanPerimeter=true,rpm={310,246,218,150,30},rpmText={310,389},
    speed={310,275,72},gear={310,147,105},speedLabel=true,gearLabel=true,
    panels={{310,216,173,294}},
    pedals={{153,224,34,158},{310,418,100,10},{467,224,34,158}},
    turns={{76,314},{544,314}},steering={310,208,51},
    edgeAux={{310,304,244,155,205},{310,304,244,25,-25}},
    edgeReadings={{111,338},{509,338}},
    hideAuxUnits=true,hideAuxValues=true,edgeIcons={{100,425},{520,425}},
    statuses={{207,527},{278,548},{349,548},{420,527}},warning={424,366},flag={196,366}},
  radial={number=3,hideRpmNumbers=true,rpm={310,307,243,-165,-15},rpmText={310,172},
    speed={310,358,63},gear={310,280,85},gearLabel=true,core={310,310,112},
    pedals={{112,343,38,83},{310,470,110,15},{508,343,38,83}},
    turns={{100,414},{520,414}},steeringRing=true,dotAux=true,aux={310,138},
    statuses={{192,508},{270,537},{350,537},{428,508}},warning={455,473},flag={165,473}},
  offset={number=4,hideRpmNumbers=true,cleanPerimeter=true,rpmBar={467,278,26,210},rpmText={467,134},
    speed={305,238,78},gear={305,358,68},speedLabel=true,gearLabel=true,
    panels={{305,232,178,136},{305,357,136,96}},
    pedals={{191,453,34,28},{310,453,34,28},{429,453,34,28}},
    steering={305,121,48},edgeAux={{310,304,244,155,205},{310,304,244,25,-25}},
    edgeReadings={{132,320},{500,410}},
    hideAuxUnits=true,edgeIcons={{100,425},{520,425}},
    warning={481,460},flag={139,460}},
  orbit={number=6,hideUnits=true,hideAuxValues=true,cleanPerimeter=true,rpm={310,315,211,-180,0},rpmText={310,76},
    speed={310,273,68},gear={310,380,70},speedLabel=true,gearLabel=true,core={310,324,121},
    pedals={{310,304,245,130,155},{310,478,100,15},{310,304,245,50,25}},
    steering={310,235,40},edgeAux={{310,304,244,-155,-105},{310,304,244,-25,-75}},
    edgeIcons={{87,225},{533,225}},
    warning={430,465},flag={190,465}},
  core_capsule={number='5D',coreCapsule=true,cleanPerimeter=true,speedGraduations=true,
    speed={310,247,108},gear={206,386,44},rpmValue={317,386},rpmBar={420,386,92,14},
    readout={310,386,350,64},edgeAux={{310,304,252,-205,-93},{310,304,252,25,-87}},
    edgeReadings={{109,443},{511,443}},edgeIcons={{103,416},{517,416}},
    hideAuxUnits=true,edgeBarWidth=10,edgeBarCount=20,
    steering={310,326,94},graduatedSteering=true,
    pedals={{190,438,52,8},{310,438,52,8},{430,438,52,8}},compactPedals=true,pedalCaptions=false,
    statuses={{211,489},{277,489},{343,489},{409,489}},iconStatuses=true,statusSize={44,40},
    warning={348,539},flag={272,539}}

}
for id,l in pairs(M.layouts) do
  l.id=id
  l.statuses=l.statuses or {{211,507},{277,533},{343,533},{409,507}}
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
