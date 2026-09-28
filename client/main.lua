---@class Component
---@field name string
---@field label string
---@field component number
---@field type string
---@field image string

---@class Slot
---@field type string
---@field bone string?
---@field flag number

---@class SlotComponent
---@field component Component
---@field slotType string

local ox_inventory = exports.ox_inventory
local inspectingWeapon

---@type Slot[]
local Slots = {
    {
        type = 'flashlight',
        bone = 'WAPFlshLasr',
        flag = 1
    },
    {
        type = 'sight',
        bone = 'WAPScop_2',
        flag = 2
    },
    {
        type = 'muzzle',
        bone = 'gun_muzzle',
        flag = 4
    },
    {
        type = 'magazine',
        bone = 'WAPClip',
        flag = 8
    },
    {
        type = 'grip',
        bone = 'WAPGrip',
        flag = 16
    },
    {
        type = 'skin',
        flag = 64
    }
}

local luxeModels = {
    [`WEAPON_PISTOL`]           = `w_pi_pistol_luxe`,
    [`WEAPON_COMBATPISTOL`]     = `w_pi_combatpistol_luxe`,
    [`WEAPON_HEAVYPISTOL`]      = `w_pi_heavypistol_luxe`,
    [`WEAPON_VINTAGEPISTOL`]    = `w_pi_vintage_pistol_luxe`,
    [`WEAPON_MARKSMANPISTOL`]   = `w_pi_singleshot_luxe`,
    [`WEAPON_SNSPISTOL`]        = `w_pi_sns_pistol_luxe`,
    [`WEAPON_MICROSMG`]         = `w_sb_microsmg_luxe`,
    [`WEAPON_SMG`]              = `w_sb_smg_luxe`,
    [`WEAPON_ASSAULTSMG`]       = `w_sb_assaultsmg_luxe`,
    [`WEAPON_ASSAULTRIFLE`]     = `w_ar_assaultrifle_luxe`,
    [`WEAPON_CARBINERIFLE`]     = `w_ar_carbinerifle_luxe`,
    [`WEAPON_ADVANCEDRIFLE`]    = `w_ar_advancedrifle_luxe`,
    [`WEAPON_SPECIALCARBINE`]   = `w_ar_specialcarbine_luxe`,
    [`WEAPON_BULLPUPRIFLE`]     = `w_ar_bullpuprifle_luxe`,
    [`WEAPON_MG`]               = `w_mg_mg_luxe`,
    [`WEAPON_COMBATMG`]         = `w_mg_combatmg_luxe`,
    [`WEAPON_PUMPSHOTGUN`]      = `w_sg_pumpshotgun_luxe`,
    [`WEAPON_ASSAULTSHOTGUN`]   = `w_sg_assaultshotgun_luxe`,
    [`WEAPON_BULLPUPSHOTGUN`]   = `w_sg_bullpupshotgun_luxe`,
    [`WEAPON_SNIPERRIFLE`]      = `w_sr_sniperrifle_luxe`,
    [`WEAPON_HEAVYSNIPER`]      = `w_sr_heavysniper_luxe`,
    [`WEAPON_MARKSMANRIFLE`]    = `w_sr_marksmanrifle_luxe`
}

---Get compatible components for weapon hash
---@param weaponHash number
---@return Component[]
local getCompatibleComponents = function(weaponHash)
    local allItems = ox_inventory:Items()
    local compatibleComponents = {}

    for name, data in pairs(allItems) do
        if data.client and data.client.component then
            for _, component in ipairs(data.client.component) do
                if DoesWeaponTakeWeaponComponent(weaponHash, component) then
                    table.insert(compatibleComponents, {
                        name = name,
                        label = data.label,
                        component = component,
                        type = data.type,
                        image = data.client.image
                            or ('nui://ox_inventory/web/images/%s.png'):format(name)
                    })

                    break
                end
            end
        end
    end

    return compatibleComponents
end

local exitInspection = function()
    if inspectingWeapon then
        if DoesEntityExist(inspectingWeapon.object) then
            DeleteEntity(inspectingWeapon.object)
            RemoveWeaponAsset(GetHashKey(inspectingWeapon.model))
        end

        if DoesCamExist(inspectingWeapon.camera) then
            RenderScriptCams(false, false, 0, true, true)
            DestroyCam(inspectingWeapon.camera, false)
        end
    end

    inspectingWeapon = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "close" })
end

---Get bones for slots
---@param weaponName string|nil To access override list
---@param components Component[]
---@return Slot[]
local getCompatibleComponentsSlots = function(weaponName, components)
    local types = lib.array.map(components, function(component)
        return component.type
    end)

    return lib.array.filter(Slots, function(slot)
        return lib.table.contains(types, slot.type)
    end)
end

---Get attached components paired with their slot, components without a slot are skipped
---@param components Component[]
---@param attachedComponents string[]
---@return SlotComponent[]
local getAttachedComponents = function(components, attachedComponents)
    components = lib.array.filter(components, function(component)
        return lib.table.contains(attachedComponents, component.name)
            and lib.array.find(Slots, function(slot)
                return slot.type == component.type
            end) ~= nil
    end)

    return lib.array.map(components, function(component)
        return {
            component = component,
            slotType = component.type
        }
    end)
end

---Update slots position on screen
local updateSlots = function()
     for _, slot in pairs(inspectingWeapon.slots) do
        ---@type vector3|nil
        local pos = GetEntityCoords(inspectingWeapon.object)

        if slot.bone then
            local boneIndex = GetEntityBoneIndexByName(inspectingWeapon.object, slot.bone)

            pos = boneIndex ~= -1 and GetWorldPositionOfEntityBone(inspectingWeapon.object, boneIndex) or nil
        end

        if pos then
            local onScreen, x, y = World3dToScreen2d(pos.x, pos.y, pos.z)

            if onScreen then
                SendNUIMessage({
                    action = "updateSlot",
                    slot = slot.type,
                    x = x,
                    y = y
                })
            end
        end
    end
end

--- Spawn weapon in front of ped, and make camera to look at that weapon zoomed in
---@param hash number
---@param customHash number?
---@return integer
local createWeaponPreviewObject = function(hash, customHash)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local previewCoords = coords + (forward * 1.0) + vector3(0.0, 0.0, 0.5)
    local heading = GetEntityHeading(ped) + 180.0

    RequestWeaponAsset(hash, 31, 1 | 2 | 4 | 8 | 16 | 32)
    while not HasWeaponAssetLoaded(hash) do Citizen.Wait(0) end

    if customHash then
        lib.requestModel(customHash)
    end

    local object = CreateWeaponObject(hash, 0, previewCoords.x, previewCoords.y, previewCoords.z, true, 1.0, customHash or 0)
    SetEntityHeading(object, heading)
    FreezeEntityPosition(object, true)
    SetEntityCollision(object, false, true)
    SetEntityInvincible(object, true)
    SetEntityVelocity(object, 0.0, 0.0, 0.0)

    return object
end

---@param weaponHash number
---@param components Component[]
---@return number dummyPed
local createDummyPedWithWeapon = function(weaponHash, components)
    local model = `mp_m_freemode_01`

    lib.requestModel(model)

    local coords = GetEntityCoords(PlayerPedId())
    local ped = CreatePed(4, model, coords.x, coords.y, coords.z, 0.0, false, true)

    SetEntityVisible(ped, false, false)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetEntityCollision(ped, false, false)

    GiveWeaponToPed(ped, weaponHash, 0, true, true)

    for _, component in ipairs(components) do
        GiveWeaponComponentToPed(ped, weaponHash, component.component)
    end

    return ped
end

---Update weapon object's components
---@param weaponObject number
---@param weaponHash number
---@param attachedComponents string[]
---@param components Component[]
local updatePreviewComponents = function(weaponObject, weaponHash, attachedComponents, components)
    local dummyPed = createDummyPedWithWeapon(weaponHash, components)

    local skinComponent = lib.array.find(components, function (component)
        return component.type == 'skin'
    end)

    local skinUpdated = false

    if skinComponent then
        local isInPrevTable = inspectingWeapon?.attachedComponents and lib.table.contains(inspectingWeapon?.attachedComponents, skinComponent.name) or false
        local isInNewTable = lib.table.contains(attachedComponents, skinComponent.name)

        if (not isInPrevTable and isInNewTable) or (isInPrevTable and not isInNewTable) then
            if inspectingWeapon then
                DeleteEntity(weaponObject)
                weaponObject = createWeaponPreviewObject(weaponHash, isInNewTable and luxeModels[weaponHash] or nil)
                inspectingWeapon.object = weaponObject
                skinUpdated = true
            end

            if not isInPrevTable and isInNewTable then
                GiveWeaponComponentToWeaponObject(weaponObject, skinComponent.component)
            end
        end
    end

    for _, component in ipairs(components) do
        if component.type ~= 'skin' then
            local isInPrevTable = inspectingWeapon?.attachedComponents and lib.table.contains(inspectingWeapon?.attachedComponents, component.name) or false
            local isInNewTable = lib.table.contains(attachedComponents, component.name)

            if (skinUpdated and isInPrevTable) or (isInPrevTable and not isInNewTable) then
                RemoveWeaponComponentFromWeaponObject(weaponObject, component.component)
            end

            if (skinUpdated and isInNewTable) or (not isInPrevTable and isInNewTable) then
                GiveWeaponComponentToWeaponObject(weaponObject, component.component)
            end
        end
    end

    DeleteEntity(dummyPed)
end

---Apply components to the weapon in the player's hands if it is the one being inspected,
---ox_inventory only applies metadata components on equip
---@param attachedComponents string[]
local syncEquippedWeapon = function(attachedComponents)
    local currentWeapon = ox_inventory:getCurrentWeapon()

    if not currentWeapon or currentWeapon.slot ~= tonumber(inspectingWeapon.slot) then
        return
    end

    local ped = PlayerPedId()

    for _, component in ipairs(inspectingWeapon.components) do
        local isAttached = lib.table.contains(attachedComponents, component.name)
        local hasComponent = HasPedGotWeaponComponent(ped, currentWeapon.hash, component.component)

        if isAttached and not hasComponent then
            GiveWeaponComponentToPed(ped, currentWeapon.hash, component.component)
        elseif not isAttached and hasComponent then
            RemoveWeaponComponentFromPed(ped, currentWeapon.hash, component.component)
        end
    end
end

RegisterNetEvent('bryan_weapon_components:client:inspect', function(slotId)
    local weaponData = lib.callback.await('bryan_weapon_components:server:getWeapon', false, slotId)

    if not weaponData?.model then
        return
    end

    SetNuiFocus(true, true)

    local model, attachedComponents = weaponData.model, weaponData.components

    local weaponHash = GetHashKey(model)

    -- Build compatible attachment list
    local components = getCompatibleComponents(weaponHash)
    ox_inventory:closeInventory()

    local availableComponents = lib.callback.await('bryan_weapon_components:server:getInventoryComponents', false, components)

    local hasSkin = lib.array.find(attachedComponents, function (attachedComponent)
        return string.find(attachedComponent, '_luxe') ~= nil
    end) ~= nil
    local previewObject = createWeaponPreviewObject(weaponHash, hasSkin and luxeModels[weaponHash] or nil)
    -- Components
    updatePreviewComponents(previewObject, weaponHash, attachedComponents, components)

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local camCoords = coords + (forward * 1.5) + vector3(0.0, 0.0, 0.5)
    local cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(cam, camCoords.x, camCoords.y, camCoords.z)
    PointCamAtEntity(cam, previewObject, 0.0, 0.0, 0.0, false)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 500, true, true)

    inspectingWeapon = {
        object = previewObject,
        model = model,
        camera = cam,
        slots = getCompatibleComponentsSlots(nil, components),
        attachedComponents = attachedComponents,
        slot = slotId,
        components = components
    }

    Citizen.Wait(1000)
    updateSlots()

    -- NUI open
    SendNUIMessage({
        action = "open",
        availableComponents = availableComponents,
        attachedComponents = getAttachedComponents(components, attachedComponents)
    })
end)

RegisterNUICallback("close", function(_, cb)
    exitInspection()
    cb('ok')
end)

RegisterNUICallback("rotatePreviewDelta", function(data, cb)
    if not DoesEntityExist(inspectingWeapon.object) then return cb({}) end

    local deltaYaw = data.deltaYaw or 0.0
    local deltaPitch = data.deltaPitch or 0.0

    local rot = GetEntityRotation(inspectingWeapon.object, 2)
    local pitch = rot.x - deltaPitch
    local yaw = rot.z + deltaYaw

    pitch = math.max(-89.0, math.min(89.0, pitch))

    SetEntityRotation(inspectingWeapon.object, pitch, 0.0, yaw, 0, true)
    updateSlots()

    cb({})
end)

RegisterNUICallback('attach', function(data, cb)
    local slotType = data.slot
    local component = data.component

    if not slotType or not component then
        return cb(false)
    end

    for _, slot in ipairs(Slots) do
        if slot.type == component.type then
            if slotType ~= slot.type then
                lib.notify({
                    title = 'Weapon Component',
                    description = 'Component does not go in this slot',
                    type = 'error'
                })
                return cb(false)
            end

            break
        end
    end

    if not DoesWeaponTakeWeaponComponent(inspectingWeapon.model, component.component) then
        lib.notify({
            title = 'Weapon Component',
            description = 'Weapon does not take this component',
            type = 'error'
        })
        return cb(false)
    end

    local attachedComponents = lib.callback.await('bryan_weapon_components:server:updateComponents', false, inspectingWeapon.slot, component)

    if attachedComponents then
        local availableComponents = lib.callback.await('bryan_weapon_components:server:getInventoryComponents', false, inspectingWeapon.components)

        updatePreviewComponents(inspectingWeapon.object, GetHashKey(inspectingWeapon.model), attachedComponents, inspectingWeapon.components)
        syncEquippedWeapon(attachedComponents)

        inspectingWeapon.attachedComponents = attachedComponents

        return cb({
            attachedComponents = getAttachedComponents(inspectingWeapon.components, attachedComponents),
            availableComponents = availableComponents
        })
    end

    cb({})
end)

RegisterNUICallback('remove', function(data, cb)
    local slotType = data.slot

    if not slotType then
        return cb(false)
    end

    local component = lib.array.find(inspectingWeapon.components, function(c)
        return c.type == slotType
    end)

    if not component then
        lib.notify({
            title = 'Weapon Component',
            description = 'Could not find the component',
            type = 'error'
        })
        return cb(false)
    end

    local attachedComponents = lib.callback.await('bryan_weapon_components:server:updateComponents', false, inspectingWeapon.slot, component, true)

    if attachedComponents then
        local availableComponents = lib.callback.await('bryan_weapon_components:server:getInventoryComponents', false, inspectingWeapon.components)

        updatePreviewComponents(inspectingWeapon.object, GetHashKey(inspectingWeapon.model), attachedComponents, inspectingWeapon.components)
        syncEquippedWeapon(attachedComponents)

        inspectingWeapon.attachedComponents = attachedComponents

        return cb({
            attachedComponents = getAttachedComponents(inspectingWeapon.components, attachedComponents),
            availableComponents = availableComponents
        })
    end

    cb(false)
end)


Citizen.CreateThread(function()
    while true do
        if inspectingWeapon and not DoesEntityExist(inspectingWeapon.object) then
            exitInspection()
        end

        Citizen.Wait(500)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() and inspectingWeapon then
        exitInspection()
    end
end)
