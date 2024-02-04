-- This code is an adaptation of Tozes' lua script for X9D.
-- As the QX7 doesn't allow functions like pixmap and can display images, all the bmp files have been replaced by text and rectangles.
-- This script is made for my model setup. You can change it if it doesn't fit your model setup.

-- function to round values to 2 decimal of precision
function round(num, decimals)
  local mult = 10^(decimals or 0)
  return math.floor(num * mult + 0.5) / mult
end
function clamp(a,b,c) return math.min(math.max(a,b),c) end

---- Screen setup
-- top left pixel coordinates
local min_x, min_y = 0, 0 
-- bottom right pixel coordinates
local max_x, max_y = 128, 63 
-- set to create a header, the grid will adjust automatically but not its content
local header_height = 0  
-- set the grid left and right coordinates; leave space left and right for batt and rssi
local grid_limit_left, grid_limit_right = 20, 108 
-- calculated grid dimensions
local grid_width = round((max_x - (max_x - grid_limit_right) - grid_limit_left), 0)
local grid_height = round(max_y - min_y - header_height)
local grid_middle = round((grid_width / 2) + grid_limit_left, 0)
local cell_height = round(grid_height / 3, 0)

local batt_graph = {}
local rssi_graph = {}

function init_graph(graph, min, max, width, height, interval)
  graph['min'] = min
	graph['max'] = max
	graph['width'] = width
	graph['height'] = height
  graph['interval'] = interval
	graph['i'] = 0
	graph['tick'] = 0
end	

function record_datapoint(graph, val)
	if graph['tick'] == 0 then
					v = clamp(val, graph['min'], graph['max'])
					graph[graph['i']] = (v-graph['min'])/(graph['max']-graph['min'])*graph['height']
					graph['i'] = (graph['i']+1) % graph['width']
	end
	graph['tick'] = (graph['tick'] + 1) % graph['interval']
end

function drawGraph(graph, x, y)
 lx=x
 ly=y+graph['height']
 for px=0,graph['width'] do
  i=(graph['i']+px+1)%graph['width']	
	if graph[i]~=nil then
		nx=x+px
		ny=y+graph['height']-graph[i]
  	lcd.drawLine(lx,ly,nx,ny, SOLID, FORCE)
		lx=nx
		ly=ny
	end
 end
end

-- RSSI
local max_rssi = 90
local min_rssi = 45

local function drawGrid(lines, cols)
  -- Grid limiter lines
  ---- Table Limits
  lcd.drawLine(grid_limit_left, min_y, grid_limit_right, min_y, SOLID, FORCE)
  lcd.drawLine(grid_limit_left, min_y, grid_limit_left, max_y, SOLID, FORCE)
  lcd.drawLine(grid_limit_right, min_y, grid_limit_right, max_y, SOLID, FORCE)
  lcd.drawLine(grid_limit_left, max_y, grid_limit_right, max_y, SOLID, FORCE)
  ---- Header
  lcd.drawLine(grid_limit_left, min_y + header_height, grid_limit_right, min_y + header_height, SOLID, FORCE)
  ---- Grid
  ------ Top
  lcd.drawLine(grid_middle, min_y + header_height, grid_middle, max_y, SOLID, FORCE)
  ------ Hrznt Line 1
  lcd.drawLine(grid_limit_left, cell_height + header_height - 2, grid_limit_right, cell_height + header_height -2, SOLID, FORCE)
  lcd.drawLine(grid_limit_left, cell_height * 2 + header_height - 1, grid_limit_right, cell_height * 2 + header_height - 1, SOLID, FORCE)
end

-- Batt
local max_batt = 4.2
local min_batt = 3.1
local max_seen_bat = 0
local min_seen_bat = 5

-- Draw the battery indicator
local function drawBatt()
  local batt = getValue("A1")
  local max_seen_batt = 0
  local min_seen_batt = 5

  record_datapoint(batt_graph, batt)
  max_seen_bat = math.max(round(batt, 2), max_seen_bat)
  if batt>0 then
    min_seen_bat = math.min(round(batt, 2), min_seen_bat)
  end
    
-- Calculate the size of the level
  local total_steps = 30 
  local range = max_batt - min_batt
  local step_size = range/total_steps
  local current_level = math.floor(total_steps - ((batt - min_batt) / step_size))
  if current_level>30 then
    current_level=30
  end
  if current_level<0 then
    current_level=0
  end
    --draw graphic battery level
  lcd.drawFilledRectangle(6, 2, 8, 4, SOLID)
  lcd.drawFilledRectangle(3, 5, 14, 32, SOLID)
  lcd.drawFilledRectangle(4, 6, 12, current_level, ERASE)
    
  -- Values
  lcd.drawText(2, 39, round(batt, 2),SMLSIZE)
  
  -- Min/Max
  lcd.drawText(2, 48, "+" .. round(max_seen_bat, 2), INVERS+SMLSIZE)
  lcd.drawText(2, 57, "-" .. round(min_seen_bat, 2), INVERS+SMLSIZE)

  -- Bottom Left cell -- Channels
  total_steps = cell_height/2.0
  step_size = 1024.0 / total_steps
  local cell_vmid = min_y + header_height + cell_height * 2.5
  local chanval = 0
	local grid_limit_left = grid_limit_left + 1
  chans = {'ch1', 'ch2', 'ch3', 'ch4', 'ch5', 'ch6', 'ch7', 'ch8', 'ch9'}
	lcd.drawLine(grid_limit_left + 1, cell_vmid, grid_middle, cell_vmid, DOTTED, 0)
  for i, chan in ipairs(chans) do 
    chanval = -getValue(chan)
		lcd.drawLine(grid_limit_left + 4*i+1, cell_vmid-cell_height/2, grid_limit_left + 4*i+1, cell_vmid+cell_height/2, DOTTED, 0)
    if chanval<0 then
		  --up
      lcd.drawFilledRectangle(grid_limit_left + 4*i, cell_vmid + math.floor(chanval/step_size), 3, -math.floor(chanval/step_size)+1, SOLID)
    else
			lcd.drawFilledRectangle(grid_limit_left + 4*i, cell_vmid-1, 3, math.ceil(chanval/step_size)+1, SOLID)
		end
  end
end

local function drawRSSI()
  local rssi = getValue("RSSI")
	record_datapoint(rssi_graph, rssi)
  local CLAMPrssi = rssi
  if (rssi<45) then
        CLAMPrssi = 45
    elseif (rssi>90) then
        CLAMPrssi = 90
    end
    
  local total_steps = 30
  local range = max_rssi - min_rssi
  local step_size = range/total_steps
  local current_level = math.floor(total_steps-((CLAMPrssi - min_rssi) / step_size))

    --draw graphic rssi level
  lcd.drawFilledRectangle(111, 4, 14, 32, SOLID)
  lcd.drawFilledRectangle(112, 5, 12, current_level, ERASE)

  -- Display durrent RSSI value

  if (rssi>=100) then
  lcd.drawText(111, 42, round(rssi, 0))
  else
  lcd.drawText(110, 38, round(rssi, 0), DBLSIZE)
  end
  
  lcd.drawText(109, 57, "rssi", INVERS+SMLSIZE)
end


-- Top Left cell -- Flight mode
local function cell_1()
  local x1 = grid_limit_left + 1
  local y1 = min_y + header_height - 2

  -- FMODE
  local f_mode = "UNKN"
  local fm = getValue("sb")
	if fm < -1000 then
		f_mode = "ANGL"
	elseif (-10 < fm and fm < 10) then
		f_mode = "ACRO"
	elseif fm > 1000 then
	    f_mode = "AIR"
	end
  lcd.drawText(x1 + 4, y1 + 6, f_mode, MIDSIZE)
end

-- Middle left cell -- Switch statuses (enabled, disabled)
local function cell_2()
  local x1 = grid_limit_left + 0
  local y1 = min_y + header_height + cell_height - 1

  local armed = getValue("sc")  -- arm
  local turtmode = getValue("ls4") -- turt
  local race = getValue("ls7") -- race mode
  local beepr_val = getValue('sa') -- beeper
  local beepr = not (-10 < beepr_val and beepr_val < 10)  -- beeper
  local failsafe = -100

  if (armed < 10 and failsafe < 0) then
        lcd.drawText(x1 + 3, y1 + 2, "Arm", SMLSIZE)
  elseif (failsafe < 0) then
        lcd.drawText(x1 + 3, y1 + 2, "Arm", INVERS+SMLSIZE)
  end

  if (turtmode < -10 and failsafe < 0) then
        lcd.drawText(x1 + 24, y1 + 2, "Turt", SMLSIZE)
  elseif (failsafe < 0) then
        lcd.drawText(x1 + 24, y1 + 2, "Turt", INVERS+SMLSIZE)
  end
  
  if (race < -10 and failsafe < 0) then
        lcd.drawText(x1 + 3, y1 + 12, "Race", SMLSIZE)
  elseif (failsafe < 0) then
        lcd.drawText(x1 + 3, y1 + 12, "Race", INVERS+SMLSIZE)
  end

  if (beepr and failsafe < 0) then
        lcd.drawText(x1 + 24, y1 + 12, "Beep", SMLSIZE)
  elseif (failsafe < 0) then
        lcd.drawText(x1 + 24, y1 + 12, "Beep", INVERS+SMLSIZE)
  end

 if failsafe > -10 then
        lcd.drawFilledRectangle(x1, y1, (grid_limit_right - grid_limit_left) / 2, cell_height, DEFAULT)
        lcd.drawText(x1+2, y1+2, "FailSafe", SMLSIZE+INVERS+BLINK)
        lcd.drawText(x1 + 25, y1 + 12, "Beep", INVERS+SMLSIZE+BLINK)
 end
end

-- Top Right cell -- Current time
local function cell_4() 
  local x1 = grid_middle + 1
  local y1 = min_y + header_height + 1

  local datenow = getDateTime()
  lcd.drawText(x1 + 4, y1 + 6, string.format("%.2d:%.2d:%.2d", datenow.hour, datenow.min, datenow.sec))
end

-- Center right cell -- Timer1
local function cell_5() 
  local x1 = grid_middle + 1
  local y1 = min_y + header_height + cell_height + 1

  timer = model.getTimer(0)
  s = timer.value
  time = string.format("%.2d:%.2d", s/60%60, s%60)
  lcd.drawText(x1+2, y1, "TH")
  lcd.drawText(x1+17, y1, time)
  timer = model.getTimer(1)
  s = timer.value
  time = string.format("%.2d:%.2d", s/60%60, s%60)
  lcd.drawText(x1+2, y1+10, "TT")
  lcd.drawText(x1+17, y1+10, time)
end

-- Bottom right cell -- Graph?
local function cell_6() 
  local x1 = grid_middle + 1
  local y1 = min_y + header_height + cell_height * 2
  --drawGraph(batt_graph, x1, y1)
  drawGraph(rssi_graph, x1, y1)
end

-- Execute
local function run(event)
  lcd.clear()
  cell_1()
  cell_2()
  cell_4()
  cell_5()
  cell_6()
  drawBatt()
  drawRSSI()
  drawGrid()
end

local function init_func()
  init_graph(batt_graph, min_batt, max_batt, grid_width/2, cell_height-1, 5)
  init_graph(rssi_graph, 45, 90, grid_width/2, cell_height-1, 5)
end

return{run=run, init=init_func}
