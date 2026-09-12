local AceLocale = LibStub("AceLocale-3.0")
local L = AceLocale:NewLocale("Details_MyDamageTaken", "deDE")

if (not L) then return end

L["STRING_PLUGIN_NAME"] = "Mein erlittener Schaden"
L["STRING_PLUGIN_DESC"] = "Zeigt den in deiner letzten Kampf-Sitzung erlittenen Schaden, aufgeschlüsselt nach Zauber."
L["STRING_NO_DATA"]     = "Keine Daten zu erlittenem Schaden"
L["STRING_OPTIONS"]     = "Optionen"
L["STRING_UPDATE_SPEED"] = "Aktualisierungsrate"
L["STRING_UPDATE_SPEED_DESC"] = "Wie schnell das Fenster aktualisiert wird (in Sekunden)."
