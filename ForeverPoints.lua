-- ForeverPoints: on leaving combat, check for unspent talent points and legacy points.

local ADDON = "ForeverPoints"
local PREFIX = "|cff33ff99Forever Points:|r "

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)
end

----------------------------------------------------------------------
-- Check 1: unspent talent points
-- Return a number, or nil if it can't be read.
----------------------------------------------------------------------
local function GetUnspentTalents()
    if not C_ClassTalents or not C_ClassTalents.HasUnspentTalentPoints then return nil end
	
	local _, numClassPoints, _ = C_ClassTalents.HasUnspentTalentPoints()
	return numClassPoints
end

----------------------------------------------------------------------
-- Check 2: unspent legacy points
-- Return a number, or nil if it can't be read.
----------------------------------------------------------------------
local function GetUnspentLegacyPoints()
	if not LegacySystem then return nil end
	
	LegacySystem.UpdateCurrencyInfo() -- update the currency
		
	local currencyInfo = LegacySystem.GetCurrencyInfo();
	local legacyPointsCurrencyAvailable = currencyInfo and currencyInfo.quantity or nil
    return legacyPointsCurrencyAvailable
end

----------------------------------------------------------------------
-- Run both checks and report
----------------------------------------------------------------------
local function RunChecks()
	if UnitAffectingCombat("player") then return end

    local talents = GetUnspentTalents()
    if talents and talents > 0 then
        Print(string.format("You have |cffffff00%d|r unspent talent point%s.",
            talents, talents == 1 and "" or "s"))
    end

    local legacy = GetUnspentLegacyPoints()
    if legacy and legacy > 0 then
        Print(string.format("You have |cffffff00%d|r unspent legacy point%s.",
            legacy, legacy == 1 and "" or "s"))
    end
end

----------------------------------------------------------------------
-- Throttling: all automatic triggers go through here. The first call
-- starts a short timer; calls that arrive while it runs are ignored,
-- so e.g. levelling up and leaving combat together print only once.
-- The delay also lets the client update talent/currency data first.
----------------------------------------------------------------------
local CHECK_DELAY = 1
local checkPending = false

local function ScheduleCheck()
	if checkPending then return end
	checkPending = true
	C_Timer.After(CHECK_DELAY, function()
		checkPending = false
		RunChecks()
	end)
end

----------------------------------------------------------------------
-- Events
----------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")   -- fires when you leave combat
frame:RegisterEvent("PLAYER_ENTERING_WORLD") -- after loading screen
frame:RegisterEvent("PLAYER_LEVEL_UP")   -- fires when you level up
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, arg1, ...)
	-- Print points after combat or leveling up
	-- TODO: add an event for an achievement maybe?
	if event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_LEVEL_UP" then
		ScheduleCheck()
	end
	
	if event == "PLAYER_ENTERING_WORLD" then
		-- Load the Blizzard_LegacySystem addon so that we can read the LegacyPoints
		if not C_AddOns.IsAddOnLoaded("Blizzard_LegacySystem") then 
			C_Timer.After(CHECK_DELAY, function() 
				C_AddOns.LoadAddOn("Blizzard_LegacySystem") 
			end)
		end
	end
	-- After Blizzard_LegacySystem is loaded, we scan talent and legacy points and print it
	if event == "ADDON_LOADED" and arg1 == "Blizzard_LegacySystem" then
		ScheduleCheck()
	end
end)

-- Manual trigger for testing: /fpoints (runs immediately, no throttle)
SLASH_FOREVERPOINTS1 = "/fpoints"
SlashCmdList["FOREVERPOINTS"] = RunChecks