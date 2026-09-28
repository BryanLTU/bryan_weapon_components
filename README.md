# bryan_weapon_components

Inspect a weapon in 3D and drag and drop attachments onto it, using components from your ox_inventory.

## Requirements

- [ox_lib](https://github.com/overextended/ox_lib)
- [ox_inventory](https://github.com/overextended/ox_inventory)

## Installation

1. Build the UI:

   ```sh
   cd web
   npm install
   npm run build
   ```

2. Add the resource to your `server.cfg` after its dependencies:

   ```cfg
   ensure ox_lib
   ensure ox_inventory
   ensure bryan_weapon_components
   ```

3. Add the inspect button to the weapons you want (see below).

## Adding the inspect button to a weapon

The attachment menu is opened from a button in the ox_inventory item context menu. Buttons can't be added from another resource, so add one to each weapon in `ox_inventory/data/weapons.lua`.

Find the weapon under `Weapons` and add a `buttons` table:

```lua
['WEAPON_ASSAULTRIFLE'] = {
    label = 'Assault Rifle',
    weight = 6500,
    durability = 0.03,
    ammoname = 'ammo-rifle2',
    buttons = {
        {
            label = 'Inspect Attachments',
            action = function(slot)
                TriggerEvent('bryan_weapon_components:client:inspect', slot)
            end
        }
    }
},
```

If the weapon already has a `buttons` table, add the entry to it instead of creating a second one.

Restart the server after editing. ox_inventory sends buttons to the player when they load, so restarting only ox_inventory while players are connected isn't enough; they need to reconnect.

## Components

Components come from the `Components` section of `ox_inventory/data/weapons.lua`. A component only shows up in the menu if the weapon accepts it and its `type` matches a slot in `Config.Slots` (`config.lua`). The default slots are:

| `type`       | Slot       |
|--------------|------------|
| `flashlight` | Flashlight |
| `sight`      | Sight      |
| `muzzle`     | Muzzle     |
| `magazine`   | Magazine   |
| `grip`       | Grip       |
| `skin`       | Finish     |

```lua
['at_flashlight'] = {
    label = 'Tactical Flashlight',
    type = 'flashlight',
    weight = 120,
    client = {
        component = { `COMPONENT_AT_AR_FLSH`, `COMPONENT_AT_PI_FLSH` },
        usetime = 2500
    }
},
```

Only one component per slot can be attached. Attaching a new one returns the old one to the player's inventory.
