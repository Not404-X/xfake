script_name("SA-MPxNot404 MENU")
script_author("xFake")
require "lib.moonloader"
require "lib.sampfuncs"

local f = io.open("/data/data/ro.alyn_sampmobile.game/files/lua_token.txt", "r")
    
    if not f then
        sampAddChatMessage("{FF0000}Unauthorized Client", -1)
        thisScript():unload()
        return
    end
    
    local token = f:read("*a")
    f:close()
    
    if token ~= "xFake_THE ONLY ONE" then
        sampAddChatMessage("{FF0000}Invalid Client", -1)
        thisScript():unload()
        return
    end
    
    sampAddChatMessage("{00FF00}Client Verified", -1)

local sampev = require "samp.events"
local ini    = require "inicfg"
local imgui  = require "mimgui"
local bit    = require "bit"
local widgets = require 'widgets'

-- FIX WIDGET
if not WIDGET_SCHOOL_START then
    WIDGET_SCHOOL_START = 18
end

local god_enabled = false
local car_god_enabled = false
local last_god_vehicle = nil
local function setVehicleProofsSafe(vehicle, state)
    if type(vehicle) ~= "number" or vehicle == 0 then return end
    if not doesVehicleExist(vehicle) then return end
    pcall(function()
        setCarProofs(vehicle, state, state, state, state, state)
    end)
end
local INI_PATH = "esp_config"
local CFG = ini.load({settings = {
    maxDist       = 300.0,
    fontSize      = 12,
    textColor     = 0xFFFFFFFF,
    lineColor     = 0xFFFFFFFF,
    showLines     = false,
    showVeh       = false,
    showBox       = false,
    showHP        = false,
    showName      = false,
    showWeapon    = false,
    playerGodmode    = false,
    playerAirBrake   = false,
    tpMarker= false,
    playerHighJump   = false,
    playerSprint     = false,
    bypassX      = false,
    vehGodmode        = false,
    vehFixBody        = false,
    vehRepair        = false,
    vehAutoEngine     = false,
    vehOpenVehicle    = false,
    vehJumpX   = false
}}, INI_PATH)

phone_prev = false
phoneWidgetVisible = false
prevAirBrake = false
ab_enabled = false

local fName, fVeh, fSmall
local nameStack = {}
local hpC, arC = {}, {}
local lastInvisState = false
local airBrakeHoldCoords = nil
if _G.currentTab == nil then _G.currentTab = "ESP" end
local weaponNames = {
    [0]="Tangan Kosong",[22]="9mm",[23]="Silenced 9mm",[24]="Desert Eagle",
    [25]="Shotgun",[26]="Sawn-off",[27]="SPAS-12",[28]="Micro Uzi",[29]="MP5",
    [30]="AK-47",[31]="M4",[32]="Tec-9",[33]="Rifle",[34]="Sniper Rifle"
}
local function getWeaponName(id) return weaponNames[id] or ("Weapon "..tostring(id)) end
local function hex_to_rgba_table(hex)
    local a = bit.band(bit.rshift(hex,24),0xFF)/255
    local r = bit.band(bit.rshift(hex,16),0xFF)/255
    local g = bit.band(bit.rshift(hex,8),0xFF)/255
    local b = bit.band(hex,0xFF)/255
    return {r,g,b,a}
end
local function rgba_table_to_hex(t)
    local a = bit.band(math.floor((t[4] or 1)*255),0xFF)
    local r = bit.band(math.floor((t[1] or 1)*255),0xFF)
    local g = bit.band(math.floor((t[2] or 1)*255),0xFF)
    local b = bit.band(math.floor((t[3] or 1)*255),0xFF)
    return bit.bor(bit.lshift(a,24),bit.lshift(r,16),bit.lshift(g,8),b)
end
function fixVehicleVisual(veh)
    if not doesVehicleExist(veh) then return end
    local health = getCarHealth(veh)
    pcall(function() fixCar(veh) end)
    if health < 1000.0 then setCarHealth(veh, health) end
end
local RPC_SCRSETVEHICLEPARAMSFORPLAYER = RPC_SCRSETVEHICLEPARAMSFORPLAYER or 137
local VEH_MIN = 1
local VEH_MAX = 211
local function raknet_ok()
    return type(raknetNewBitStream) == "function"
       and type(raknetBitStreamWriteInt16) == "function"
       and type(raknetBitStreamWriteInt8) == "function"
       and type(raknetEmulRpcReceiveBitStream) == "function"
end
local function freeBitStream(bs)
    if type(raknetFreeBitStream) == "function" then
        raknetFreeBitStream(bs)
    elseif type(raknetDeleteBitStream) == "function" then
        raknetDeleteBitStream(bs)
    end
end
local function unlockVeh(v)
    if type(v) ~= "number" or v == 0 then return false end
    if not raknet_ok() then return false end
    local bs = raknetNewBitStream()
    if not bs then return false end
    raknetBitStreamWriteInt16(bs, v)
    raknetBitStreamWriteInt8(bs, 0)
    raknetBitStreamWriteInt8(bs, 0)
    pcall(function()        raknetEmulRpcReceiveBitStream(RPC_SCRSETVEHICLEPARAMSFORPLAYER, bs)
    end)
    freeBitStream(bs)
    return true
end
-- line lingkaran 
function drawCircle(x, y, radius, color, segments)
    segments = segments or 16
    local step = (math.pi * 2) / segments
    local lastX = x + radius
    local lastY = y

    for i = 1, segments do
        local angle = step * i
        local newX = x + math.cos(angle) * radius
        local newY = y + math.sin(angle) * radius

        renderDrawLine(lastX, lastY, newX, newY, 0.8, color)

        lastX = newX
        lastY = newY
    end
end
-- SAVE CONFIG
local function save()
    ini.save(CFG, INI_PATH)
end

-- UPDATE FONTS
local function updFonts()
    if fName then renderReleaseFont(fName) end
    if fVeh then renderReleaseFont(fVeh) end
    if fSmall then renderReleaseFont(fSmall) end

    fName  = renderCreateFont("Arial", CFG.settings.fontSize, 5)
    fVeh   = renderCreateFont("Arial", 12, 0)
    fSmall = renderCreateFont("Arial", 8, 5)
end

-------------------------------------------------
-- SAFE HP ARMOR (SAMP + PED FALLBACK)
-------------------------------------------------
local function safeHP(id, ped)
    local hp = sampGetPlayerHealth(id) or 0
    local ar = sampGetPlayerArmor(id) or 0

    if hp == 0 and doesCharExist(ped) then
        hp = getCharHealth(ped)
    end

    if ar == 0 and doesCharExist(ped) then
        ar = getCharArmour(ped)
    end

    if hp > 100 then hp = 100 end
    if ar > 100 then ar = 100 end

    return hp, ar
end

-------------------------------------------------
-- DRAW HP + ARMOR BAR
-------------------------------------------------
local function drawHPBar(id, ped, sx, sy)

    if not CFG.settings.showHP then return end

    local hp, ar = safeHP(id, ped)

    local px,py,pz = getCharCoordinates(PLAYER_PED)
    local x,y,z = getCharCoordinates(ped)

    local dist = getDistanceBetweenCoords3d(px,py,pz,x,y,z)

    local baseWidth = 60
    local baseHeight = 6

    local scale = 1 - (dist * 0.025)
    if scale < 0.55 then scale = 0.55 end

    local w = baseWidth * scale
    local h = baseHeight * scale
    local spacing = 2 * scale

    local bg = 0xAA000000
    local hpColor = 0xFFFF0000   -- merah
    local armorColor = 0xFFFFFFFF -- putih

    -- ARMOR BAR
    if ar > 0 then
        renderDrawBox(sx - w/2, sy, w, h, bg)
        renderDrawBox(sx - w/2, sy, (ar/100)*w, h, armorColor)
        sy = sy + h + spacing
    end

    -- HP BAR
    renderDrawBox(sx - w/2, sy, w, h, bg)
    renderDrawBox(sx - w/2, sy, (hp/100)*w, h, hpColor)

end

-------------------------------------------------
-- VEHICLE ESP CONFIG
-------------------------------------------------
local VEH_DRAW_LIMIT = 150
local VEH_UPDATE_MS  = 500
local vehicleCache = {}

local vehicleNames = {
    [411]="Infernus",[415]="Cheetah",[451]="Turismo",[560]="Sultan",[562]="Elegy",
    [559]="Jester",[541]="Bullet",[602]="Alpha",[429]="Banshee",[506]="Super GT",
    [400]="Landstalker",[401]="Bravura",[402]="Buffalo",[403]="Linerunner",[404]="Perrenial",
    [405]="Sentinel",[420]="Taxi",[421]="Washington",[426]="Premier",[507]="Elegant",
    [516]="Nebula",[517]="Majestic",[518]="Buccaneer",[540]="Vincent",[550]="Sunrise",
    [551]="Merit",[554]="Yosemite",[579]="Huntley",[580]="Stafford",[585]="Emperor",
    [489]="Rancher",[495]="Sandking",[500]="Mesa",[561]="Stratum",[565]="Flash",
    [567]="Savanna",[575]="Broadway",[576]="Tornado",[558]="Uranus"
}

local function isValidCoord(x,y,z)
    return x and y and z and x == x and z > -100 and z < 2000
end

-------------------------------------------------
-- VEHICLE CACHE THREAD
-------------------------------------------------
lua_thread.create(function()

    while true do

        local px,py,pz = getCharCoordinates(PLAYER_PED)
        local tmp = {}

        for i = 0, 1999 do

            if doesVehicleExist(i) then

                local ok,x,y,z = pcall(getCarCoordinates, i)

                if ok and isValidCoord(x,y,z) then

                    local dist = getDistanceBetweenCoords3d(px,py,pz,x,y,z)

                    if dist < CFG.settings.maxDist then
                        tmp[#tmp+1] = {id=i,x=x,y=y,z=z,dist=dist}
                    end
                end
            end
        end

        table.sort(tmp,function(a,b) return a.dist < b.dist end)

        vehicleCache = tmp

        wait(VEH_UPDATE_MS)

    end

end)

-------------------------------------------------
-- DRAW VEHICLE ESP
-------------------------------------------------
local function drawVehicleESP()

    if not CFG.settings.showVeh or not fVeh then return end
    if #vehicleCache == 0 then return end

    local px,py,pz = getCharCoordinates(PLAYER_PED)

    local count = 0

    for i = 1, math.min(#vehicleCache, VEH_DRAW_LIMIT) do

        local v = vehicleCache[i]

        if doesVehicleExist(v.id) then

            local ok,x,y,z = pcall(getCarCoordinates, v.id)

            if ok and isValidCoord(x,y,z) and isCarOnScreen(v.id) then

                local dist = getDistanceBetweenCoords3d(px,py,pz,x,y,z)

                if dist <= CFG.settings.maxDist then

                    local sx,sy = convert3DCoordsToScreen(x,y,z+0.8)

                    if sx and sy then

                        local r,g,b = 255,0,0

                        if dist < 15 then
                            r,g,b = 0,255,0
                        elseif dist < 60 then
                            r,g,b = 255,255,0
                        end

                        local color = bit.bor(bit.lshift(255,24),bit.lshift(r,16),bit.lshift(g,8),b)

                        local model = getCarModel(v.id)
                        local name = vehicleNames[model] or "Vehicle"

                        local text = string.format("%s (%d) [%.1fm]",name,model,dist)

                        renderFontDrawText(fVeh,text,sx-45,sy,color)

                        count = count + 1
                        if count >= VEH_DRAW_LIMIT then break end

                    end
                end
            end
        end
    end
end

-------------------------------------------------
-- PLAYER ESP
-------------------------------------------------
function drawESP()

    if not (CFG.settings.showLines or CFG.settings.showBox or CFG.settings.showHP or CFG.settings.showWeapon or CFG.settings.showName) then
        return
    end

    local px,py,pz = getCharCoordinates(PLAYER_PED)
    local _,myId = sampGetPlayerIdByCharHandle(PLAYER_PED)

    -- filter ped supaya tidak double
    local pedUsed = {}

    for id = 0, 1000 do

        if id ~= myId and sampIsPlayerConnected(id) then

            local ok,ped = sampGetCharHandleBySampPlayerId(id)

            if ok and ped ~= PLAYER_PED and doesCharExist(ped) and not isCharDead(ped) then

                -- jika ped sudah dipakai skip
                if pedUsed[ped] then
                    goto skip
                end
                pedUsed[ped] = true

                local x,y,z = getCharCoordinates(ped)
                local dist = getDistanceBetweenCoords3d(px,py,pz,x,y,z)

                if dist < CFG.settings.maxDist and isCharOnScreen(ped) then

                    local sx,sy = convert3DCoordsToScreen(x,y,z+1.0)

                    if sx and sy then

                        local scale = 1 - (dist*0.03)
                        if scale < 0.6 then scale = 0.6 end

                        -- lanjutkan kode ESP kamu di sini
                        ------------------------------------------------
                        -- LINE ESP
                        ------------------------------------------------
                        if CFG.settings.showLines then

    local screenW, screenH = getScreenResolution()

    -- start dari atas tengah layar
    local startX = screenW / 2
    local startY = screenH * 0.05

    -- pakai warna server
    local color = sampGetPlayerColor(id) or CFG.settings.lineColor

    -- garis tipis
    local thickness = 0.4

    renderDrawLine(startX, startY, sx, sy, thickness, color)

    -- lingkaran di ujung player
    drawCircle(sx, sy, 4, color, 18)

end

        ------------------------------------------------
        -- BOX ESP
        ------------------------------------------------
        local topX,topY = convert3DCoordsToScreen(x,y,z+1.0)
        local botX,botY = convert3DCoordsToScreen(x,y,z-1.0)
        
        if topX and botX then
        
            local h = math.abs(topY - botY)
            local w = h / 4.5
        
            local color = sampGetPlayerColor(id) or CFG.settings.lineColor
        
            if CFG.settings.showBox then
        
                renderDrawLine(topX-w,topY,topX+w,topY,1.0,color)
                renderDrawLine(topX-w,botY,topX+w,botY,1.0,color)
                renderDrawLine(topX-w,topY,topX-w,botY,1.0,color)
                renderDrawLine(topX+w,topY,topX+w,botY,1.0,color)
        
            end
        
            ------------------------------------------------
            -- DISTANCE TEXT
            ------------------------------------------------
            if CFG.settings.showBox and fSmall then
        
                local distText = string.format("%.0fm", dist)
        
                local midY = (topY + botY) / 2
                local textX = topX + w + 10
                local textY = midY - 5
        
                renderFontDrawText(
                    fSmall,
                    distText,
                    textX,
                    textY,
                    0xFFFFFFFF
                )
        
            end
        end

                        ------------------------------------------------
                        -- WEAPON ESP
                        ------------------------------------------------
                        if CFG.settings.showWeapon and fVeh then

                            local weapon = getCurrentCharWeapon(ped)
                            local weaponName = getWeaponName(weapon)

                            if weaponName then

                                local tw = renderGetFontDrawTextLength(fVeh,weaponName)

                                renderFontDrawText(
                                    fVeh,
                                    weaponName,
                                    sx - tw/2,
                                    sy - (40*scale),
                                    0xFFFFFFFF
                                )
                            end
                        end

                        ------------------------------------------------
                        -- HP BAR
                        ------------------------------------------------
                        drawHPBar(id,ped,sx,sy-(8*scale))

                        ------------------------------------------------
                        -- NAME ESP
                        ------------------------------------------------
                        if CFG.settings.showName and fName then

                            local name = sampGetPlayerNickname(id)

                            if name then

                                local text = string.format("%s (%d)",name,id)
                                local tw = renderGetFontDrawTextLength(fName,text)

                                local color = sampGetPlayerColor(id) or CFG.settings.textColor

                                renderFontDrawText(
                                    fName,
                                    text,
                                    sx - tw/2,
                                    sy - (35*scale),
                                    color
                                )
                          end      
                      end          
                    end
                end
            end
        end
        ::skip::
    end
end

function sampev.onPlayerSync(pid, d) if d then hpC[pid]=d.health; arC[pid]=d.armour end end
function sampev.onSetPlayerHealth(pid,h) hpC[pid]=h end
function sampev.onSetPlayerArmour(pid,a) arC[pid]=a end
local stealth = {}
local stealth_enabled = false
local lastSend = 0
local safeDelay = 0.12
local maxDelta = 15.0
function stealth.setState(state)
    stealth_enabled = state
    if stealth_enabled then
    end
end
local function safePosition(x, y, z)
    local px, py, pz = getCharCoordinates(PLAYER_PED)
    if getDistanceBetweenCoords3d(x, y, z, px, py, pz) > maxDelta then
        local nx = px + (x - px) * 0.3
        local ny = py + (y - py) * 0.3
        local nz = pz + (z - pz) * 0.3
        return nx, ny, nz
    end
    return x, y, z
end
function stealth.sendRPC(rpcId, writeFunc)
    if not stealth_enabled then return end
    if os.clock() - lastSend < safeDelay then return end
    lastSend = os.clock()

    local bs = raknetNewBitStream()
    writeFunc(bs)
    raknetEmulRpcReceiveBitStream(rpcId, bs)
    raknetDeleteBitStream(bs)
end
function stealth.safeSetPos(x, y, z)
    if not stealth_enabled then
        setCharCoordinatesNoOffset(PLAYER_PED, x, y, z)
        return
    end
    local sx, sy, sz = safePosition(x, y, z)
    setCharCoordinatesNoOffset(PLAYER_PED, sx, sy, sz)
end
local ab_enabled = CFG.settings.playerAirBrake or false
local speed = 0.3
local was_in_car = false
local last_car = nil
local safeTick = 0
local lastSpeedChange = 0
local function getMoveSpeed(heading, spd)
    return math.sin(-math.rad(heading)) * spd, math.cos(-math.rad(heading)) * spd
end
local function setPlayerCarCoordinatesFixed(x, y, z)
    local ox, oy, oz = getCharCoordinates(PLAYER_PED)
    setCharCoordinates(PLAYER_PED, ox, oy, oz)
    local nx, ny, nz = getCharCoordinates(PLAYER_PED)
    local xoff, yoff, zoff = nx - ox, ny - oy, nz - oz
    setCharCoordinates(PLAYER_PED, x - xoff, y - yoff, z - zoff)
end
function onSendPlayerSync(data)
    if ab_enabled then
        if os.clock() - safeTick < 0.05 then return false end
        safeTick = os.clock()
        local mx, my = getMoveSpeed(getCharHeading(PLAYER_PED), math.min(speed, 1))
        data.moveSpeed.x = mx
        data.moveSpeed.y = my
        data.moveSpeed.z = 0.0
        data.surfingVehicleId = 65535
    end
end
function onSendVehicleSync(data)
    if ab_enabled then
        if os.clock() - safeTick < 0.05 then return false end
        safeTick = os.clock()
        local mx, my = getMoveSpeed(getCharHeading(PLAYER_PED), math.min(speed, 2))
        data.moveSpeed.x = mx
        data.moveSpeed.y = my
        data.moveSpeed.z = 0.0
    end
end
local function processSpecialWidgets()
    local dz = 0
    if isWidgetPressed(WIDGET_ZOOM_IN) then dz = dz + speed / 2 end
    if isWidgetPressed(WIDGET_ZOOM_OUT) then dz = dz - speed / 2 end

    if os.clock() - lastSpeedChange > 0.2 then
        if isWidgetPressed(WIDGET_VIDEO_POKER_ADD_COIN) then
            speed = math.min(speed + 0.05, 1.0)
            printStringNow('Speed: ' .. string.format('%.2f', speed), 500)
            lastSpeedChange = os.clock()
        elseif isWidgetPressed(WIDGET_VIDEO_POKER_REMOVE_COIN) then
            speed = math.max(speed - 0.05, 0.1)
            printStringNow('Speed: ' .. string.format('%.2f', speed), 500)
            lastSpeedChange = os.clock()
        end
    end
    return dz
end
local function processAirBrake()
    local camX, camY, camZ = getActiveCameraCoordinates()
    local lookX, lookY, lookZ = getActiveCameraPointAt()
    local angle = -math.rad(getHeadingFromVector2d(lookX - camX, lookY - camY))
    if isCharInAnyCar(PLAYER_PED) then
        local car = storeCarCharIsInNoSave(PLAYER_PED)
        if car ~= last_car and last_car and doesVehicleExist(last_car) and was_in_car then
            freezeCarPosition(last_car, false)
            setCarCollision(last_car, true)
        end
        was_in_car = true
        last_car = car
        freezeCarPosition(car, true)
        setCarCollision(car, false)
        local ok, rawX, rawY = isWidgetPressedEx(WIDGET_VEHICLE_STEER_ANALOG, 0)
        if not ok then rawX, rawY = 0, 0 end
        local iX, iY = rawX / 127, rawY / 127
        local cx, cy, cz = getCharCoordinates(PLAYER_PED)
        cx = cx - (math.sin(angle) * speed * iY)
        cy = cy - (math.cos(angle) * speed * iY)
        cx = cx + (math.cos(angle) * speed * iX)
        cy = cy - (math.sin(angle) * speed * iX)
        cz = cz + processSpecialWidgets()
        setPlayerCarCoordinatesFixed(cx, cy, cz)
        setCarHeading(car, math.deg(-angle))
        stealth.sendRPC(200, function(bs)
            raknetBitStreamWriteFloat(bs, cx)
            raknetBitStreamWriteFloat(bs, cy)
            raknetBitStreamWriteFloat(bs, cz)
        end)
    else
        if was_in_car and last_car and doesVehicleExist(last_car) then
            freezeCarPosition(last_car, false)
            setCarCollision(last_car, true)
        end
        was_in_car = false
        freezeCharPosition(PLAYER_PED, true)
        setCharCollision(PLAYER_PED, false)
        local ok, rawX, rawY = isWidgetPressedEx(WIDGET_PED_MOVE, 0)
        if not ok then rawX, rawY = 0, 0 end
        local iX, iY = rawX / 127, rawY / 127
        local cx, cy, cz = getCharCoordinates(PLAYER_PED)
        cx = cx - (math.sin(angle) * speed * iY)
        cy = cy - (math.cos(angle) * speed * iY)
        cx = cx + (math.cos(angle) * speed * iX)
        cy = cy - (math.sin(angle) * speed * iX)
        cz = cz + processSpecialWidgets()
        stealth.safeSetPos(cx, cy, cz)
        setCharHeading(PLAYER_PED, math.deg(-angle))
        stealth.sendRPC(207, function(bs)
            raknetBitStreamWriteFloat(bs, cx)
            raknetBitStreamWriteFloat(bs, cy)
            raknetBitStreamWriteFloat(bs, cz)
        end)
    end
end
local function enableAirBrake()
    ab_enabled = true
    stealth.setState(true)
end
function disableAirBrake()
    ab_enabled = false
    stealth.setState(false)
    if isCharInAnyCar(PLAYER_PED) then
        local car = storeCarCharIsInNoSave(PLAYER_PED)
        if doesVehicleExist(car) then
            freezeCarPosition(car, false)
            setCarCollision(car, true)
            setCarProofs(car, false, false, false, false, false)
        end
    else
        freezeCharPosition(PLAYER_PED, false)
        setCharCollision(PLAYER_PED, true)
    end
    was_in_car = false
    last_car = nil
end
local showGUI = imgui.new.bool(false)
local maxDistPtr = imgui.new.float(CFG.settings.maxDist)
local fontSizePtr = imgui.new.int(CFG.settings.fontSize)
local textC,lineC = imgui.new.float[4](),imgui.new.float[4]()
local function loadColorPicker()
    local t = hex_to_rgba_table(CFG.settings.textColor)
    for i=0,3 do textC[i]=t[i+1] end
    local l = hex_to_rgba_table(CFG.settings.lineColor)
    for i=0,3 do lineC[i]=l[i+1] end
end
local function applyStyle()
    local style = imgui.GetStyle()
    style.WindowPadding = imgui.ImVec2(10, 6)
    style.FramePadding = imgui.ImVec2(6, 4)
    style.ItemSpacing = imgui.ImVec2(8, 6)
    style.WindowRounding = 8
    style.FrameRounding = 6
    style.ScrollbarSize = 12
    style.GrabRounding = 6
    style.WindowBorderSize = 1.2
    style.FrameBorderSize = 1
    style.ChildBorderSize = 1
    style.PopupBorderSize = 1
    local function rgb(r, g, b, a)
        a = a or 255
        return imgui.ImVec4(r/255, g/255, b/255, a/255)
    end
    local bg_glass        = rgb(10, 10, 18, 235)
    local panel_dark      = rgb(20, 20, 35, 240)
    local neon_blue       = rgb(0, 185, 255)
    local neon_blue_hover = rgb(40, 210, 255)
    local gold_glow       = rgb(255, 215, 120)
    local gold_strong     = rgb(255, 190, 80)
    local text_glow       = rgb(240, 240, 255)
    local text_soft       = rgb(180, 180, 200)
    local border_glow     = rgb(80, 110, 255)
    local shadow_dark     = rgb(0, 0, 0, 180)
    local accent_shadow   = rgb(15, 15, 25)
    style.Colors[imgui.Col.WindowBg]        = bg_glass
    style.Colors[imgui.Col.ChildBg]         = panel_dark
    style.Colors[imgui.Col.PopupBg]         = panel_dark
    style.Colors[imgui.Col.Border]          = border_glow
    style.Colors[imgui.Col.BorderShadow]    = shadow_dark
    style.Colors[imgui.Col.Text]            = text_glow
    style.Colors[imgui.Col.TextDisabled]    = text_soft
    style.Colors[imgui.Col.TitleBg]         = rgb(15,15,25)
    style.Colors[imgui.Col.TitleBgActive]   = rgb(30,30,45)
    style.Colors[imgui.Col.TitleBgCollapsed]= rgb(10,10,20)
    style.Colors[imgui.Col.Button]          = rgb(25,25,45)
    style.Colors[imgui.Col.ButtonHovered]   = neon_blue_hover
    style.Colors[imgui.Col.ButtonActive]    = neon_blue
    style.Colors[imgui.Col.Header]          = rgb(25,25,45)
    style.Colors[imgui.Col.HeaderHovered]   = neon_blue_hover
    style.Colors[imgui.Col.HeaderActive]    = neon_blue
    style.Colors[imgui.Col.FrameBg]         = rgb(30,30,50)
    style.Colors[imgui.Col.FrameBgHovered]  = rgb(45,45,65)
    style.Colors[imgui.Col.FrameBgActive]   = neon_blue
    style.Colors[imgui.Col.CheckMark]       = gold_strong
    style.Colors[imgui.Col.SliderGrab]      = neon_blue
    style.Colors[imgui.Col.SliderGrabActive]= gold_glow
    style.Colors[imgui.Col.ScrollbarBg]            = accent_shadow
    style.Colors[imgui.Col.ScrollbarGrab]          = rgb(50,50,70)
    style.Colors[imgui.Col.ScrollbarGrabHovered]   = neon_blue
    style.Colors[imgui.Col.ScrollbarGrabActive]    = gold_glow
    style.Colors[imgui.Col.Tab]             = rgb(25,25,45)
    style.Colors[imgui.Col.TabHovered]      = neon_blue_hover
    style.Colors[imgui.Col.TabActive]       = neon_blue
    style.Colors[imgui.Col.TabUnfocused]    = rgb(25,25,35)
    style.Colors[imgui.Col.TabUnfocusedActive] = rgb(35,35,50)
    style.Colors[imgui.Col.Separator]       = rgb(50,50,80)
    style.Colors[imgui.Col.SeparatorHovered]= neon_blue_hover
    style.Colors[imgui.Col.SeparatorActive] = gold_glow
    style.Colors[imgui.Col.PlotLines]       = neon_blue
    style.Colors[imgui.Col.PlotLinesHovered]= gold_glow
    style.Colors[imgui.Col.PlotHistogram]   = gold_strong
    style.Colors[imgui.Col.PlotHistogramHovered]= neon_blue_hover
end
local function colorButtonWithPopup(label, colArr, key)
    imgui.SameLine()
    if imgui.ColorButton(label.."##btn", imgui.ImVec4(colArr[0], colArr[1], colArr[2], colArr[3]), 0, imgui.ImVec2(28,18)) then
        imgui.OpenPopup(label.."Popup")
    end
    if imgui.BeginPopup(label.."Popup") then
        if imgui.ColorPicker4("##picker_"..label, colArr) then
            CFG.settings[key] = rgba_table_to_hex({colArr[0],colArr[1],colArr[2],colArr[3]})
        end
        imgui.EndPopup()
    end
end
local function checkboxNoSave(label, cfg_key)
    local ref = imgui.new.bool(CFG.settings[cfg_key])
    if imgui.Checkbox(label, ref) then
        CFG.settings[cfg_key] = ref[0]
    end
end
imgui.OnFrame(function() return showGUI[0] end, function()
    applyStyle()
  imgui.SetNextWindowSize(imgui.ImVec2(380, 380), imgui.Cond.FirstUseEver)
    imgui.Begin("##main", showGUI)
    if not selTabPtr then selTabPtr = imgui.new.int(1) end
    imgui.Separator()
local content_w = imgui.GetWindowContentRegionWidth()
local tab_w = (content_w - 8) / 3
imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.10,0.10,0.15,1.0))
imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.20,0.50,1.0,1.0))
imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.15,0.45,0.90,1.0))
if imgui.Button(" ESP ", imgui.ImVec2(tab_w, 28)) then
    _G.currentTab = "ESP"
end
imgui.SameLine()
if imgui.Button(" Player ", imgui.ImVec2(tab_w, 28)) then
    _G.currentTab = "PLAYER"
end
imgui.SameLine()
if imgui.Button(" Vehicle ", imgui.ImVec2(tab_w, 28)) then
    _G.currentTab = "VEHICLE"
end
imgui.PopStyleColor(3)
imgui.Separator()
imgui.Spacing()
    if _G.currentTab == "ESP" then
        imgui.Text("ESP Settings")
        imgui.Separator()
        imgui.Columns(2, nil, false)
        local itemsLeft = {{"Lines","showLines"},{"HpArmor","showHP"},{"Vehicle","showVeh"}}
        local itemsRight = {{"Kotak","showBox"},{"Names","showName"},{"Weapon","showWeapon"}}
        for _,v in ipairs(itemsLeft) do
            local ref = imgui.new.bool(CFG.settings[v[2]])
            if imgui.Checkbox(v[1], ref) then
                CFG.settings[v[2]] = ref[0]
            end
        end
        imgui.NextColumn()
        for _,v in ipairs(itemsRight) do
            local ref = imgui.new.bool(CFG.settings[v[2]])
            if imgui.Checkbox(v[1], ref) then
                CFG.settings[v[2]] = ref[0]
            end
        end
        imgui.Columns(1)
        imgui.Separator()
        imgui.Text("ESP Range:")
        imgui.PushItemWidth(270)
        if imgui.SliderFloat("##range", maxDistPtr, 50.0, 500.0) then
            CFG.settings.maxDist = maxDistPtr[0]
        end
        imgui.PopItemWidth()
        imgui.SameLine()
        colorButtonWithPopup("Line", lineC, "lineColor")
        imgui.Text("Font Size (Name):")
        imgui.PushItemWidth(270)
        if imgui.SliderInt("##fontSize", fontSizePtr, 8, 30) then
            CFG.settings.fontSize = fontSizePtr[0]
            updFonts()
        end
        imgui.PopItemWidth()
        imgui.SameLine()
        colorButtonWithPopup("Text", textC, "textColor")
    elseif _G.currentTab == "PLAYER" then
        imgui.Text("Player Options")
        imgui.Separator()
        imgui.Columns(2, nil, false)
        checkboxNoSave("Godmode",        "playerGodmode")
        checkboxNoSave("AirBrake",       "playerAirBrake")
        checkboxNoSave("Teleport",   "tpMarker")
        imgui.NextColumn()
        checkboxNoSave("Aim Lock",  "playerHighJump")
        checkboxNoSave("Stamina",   "playerSprint")
        checkboxNoSave("BypassX",     "bypassX")
        imgui.Columns(1)
        imgui.Separator()
        imgui.TextWrapped("xFake Community SA-MP × xNot404")
    elseif _G.currentTab == "VEHICLE" then
        imgui.Text("Vehicle Options")
        imgui.Separator()
        imgui.Columns(2, nil, false)
        checkboxNoSave("RepairX",       "vehRepair")
        checkboxNoSave("Godmode",        "vehGodmode")
        checkboxNoSave("FixBody",       "vehFixBody")        
        imgui.NextColumn()
        checkboxNoSave("Engine",    "vehAutoEngine")
        checkboxNoSave("Unlock",   "vehOpenVehicle")
        checkboxNoSave("Jump",  "vehJumpX")
        imgui.Columns(1)
        imgui.Separator()
        imgui.TextWrapped("xFake Community SA-MP × xNot404")
    end
    imgui.End()
end)
function main()
    repeat wait(0) until isSampAvailable()
    updFonts()
    loadColorPicker()
    --sampAddChatMessage("[MENU404] Loaded! Gunakan /x untuk buka menu.", 0xFFFF2040)
    sampRegisterChatCommand("x", function()
        showGUI[0] = not showGUI[0]
        loadColorPicker()
    end)
    local prevAirBrake = CFG.settings.playerAirBrake or false
    if prevAirBrake then
        enableAirBrake()
    else
        disableAirBrake()
    end
    while true do
    wait(0)
    drawESP()
    drawVehicleESP()
if CFG.settings and CFG.settings.playerGodmode then
    if not god_enabled then
        god_enabled = true
        printStringNow("Godmode ON", 1000)
    end

    if doesCharExist(PLAYER_PED) then
        pcall(function() setCharProofs(PLAYER_PED, true, true, true, true, true) end)
        pcall(function() setCharHealth(PLAYER_PED, 100) end)
    end
else
    if god_enabled then
        god_enabled = false
        printStringNow("Godmode OFF", 1000)
        pcall(function() setCharProofs(PLAYER_PED, false, false, false, false, false) end)
    end
end
if CFG.settings.vehOpenVehicle then
    for id = VEH_MIN, VEH_MAX do
        unlockVeh(id)    
    end
end
    if CFG.settings.vehFixBody and isCharInAnyCar(PLAYER_PED) then
        local veh = storeCarCharIsInNoSave(PLAYER_PED)
        if veh and doesVehicleExist(veh) then
            fixVehicleVisual(veh)
        end
    end
    if CFG.settings.vehGodmode and not car_god_enabled then
    car_god_enabled = true    
elseif not CFG.settings.vehGodmode and car_god_enabled then
    car_god_enabled = false
    if last_god_vehicle then                    setVehicleProofsSafe(last_god_vehicle, false)
        last_god_vehicle = nil
    end
end
if car_god_enabled and isCharInAnyCar(PLAYER_PED) then
    local veh = storeCarCharIsInNoSave(PLAYER_PED)
    if veh and doesVehicleExist(veh) then
        if last_god_vehicle and last_god_vehicle ~= veh then            setVehicleProofsSafe(last_god_vehicle, false)
        end
        setVehicleProofsSafe(veh, true)
        last_god_vehicle = veh      
    end
elseif not CFG.settings.vehGodmode and isCharInAnyCar(PLAYER_PED) then
    local veh = storeCarCharIsInNoSave(PLAYER_PED)
    setVehicleProofsSafe(veh, false)
    last_god_vehicle = nil
end
if CFG.settings.playerAirBrake ~= prevAirBrake then
    prevAirBrake = CFG.settings.playerAirBrake
    phoneWidgetVisible = prevAirBrake
    if not prevAirBrake and ab_enabled then
        ab_enabled = false
        disableAirBrake()
    end
end
if phoneWidgetVisible then
    local phone_now = isWidgetPressed(WIDGET_PHONE)

    if phone_now and not phone_prev then
        if not ab_enabled then
            ab_enabled = true
            enableAirBrake()
        else
            ab_enabled = false
            disableAirBrake()
        end
    end

    phone_prev = phone_now
end
if ab_enabled then
    if isSampAvailable() and doesCharExist(PLAYER_PED) and not isCharDead(PLAYER_PED) then
        processAirBrake()
    end
end

end
end
lua_thread.create(function()
    while true do
        wait(0)

        if isCharInAnyCar(PLAYER_PED) then
            local veh = storeCarCharIsInNoSave(PLAYER_PED)

            if veh ~= 0 and doesVehicleExist(veh) and getDriverOfCar(veh) == PLAYER_PED then
            
                -- VEHICLE JUMP
                if CFG.settings.vehJumpX and isCharInAnyCar(PLAYER_PED) then
                
                    local veh = storeCarCharIsInNoSave(PLAYER_PED)
                
                    if veh ~= 0 and doesVehicleExist(veh) and getDriverOfCar(veh) == PLAYER_PED then
                
                        if isWidgetPressed(WIDGET_SCHOOL_START) then
                
                            local vx,vy,vz = getCarSpeedVector(veh)
                
                            if vz < 6 then
                
                                local force = 0.23 + math.random() * 0.04
                
                                applyForceToCar(veh,0,0,force,0,0,0)
                
                                wait(120)
                
                            end
                
                        end
                
                    end
                
                end

                -- AUTO ENGINE
                if CFG.settings.vehAutoEngine then
                    local hp = getCarHealth(veh)
                    if hp < 250 then setCarHealth(veh, 260) end

                    if not isCarEngineOn(veh) then
                        switchCarEngine(veh, true)
                        setCarEngineOn(veh, true)
                        setCarEngineBroken(veh, false)
                        setCarLightsOn(veh, true)
                    end
                end
                
                
                -- VEHICLE REPAIR
                if CFG.settings.vehRepair then
                    fixCar(veh)
                    setCarHealth(veh, 1000)

                    wait(300)

                    syncVehicle(veh)

                    CFG.settings.vehRepair = false
                end

            end
        end

    end
end) -- sampai sini

-- Fungsi Sync repair
local raknet = require "samp.raknet"

function syncVehicle(car)

    local vehid = sampGetVehicleIdByCarHandle(car)
    if type(vehid) ~= "number" then return end

    local bs = raknetNewBitStream()

    raknetBitStreamWriteInt16(bs, vehid)
    raknetBitStreamWriteFloat(bs, 1000.0)

    raknetEmulRpcReceiveBitStream(106, bs)

    raknetDeleteBitStream(bs)

end -- sampai sini 

function onSendPacket(id, bs)
    if CFG.settings and CFG.settings.playerGodmode and (id == 115 or id == 103 or id == 50) then
        return false
    end
end

function onReceivePacket(id, bs)
    if CFG.settings and CFG.settings.playerGodmode and (id == 115 or id == 103 or id == 50) then
        return false
    end
end

------------------------------------------------------------
-- TP MARKER SYSTEM (INSTANT STRONG)
------------------------------------------------------------

local spoof = false
local spoofEnd = 0
local SPOOF_TIME = 1500

local lastX,lastY,lastZ = 0,0,0
local lastTeleport = 0
local TP_COOLDOWN = 1200


function sendRaknetPos(x,y,z)

    local bs = raknetNewBitStream()

    raknetBitStreamWriteFloat(bs,x)
    raknetBitStreamWriteFloat(bs,y)
    raknetBitStreamWriteFloat(bs,z)

    raknetSendRpc(12,bs)

    raknetDeleteBitStream(bs)

end


function teleport(x,y,z)

    local now = os.clock()*1000
    if now - lastTeleport < TP_COOLDOWN then return end
    lastTeleport = now

    -- random kecil supaya tidak terlalu perfect
    x = x + math.random(-1,1)
    y = y + math.random(-1,1)

    spoof = true
    spoofEnd = os.clock()*1000 + SPOOF_TIME

    if isCharInAnyCar(PLAYER_PED) then

        local car = storeCarCharIsInNoSave(PLAYER_PED)

        if car and doesVehicleExist(car) then
            setCarCoordinates(car,x,y,z)
        end

    else

        setCharCoordinates(PLAYER_PED,x,y,z)

    end

    wait(80)

    -- sync posisi 2x supaya server langsung update
    sendRaknetPos(x,y,z)

    wait(40)

    sendRaknetPos(x,y,z)

end


function checkMarker()

    local result,x,y,z = getTargetBlipCoordinates()

    if result then

        if x ~= lastX or y ~= lastY then

            lastX = x
            lastY = y
            lastZ = z

            teleport(x,y,z)

        end

    end

end


lua_thread.create(function()
    while true do
        wait(200)

        if CFG.settings.tpMarker and not isCharDead(PLAYER_PED) then
            checkMarker()
        end

    end
end)

--====================================================
-- UNIVERSAL BYPASS PRO
--====================================================

local spectateWarn = false
local lastSync = os.clock()

----------------------------------------------------
-- RPC PROTECTION
----------------------------------------------------

local BLOCK_RPC = {

    -- kick / reconnect
    [32] = true,
    [33] = true,
    [40] = true,
    [41] = true,

    -- camera / spectate
    [52] = true,
    [53] = true,
    [54] = true,

    -- freeze control
    [55] = true,
    [56] = true,
    [57] = true,

    -- crash
    [63] = true,
    [72] = true,
    [73] = true,

    -- forced animation
    [91] = true,
    [92] = true,
    [93] = true,

    -- anti cheat punish
    [129] = true,
    [154] = true,
    [161] = true,
    [162] = true,

    -- spectate tools
    [171] = true,
    [172] = true,
    [173] = true,

    -- vehicle force
    [181] = true,
    [182] = true,

    -- misc punish
    [203] = true,
    [206] = true,
    [207] = true
}

function sampev.onRPCReceive(id, bs)

    if CFG.settings.bypassX and BLOCK_RPC[id] then
        return false
    end

end


----------------------------------------------------
-- PACKET PROTECTION
----------------------------------------------------

function sampev.onReceivePacket(id, bs)

    if not CFG.settings.bypassX then return end

    -- teleport correction
    if id == 206 or id == 207 then
        return false
    end

    -- freeze sync
    if id == 90 or id == 91 then
        return false
    end

end


----------------------------------------------------
-- NETWORK BYPASS
----------------------------------------------------

function sampev.onSendPlayerSync(data)

    if CFG.settings.bypassX then

        -- random natural sync
        data.position.x = data.position.x + math.random(-1,1) * 0.02
        data.position.y = data.position.y + math.random(-1,1) * 0.02

        -- speed normalize
        data.moveSpeed.x = data.moveSpeed.x * 0.98
        data.moveSpeed.y = data.moveSpeed.y * 0.98

        -- fake small sync delay
        if os.clock() - lastSync < 0.03 then
            return false
        end

        lastSync = os.clock()

    end

    return data
end


function sampev.onSendVehicleSync(data)

    if CFG.settings.bypassX then

        data.position.x = data.position.x + math.random(-1,1) * 0.02
        data.position.y = data.position.y + math.random(-1,1) * 0.02

    end

    return data
end


----------------------------------------------------
-- ADMIN SPECTATE DETECTOR
----------------------------------------------------

function sampev.onPlayerSpectate(playerId, state)

    if state and not spectateWarn then
        spectateWarn = true
        sampAddChatMessage("{FF0000}[WARNING] Admin mungkin sedang spectate kamu!", -1)
    end

    if not state then
        spectateWarn = false
    end

    if CFG.settings.bypassX then
        return false
    end

end

----------------------------------------------------
-- JUMP SYNC
----------------------------------------------------
function sampev.onSendVehicleSync(data)

    if CFG.settings.vehJumpX then

        data.position.x = data.position.x + math.random(-1,1) * 0.015
        data.position.y = data.position.y + math.random(-1,1) * 0.015

        data.moveSpeed.z = data.moveSpeed.z + math.random() * 0.015

        -- anti fall detect
        if data.moveSpeed.z < -0.6 then
            data.moveSpeed.z = -0.6
        end

        -- fake speed sync
        local maxSpeed = 1.8

        if data.moveSpeed.x > maxSpeed then
            data.moveSpeed.x = maxSpeed
        end

        if data.moveSpeed.y > maxSpeed then
            data.moveSpeed.y = maxSpeed
        end

    end

end