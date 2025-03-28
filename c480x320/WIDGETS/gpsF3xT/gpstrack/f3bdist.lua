--[[#############################################################################
COMPETITION Library: F3B Distance
F3B: we define: baseA is always left. 
state:
 0: not armed
 5: entry: armed
10: entry: wait for BaseLineOut/In event
15: entry: wait for BaseLineIn event
20: competition: start countdown timer (4 mins or remaining frame time) 
25: BaseBOut, lap = lap + 1
27: BaseAOut, lap = lap + 1 
functions: ---------------------------------------------------------------------
################################################################################]]

local comp = {name='f3bdist.lua', baseAleft=true, mode='training', trainig=true, state=0, groundHeight=0., lastHeight=0., runtime=0, message='---'}

function comp.init(mode, startLeft)
    comp.training = false -- not needed
    comp.mode = 'competition' -- not needed
    --comp.baseAleft = true -- always true for F3B
    if startLeft then
        comp.baseAleft = true
    else
        comp.baseAleft = false
    end
    comp.state = 0 -- initial state
    comp.startTime_ms = 0
    comp.lap = 0
    comp.laptime = 0
    comp.lastLap = 0
    comp.runs = 0
    comp.leftBaseIn = 0
    comp.leftBaseOut = 0
    comp.rightBaseIn = 0
    comp.rightBaseOut = 0
    comp.workingTime_ms = (7 * 60 * 1000)
    comp.compTime_ms = (4 * 60 * 1000)
    comp.played = { }
    comp.played_minutes = { }
end


function comp.countdown(elapsed_milliseconds)
    local milliseconds = (comp.comptTime_ms + 500) - elapsed_milliseconds
    local seconds = math.floor(milliseconds / 1000)
    
    if seconds >= 60 then
        local minutes = math.floor(seconds/60)
        if not com.played_minutes[minutes] then
            playNumber(minutes,36)
            comp.played_minutes[minutes] = true
        end
        return
    end
    if seconds >= 10 and seconds % 10 == 0 then 
        if not comp.played[seconds] then
            playNumber(seconds,0)
            comp.played[seconds] = true
        end
    end
end
-- prepare all bases for next timing event 
function comp.cleanbases()
    comp.leftBaseIn = 0
    comp.leftBaseOut = 0
    comp.rightBaseIn = 0
    comp.rightBaseOut = 0
end
-- start competition timer
function comp.startTimer()
    comp.runtime = 0
    comp.laptime = 0
    comp.startTime_ms = getTime() * 10
end
-- reset all values and start the competition
function comp.start()
    playTone(800,300,0,PLAY_NOW)
    -- start button activated during run -> finish run
    if comp.state == 25 or comp.state == 27 then
        comp.state = 30
        return
    end
    -- start the status machine
    comp.cleanbases()
    comp.lap = 0
    comp.runtime = 0
    comp.laptime = 0 

    if comp.state == 1 then
        comp.message = "started..."
        comp.state = 10
    else
        comp.message = "cancelled..."
        comp.state = 0
        comp.runtime = 0
        comp.laptime = 0
    end
end
-- messages on base
function comp.lapPassed(lap, laptime, lostHeight)
    comp.message = string.format("lap %d: %5.2fs diff: %-5.1fm", lap, laptime/1000.0, lostHeight)
    playNumber(lap, 0)
    playNumber((laptime+5) / 10., UNIT_SECONDS, PREC2) -- milliseconds * 1000 = seconds * 10 = seconds + 1 decimal
    playHaptic(300, 0, PLAY_NOW)
    --[[
    if math.abs(lostHeight) > 0.5 then
        playNumber(lostHeight,0,PREC2) -- lost height in meters per lap
    end
    ]]--
end
-------------------------------------------------------
-- Update Competition Status Machine
-------------------------------------------------------
function comp.update(height)
    comp.groundHeight = height or 0.
    -------------------------------------------------------
    -- 0/1: not armed 
    ------------------------------------------------------- 
    if comp.state == 0 then
        -- set start message and block further updates
        comp.message = "waiting for start..."
        comp.state = 1
        return
    elseif comp.state == 1 then
        return
    end
    -------------------------------------------------------
    -- 10: WAIT for BASE A IN/OUT
    -------------------------------------------------------
    if comp.state == 10 then
        if comp.baseAleft then
            if comp.leftBaseOut > 0 then
                playTone(800,300,0,PLAY_NOW)
                comp.cleanbases()
                comp.message = "out of course"
                comp.state = 15 -- wait for base A in event
            elseif comp.leftBaseIn > 0 then
                playTone(800,300,0,PLAY_NOW)
                comp.message = "in course..."
                comp.state = 20 -- go to start
            end
        else
            if comp.rightBaseOut > 0 then
                playTone(800,300,0,PLAY_NOW)
                comp.cleanbases()
                comp.message = "out of course"
                comp.state = 15 -- wait for base A in event
            elseif comp.rightBaseIn > 0 then
                playTone(800,300,0,PLAY_NOW)
                comp.message = "in course..."
                comp.state = 20 -- go to start
            end
        end
        return
    end
    -------------------------------------------------------
    -- 15: BASE A IN (from outside)
    -------------------------------------------------------
    if comp.state == 15 then
        if comp.baseAleft then
            if comp.leftBaseIn > 0 then
                playTone(800,300,0,PLAY_NOW)
                comp.message = "in course..."
                comp.state = 20
                return
            end
        else
            if comp.rightBaseIn > 0 then
                playTone(800,300,0,PLAY_NOW)
                comp.message = "in course..."
                comp.state = 20
                return
            end
        end
        return
    end
    -------------------------------------------------------
    -- 20: START at BASE A
    -------------------------------------------------------
    if comp.state == 20 then
        comp.startTimer()
        comp.cleanbases()
        comp.lastLap = comp.startTime_ms
        comp.lap = 1
        if comp.baseAleft then
            comp.state = 25 -- first base is right
        else
            comp.state = 27 -- first base is left
        end
        return
    end
    -------------------------------------------------------
    -- 25: BASE B (comp running)
    -------------------------------------------------------
    if comp.state == 25 and comp.lap > 0 then
        -- working time exceeded?
        comp.runtime = getTime() * 10 - comp.startTime_ms
        if comp.runtime >= comp.compTime_ms then
            -- competition ended after 4 minutes
            comp.state = 30
            return
        end  
        -- Base B
        if comp.rightBaseOut  > 0 then
            local laptime = comp.rightBaseOut - comp.lastLap
            local lostHeight = comp.groundHeight - comp.lastHeight
            playTone(800,300,0,PLAY_NOW)
            comp.lastLap = comp.rightBaseOut
            comp.lastHeight = comp.groundHeight
            comp.cleanbases()
            comp.lapPassed(comp.lap, laptime, lostHeight)
            comp.lap = comp.lap + 1
            comp.laptime = laptime / 1000.
            comp.state = 27 -- next base must be A
        end
        return
    end
    -------------------------------------------------------
    -- 27: BASE A (comp running)
    -------------------------------------------------------
    if comp.state == 27 and comp.lap > 0 then
        -- working time exceeded?
        comp.runtime = getTime() * 10 - comp.startTime_ms
        if comp.runtime > comp.compTime_ms then
            -- competition ended after 4 minutes
            comp.state = 30
            return
        end
        -- Base A
        if comp.leftBaseOut > 0 then
            local laptime = comp.leftBaseOut - comp.lastLap
            local lostHeight = comp.groundHeight - comp.lastHeight
            playTone(800,300,0,PLAY_NOW)
            comp.lastLap = comp.leftBaseOut
            comp.lastHeight = comp.groundHeight
            comp.cleanbases()
            comp.lapPassed(comp.lap, laptime, lostHeight)
            comp.lap = comp.lap + 1
            comp.laptime = laptime / 1000.
            comp.state = 25 -- next base must be A
        end     
        return
    end
    -------------------------------------------------------
    -- 30: END
    -------------------------------------------------------
    if comp.state == 30 then
        playTone(1000,1000,0,PLAY_NOW) -- 1000Hz, 1000ms duration
        if comp.lap > 0 then
            playNumber(comp.lap - 1, 0) -- lap count
        end

        comp.runtime = comp.compTime_ms
        comp.runs = comp.runs + 1
        comp.state = 0
        return
    end
end

return comp
