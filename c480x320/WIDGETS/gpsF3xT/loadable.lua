---------------------------------------------------------------------------
-- The dynamically loadable part of the demonstration Lua widget.        --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Date:    2022-02-27                                                   --
-- Version: 1.0.0                                                        --
--                                                                       --
-- Copyright (C) EdgeTX                                                  --
--                                                                       --
-- License GPLv2: http://www.gnu.org/licenses/gpl-2.0.html               --
--                                                                       --
-- This program is free software; you can redistribute it and/or modify  --
-- it under the terms of the GNU General Public License version 2 as     --
-- published by the Free Software Foundation.                            --
--                                                                       --
-- This program is distributed in the hope that it will be useful        --
-- but WITHOUT ANY WARRANTY; without even the implied warranty of        --
-- MERCHANTABILITY or FITNESS FOR borderON PARTICULAR PURPOSE. See the   --
-- GNU General Public License for more details.                          --
---------------------------------------------------------------------------

-- This code chunk is loaded on demand by the LibGUI widget's main script
-- when the create(...) function is run. Hence, the body of this file is
-- executed by the widget's create(...) function.

-- zone and options were passed as arguments to chunk(...)
local zone, options = ...

-- GLOBAL VARIABLES
global_gps_pos = {lat=0.,lon=0.}
global_gps_sensor = nil
global_gps_init = false

-- Miscellaneous constants
local HEADER = 40
local WIDTH  = 100
local COL1   = 10
local COL2   = 130
local COL3   = 250
local COL4   = 370
local COL2s  = 120
local TOP    = 44
local ROW    = 28
local ROW2    = 132
local HEIGHT = 24

-- better font names
local FONT_38 = XXLSIZE -- 38px
local FONT_16 = DBLSIZE -- 16px
local FONT_12 = MIDSIZE -- 12px
local FONT_8 = 0 -- Default 8px
local FONT_6 = SMLSIZE -- 6px

-- LOCAL VARIABLES
local on_simulator = false
local basePath = '/WIDGETS/gpsF3xT/gpstrack/'
local gpsOK = false
local tx16s = false

-- local sensor = nil

-----------------------------------------------------------
-- module load function
-----------------------------------------------------------
function mydofile (filename)
    -- local f = assert(loadfile(filename))
    --  mode: b: only binary, t: only text, c: compile only, x: do not compile
    local mode = 'bt'
    if on_simulator then
        mode = 'T'
    end
    local f = assert(loadScript(filename, mode))
    return f()
end
  
local ver, radio, maj, minor, rev = getVersion()
if string.find(radio,"-simu") then
    print("Simulator detectded")
    on_simulator = true
elseif string.find(radio,"tx16s") then
    tx16s = true;
end
--[[
local settings = getGeneralSettings()
print("Language : "..settings["language"])
print("Voice : "..settings["voice"])
]]--
-- load gps library
gps = mydofile(basePath..'gpslib.lua')
-- load sensor 
global_gps_sensor = mydofile(basePath..'sensors.lua')

gpsOK = global_gps_sensor.init('gpsF3x')
global_gps_init = gpsOK
-- gpsOK = global_gps_sensor.init('gpsV2')
-- gpsOK = global_gps_sensor.init('logger3')
-- load course (2 bases)   
course = mydofile(basePath..'course.lua')

-- reloadCompetition()

-------------------------------------------------------------------------------------------------
-- get one full entry from supported competition types {name, default_mode, course_length, file}
-------------------------------------------------------------------------------------------------

local function getCompEntry(name)
    for key,entry in pairs(global_comp_types) do
        if entry.name == name then
            return entry
        end
    end
    return nil
end

-------------------------------------------------------
-- load a new competition type
-------------------------------------------------------

local comp = nil

local function reloadCompetition()
    -- reload competition accordingly to new parameters
    local _gpsOK = gpsOK
    -- inactivate background process
    gpsOK = false 
        
    -- set some useful default values (just in case ...)
    local file_name = 'f3f.lua'
    local mode = 'training'
    local length = 50
    local entry = getCompEntry(global_comp_type)
    if entry then
        -- overwrite the defaults
        file_name = entry.file
        mode = entry.default_mode
        length = entry.course_length / 2
    end    
    if comp == nil or comp.name ~= file_name then
        -- empty or different competition required
        if comp ~= nil then
            print("unload: " .. comp.name)
        end
        print("load: " .. file_name)
        -- remove old competition class
        comp = nil
        -- cleanup memory
        collectgarbage("collect")
        -- load new competition (will crash if file does not exist!)
        comp = mydofile(basePath..file_name)
    end
    -- reset competition
    comp.init(mode, global_baseA_left)
    -- set ground height
    if _gpsOK then
        comp.groundHeight = global_gps_sensor.gpsAlt() or 0.
    end
    -- reset course and update competition hooks
    course.init(length, math.rad(global_home_dir), comp)
    -- for F3B the home position is base A always. The course library needs the home in the middle between the bases. -> move home in direction of base B
    if string.find(global_comp_type,"f3b") then
        local new_position = gps.getDestination(global_home_pos, length, global_home_dir)
        print(string.format("F3B: moved home by %d meter from: %9.6f, %9.6f to: %9.6f, %9.6f",length, global_home_pos.lat, global_home_pos.lon, new_position.lat, new_position.lon))
        global_home_pos = new_position
    end
    
    gpsOK = _gpsOK
end

-- The widget table will be returned to the main script
local widget = { }

-- Load the GUI library by calling the global function declared in the main script.
-- As long as LibGUI is on the SD card, any widget can call loadGUI() because it is global.
local libGUI = loadGUI()

-- Instantiate a new GUI object
local gui = libGUI.newGUI()

-- Make a minimize button from a custom element
local custom = gui.custom({ }, LCD_W - 34, 6, 28, 28)

function custom.draw(focused)
  lcd.drawRectangle(LCD_W - 34, 6, 28, 28, libGUI.colors.primary2)
  lcd.drawFilledRectangle(LCD_W - 30, 19, 20, 3, libGUI.colors.primary2)
  if focused then
    custom.drawFocus()
  end
end

function custom.onEvent(event, touchState)
  if event == EVT_VIRTUAL_ENTER then
    lcd.exitFullScreen()
  end
end

-- Prompt showing About text
local aboutPage = 1
local aboutText = {
--[[  
  "LibGUI is a Lua library for creating graphical user interfaces for Lua widgets on EdgeTX transmitters with color screens. " ..
  "It is a code library embedded in a widget. Since all Lua widgets are always loaded into memory, whether they are used or not, " ..
  "the global function named 'loadGUI()', defined in the 'main.lua' file of this widget, is always available to be used by other widgets.",
  "The library code is implemented in the 'libgui.lua' file of this widget. This code is loaded on demand, i.e. it is only loaded if " ..
  "loadGUI() is called by a client widget to create a new libGUI Lua table object. That way, the library is not using much of " ..
  "the radio's memory unless it is being used. And since it is all Lua code, you can inspect the file yourself, if you are curious " ..
  "or you have found a problem.",
  "When you add the widget to your radio's screen, then this demo is loaded. It is implemented in the 'loadable.lua' file of this " ..
  "widget. Hence, like the LibGUI library itself, it does not waste your radio's memory, unless it is being used. And you can view " ..
  "the 'loadable.lua' file in the widget folder to see for yourself how this demo is loading LibGUI and using it, so you can start " ..
  "creating your own awesome widgets!",
   "Copyright (C) EdgeTX\n\nLicensed under GNU Public License V2:\nwww.gnu.org/licenses/gpl-2.0.html\n\nAuthored by Jesper Frickmann."
]]--
  "MIT License\n" ..
  "Copyright (c) 2024 Axel Barnitzke\n\n"
  "Copyright (c) 2025 Steve Chang"
}

local aboutPrompt = libGUI.newGUI()

function aboutPrompt.fullScreenRefresh()
  lcd.drawFilledRectangle(40, 30, LCD_W - 80, 30, COLOR_THEME_SECONDARY1)
--  lcd.drawText(50, 45, "About LibGUI  " .. aboutPage .. "/" .. #aboutText, VCENTER + MIDSIZE + libGUI.colors.primary2)
  lcd.drawText(50, 45, "About gpsF3XTracker  " .. aboutPage .. "/" .. #aboutText, VCENTER + MIDSIZE + libGUI.colors.primary2)
  lcd.drawFilledRectangle(40, 60, LCD_W - 80, LCD_H - 90, libGUI.colors.primary2)
  lcd.drawRectangle(40, 30, LCD_W - 80, LCD_H - 60, libGUI.colors.primary1, 2)
  lcd.drawTextLines(50, 70, LCD_W - 120, LCD_H - 110, aboutText[aboutPage])
end

-- Button showing About prompt
gui.button(COL3, TOP + 7 * ROW, WIDTH, HEIGHT, "About", function() gui.showPrompt(aboutPrompt) end)

-- Make a dismiss button from a custom element
local custom2 = aboutPrompt.custom({ }, LCD_W - 65, 36, 20, 20)

function custom2.draw(focused)
  lcd.drawRectangle(LCD_W - 65, 36, 20, 20, libGUI.colors.primary2)
  lcd.drawText(LCD_W - 55, 45, "X", MIDSIZE + CENTER + VCENTER + libGUI.colors.primary2)
  if focused then
    custom2.drawFocus()
  end
end

function custom2.onEvent(event, touchState)
  if event == EVT_VIRTUAL_ENTER then
    gui.dismissPrompt()
  end
end

-- Add a vertical slider to scroll pages
local function verticalSliderCallBack(slider)
  aboutPage = #aboutText + 1 - slider.value
end

local verticalSlider = aboutPrompt.verticalSlider(LCD_W - 60, 80, LCD_H - 130, #aboutText, 1, #aboutText, 1, verticalSliderCallBack)

-------------------------------------------------------
-- setup screen   
-------------------------------------------------------

reloadCompetition()

local startSwitchInfo = getFieldInfo("sh")
local centerSliderInfo = getFieldInfo("s2")

local compLabel = gui.label(COL1, TOP, WIDTH, HEIGHT, global_comp_display)
local baseALabel = gui.label(COL2, TOP, 2 * WIDTH, HEIGHT, "BASE A Left")
local switchLabel = gui.label(COL3, TOP, 2 * WIDTH, HEIGHT, "<"..startSwitchInfo.name.."> / <".. centerSliderInfo.name..">")
-- local lapsLabel = gui.label(COL4, TOP, 2 * WIDTH, HEIGHT, "Lap ---")

local timerLabel = gui.label(COL1, TOP + ROW, WIDTH, 2 * HEIGHT, "00:00", VCENTER + FONT_38 + YELLOW)
local gpsSignal = gui.label(COL1, TOP + 3 * ROW, 2 * WIDTH, HEIGHT, strWaitingForGpsSignal, VCENTER + BOLD + RED + BLINK)
gui.label(COL1, TOP + 4 * ROW, WIDTH, HEIGHT, "Latitude", VCENTER + BOLD)
gui.label(COL2, TOP + 4 * ROW, WIDTH, HEIGHT, "Longitude", VCENTER + BOLD)
local latLabel = gui.label(COL1, TOP + 5 * ROW, WIDTH, HEIGHT, "---")
local lonLabel = gui.label(COL2, TOP + 5 * ROW, WIDTH, HEIGHT, "---")
local courseLabel = gui.label(COL1, TOP + 6 * ROW, WIDTH, HEIGHT, "center ---")
local speedDestLabel = gui.label(COL1, TOP + 7 * ROW, WIDTH, HEIGHT, "V: 0.00 m/s Dst:-0.00 m ")

gui.label(COL3, TOP + 4 * ROW, WIDTH, HEIGHT, "Center Offset", VCENTER + BOLD)
local centerOffsetLabel = gui.label(COL3, TOP + 5 * ROW, WIDTH, HEIGHT, "Center 0 m")
local startSwitchValue = getValue(startSwitchInfo.id)

local lapItems = {"L1 : ", "L2 : ", "L3 : ", "L4 : ", "L5 : ", "L6 : ", "L7 : ", "L8 : ", "L9 : ", "L10 : "}
--local lapItems = {"L1 : "}
local lapsMenu = gui.menu(COL4, TOP, WIDTH, 9 * HEIGHT, lapItems, nil, GREEN)

local function startSwitchPressed()
    local startSwitchInfo = getFieldInfo("sh")

    local val = getValue(startSwitchInfo.id)
    if startSwitchValue ~= val then
        -- print(string.format("SH : %d", val))
        startSwitchValue = val
         
        if val > 512 then
            return true
        end
    end
    return false
end

local runs = 0

-- Draw on the screen before adding gui elements
function gui.fullScreenRefresh()
    -- Draw header
    lcd.drawFilledRectangle(0, 0, LCD_W, HEADER, COLOR_THEME_SECONDARY1)
    lcd.drawText(COL1, HEADER / 2, "gpsF3xTracker", VCENTER + DBLSIZE + libGUI.colors.primary2)

    if not gpsOK then
        gpsSignal.title = strSensorInitFailed
        gpsSignal.flags = VCENTER + BOLD + RED + BLINK
        return
    end

    -- if gpsOK or debug then  
    if type(global_gps_pos) == 'table' and 
            (global_gps_pos.lat ~= 0.0 and global_gps_pos.lon ~= 0.0) then   
        compLabel.title = global_comp_display

        -- check for start event
        if startSwitchPressed() then
            if global_comp_type == 'f3b_dist' then
                if comp.state ~= 1 and comp.runs > 0 and runs ~= comp.runs then
                    -- comp finished by hand
                    runs = comp.runs -- lock update 
                    -- screen.addLaps(comp.runs, comp.lap - 1)                    
                end
            end
            comp.start()
            lapItems = {"L1 : ", "L2 : ", "L3 : ", "L4 : ", "L5 : ", "L6 : ", "L7 : ", "L8 : ", "L9 : ", "L10 : "}
            -- lapsMenu.reset(lapItems)
            lapsMenu.items = lapItems
            comp.lap = 0
        end
--[[     
        if comp.state == 1 and comp.runs > 0 and runs ~= comp.runs then
            runs = comp.runs -- lock update
            if global_comp_type == 'f3b_dist' then
                -- screen.addLaps(runs, comp.lap - 1)
            else
                -- screen.addTime(runs, comp.runtime)
            end
            -- screen.showStack()
        end
]]--
        integer, decimal_part = math.modf(comp.runtime / 1000)
        timerLabel.title = string.format("%02d:%02d", integer, decimal_part * 100)
        courseLabel.title = comp.message
        if global_comp_type == 'f3b_dist' or global_comp_type == 'f3b_spee' then
          if global_baseA_left then
            speedDestLabel.title = string.format("V: %6.2f m/s Dst: %-7.2f m ", course.lastGroundSpeed,  course.lastDistance + 75)
          else
            speedDestLabel.title = string.format("V: %6.2f m/s Dst: %-7.2f m ", course.lastGroundSpeed,  course.lastDistance - 75)
          end
        else
          speedDestLabel.title = string.format("V: %6.2f m/s Dst: %-7.2f m ", course.lastGroundSpeed,  course.lastDistance)
        end
        latLabel.title = global_gps_pos.lat
        lonLabel.title = global_gps_pos.lon
        latLabel.flags = VCENTER + BLACK
        lonLabel.flags = VCENTER + BLACK
        
        -- print(string.format("GPS: %9.6f %9.6f", global_gps_pos.lat, global_gps_pos.lon))
        gpsSignal.title = strGpsFixLock.." ... [ "..global_gps_sensor.gpsSats().." ]"
        gpsSignal.flags = VCENTER + BOLD + BLACK
        
        if comp.lap > 1 then
            if global_comp_type == 'f3b_dist' then
                -- lapItems[comp.lap] = "L"..comp.lap.." : "..comp.laptime --timerLabel.title 
                lapItems[comp.lap - 1] = string.format("L%d : %3.2fs", comp.lap - 1, comp.laptime)
            else
                -- lapItems[comp.lap] = "L"..comp.lap.." : "..comp.laptime
                lapItems[comp.lap - 1] = string.format("L%d : %3.2fs", comp.lap - 1, comp.laptime)
            end
            lapsMenu.items = lapItems
        end
    else
        -- GPS sensor is warming up
        gpsSignal.title = strWaitingForGpsSignal
        gpsSignal.flags = VCENTER + BOLD + RED + BLINK
        latLabel.title = "---"
        lonLabel.title = "---"
        latLabel.flags = VCENTER + LIGHTGREY
        lonLabel.flags = VCENTER + LIGHTGREY
    end
end

-- Draw in widget mode
function libGUI.widgetRefresh()
  lcd.drawRectangle(0, 0, zone.w, zone.h, libGUI.colors.primary3)
  lcd.drawText(zone.w / 2, zone.h / 2, "gpsF3xTracker", DBLSIZE + CENTER + VCENTER + libGUI.colors.primary3)
--[[
      -- if gpsOK or debug then  
    if type(global_gps_pos) == 'table' and 
            (global_gps_pos.lat ~= 0.0 and global_gps_pos.lon ~= 0.0) then   
        compLabel.title = global_comp_display

        -- check for start event
        if startSwitchPressed() then
            if global_comp_type == 'f3b_dist' then
                if comp.state ~= 1 and comp.runs > 0 and runs ~= comp.runs then
                    -- comp finished by hand
                    runs = comp.runs -- lock update 
                    -- screen.addLaps(comp.runs, comp.lap - 1)
                    -- lapsLabel.title = "Lap " .. (comp.lap - 1)
                end
            end
            comp.start()
        end
     
        if comp.state == 1 and comp.runs > 0 and runs ~= comp.runs then
            runs = comp.runs -- lock update
            if global_comp_type == 'f3b_dist' then
                -- screen.addLaps(runs, comp.lap - 1)
                -- lapsLabel.title = "Lap " .. (comp.lap - 1)
            else
                -- screen.addTime(runs, comp.runtime)
            end
            -- screen.showStack()
        end
    end
    
    lcd.drawText(4, 4, global_comp_display)
    if global_baseA_left then
        lcd.drawText(124, 4, "BASE A Left")
    else
        lcd.drawText(124, 4, "BASE A Right")
    end
    integer, decimal_part = math.modf(comp.runtime / 1000)    
    lcd.drawText(10, 20, string.format("%02d:%02d", integer, decimal_part * 100), FONT_38 + YELLOW)
    -- lcd.drawText(10, 100, comp.message)
    if type(global_gps_pos) == 'table' and 
            (global_gps_pos.lat ~= 0.0 and global_gps_pos.lon ~= 0.0) then   
      lcd.drawText(10, 90, strGpsFixLock.." ... [ "..global_gps_sensor.gpsSats().." ]", BOLD + BLACK)
    else
      lcd.drawText(10, 90, strWaitingForGpsSignal, BOLD + RED)
    end
]]--
    lcd.drawText(10, zone.h - 26, "Touch then press ENT full screen mode", BOLD + GREY)

    --print("sh = "..startSwitchInfo.id) -- 127
    --print("s2 = "..centerSliderInfo.id) -- 93
end

function refresh()
    local centerSliderInfo = getFieldInfo("s2")
---[[  
    local val = getValue(centerSliderInfo.id) / 20.
    if val > 50 then
        val = 50
    elseif val < -50 then
        val = -50
    end
--]]--    
--[[
    local val = getValue(centerSliderInfo.id) / 5.
    if val > 200 then
        val = 200
    elseif val < -200 then
        val = -200
    end
--]]--  
    course.centerOffset = val

    local dirStr = ""
    if val < 0 then
       dirStr = "Left"
    elseif val > 0 then
       dirStr = "Right"
    elseif val == 0 then
       dirStr = "Center"
    end
    centerOffsetLabel.title = string.format("%s %.1f m", dirStr, val)

    if global_comp_type == 'f3b_dist' or global_comp_type == 'f3b_spee' then
      -- course.centerOffset = course.centerOffset - 75 -- Base A located on the left side of center position face to course frame
      if global_baseA_left then
        course.centerOffset = course.centerOffset - 75
      else
        course.centerOffset = course.centerOffset + 75
      end
    end

    if global_has_changed then
        -- print("Reload Competition ...")
        reloadCompetition()
        if global_comp_type == 'f3b_dist' or global_comp_type == 'f3b_spee' then
          baseALabel.title = "---"
        else  
          if global_baseA_left then
              baseALabel.title = "BASE A Left"
          else
              baseALabel.title = "BASE A Right"
          end
        end
        global_has_changed = false
    end
    
    if gpsOK then
        global_gps_pos = global_gps_sensor.gpsCoord()

        -- if type(global_gps_pos) == 'table' and type(global_home_pos) == 'table' then
        if type(global_gps_pos) == 'table' and 
                (global_gps_pos.lat ~= 0.0 and global_gps_pos.lon ~= 0.0) then
            if global_home_pos.lat == 0.0 and global_home_pos.lon == 0.0 then
                global_home_pos.lat = global_gps_pos.lat
                global_home_pos.lon = global_gps_pos.lon
-- print("Set current position as home ...")
-- print(string.format("GPS: %9.6f %9.6f", global_gps_pos.lat, global_gps_pos.lon))
                -- global_has_changed = true
            end
            local dist2home = gps.getDistance(global_home_pos, global_gps_pos)
            local dir2home = gps.getBearing(global_home_pos, global_gps_pos)
            local groundSpeed = global_gps_sensor.gpsSpeed() or 0.
            local gpsHeight = global_gps_sensor.gpsAlt() or 0.
            local acclZ = global_gps_sensor.az() or 0.
            -- update course
            course.update(dist2home, dir2home, groundSpeed, acclZ)
            -- update competition
            comp.update(gpsHeight)
            -- print(string.format("comp.state = %d", comp.state))
            -- print(string.format("V: %6.2f m/s Dst: %-7.2f m ", course.lastGroundSpeed,  course.lastDistance))
        else
            -- print("waiting...")
        end
    end
end

-- This function is called from the refresh(...) function in the main script
function widget.refresh(event, touchState)
  refresh()
  gui.run(event, touchState)
  -- print("refresh...")
end

function widget.background(widget)
  refresh()
    -- print("background...")
end

-- Return to the create(...) function in the main script
return widget
