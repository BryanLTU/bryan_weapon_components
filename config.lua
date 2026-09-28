---@class Slot
---@field type string Component item `type` from ox_inventory/data/weapons.lua
---@field bone string? Weapon bone the slot is shown at, weapon center when not set

Config = {}

-- Preview placement in front of the ped
Config.PreviewDistance = 1.0
Config.CameraDistance = 1.5
Config.PreviewHeight = 0.5

-- Distance the ped can move from where the inspection was opened before it closes
Config.MaxMoveDistance = 1.0

-- Components can only be attached to a slot listed here
---@type Slot[]
Config.Slots = {
    { type = 'flashlight', bone = 'WAPFlshLasr' },
    { type = 'sight',      bone = 'WAPScop_2' },
    { type = 'muzzle',     bone = 'gun_muzzle' },
    { type = 'magazine',   bone = 'WAPClip' },
    { type = 'grip',       bone = 'WAPGrip' },
    { type = 'skin' }
}

-- Luxe skins replace the whole weapon model, preview is created with this model when any skin is attached
Config.LuxeModels = {
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
