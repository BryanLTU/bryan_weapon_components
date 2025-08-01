local ox_inventory = exports.ox_inventory

lib.callback.register('bryan_weapon_components:server:getWeapon', function(source, slotId)
    local slot = ox_inventory:GetSlot(source, slotId)
    if not slot then return nil end

    local item = ox_inventory:Items(slot.name)
    if not item or not item.weapon then
        return
    end

    return {
        model = item.model,
        components = slot.metadata?.components or {}
    }
end)

lib.callback.register('bryan_weapon_components:server:getInventoryComponents', function(source, components)
    return lib.array.filter(components, function(component)
        return ox_inventory:GetItemCount(source, component.name) > 0
    end)
end)

lib.callback.register('bryan_weapon_components:server:updateComponents', function(source, slotId, component, remove)
    local slot = ox_inventory:GetSlot(source, slotId)

    if not slot then
        lib.notify(source, {
            title = 'Weapon Components',
            description = 'Could not find the weapon'
        })
        return false
    end

    if not remove and ox_inventory:GetItemCount(source, component.name) < 1 then
        lib.notify(source, {
            title = 'Weapon Components',
            description = 'Could not find the component'
        })
        return false
    end

    local metadata = slot.metadata

    for index, attachedComponent in ipairs(metadata?.components) do
        local item = ox_inventory:Items(attachedComponent)

        if item.type == component.type then
            table.remove(metadata.components, index)
            ox_inventory:AddItem(source, attachedComponent, 1)

            break
        end
    end

    if not remove then
        ox_inventory:RemoveItem(source, component.name, 1)
        table.insert(metadata.components, component.name)
    end

    ox_inventory:SetMetadata(source, slotId, metadata)

    return metadata.components
end)