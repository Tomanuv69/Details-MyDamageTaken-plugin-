local AceLocale = LibStub("AceLocale-3.0")
local L = AceLocale:NewLocale("Details_MyDamageTaken", "enUS", true)

if (not L) then return end

L["STRING_PLUGIN_NAME"] = "My Damage Taken"
L["STRING_PLUGIN_DESC"] = "Shows the damage you have taken in your last combat session, broken down by spell."
L["STRING_NO_DATA"]     = "No damage taken data"
L["STRING_OPTIONS"]     = "Options"
L["STRING_UPDATE_SPEED"] = "Update Speed"
L["STRING_UPDATE_SPEED_DESC"] = "How fast the window gets updated (in seconds)."
