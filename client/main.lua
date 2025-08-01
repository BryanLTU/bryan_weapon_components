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
        type = 'scope',
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

-- lib.requestWeaponAsset('WEAPON_CARBINERIFLE', nil, 31, 63)
-- local weapon = CreateWeaponObject(GetHashKey('WEAPON_CARBINERIFLE'), 1, GetEntityCoords(PlayerPedId()).x, GetEntityCoords(PlayerPedId()).y, GetEntityCoords(PlayerPedId()).z, true, 1.0, 0)
-- GiveWeaponComponentToWeaponObject(weapon, GetHashKey('COMPONENT_AT_AR_FLSH'))
-- Wait(100)
-- GiveWeaponComponentToWeaponObject(weapon, GetHashKey('COMPONENT_CARBINERIFLE_VARMOD_LUXE'))

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

---comment
---@param components Component[]
---@param attachedComponents string[]
---@return SlotComponent[]
local getAttachedComponents = function(components, attachedComponents)
    components = lib.array.filter(components, function(component)
        return lib.table.contains(attachedComponents, component.name)
    end)

    return lib.array.map(components, function(c, index, array)
        local slot = lib.array.find(Slots, function(s)
            return s.type == c.type
        end)

        return {
            component = c,
            slotType = slot.type
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

        -- lib.print.info(slot.bone, boneIndex ~= -1)
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

    -- for _, bone in ipairs({
    --     "gun_root",
    --     "gun_gripr",
    --     "gun_gripl",
    --     "gun_muzzle",
    --     "gun_vfx_eject",
    --     "gun_magazine",
    --     "gun_ammo",
    --     "gun_vfx_projtrail",
    --     "gun_barrels",
    --     "WAPClip",
    --     "WAPClip_2",
    --     "WAPScop",
    --     "WAPScop_2",
    --     "WAPGrip",
    --     "WAPGrip_2",
    --     "WAPSupp",
    --     "WAPSupp_2",
    --     "WAPFlsh",
    --     "WAPFlsh_2",
    --     "WAPStck",
    --     "WAPSeWp",
    --     "WAPLasr",
    --     "WAPLasr_2",
    --     "WAPFlshLasr",
    --     "WAPFlshLasr_2",
    --     "NM_Butt_Marker",
    --     "Gun_GripR",
    --     "Gun_Nuzzle",
    --     "gun_drum"
    -- }) do
    --     local boneIndex = GetEntityBoneIndexByName(inspectingWeapon.object, bone)
    --     lib.print.info(bone, boneIndex ~= -1)
    -- end
end

---Update weapon object's components
---@param weaponObject number
---@param weaponHash number
---@param attachedComponents string[]
---@param components Component[]
local updatePreviewComponents = function(weaponObject, weaponHash, attachedComponents, components)
    for _, component in ipairs(components) do
        local isInPrevTable = inspectingWeapon?.attachedComponents and lib.table.contains(inspectingWeapon?.attachedComponents, component.name) or false
        local isInNewTable = lib.table.contains(attachedComponents, component.name)

        if isInPrevTable and not isInNewTable then
            RemoveWeaponComponentFromWeaponObject(weaponObject, component.component)
        elseif not isInPrevTable and isInNewTable then
            GiveWeaponComponentToWeaponObject(weaponObject, component.component)
        end
    end
end

RegisterNetEvent('bryan_weapon_components:client:inspect', function(slotId)
    local weaponData = lib.callback.await('bryan_weapon_components:server:getWeapon', false, slotId)

    if not weaponData?.model then
        return
    end

    local model, attachedComponents = weaponData.model, weaponData.components

    local weaponHash = GetHashKey(model)

    -- Build compatible attachment list
    local components = getCompatibleComponents(weaponHash)
    ox_inventory:closeInventory()

    local availableComponents = lib.callback.await('bryan_weapon_components:server:getInventoryComponents', false, components)

    -- Spawn weapon in front of ped, and make camera to look at that weapon zoomed in
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local forward = GetEntityForwardVector(ped)
    local previewCoords = coords + (forward * 1.0) + vector3(0.0, 0.0, 0.5)

    RequestWeaponAsset(weaponHash, 31, 1 | 2 | 4 | 8 | 16 | 32)
    while not HasWeaponAssetLoaded(weaponHash) do Citizen.Wait(10) end

    local previewObject = CreateWeaponObject(weaponHash, 0, previewCoords.x, previewCoords.y, previewCoords.z, false, 1.0, 0)
    SetEntityHeading(previewObject, GetEntityHeading(ped) + 180)
    FreezeEntityPosition(previewObject, true)
    SetEntityCollision(previewObject, false, true)
    SetEntityInvincible(previewObject, true)
    SetEntityVelocity(previewObject, 0.0, 0.0, 0.0)

    -- Components
    updatePreviewComponents(previewObject, weaponHash, attachedComponents, components)

    local camCoords = coords + (forward * 1.5) + vector3(0.0, 0.0, 0.5)
    local cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(cam, camCoords.x, camCoords.y, camCoords.z)
    PointCamAtEntity(cam, previewObject, 0.0, 0.0, 0.0, false)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)

    inspectingWeapon = {
        object = previewObject,
        model = model,
        camera = cam,
        slots = getCompatibleComponentsSlots(nil, components),
        attachedComponents = attachedComponents,
        slot = slotId,
        components = components
    }

    Citizen.Wait(500)
    updateSlots()

    -- NUI open
    SendNUIMessage({
        action = "open",
        availableComponents = availableComponents,
        attachedComponents = getAttachedComponents(components, attachedComponents)
    })
    SetNuiFocus(true, true)
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
