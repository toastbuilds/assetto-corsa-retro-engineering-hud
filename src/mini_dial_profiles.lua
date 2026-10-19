-- Reference sheet coordinates are stable IDs, shared by settings and previews.
-- All concept faces use another 10% of space; side labels free the lower edge.
-- Presented bounds remain x +/-107; full-face footers stay inside the face.
local M = { choices = {} }
local rows = {
  {'Twin Rim', 'Spoke Wheel', 'Crown Blocks', 'Offset Blocks'},
  {'Accent Rim', 'Open Ring', 'Inward Ticks', 'Dashed Ring'},
  {'Shelf Scale', 'Sun Scale', 'Triple Arch', 'Radial Cells'},
  {'Open Ticks', 'Sweep Band', 'Lattice Arch', 'Segment Arch'}
}
local specifications = {
  {rim=2,ticks=12,needle='spear',segmentCount=24},
  {rim=1, wheel=true, ticks=0, needle='line', hub='solid', first=150,last=390,
    segmentCount=8,segmentRadius=29.5,segmentWidth=8},
  {rim=1, blocks=5, first=180, last=360, needle='spear', broad=true},
  {rim=1, blocks=5, first=180, last=400, needle='line', hub='open', broad=true,
    cellAngles={180,212.5,245,277.5,310,400},segmentRadius=35,segmentWidth=8},
  {rim=2, ticks=8, accent=true, needle='diamond', tail=true,
    segmentCount=24,segmentRadius=33,segmentWidth=5,needleLength=31},
  {rim=1, inner=true, ticks=6, needle='line', hub='open', tail=true,
    segmentCount=24,segmentRadius=32,segmentWidth=5,needleLength=31},
  {rim=1, inward=true, ticks=24, needle='spear', hub='open',
    segmentCount=24,segmentRadius=35,segmentWidth=8},
  {rim=1, dashed=true, ticks=0, needle='line', hub='open',tail=true,counterweight='semiarc',
    segmentCount=16,segmentRadius=36,segmentWidth=3},
  {rim=1, shelf=true, ticks=32, needle='club',first=155,last=385,
    segmentCount=32,segmentRadius=31,segmentWidth=5},
  {rim=1, sun=true, ticks=16, needle='line', hub='open',
    segmentCount=16,segmentRadius=36.5,segmentWidth=4},
  {rim=1, arch=true, ticks=0, needle='line', hub='open', tail=true, plaque=true,
    first=180,last=360,segmentCount=12,segmentRadius=35,segmentWidth=3},
  {rim=1, cells=true, ticks=0, needle='line', hub='open',first=150,last=390,
    segmentCount=4,segmentRadius=33.5,segmentWidth=4.8},
  {half=true, ticks=20, needle='club',segmentRadius=60,segmentWidth=4},
  {half=true, ticks=0, sweep=true, needle='cutout',digital=false},
  {half=true, ticks=16, lattice=true, needle='spear', base=true},
  {half=true, ticks=0, blocks=8, needle='club', broad=true}
}
M.profiles = {}
for index, profile in ipairs(specifications) do
  local row, column = math.floor((index-1)/4)+1, (index-1)%4+1
  local id = string.format('mini_f%dc%d', row, column)
  profile.id, profile.name = id, rows[row][column]
  profile.reference = string.format('F%dC%d', row, column)
  profile.radius = profile.half and 63 or 44
  profile.ticks = profile.ticks or 0
  profile.y = profile.half and 0 or -20
  profile.sizeScale=(profile.half and 1.05 or 1.32)*1.10
  profile.offsetY=profile.half and 5 or 13.5
  profile.first = math.rad(profile.first or (profile.half and 180 or 140))
  profile.last = math.rad(profile.last or (profile.half and 360 or 400))
  profile.segmentRadius=profile.segmentRadius or (profile.half and 54 or 35)
  profile.segmentWidth=profile.segmentWidth or 6
  profile.segmentCount=profile.segmentCount or profile.blocks or 20
  profile.needleLength=profile.needleLength or (profile.sun and 20 or profile.shelf and 24
    or profile.half and 50 or profile.segmentRadius-4)
  profile.edges={}
  for i=0,profile.segmentCount do
    profile.edges[i+1]=profile.cellAngles and math.rad(profile.cellAngles[i+1])
      or profile.first+(profile.last-profile.first)*i/profile.segmentCount
  end
  M.profiles[id] = profile
  M.choices[#M.choices+1] = {value=id, label=profile.reference .. ' - ' .. profile.name}
end
function M.get(id) return M.profiles[id] end

-- Every cell represents one equal value step, even when its angle is wider.
function M.angle(profile,value)
  local position=math.max(0,math.min(1,value))*profile.segmentCount
  local cell=math.min(profile.segmentCount,math.floor(position)+1)
  return profile.edges[cell]+(profile.edges[cell+1]-profile.edges[cell])*(position-cell+1)
end
return M
