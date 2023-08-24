local vehicle = require 'client.modules.vehicle'
local Store = require 'client.modules.store'
local poly = require 'client.modules.polyzone'
local camera = require 'client.modules.camera'
local Interface = require 'client.modules.utils'
local currentData = Store.data
local table_contain = lib.table.contains

local function resetMenuData()
    local entity = cache.vehicle
    SetVehicleDoorsLocked(entity , 1)
    FreezeEntityPosition(entity, false)
    Store.data = { menu = 'main', modType = 'none', stored = {}, preview = false}
    camera.destroyCam()
end

local function showMenu(show)
    if not show then 
        Interface.SendReactMessage('setVisible', false)
        resetMenuData()
        return
    end
    local entity = cache.vehicle
    if not poly.isNear or not entity then return end
    Interface.SendReactMessage('setVisible', true, true, true)
    local coords = poly.pos
    SetVehicleEngineOn(entity, true, true, false)
    SetVehicleAutoRepairDisabled(entity, true)
    SetVehicleModKit(entity, 0)
    SetEntityHeading(entity, coords.w)
    SetEntityCoords(entity, coords.x, coords.y, coords.z)
    FreezeEntityPosition(entity, true)
    SetVehicleDoorsLocked(entity , 4)
    camera.createMainCam()
end

local function getModType(type)
    local selector = {
        wheels = vehicle.getVehicleWheelsType,
        decals = vehicle.getMods,
        paint = vehicle.getVehicleColorsTypes,
    }

    return selector[currentData.menu] and selector[currentData.menu](type)
end

local function handleMainMenus(menu)
    local selector = {
        exit = function()
            showMenu(false)
            return true
        end,
        decals = vehicle.getVehicleDecals,
        wheels = vehicle.getVehicleWheels,
        paint = vehicle.getVehicleColors,
        preview = function()
            currentData.preview = not currentData.preview
            if currentData.preview then
                camera.destroyCam()
            else
                camera.createMainCam()
            end
        end,
    }

    return selector[menu] and selector[menu]()
end

local function applyMod(menu)
    local entity = cache.vehicle
    if menu.type == 51 then -- plate index
        SetVehicleNumberPlateTextIndex(entity, menu.index)
    else
        SetVehicleMod(entity, menu.type, menu.index, currentData.stored.customTyres)
    end
    --if menu.type == 14 then -- do a special thing if you selected a mod
    --end
end

local function applyColorMod(menu)
    local selector = {
        Primary = vehicle.applyVehicleColor,
        Secondary = vehicle.applyVehicleColor,
        Interior = vehicle.applyInteriorColor,
        Wheels = vehicle.applyExtraColor,
        Pearlescent = vehicle.applyExtraColor,
        Dashboard = vehicle.applyDashboardColor,
        Neon = vehicle.applyNeonColor,
        ['Tyre Smoke'] = vehicle.applyTyreSmokeColor,
        ['Xenon Lights'] = vehicle.applyXenonLightsColor,
        ['Window Tint'] = vehicle.applyWindowsTint,
        ['Neon Colors'] = vehicle.applyNeonColor,
    }
    local isSelector = selector[menu.colorType]
    if not isSelector then return end
    isSelector(menu)
end

local function handleMod(modIndex)
    currentData.stored.appliedMods = {modType = currentData.modType, mod = modIndex}
    if currentData.menu == 'paint' then
        applyColorMod({ colorType = currentData.modType, modIndex = modIndex })
    else
        applyMod({ type = currentData.menu == 'wheels' and 23 or Store.decals[currentData.modType].id, index = modIndex })
    end
end

local function handleMenuClick(data)
    local menuType = data.type
    local clickedCard = data.clickedCard
    if clickedCard == nil then return end
    camera.switchCam()
    if data.isBack then
        local storedData = currentData.stored
        if not storedData.boughtMods or storedData.appliedMods and storedData.appliedMods.modType ~= storedData.boughtMods.modType or storedData.appliedMods.mod ~= storedData.boughtMods.mod then
            if currentData.menu == 'wheels' then
                SetVehicleWheelType(cache.vehicle, currentData.stored.currentWheelType)
            end
            handleMod(storedData.currentMod)
        end
    end
    if menuType == 'menu' then
        currentData.menu = clickedCard
    elseif menuType == 'modType' then
        currentData.modType = currentData.menu == 'paint' and (table_contain(Store.colors.types, clickedCard) and clickedCard or currentData.modType) or clickedCard
    end

    return menuType == 'menu' and handleMainMenus(clickedCard) or getModType(clickedCard)
end

local function buyMod(data)
    local storedData = currentData.stored

    if storedData.currentMod == data.mod then 
        lib.notify({
            title = 'Customs',
            description = 'You have this mod already',
            type = 'warning'
        })
        return end
    print(data.price)
    storedData.boughtMods = {price = data.price, mod = data.mod, modType = currentData.modType}
    storedData.currentMod = data.mod
    return true
end

local function toggleMod(data)
    print(data.price)
    if currentData.menu == 'wheels' then
        vehicle.toggleCustomTyres(data.toggle)
    elseif currentData.modType == 'Neon' then
        vehicle.enableNeonColor({modIndex = data.mod, toggle = data.toggle})
    end
    return true
end

RegisterNUICallback('hideFrame', function(_, cb)
    resetMenuData()
    cb({})
end)

RegisterNUICallback('setMenu', function(menu, cb)
    local menuData = handleMenuClick(menu)
    cb(menuData or false)
end)

RegisterNUICallback('applyMod', function(modIndex, cb)
    handleMod(modIndex)
    cb(true)
end)

RegisterNUICallback('buyMod', function(data, cb)
    cb(buyMod(data))
end)

RegisterNUICallback('toggleMod', function(data, cb)
    cb(toggleMod(data))
end)

return showMenu