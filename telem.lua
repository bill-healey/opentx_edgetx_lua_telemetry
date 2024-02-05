-- This code is an adaptation of Tozes' lua script for X9D.
-- This script is made for my model setup. You can change it if it doesn't fit your model setup.
-- Graphs and general layout modified by Bill Healey

-- function to round values to 2 decimal of precision
function round(num, decimals)
  if num == nil then return 0 end
  local mult = 10^(decimals or 0)
  return math.floor(num * mult + 0.5) / mult
end
function clamp(a,b,c) return math.min(math.max(a,b),c) end

---- Screen setup
-- top left pixel coordinates
local min_x, min_y = 0, 0 
-- bottom right pixel coordinates
local max_x, max_y = 128, 63 
-- set the grid left and right coordinates; leave space left and right for batt and rssi
local grid_limit_left, grid_limit_right = 20, 108 
-- calculated grid dimensions
local grid_width = round((max_x - (max_x - grid_limit_right) - grid_limit_left))
local grid_height = round(max_y - min_y)
local grid_middle = round((grid_width / 2) + grid_limit_left)
local cell_height = round(grid_height / 3)

local batt_graph = {}
local rssi_graph = {}
local min_seen_rssi, min_seen_batt, max_seen_batt
local SETTINGS_FILE = "/SCRIPTS/TELEMETRY/telem_settings.txt"
local settings = {
	rssi_source="RSSI",
	rssi_min=20,
	rssi_max=99,
	rssi_graph_update_every_n_ticks=5,
	batt_source="BATT",
	batt_min=2.9,
	batt_max=4.35,
	batt_graph_update_every_n_ticks=5
}
--  local armed = getValue("sc")  -- arm
--  local turtmode = getValue("ls4") -- turt
 -- local race = getValue("ls7") -- race mode
--  local beepr_val = getValue('sa') -- beeper
--  local beepr = not (-10 < beepr_val and beepr_val < 10)
--  local failsafe = -100


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
 for px=0,graph['width']-1 do
  i=(graph['i']+px)%graph['width']  
  if graph[i]~=nil then
    nx=x+px
    ny=y+graph['height']-graph[i]
    lcd.drawLine(lx,ly,nx,ny, SOLID, FORCE)
    lx=nx
    ly=ny
  end
 end
end

local function drawGrid(lines, cols)
  -- Grid limiter lines
  ---- Table Limits
  lcd.drawLine(grid_limit_left, min_y, grid_limit_right, min_y, SOLID, FORCE)
  lcd.drawLine(grid_limit_left, min_y, grid_limit_left, max_y, SOLID, FORCE)
  lcd.drawLine(grid_limit_right, min_y, grid_limit_right, max_y, SOLID, FORCE)
  lcd.drawLine(grid_limit_left, max_y, grid_limit_right, max_y, SOLID, FORCE)
  ---- Header
  lcd.drawLine(grid_limit_left, min_y, grid_limit_right, min_y, SOLID, FORCE)
  ---- Grid
  ------ Top
  lcd.drawLine(grid_middle, min_y, grid_middle, max_y, SOLID, FORCE)
  ------ Hrznt Line 1
  lcd.drawLine(grid_limit_left, cell_height - 2, grid_limit_right, cell_height -2, SOLID, FORCE)
  lcd.drawLine(grid_limit_left, cell_height * 2 - 1, grid_limit_right, cell_height * 2 - 1, SOLID, FORCE)
end

local function drawBatt()
  local batt = getValue(settings.batt_source)
  record_datapoint(batt_graph, batt)
  if batt and batt>2.5 then
    max_seen_batt = math.max(round(batt, 2), max_seen_batt or 0)
    min_seen_batt = math.min(round(batt, 2), min_seen_batt or 99)
  end
    
  -- Calculate the size of the level
  local total_steps = 30 
  local range = settings.batt_max - settings.batt_min
  local step_size = range/total_steps
  local current_level = math.floor(total_steps - ((batt - settings.batt_min) / step_size))
  if current_level>30 then
    current_level=30
  end
  if current_level<0 then
    current_level=0
  end
  -- Draw graphic battery level
  lcd.drawFilledRectangle(6, 2, 8, 4, SOLID)
  lcd.drawFilledRectangle(3, 5, 14, 32, SOLID)
  lcd.drawFilledRectangle(4, 6, 12, current_level, ERASE)
    
  -- Current Battery Level
  lcd.drawText(2, 39, round(batt, 2),SMLSIZE)
  
  -- Display Min Max Battery Level
  lcd.drawText(2, 49, "+" .. round(max_seen_batt, 2), INVERS+SMLSIZE)
  lcd.drawText(2, 57, "-" .. round(min_seen_batt, 2), INVERS+SMLSIZE)
end

local function drawChannels(x, y)
  total_steps = cell_height/2.0
  step_size = 1024.0 / total_steps
  local cell_vmid = y+.5*cell_height
  local chanval = 0
  local x = x + 1
  chans = {'ch1', 'ch2', 'ch3', 'ch4', 'ch5', 'ch6', 'ch7', 'ch8', 'ch9'}
  for i, chan in ipairs(chans) do
    chanval = -getValue(chan)
    lcd.drawLine(x + 4*i+1, cell_vmid-cell_height/2, x + 4*i+1, cell_vmid+cell_height/2, DOTTED, 0)
    if chanval<0 then
      --upwards
      lcd.drawFilledRectangle(x + 4*i, cell_vmid + math.floor(chanval/step_size), 3, -math.floor(chanval/step_size)+2, SOLID, FORCE)
    else
      --downwards
      lcd.drawFilledRectangle(x + 4*i, cell_vmid-1, 3, math.ceil(chanval/step_size)+1, SOLID, FORCE)
    end
  end
  lcd.drawLine(x + 1, cell_vmid, y+(grid_middle-grid_limit_left), cell_vmid, DOTTED, FORCE)
end

local function drawRSSI()
  local rssi = getValue(settings.rssi_source)
  record_datapoint(rssi_graph, rssi)
  local clamped_rssi = clamp(rssi, settings.rssi_min, settings.rssi_max)
  local total_steps = 30
  local range = settings.rssi_max - settings.rssi_min
  local step_size = range/total_steps
  local current_level = math.floor(total_steps-((clamped_rssi - settings.rssi_min) / step_size))

  lcd.drawFilledRectangle(111, 4, 14, 32, SOLID)
  lcd.drawFilledRectangle(112, 5, 12, current_level, ERASE)

  if rssi>10 then
    min_seen_rssi = math.min(round(rssi, 0), min_seen_rssi or 99)
  end

  lcd.drawText(111, 39, round(rssi, 0))
  lcd.drawText(109, 49, "-"..round(min_seen_rssi, 0), INVERS+SMLSIZE)
  lcd.drawText(109, 57, "RSSI", INVERS+SMLSIZE)
end

local function drawFlightMode(x, y)
  local f_mode = "UNKN"
  local fm = getValue("sb")
  if fm < -1000 then
    f_mode = "ANGL"
  elseif (-10 < fm and fm < 10) then
    f_mode = "ACRO"
  elseif fm > 1000 then
    f_mode = "AIR"
  end
  lcd.drawText(x + 4, y + 6, f_mode, MIDSIZE)
end

local function drawSwitchStatus(x, y)
  local armed = getValue("sc")  -- arm
  local turtmode = getValue("ls4") -- turt
  local race = getValue("ls7") -- race mode
  local beepr_val = getValue('sa') -- beeper
  local beepr = not (-10 < beepr_val and beepr_val < 10)
  local failsafe = -100

  if (armed < 10 and failsafe < 0) then
        lcd.drawText(x + 3, y + 2, "Arm", SMLSIZE)
  elseif (failsafe < 0) then
        lcd.drawText(x + 3, y + 2, "Arm", INVERS+SMLSIZE)
  end

  if (turtmode < -10 and failsafe < 0) then
        lcd.drawText(x + 24, y + 2, "Turt", SMLSIZE)
  elseif (failsafe < 0) then
        lcd.drawText(x + 24, y + 2, "Turt", INVERS+SMLSIZE)
  end
  
  if (race < -10 and failsafe < 0) then
        lcd.drawText(x + 3, y + 12, "Race", SMLSIZE)
  elseif (failsafe < 0) then
        lcd.drawText(x + 3, y + 12, "Race", INVERS+SMLSIZE)
  end

  if (beepr and failsafe < 0) then
        lcd.drawText(x + 24, y + 12, "Beep", SMLSIZE)
  elseif (failsafe < 0) then
        lcd.drawText(x + 24, y + 12, "Beep", INVERS+SMLSIZE)
  end

 if failsafe > -10 then
        lcd.drawFilledRectangle(x, y, (grid_limit_right - grid_limit_left) / 2, cell_height, DEFAULT)
        lcd.drawText(x+2, y+2, "FailSafe", SMLSIZE+INVERS+BLINK)
        lcd.drawText(x + 25, y + 12, "Beep", INVERS+SMLSIZE+BLINK)
 end
end

local function drawTime(x, y)
  local datenow = getDateTime()
  timer = model.getTimer(0)
  s = timer.value
  lcd.drawText(x + 4, y + 2, string.format("%.2d:%.2d:%.2d", datenow.hour, datenow.min, datenow.sec))
  lcd.drawText(x + 2, y + 11, string.format("Th %.2d:%.2d", s/60%60, s%60))
  --timer = model.getTimer(1)
end

local settings_screen = false
local selected = false
local settings_cursor=0

local function drawSettings(x, y, event)
	local i=0
	if event == EVT_ENTER_FIRST then
		selected = not selected
	end
	if (event == EVT_UP_FIRST or event == EVT_UP_REPT) and settings_cursor>0 and not selected then
		settings_cursor = settings_cursor - 1
	end
	if (event == EVT_DOWN_FIRST or event == EVT_DOWN_REPT) and settings_cursor<#settings then
		settings_cursor = settings_cursor + 1
	end
  for k, v in pairs(settings) do
		if i==settings_cursor and selected then
			lcd.drawText(x, y+i*7, string.format("%s: %s", k, v), SMLSIZE+BLINK+INVERS)
		elseif i==settings_cursor then
			lcd.drawText(x, y+i*7, string.format("%s: %s", k, v), SMLSIZE+INVERS)
		else
			lcd.drawText(x, y+i*7, string.format("%s: %s", k, v), SMLSIZE)
		end
		i=i+1
  end
	--popupInput(string.format("Enter new value for %s"
end

local function saveSettingsToFile()
	local file = io.open(SETTINGS_FILE, "w")
	if file then
			local serialized = ""
			for k, v in pairs(settings) do
					serialized = serialized .. k .. "=" .. tostring(v) .. "\n"
			end
			io.write(file, serialized)
			io.close(file)
	else
			error("Cannot open file for writing")
	end
end

local function loadSettingsFromFile()
    local file = io.open(SETTINGS_FILE, "r")
    if not file then 
        error("Cannot open file for reading")
    end
		local content = io.read(file, 1024)
		io.close(file)
    for line in string.gmatch(content, '([^\n]+)') do
        local key, value = string.match(line, "(%w+)=(.+)")
        settings[key] = tonumber(value) or value
    end
end


-- Main Event Loop
local function run(event)
  lcd.clear()
	if event == EVT_UP_LONG then
		settings_screen = not settings_screen
		if settings_screen == false then
			saveSettingsToFile()
		end
	end

	if settings_screen then
		drawSettings(1, 1, event)
		return
	end

  -- Top Left
  x,y=grid_limit_left + 1, min_y - 2
  drawFlightMode(x, y)

  -- Middle Left
  x,y=grid_limit_left, min_y + cell_height - 1
  drawSwitchStatus(x, y)

  -- Bottom Left
  x,y=grid_limit_left, min_y + cell_height * 2
  lcd.drawText(x+13, y+14, "BATT", SMLSIZE)
  drawGraph(batt_graph, x, y)

  -- Top Right
  drawTime(grid_middle, min_y)

  -- Center Right
  x,y=grid_middle, min_y + cell_height - 1
  lcd.drawText(x+13, y+14, "RSSI", SMLSIZE)
  drawGraph(rssi_graph, x, y)

  -- Bottom Right
  x,y=grid_middle,min_y + cell_height * 2
  drawChannels(x, y)

  drawBatt()
  drawRSSI()
  drawGrid()
end

local function init_func()
	loadSettingsFromFile()
  init_graph(batt_graph, settings.batt_min, settings.batt_max, grid_width/2, cell_height-1, 5)
  init_graph(rssi_graph, settings.rssi_min, settings.rssi_max, grid_width/2, cell_height-1, 5)
end

return{run=run, init=init_func}
