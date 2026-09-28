local ox_inventory = exports.ox_inventory

---@param source number
---@param description string
local notifyError = function(source, description)
    lib.notify(source, {
        title = 'Weapon Components',
        description = description,
        type = 'error'
    })
end

---Get inventory slot only if it contains a weapon
---@param source number
---@param slotId number
local getWeaponSlot = function(source, slotId)
    local slot = ox_inventory:GetSlot(source, slotId)
    if not slot then return end

    local item = ox_inventory:Items(slot.name)
    if not item or not item.weapon then return end

    return slot, item
end

lib.callback.register('bryan_weapon_components:server:getWeapon', function(source, slotId)
    local slot, item = getWeaponSlot(source, slotId)
    if not slot or not item then return end

    return {
        model = item.model,
        components = slot.metadata?.components or {}
    }
end)

lib.callback.register('bryan_weapon_components:server:getInventoryComponents', function(source, components)
    if type(components) ~= 'table' then return {} end

    return lib.array.filter(components, function(component)
        return type(component?.name) == 'string' and ox_inventory:GetItemCount(source, component.name) > 0
    end)
end)

lib.callback.register('bryan_weapon_components:server:updateComponents', function(source, slotId, component, remove)
    local slot = getWeaponSlot(source, slotId)

    if not slot then
        notifyError(source, 'Could not find the weapon')
        return false
    end

    -- Never trust the client's component data, use the server item definition
    local item = type(component?.name) == 'string' and ox_inventory:Items(component.name)

    if not item or not item.component or not item.type then
        notifyError(source, 'Invalid component')
        return false
    end

    if not remove and ox_inventory:GetItemCount(source, item.name) < 1 then
        notifyError(source, 'Could not find the component')
        return false
    end

    local metadata = slot.metadata or {}
    -- Copy so the live metadata is untouched if anything fails, and drop components whose item no longer exists
    local components = lib.array.filter(metadata.components or {}, function(name)
        return ox_inventory:Items(name) ~= nil
    end)

    -- Find the component currently occupying this slot type
    local attachedIndex, attachedName

    for index, name in ipairs(components) do
        if ox_inventory:Items(name).type == item.type then
            attachedIndex, attachedName = index, name
            break
        end
    end

    if not remove and attachedName == item.name then
        return components
    end

    if remove and not attachedIndex then
        return components
    end

    if not remove and not ox_inventory:RemoveItem(source, item.name, 1) then
        notifyError(source, 'Could not find the component')
        return false
    end

    if attachedIndex then
        if not ox_inventory:AddItem(source, attachedName, 1) then
            if not remove then
                ox_inventory:AddItem(source, item.name, 1)
            end

            notifyError(source, 'Not enough space in your inventory')
            return false
        end

        table.remove(components, attachedIndex)
    end

    if not remove then
        components[#components + 1] = item.name
    end

    metadata.components = components
    ox_inventory:SetMetadata(source, slotId, metadata)

    return components
end)
