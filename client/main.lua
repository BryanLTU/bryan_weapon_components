---@class Component
---@field name string
---@field label string
---@field component number
---@field type string
---@field image string

---@class SlotComponent
---@field component Component
---@field slotType string

local ox_inventory = exports.ox_inventory
local inspectingWeapon
local isOpening = false

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
        end

        RemoveWeaponAsset(inspectingWeapon.hash)

        if inspectingWeapon.camera and DoesCamExist(inspectingWeapon.camera) then
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

    return lib.array.filter(Config.Slots, function(slot)
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
            and lib.array.find(Config.Slots, function(slot)
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

        local onScreen, x, y = false, 0.0, 0.0

        if pos then
            onScreen, x, y = World3dToScreen2d(pos.x, pos.y, pos.z)
        end

        if onScreen then
            SendNUIMessage({
                action = "updateSlot",
                slot = slot.type,
                x = x,
                y = y
            })
        else
            SendNUIMessage({
                action = "hideSlot",
                slot = slot.type
            })
        end
    end
end

---Update slot positions on the next frame, once a respawned object and new components have bones in place
local refreshSlots = function()
    Citizen.Wait(0)

    if inspectingWeapon and DoesEntityExist(inspectingWeapon.object) then
        updateSlots()
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
    local previewCoords = coords + (forward * Config.PreviewDistance) + vector3(0.0, 0.0, Config.PreviewHeight)
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

---Get the skin component attached to the weapon, only one can be attached at a time
---@param components Component[]
---@param attachedComponents string[]
---@return Component?
local getAttachedSkin = function(components, attachedComponents)
    return lib.array.find(components, function(component)
        return component.type == 'skin' and lib.table.contains(attachedComponents, component.name)
    end)
end

---Get the model the weapon object has to be created with for the attached skin
---@param weaponHash number
---@param skin Component?
---@return number?
local getSkinModel = function(weaponHash, skin)
    return skin and Config.LuxeModels[weaponHash] or nil
end

---Update weapon object's components
---@param weaponObject number
---@param weaponHash number
---@param prevAttachedComponents string[]? Components already on the object, nil for a freshly created object
---@param attachedComponents string[]
---@param components Component[]
---@return number weaponObject New object when a skin change needed a different model
local updatePreviewComponents = function(weaponObject, weaponHash, prevAttachedComponents, attachedComponents, components)
    local dummyPed = createDummyPedWithWeapon(weaponHash, components)

    local prevModel = getSkinModel(weaponHash, getAttachedSkin(components, prevAttachedComponents or {}))
    local newModel = getSkinModel(weaponHash, getAttachedSkin(components, attachedComponents))
    local respawned = false

    -- Luxe skins replace the whole weapon model, so the object has to be recreated with it
    if prevAttachedComponents and prevModel ~= newModel then
        -- Keep the player's rotation on the respawned object
        local rotation = GetEntityRotation(weaponObject, 2)

        DeleteEntity(weaponObject)
        weaponObject = createWeaponPreviewObject(weaponHash, newModel)
        SetEntityRotation(weaponObject, rotation.x, rotation.y, rotation.z, 2, true)
        respawned = true
    end

    for _, component in ipairs(components) do
        -- A respawned or fresh object has no components, everything attached has to be given
        local wasAttached = not respawned and prevAttachedComponents ~= nil
            and lib.table.contains(prevAttachedComponents, component.name)
        local isAttached = lib.table.contains(attachedComponents, component.name)

        if wasAttached and not isAttached then
            RemoveWeaponComponentFromWeaponObject(weaponObject, component.component)
        elseif isAttached and not wasAttached then
            GiveWeaponComponentToWeaponObject(weaponObject, component.component)
        end
    end

    DeleteEntity(dummyPed)

    return weaponObject
end

---Apply components to the weapon in the player's hands if it is the one being inspected,
---ox_inventory only applies metadata components on equip
---@param inspecting table Inspection the update belongs to, may already be closed
---@param attachedComponents string[]
local syncEquippedWeapon = function(inspecting, attachedComponents)
    local currentWeapon = ox_inventory:getCurrentWeapon()

    if not currentWeapon or currentWeapon.slot ~= tonumber(inspecting.slot) then
        return
    end

    local ped = PlayerPedId()

    for _, component in ipairs(inspecting.components) do
        local isAttached = lib.table.contains(attachedComponents, component.name)
        local hasComponent = HasPedGotWeaponComponent(ped, currentWeapon.hash, component.component)

        if isAttached and not hasComponent then
            GiveWeaponComponentToPed(ped, currentWeapon.hash, component.component)
        elseif not isAttached and hasComponent then
            RemoveWeaponComponentFromPed(ped, currentWeapon.hash, component.component)
        end
    end
end

---Check there is room in front of the ped for the preview and camera
---@param ped number
---@return boolean
local hasPreviewSpace = function(ped)
    local from = GetEntityCoords(ped) + vector3(0.0, 0.0, Config.PreviewHeight)
    local to = from + GetEntityForwardVector(ped) * (Config.CameraDistance + 0.3)

    local handle = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 1 | 2 | 16, ped, 7)
    local _, hit = GetShapeTestResult(handle)

    return not (hit == true or hit == 1)
end

---Close the inspection when the preview can no longer be seen properly, it doesn't follow the ped
---@param inspecting table
local watchInspection = function(inspecting)
    Citizen.CreateThread(function()
        while inspectingWeapon == inspecting do
            local ped = PlayerPedId()

            if not DoesEntityExist(inspecting.object)
                or IsEntityDead(ped)
                or IsPedInAnyVehicle(ped, true)
                or #(GetEntityCoords(ped) - inspecting.coords) > Config.MaxMoveDistance then
                exitInspection()
                break
            end

            Citizen.Wait(500)
        end
    end)
end

---Create the preview and camera, then open the UI
---@param slotId number
local openInspection = function(slotId)
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

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    local skinModel = getSkinModel(weaponHash, getAttachedSkin(components, attachedComponents))
    local previewObject = createWeaponPreviewObject(weaponHash, skinModel)

    -- Set as soon as the object exists, so closing or an error from here on cleans it up
    local inspecting = {
        object = previewObject,
        model = model,
        hash = weaponHash,
        slots = getCompatibleComponentsSlots(nil, components),
        attachedComponents = attachedComponents,
        slot = slotId,
        components = components,
        coords = coords
    }
    inspectingWeapon = inspecting
    watchInspection(inspecting)

    inspecting.object = updatePreviewComponents(previewObject, weaponHash, nil, attachedComponents, components)

    -- Closed while loading, don't create a camera nothing will clean up
    if inspectingWeapon ~= inspecting then
        return
    end

    local forward = GetEntityForwardVector(ped)
    local camCoords = coords + (forward * Config.CameraDistance) + vector3(0.0, 0.0, Config.PreviewHeight)
    local cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamCoord(cam, camCoords.x, camCoords.y, camCoords.z)
    PointCamAtEntity(cam, inspecting.object, 0.0, 0.0, 0.0, false)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 500, true, true)
    inspecting.camera = cam

    Citizen.Wait(1000)

    if inspectingWeapon ~= inspecting then
        return
    end

    updateSlots()

    -- NUI open
    SendNUIMessage({
        action = "open",
        availableComponents = availableComponents,
        attachedComponents = getAttachedComponents(components, attachedComponents)
    })
end

RegisterNetEvent('bryan_weapon_components:client:inspect', function(slotId)
    if inspectingWeapon or isOpening then
        return
    end

    local ped = PlayerPedId()

    if IsPedInAnyVehicle(ped, true) then
        lib.notify({
            title = 'Weapon Component',
            description = 'You cannot inspect weapons in a vehicle',
            type = 'error'
        })
        return
    end

    if not hasPreviewSpace(ped) then
        lib.notify({
            title = 'Weapon Component',
            description = 'Not enough space in front of you',
            type = 'error'
        })
        return
    end

    isOpening = true
    local ok, err = pcall(openInspection, slotId)
    isOpening = false

    -- Never leave the player with NUI focus and no UI
    if not ok then
        exitInspection()
        error(err, 0)
    end
end)

RegisterNUICallback("close", function(_, cb)
    exitInspection()
    cb('ok')
end)

RegisterNUICallback("rotatePreviewDelta", function(data, cb)
    if not inspectingWeapon or not DoesEntityExist(inspectingWeapon.object) then return cb({}) end

    local deltaYaw = data.deltaYaw or 0.0
    local deltaPitch = data.deltaPitch or 0.0

    local rot = GetEntityRotation(inspectingWeapon.object, 2)
    local pitch = rot.x - deltaPitch
    local yaw = rot.z + deltaYaw

    pitch = math.max(-89.0, math.min(89.0, pitch))

    SetEntityRotation(inspectingWeapon.object, pitch, 0.0, yaw, 2, true)
    updateSlots()

    cb({})
end)

---Apply components returned by the server to the equipped weapon, the preview and the UI
---@param inspecting table Inspection the request was made from
---@param attachedComponents string[]|false
---@param cb function
local applyComponentUpdate = function(inspecting, attachedComponents, cb)
    if not attachedComponents then
        return cb(false)
    end

    -- The weapon in hands has to match its metadata even if the inspection was closed meanwhile
    syncEquippedWeapon(inspecting, attachedComponents)

    local availableComponents = lib.callback.await('bryan_weapon_components:server:getInventoryComponents', false, inspecting.components)

    if inspectingWeapon ~= inspecting then
        return cb(false)
    end

    local object = updatePreviewComponents(inspecting.object, inspecting.hash, inspecting.attachedComponents, attachedComponents, inspecting.components)

    if inspectingWeapon ~= inspecting then
        DeleteEntity(object)
        return cb(false)
    end

    inspecting.object = object
    inspecting.attachedComponents = attachedComponents
    refreshSlots()

    cb({
        attachedComponents = getAttachedComponents(inspecting.components, attachedComponents),
        availableComponents = availableComponents
    })
end

RegisterNUICallback('attach', function(data, cb)
    local inspecting = inspectingWeapon
    local slotType = data.slot
    local component = data.component

    if not inspecting or not slotType or not component then
        return cb(false)
    end

    for _, slot in ipairs(Config.Slots) do
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

    if not DoesWeaponTakeWeaponComponent(inspecting.hash, component.component) then
        lib.notify({
            title = 'Weapon Component',
            description = 'Weapon does not take this component',
            type = 'error'
        })
        return cb(false)
    end

    local attachedComponents = lib.callback.await('bryan_weapon_components:server:updateComponents', false, inspecting.slot, component)

    applyComponentUpdate(inspecting, attachedComponents, cb)
end)

RegisterNUICallback('remove', function(data, cb)
    local inspecting = inspectingWeapon
    local slotType = data.slot

    if not inspecting or not slotType then
        return cb(false)
    end

    local component = lib.array.find(inspecting.components, function(c)
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

    local attachedComponents = lib.callback.await('bryan_weapon_components:server:updateComponents', false, inspecting.slot, component, true)

    applyComponentUpdate(inspecting, attachedComponents, cb)
end)

Citizen.CreateThread(function()
    while true do
        if inspectingWeapon then
            local ped = PlayerPedId()

            -- Close when the preview can no longer be seen properly, it doesn't follow the ped
            if not DoesEntityExist(inspectingWeapon.object)
                or IsPedInAnyVehicle(ped, true)
                or #(GetEntityCoords(ped) - inspectingWeapon.coords) > MAX_MOVE_DISTANCE then
                exitInspection()
            end
        end

        Citizen.Wait(500)
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() and inspectingWeapon then
        exitInspection()
    end
end)
