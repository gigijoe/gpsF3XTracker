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

-- GLOBAL VARIABLES
-- global_gps_pos = ... -- from main.lua
global_home_dir = 0.0 -- placeholder
global_home_pos = {lat=0.,lon=0.} -- placeholder
global_baseA_left = true -- default
global_has_changed = false -- default

global_comp_types = {
    {name='f3f_trai', default_mode='training', course_length=100, file='f3f.lua', display='F3F Training' },
    {name='f3f', default_mode='competition', course_length=100, file='f3f.lua', display='F3F Competition' },
    {name='f3b_dist', default_mode='competition', course_length=150, file='f3bdist.lua', display='F3B Distance' },
    {name='f3b_spee', default_mode='competition', course_length=150, file='f3bsped.lua', display='F3B Speed' },
    {name='f3f_debug', default_mode='training', course_length=10, file='f3f.lua', display='F3F Debug' }
}

global_comp_type = global_comp_types[1].name
global_comp_display = global_comp_types[1].display

-- GLOBAL CONSTANTS
strWaitingForGpsSignal = "Waiting for GPS Signal ..."
strGpsFixLock = "GPS Fix Lock"

-----------------------------------------------------------
-- Sub GUI
-----------------------------------------------------------

local gpsSignal = gui.label(COL1, TOP, 3 * WIDTH, HEIGHT, strWaitingForGpsSignal, BOLD)

-- A sub-gui
local subGUI = gui.gui(COL1, TOP + ROW, COL4 + 3 * WIDTH - COL3, 2 * ROW)

-----------------------------------------------------------
-- Competition
-----------------------------------------------------------

local competitionItems = {}
for i = 1, #global_comp_types do
    competitionItems[i] = global_comp_types[i].display
end

-- A drop-down with physical switches
subGUI.label(0, 0, 2 * WIDTH, HEIGHT, "Competition")

local function competitionChange(dropDown)
  local i = dropDown.selected
  global_comp_type = global_comp_types[i].name
  global_comp_display = global_comp_types[i].display
  
  global_has_changed = true
end

local competition = subGUI.dropDown(COL2s, 0, 2 * WIDTH, HEIGHT, competitionItems, 1, competitionChange)

-----------------------------------------------------------
-- Location
-----------------------------------------------------------

local locationItems = { }

function mydofile (filename)
    -- local f = assert(loadfile(filename))
    --  mode: b: only binary, t: only text, c: compile only, x: do not compile
    local mode = 'bt'
    if on_simulator then
        mode = 'T'
    end
    local f = assert(loadScript(filename,mode))
    return f()
end

local basePath = '/WIDGETS/gpsF3xT/gpstrack/'

-----------------------------------------------------------
-- Direction
-----------------------------------------------------------

-- Horizontal slider
gui.label(COL1, TOP + 5 * ROW, WIDTH, HEIGHT, "Course Direction:", BOLD)
local horizontalSliderLabel = gui.label(COL1 + 2 * WIDTH + 12, TOP + 6 * ROW, 30, HEIGHT, "", RIGHT)

local function horizontalSliderCallBack(slider)
  global_home_dir = slider.value
  horizontalSliderLabel.title = slider.value
end

local horizontalSlider = gui.horizontalSlider(COL1, TOP + 6 * ROW + HEIGHT / 2, 2 * WIDTH, 0, 0, 360, 1, horizontalSliderCallBack)
horizontalSliderCallBack(horizontalSlider)

-----------------------------------------------------------
-- Location
-----------------------------------------------------------

-- load locations table  
locations = mydofile(basePath..'locations.lua')

-- for i, s in ipairs(locations) do
for i = 1, #locations do
    locationItems[i] = locations[i].name
end

-- A drop-down with physical switches
subGUI.label(0, ROW, 3 * WIDTH, HEIGHT, "Location")

gui.label(COL1, ROW2, WIDTH, HEIGHT, "Latitude", BOLD)
gui.label(COL2, ROW2, WIDTH, HEIGHT, "Longitude", BOLD)
local latHome = gui.label(COL1, ROW2 + ROW, WIDTH, HEIGHT, "---")
local lonHome = gui.label(COL2, ROW2 + ROW, WIDTH, HEIGHT, "---")

local locationIndex = 1

local function locationChange(dropDown)
    local i = dropDown.selected
    
    if i == 1 then
        -- if type(global_gps_pos) == 'table' then
        if type(global_gps_pos) == 'table' and
                (global_gps_pos.lon ~= 0.0 or global_gps_pos.lat ~= 0.0) then
            global_home_pos.lat = global_gps_pos.lat
            global_home_pos.lon = global_gps_pos.lon
            latHome.title = global_gps_pos.lat
            lonHome.title = global_gps_pos.lon
        else
            global_home_pos.lat = 0.0
            global_home_pos.lon = 0.0
            latHome.title = "---"
            lonHome.title = "---"
        end
    else
        global_home_pos.lat = locations[i].lat
        global_home_pos.lon = locations[i].lon
        latHome.title = locations[i].lat
        lonHome.title = locations[i].lon
        horizontalSlider.value = locations[i].dir
        horizontalSliderLabel.title = locations[i].dir
    end
    locationIndex = i

    global_has_changed = true
end

local location = subGUI.dropDown(COL2s, ROW, 3 * WIDTH, HEIGHT, locationItems, 1, locationChange)

-----------------------------------------------------------
-- Base A Left / Right
-----------------------------------------------------------

-- Toggle button
local baseALeft

local function baseAleftChange(self)
    global_baseA_left = self.value
    if self.value then
        baseALeft.title = "BASE A Left"
    else
        baseALeft.title = "BASE A Right"
    end
    
    global_has_changed = true
end

baseALeft = gui.toggleButton(COL1, TOP + 7 * ROW, 2 * WIDTH, HEIGHT, "BASE A Left", true, baseAleftChange)

-- Prompt showing About text
local aboutPage = 1
local aboutText = {
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
}

local aboutPrompt = libGUI.newGUI()

function aboutPrompt.fullScreenRefresh()
  lcd.drawFilledRectangle(40, 30, LCD_W - 80, 30, COLOR_THEME_SECONDARY1)
  lcd.drawText(50, 45, "About LibGUI  " .. aboutPage .. "/" .. #aboutText, VCENTER + MIDSIZE + libGUI.colors.primary2)
  lcd.drawFilledRectangle(40, 60, LCD_W - 80, LCD_H - 90, libGUI.colors.primary2)
  lcd.drawRectangle(40, 30, LCD_W - 80, LCD_H - 60, libGUI.colors.primary1, 2)
  lcd.drawTextLines(50, 70, LCD_W - 120, LCD_H - 110, aboutText[aboutPage])
end

-- Button showing About prompt
gui.button(COL4, TOP + 7 * ROW, WIDTH, HEIGHT, "About", function() gui.showPrompt(aboutPrompt) end)

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

-- Draw on the screen before adding gui elements
function gui.fullScreenRefresh()
  -- Draw header
  lcd.drawFilledRectangle(0, 0, LCD_W, HEADER, COLOR_THEME_SECONDARY1)
  lcd.drawText(COL1, HEADER / 2, "gpsF3xSetup", VCENTER + DBLSIZE + libGUI.colors.primary2)

  -- GPS position updated in gpsF3xT widget.background(widget)
  -- global_gps_pos = global_gps_sensor.gpsCoord()
  
  if type(global_gps_pos) == 'table' and
        (global_gps_pos.lon ~= 0.0 and global_gps_pos.lat ~= 0.0) then
    if locationIndex == 1 then
        global_home_pos.lat = global_gps_pos.lat
        global_home_pos.lon = global_gps_pos.lon
        latHome.title = global_gps_pos.lat
        lonHome.title = global_gps_pos.lon
    end
    gpsSignal.title = strGpsFixLock
    gpsSignal.flags = VCENTER + BOLD + BLACK
  else
    if locationIndex == 1 then
      latHome.title = "---"
      lonHome.title = "---"
    end
    gpsSignal.title = strWaitingForGpsSignal
    gpsSignal.flags = VCENTER + BOLD + RED
  end
end

-- Draw in widget mode
function libGUI.widgetRefresh()
  lcd.drawRectangle(0, 0, zone.w, zone.h, libGUI.colors.primary3)
  lcd.drawText(zone.w / 2, zone.h / 2, "gpsF3xSetup", DBLSIZE + CENTER + VCENTER + libGUI.colors.primary3)

  lcd.drawText(10, 140, "Touch then press ENT full screen mode", BOLD + GREY)
end

-- This function is called from the refresh(...) function in the main script
function widget.refresh(event, touchState)
  gui.run(event, touchState)
end

function widget.background(widget)
end

-- Return to the create(...) function in the main script
return widget
