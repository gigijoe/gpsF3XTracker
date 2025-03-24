---------------------------------------------------------------------------
-- Shared Lua utilities library, and a widget showing how to use it.     --
-- NOTE: It is not necessary to load the widget to use the library;      --
-- as long as the files are present on the SD card it works.             --
--                                                                       --
-- Author:  Jesper Frickmann                                             --
-- Date:    2021-12-20                                                   --
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
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         --
-- GNU General Public License for more details.                          --
---------------------------------------------------------------------------
local name = "gpsF3xT"
local libGUI

-- Return GUI library table
function loadGUI()
  if not libGUI then
  -- Loadable code chunk is called immediately and returns libGUI
  	libGUI = loadScript("/WIDGETS/gpsF3xS/libgui.lua")
  end
  
  return libGUI()
end

---------------------------------------------------------------------------
-- The following widget implementation demonstrates how to use the       --
-- library and how to create a dynamically loadable widget to minimize   --
-- the amount of memory consumed when the widget is not being used.      --
-- You do not need to run the widget to use the library.                 --
---------------------------------------------------------------------------

local function create(zone, options)
  -- Loadable code chunk is called immediately and returns a widget table
  return loadScript("/WIDGETS/" .. name .. "/loadable.lua")(zone, options)
end

local function refresh(widget, event, touchState)
  widget.refresh(event, touchState)
end

local function background(widget)
  widget.background(widget)
end

local options = {
  -- If options is changed by the user in the Widget Settings menu, then update will be called with a new options table
  { "Start_Switch", SOURCE, getSourceIndex("sh") },
  { "Center_Slider", SOURCE, getSourceIndex("s2") },
}

startSwitchInfo = getFieldInfo("sh")
centerSliderInfo = getFieldInfo("s2")

local function update(widget, options)
  startSwitchInfo = getFieldInfo(options.Start_Switch)
  centerSliderInfo = getFieldInfo(options.Center_Slider)
end

return {
  name = name,
  create = create,
  refresh = refresh,
  background = background,
  options = options,
  update = update
}
