local AceLocale = LibStub("AceLocale-3.0")
local Loc = AceLocale:GetLocale("Details_MyDamageTaken")

local Details = _G.Details
local detailsFramework = _G.DetailsFramework

local _ipairs = ipairs                     --> lua api
local _cstr = string.format                --> lua api
local floor = math.floor
local max = math.max

local SharedMedia = LibStub:GetLibrary("LibSharedMedia-3.0")

--> Create the plugin Object
local MyDamageTaken = Details:NewPluginObject("Details_MyDamageTaken")

--> Main Frame
local MyDamageTakenFrame = MyDamageTaken.Frame

MyDamageTaken:SetPluginDescription(Loc["STRING_PLUGIN_DESC"])
MyDamageTaken.version_string = "2.3"

------------------------------------------------------------
-- 12.0 "Secret Values":
-- C_DamageMeter liefert im Kampf LIVE Daten, deren Zahlen aber
-- "secret" sind. Solche Werte duerfen NICHT verglichen, als
-- Tabellen-Schluessel benutzt oder numerisch formatiert werden.
-- Sie duerfen aber direkt via SetText angezeigt werden.
------------------------------------------------------------
local function IsSecret(v)
    if (type(issecretvalue) == "function") then
        local ok, res = pcall(issecretvalue, v)
        if (ok) then return res and true or false end
    end
    return false
end

------------------------------------------------------------
-- Aus einem Details!-Bar-Wrapper das ECHTE UI-Frame holen.
-- Der Wrapper selbst ist nur eine Lua-Tabelle und kann NICHT
-- an Funktionen wie GameTooltip:SetOwner uebergeben werden.
------------------------------------------------------------
local function GetRealFrame(row)
    if (not row) then return UIParent end
    --> gebraeuchliche Feldnamen der DetailsFramework-Bar
    local f = row.widget or row.statusbar or row.background
    --> manche Wrapper liefern das Frame ueber :GetObject()
    if (not f and type(row.GetObject) == "function") then
        local ok, obj = pcall(row.GetObject, row)
        if (ok) then f = obj end
    end
    --> letzte Absicherung: nur zurueckgeben, wenn es wirklich ein Frame ist
    if (f and type(f) == "table" and type(f.GetObjectType) == "function") then
        return f
    end
    return UIParent
end

------------------------------------------------------------
-- Zahl secret-sicher formatieren.
-- Bei secret-Werten wird der Wert unveraendert zurueckgegeben;
-- WoW erlaubt dessen Anzeige via SetText.
------------------------------------------------------------
local function FormatNumberSmart(value)
    if (IsSecret(value)) then
        return value            --> secret: direkt anzeigen lassen
    end

    local num = tonumber(value)
    if (not num) then
        return value
    end

    local size = ""
    if (num >= 100000000) then
        size = " M"
        num = num / 1000000
    elseif (num >= 100000) then
        size = " K"
        num = num / 1000
    end

    local formatted = _cstr("%d", num)
    formatted = formatted:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    if (formatted:sub(1, 1) == ",") then
        formatted = formatted:sub(2)
    end
    return formatted .. size
end

------------------------------------------------------------
-- Datenquelle abrufen (kompatibel zu GetMyTakenDamage /
-- GetTakenDamage). Reihenfolge wird beibehalten - KEIN sort.
------------------------------------------------------------
local function FetchData()
    if (not MyDT) then return {} end
    local getter = MyDT.GetMyTakenDamage or MyDT.GetTakenDamage
    if (not getter) then return {} end
    local ok, data = pcall(getter, MyDT)
    if (ok and type(data) == "table") then
        return data
    end
    return {}
end

------------------------------------------------------------
-- Tooltip: echter Blizzard-Zauber-Tooltip (SetSpellByID).
-- Liest die Daten aus row.spellData (exakt wie in der
-- funktionierenden V2.0). Nur nach Kampfende moeglich, da die
-- spellID im Kampf ein "secret value" ist.
------------------------------------------------------------
local function ShowRowTooltip(row)
    local data = row.spellData
    if (not data) then
        return
    end

    local spellID   = data.spellID
    local spellName = data.spellName

    --> im Kampf ist spellID secret -> dann keinen Tooltip zeigen
    if (not spellID or IsSecret(spellID)) then
        return
    end

    local anchorFrame = GetRealFrame(row)   --> ECHTES Frame, nicht der Wrapper
    GameTooltip:SetOwner(anchorFrame, "ANCHOR_RIGHT")

    local shown = false
    if (spellID and spellID > 0) then
        shown = pcall(GameTooltip.SetSpellByID, GameTooltip, spellID)
    end
    if (not shown) then
        GameTooltip:SetText(spellName or "?", 1, 1, 1)
    end
    GameTooltip:Show()
end

local function HideRowTooltip()
    GameTooltip:Hide()
end

------------------------------------------------------------
-- Maus + OnEnter/OnLeave direkt auf ALLE moeglichen klickbaren
-- Frames haengen. (Das ist der bewaehrte, funktionierende Weg.)
------------------------------------------------------------
local function HookRowMouse(row)
    local onEnter = function() ShowRowTooltip(row) end
    local onLeave = function() HideRowTooltip() end
    local candidates = { row, row.statusbar, row.widget, row.background }
    for _, frame in _ipairs(candidates) do
        if (frame and frame.EnableMouse) then
            frame:EnableMouse(true)
            if (frame.SetScript) then
                frame:SetScript("OnEnter", onEnter)
                frame:SetScript("OnLeave", onLeave)
            end
        end
    end
    if (row.SetHook) then
        row:SetHook("OnEnter", onEnter)
        row:SetHook("OnLeave", onLeave)
    end
end

------------------------------------------------------------
-- Widgets erstellen
------------------------------------------------------------
local function CreatePluginFrames(data)

    if (not Details) then
        return
    end

    local _detalhes = _G.Details
    local DetailsFrameWork = _detalhes.gump

    MyDamageTaken.data = data or {}

    MyDamageTaken.RowWidth = 294
    MyDamageTaken.RowHeight = 14
    MyDamageTaken.CanShow = 0
    MyDamageTaken.Rows = {}
    MyDamageTaken.ShownRows = {}
    MyDamageTaken.Actived = false

    local instance

    ----------------------------------------------------------
    -- Details! Event-Handler
    ----------------------------------------------------------
    function MyDamageTaken:OnDetailsEvent(event, ...)

        if (event == "HIDE") then
            MyDamageTakenFrame:SetScript("OnUpdate", nil)
            MyDamageTaken.Actived = false
            MyDamageTaken:HideBars()

        elseif (event == "SHOW") then
            instance = MyDamageTaken:GetInstance(MyDamageTaken.instance_id)
            if (instance) then
                MyDamageTaken.RowWidth = instance.baseframe:GetWidth() - 6
            end
            MyDamageTaken:UpdateContainers()
            MyDamageTaken:UpdateRows()
            MyDamageTaken:SizeChanged()
            MyDamageTaken:RaiseFrameLevel()
            MyDamageTaken.Actived = true
            MyDamageTaken:Start()

        elseif (event == "COMBAT_PLAYER_ENTER") then
            MyDamageTaken.Actived = true
            MyDamageTaken:Start()

        elseif (event == "COMBAT_PLAYER_LEAVE") then
            MyDamageTaken:RefreshData()

        elseif (event == "DETAILS_INSTANCE_ENDRESIZE" or event == "DETAILS_INSTANCE_SIZECHANGED") then
            MyDamageTaken:SizeChanged()
            MyDamageTaken:RaiseFrameLevel()

        elseif (event == "DETAILS_INSTANCE_STARTSTRETCH") then
            if (instance) then
                MyDamageTakenFrame:SetFrameStrata("TOOLTIP")
                MyDamageTakenFrame:SetFrameLevel(instance.baseframe:GetFrameLevel() + 1)
            end

        elseif (event == "DETAILS_INSTANCE_ENDSTRETCH") then
            MyDamageTakenFrame:SetFrameStrata("MEDIUM")
            MyDamageTaken:RaiseFrameLevel()

        elseif (event == "DETAILS_OPTIONS_MODIFIED") then
            MyDamageTaken:UpdateRows()
            MyDamageTaken:RefreshData()

        elseif (event == "PLUGIN_DISABLED") then
            MyDamageTakenFrame:SetScript("OnUpdate", nil)
            MyDamageTaken:HideBars()

        elseif (event == "PLUGIN_ENABLED") then
            MyDamageTaken.Actived = true
            MyDamageTaken:Start()
        end
    end

    MyDamageTakenFrame:SetWidth(300)
    MyDamageTakenFrame:SetHeight(100)

    ----------------------------------------------------------
    -- Frame-Ebene ueber die Details!-Fensterinhalte heben.
    -- WICHTIG fuer den Tooltip: sonst liegen die Balken UNTER
    -- den Details!-Frames und erhalten keine Maus-Events
    -- (OnEnter feuert nicht -> kein Tooltip).
    ----------------------------------------------------------
    function MyDamageTaken:RaiseFrameLevel()
        if (not instance or not instance.baseframe) then return end
        local baseLevel = instance.baseframe:GetFrameLevel() or 1
        MyDamageTakenFrame:SetFrameLevel(baseLevel + 5)
        for _, row in _ipairs(MyDamageTaken.Rows) do
            local f = GetRealFrame(row)
            if (f and f.SetFrameLevel and f ~= UIParent) then
                f:SetFrameLevel(baseLevel + 6)
            end
        end
    end

    ----------------------------------------------------------
    -- Row-Verwaltung
    ----------------------------------------------------------
    function MyDamageTaken:UpdateContainers()
        if (not instance) then return end
        for _, row in _ipairs(MyDamageTaken.Rows) do
            row:SetContainer(instance.baseframe)
        end
    end

    function MyDamageTaken:UpdateRows()
        for _, row in _ipairs(MyDamageTaken.Rows) do
            row.width = MyDamageTaken.RowWidth
            local pluginInstance = MyDamageTaken:GetPluginInstance()
            if (pluginInstance) then
                row.textsize = pluginInstance.row_info.font_size
                local font = SharedMedia:Fetch("font", pluginInstance.row_info.font_face, true) or pluginInstance.row_info.font_face
                row.textfont = font
                row.texture  = pluginInstance.row_info.texture
                row.shadow   = pluginInstance.row_info.textL_outline
            end
        end
    end

    function MyDamageTaken:HideBars()
        for _, row in _ipairs(MyDamageTaken.Rows) do
            row:Hide()
        end
    end

    function MyDamageTaken:SizeChanged()
        local pluginInstance = MyDamageTaken:GetPluginInstance()
        if (not pluginInstance) then return end

        local w, h = pluginInstance:GetSize()
        MyDamageTakenFrame:SetWidth(w)
        MyDamageTakenFrame:SetHeight(h)

        MyDamageTaken.RowHeight = pluginInstance.row_info.height
        MyDamageTaken.CanShow = floor(h / (MyDamageTaken.RowHeight + 1))

        for i = #MyDamageTaken.Rows + 1, MyDamageTaken.CanShow do
            MyDamageTaken:NewRow(i)
        end

        MyDamageTaken.ShownRows = {}
        for i = 1, MyDamageTaken.CanShow do
            MyDamageTaken.ShownRows[#MyDamageTaken.ShownRows + 1] = MyDamageTaken.Rows[i]
            MyDamageTaken.Rows[i].width = w - 5
        end

        for i = #MyDamageTaken.ShownRows + 1, #MyDamageTaken.Rows do
            MyDamageTaken.Rows[i]:Hide()
        end
    end

    function MyDamageTaken:NewRow(i)
        local newrow = DetailsFrameWork:NewBar(MyDamageTakenFrame, nil, "DetailsMyDamageTakenRow" .. i, nil, 300, MyDamageTaken.RowHeight)
        newrow:SetPoint(3, -((i - 1) * (MyDamageTaken.RowHeight + 1)))
        newrow.lefttext = "spell " .. i
        newrow.color = "red"
        newrow.fontsize = 10
        newrow.fontface = "GameFontHighlightSmall"
        newrow.rowId = i

        --> Maus + Tooltip auf alle Kandidaten-Frames (bewaehrter Weg)
        HookRowMouse(newrow)

        MyDamageTaken.Rows[#MyDamageTaken.Rows + 1] = newrow
        newrow:Hide()
        return newrow
    end

    ----------------------------------------------------------
    -- Daten holen (LIVE aus C_DamageMeter) und in die Balken
    -- schreiben - SECRET-SICHER:
    --   * keine Aggregation, keine Sortierung
    --   * Balkenlaenge rangbasiert (Index), nicht aus amount
    --   * amount nur nach IsSecret()-Pruefung formatieren
    --   * Datenzeile fuer den Tooltip direkt auf der Zeile (spellData)
    ----------------------------------------------------------
    function MyDamageTaken:RefreshData()
        if (not MyDamageTaken.Actived) then
            return
        end

        local data = FetchData()          --> Reihenfolge beibehalten
        local n = #data
        local shown = #MyDamageTaken.ShownRows

        for index = 1, shown do
            local thisRow = MyDamageTaken.ShownRows[index]
            local d = data[index]

            if (thisRow and d) then
                --> Datenzeile fuer den Tooltip direkt auf der Zeile ablegen
                --> (Tabellen-Referenz -> unkritisch; genau wie in V2.0).
                thisRow.spellData = d

                --> linker Text: Zauber (+ Verursacher)
                local spellName = d.spellName or "Unbekannt"
                local unitName  = d.unitName
                if (unitName) then
                    thisRow:SetLeftText(spellName .. " - |cffB08484" .. unitName .. "|r")
                else
                    thisRow:SetLeftText(spellName)
                end

                --> rechter Text: Betrag (secret-sicher formatiert)
                thisRow:SetRightText(FormatNumberSmart(d.amount))

                --> Balkenlaenge RANGBASIERT (kein amount-Vergleich)
                local rankFactor = (n > 1) and (1 - ((index - 1) / (n - 1)) * 0.80) or 1
                thisRow:SetValue(max(20, rankFactor * 100))

                --> Zauber-Icon
                if (thisRow._icon) then
                    thisRow._icon:SetTexture(d.spellIconID or d.spellIcon or 136235)
                    thisRow._icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
                end

                thisRow:SetColor(0.85, 0.20, 0.20, 1)

                if (not thisRow.statusbar:IsShown()) then
                    thisRow:Show()
                end
            elseif (thisRow) then
                thisRow.spellData = nil
                thisRow:Hide()
            end
        end
    end

    ----------------------------------------------------------
    -- Live-Update-Schleife
    ----------------------------------------------------------
    local timer = 0
    local function OnUpdate(self, elapsed)
        timer = timer + elapsed
        local interval = (MyDamageTaken.saveddata and MyDamageTaken.saveddata.updatespeed) or 0.5
        if (timer > interval) then
            timer = 0
            MyDamageTaken:RefreshData()
        end
    end

    function MyDamageTaken:Start()
        if (MyDamageTaken.Actived) then
            MyDamageTakenFrame:SetScript("OnUpdate", OnUpdate)
            MyDamageTaken:RefreshData()
        end
    end

    function MyDamageTaken:End()
        MyDamageTakenFrame:SetScript("OnUpdate", nil)
        MyDamageTaken:HideBars()
    end

    function MyDamageTaken:Cancel()
        MyDamageTakenFrame:SetScript("OnUpdate", nil)
        MyDamageTaken:HideBars()
        MyDamageTaken.Actived = false
    end
end

------------------------------------------------------------
-- Options-Panel
------------------------------------------------------------
local build_options_panel = function()
    local options_frame = MyDamageTaken:CreatePluginOptionsFrame("MyDamageTakenOptionsWindow", Loc["STRING_PLUGIN_NAME"] .. " " .. Loc["STRING_OPTIONS"], 1)

    local menu = {
        {
            type = "range",
            get = function() return MyDamageTaken.saveddata.updatespeed end,
            set = function(self, fixedparam, value) MyDamageTaken.saveddata.updatespeed = value end,
            min = 0.2,
            max = 3,
            step = 0.1,
            desc = Loc["STRING_UPDATE_SPEED_DESC"],
            name = Loc["STRING_UPDATE_SPEED"],
            usedecimals = true,
        },
    }

    local options_text_template     = detailsFramework:GetTemplate("font", "OPTIONS_FONT_TEMPLATE")
    local options_dropdown_template = detailsFramework:GetTemplate("dropdown", "OPTIONS_DROPDOWN_TEMPLATE")
    local options_switch_template   = detailsFramework:GetTemplate("switch", "OPTIONS_CHECKBOX_TEMPLATE")
    local options_slider_template   = detailsFramework:GetTemplate("slider", "OPTIONS_SLIDER_TEMPLATE")
    local options_button_template   = detailsFramework:GetTemplate("button", "OPTIONS_BUTTON_TEMPLATE")

    menu.always_boxfirst = true
    detailsFramework:BuildMenu(options_frame, menu, 15, -35, 160, false, options_text_template, options_dropdown_template, options_switch_template, true, options_slider_template, options_button_template)
    options_frame:SetHeight(100)
end

MyDamageTaken.OpenOptionsPanel = function()
    if (not MyDamageTakenOptionsWindow) then
        build_options_panel()
    end
    MyDamageTakenOptionsWindow:Show()
end

------------------------------------------------------------
-- Installation / ADDON_LOADED
------------------------------------------------------------
function MyDamageTaken:OnEvent(_, event, ...)
    if (event == "ADDON_LOADED") then
        local AddonName = select(1, ...)
        if (AddonName == "Details_MyDamageTaken") then
            if (_G.Details) then

                CreatePluginFrames(data)

                local MINIMAL_DETAILS_VERSION_REQUIRED = 1

                local install, saveddata = _G.Details:InstallPlugin(
                    "RAID",
                    Loc["STRING_PLUGIN_NAME"],
                    "Interface\\Icons\\Ability_Warrior_ShieldWall",
                    MyDamageTaken,
                    "DETAILS_PLUGIN_MY_DAMAGE_TAKEN",
                    MINIMAL_DETAILS_VERSION_REQUIRED,
                    "Nuvolin",
                    MyDamageTaken.version_string
                )

                if (type(install) == "table" and install.error) then
                    print(install.error)
                end

                _G.Details:RegisterEvent(MyDamageTaken, "COMBAT_PLAYER_ENTER")
                _G.Details:RegisterEvent(MyDamageTaken, "COMBAT_PLAYER_LEAVE")
                _G.Details:RegisterEvent(MyDamageTaken, "DETAILS_INSTANCE_ENDRESIZE")
                _G.Details:RegisterEvent(MyDamageTaken, "DETAILS_INSTANCE_SIZECHANGED")
                _G.Details:RegisterEvent(MyDamageTaken, "DETAILS_INSTANCE_STARTSTRETCH")
                _G.Details:RegisterEvent(MyDamageTaken, "DETAILS_INSTANCE_ENDSTRETCH")
                _G.Details:RegisterEvent(MyDamageTaken, "DETAILS_OPTIONS_MODIFIED")

                MyDamageTaken.saveddata = saveddata or {}
                MyDamageTaken.saveddata.updatespeed = MyDamageTaken.saveddata.updatespeed or 0.5
                MyDamageTaken.options = MyDamageTaken.saveddata

                SLASH_DETAILS_MYDAMAGETAKEN1 = "/mydamagetaken"
                SLASH_DETAILS_MYDAMAGETAKEN2 = "/mydt"
                function SlashCmdList.DETAILS_MYDAMAGETAKEN(msg)
                    MyDamageTaken.OpenOptionsPanel()
                end

                MyDamageTaken.initialized = true
            end

        elseif (event == "PLAYER_LOGOUT") then
            _detalhes_databaseMyDamageTaken = MyDamageTaken.data
        end
    end
end
