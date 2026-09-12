local ADDON_NAME = ...

MyDT = MyDT or {}
MyDT.debug = false

------------------------------------------------------------
-- Datenquelle (12.0)
------------------------------------------------------------
local function GetLastSessionID(t)
    -- Finde den hoechsten numerischen Index
    local sessionID = nil
    for k, session in pairs(t) do
        local n = session.sessionID
        if type(n) == "number" then
            if not sessionID or n > sessionID then
                sessionID = n
            end
        end
    end

    -- Falls kein Eintrag vorhanden ist
    if not sessionID then
        return nil
    end

    return sessionID
end

function MyDT:GetCombatSessionSourceFromID(type)
        -- Enum.DamageMeterType
        -- Value 	Field 	Description
        -- 0 	DamageDone
        -- 1 	Dps
        -- 2 	HealingDone
        -- 3 	Hps
        -- 4 	Absorbs
        -- 5 	Interrupts
        -- 6 	Dispels
        -- 7 	DamageTaken
        -- 8 	AvoidableDamageTaken
    local result = {}

    if C_DamageMeter then
        local sessions = C_DamageMeter.GetAvailableCombatSessions()
        local lastSession = GetLastSessionID(sessions)
        if not lastSession then return result end
        local combatSessionSource = C_DamageMeter.GetCombatSessionSourceFromID(lastSession, type, UnitGUID("player"))
        for k, combatSpells, _ in pairs(combatSessionSource) do
            if k == "combatSpells" then
                for k2, t2, _ in pairs(combatSpells) do
                    table.insert(result, {
                        unitName          = t2.combatSpellDetails.unitName,
                        unitClassFilename = t2.combatSpellDetails.unitClassFilename,
                        amount            = t2.combatSpellDetails.amount,
                        spellID           = t2.spellID,
                        spellName         = C_Spell.GetSpellInfo(t2.spellID).name,
                        spellIconID       = C_Spell.GetSpellInfo(t2.spellID).iconID,
                        mapID             = C_Map.GetBestMapForUnit("player")
                    })
                end
            end
        end
    end

    return result
end

function MyDT:GetMyTakenDamage()
    return MyDT:GetCombatSessionSourceFromID(Enum.DamageMeterType.DamageTaken)
end
