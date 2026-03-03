-- =============================================================================
-- CyberLive Refreshed Link v7.1.0
-- Enhanced with Auto-Targeting System
-- Press F9 to scan target under crosshair and auto-select in UI
-- =============================================================================

local bridge = {
    is_open = false,
    selected_npc = "None",
    active_hash = "0",
    custom_name_input = "",  -- For typing custom names
    custom_hash_input = "",  -- For typing custom hash
    save_as_preset = true,   -- Checkbox to save custom entries as presets
    npc_list = {
        { name = "Jackie Welles", hash = "0xA1C7BC30" },
        { name = "Alt Cunningham", hash = "0x47004" },
        { name = "Judy Alvarez", hash = "0xBD3A1" },
        { name = "Johnny Silverhand", hash = "0x12345" },
        { name = "Generic Resident", hash = "0x67890" }
    }
}

-- Targeting System Variables
local targeting = {
    current_target = nil,
    last_scan_time = 0,
    scan_cooldown = 0.3, -- Prevent spam
    is_scanning = false,
    scanned_name = "None",
    scanned_hash = "0"
}

local target_file = "target.txt"

-- ============================================================================
-- FILE I/O FUNCTIONS
-- ============================================================================

function WriteToBrain(name, hash, status)
    local t = io.open(target_file, "w")
    if t then
        t:write(name .. "|" .. hash .. "|" .. status .. "\n")
        t:write("Timestamp: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n")
        
        -- Add memory file path for brain.exe
        local safe_name = name:gsub("[^%w%s-]", ""):gsub("%s+", "_")
        local memory_file = "memory_" .. safe_name .. ".json"
        t:write("Memory: " .. memory_file)
        
        t:flush()
        t:close()
        print("[CyberLive] Brain IO Success: " .. name)
        return true
    else
        print("[CyberLive] ERROR: Could not write to target.txt")
        return false
    end
end

-- ============================================================================
-- TARGETING SYSTEM FUNCTIONS
-- ============================================================================

-- Get the player entity
local function GetPlayer()
    return Game.GetPlayer()
end

-- Get the target under the crosshair (Multiple methods for modded games)
local function GetTargetFromCrosshair()
    local player = GetPlayer()
    if not player then return nil end
    
    local target = nil
    
    -- Method 1: Try standard targeting system
    local targetingSystem = Game.GetTargetingSystem()
    if targetingSystem then
        target = targetingSystem:GetLookAtObject(player, false, false)
        if target then return target end
    end
    
    -- Method 2: Try getting target from player directly
    local targetTrackerComponent = player:GetTargetTrackerComponent()
    if targetTrackerComponent then
        local threatTarget = targetTrackerComponent:GetHostileThreat(player)
        if threatTarget then return threatTarget end
    end
    
    -- Method 3: Try scanning system
    local scanningController = player:GetScanningController()
    if scanningController then
        local scannedObject = scanningController:GetScannedObject()
        if scannedObject then return scannedObject end
    end
    
    -- Method 4: Use VisionModeSystem
    local visionModeSystem = Game.GetVisionModeSystem()
    if visionModeSystem then
        local lookedAtObject = visionModeSystem:GetScanningController():GetScannedObject()
        if lookedAtObject then return lookedAtObject end
    end
    
    return nil
end

-- Extract NPC name from entity (Enhanced for modded games)
local function GetNPCName(entity)
    if not entity then return "Unknown" end
    
    -- Method 1: Try display name
    local displayName = entity:GetDisplayName()
    if displayName then
        local localizedName = Game.GetLocalizedTextByKey(displayName)
        if localizedName and localizedName ~= "" and localizedName ~= "None" then
            return localizedName
        end
    end
    
    -- Method 2: Try getting name from record
    local recordID = entity:GetRecordID()
    if recordID then
        local record = TweakDB:GetRecord(recordID)
        if record then
            local fullName = record:FullName()
            if fullName and fullName ~= "" then
                return Game.GetLocalizedTextByKey(fullName)
            end
        end
    end
    
    -- Method 3: Try entity name
    local entityName = entity:GetClassName()
    if entityName and entityName ~= "" then
        -- Clean up the class name
        local cleanName = tostring(entityName.value)
        if cleanName and cleanName ~= "" then
            return cleanName:gsub("_", " ")
        end
    end
    
    -- Method 4: Fallback to entity ID
    local entityID = entity:GetEntityID()
    if entityID then
        local idString = tostring(entityID.hash)
        if idString and idString ~= "" and idString ~= "0" then
            return "NPC_" .. idString:sub(1, 8)
        end
    end
    
    return "Unknown Target"
end

-- Get entity hash/ID
local function GetEntityHash(entity)
    if not entity then return "0" end
    
    local entityID = entity:GetEntityID()
    if entityID then
        return tostring(entityID.hash)
    end
    
    return "0"
end

-- Check if scanned NPC matches one in our list
local function FindMatchingNPC(scannedName)
    for _, npc in ipairs(bridge.npc_list) do
        if string.find(scannedName:lower(), npc.name:lower()) or 
           string.find(npc.name:lower(), scannedName:lower()) then
            return npc
        end
    end
    return nil
end

-- Add custom NPC to the preset list
local function AddToPresetList(name, hash)
    -- Check if already exists
    for _, npc in ipairs(bridge.npc_list) do
        if npc.name == name then
            print("[CyberLive] NPC already in preset list: " .. name)
            return false
        end
    end
    
    -- Add to list
    table.insert(bridge.npc_list, { name = name, hash = hash })
    print("[CyberLive] Added to presets: " .. name)
    
    -- Create memory file for this character
    CreateMemoryFile(name, hash)
    
    SavePresetList() -- Auto-save when adding
    return true
end

-- Create a JSON memory file for a character
local function CreateMemoryFile(name, hash)
    -- Create safe filename (remove special characters)
    local safe_name = name:gsub("[^%w%s-]", ""):gsub("%s+", "_")
    local filename = "memory_" .. safe_name .. ".json"
    
    -- Check if file already exists
    local existing = io.open(filename, "r")
    if existing then
        existing:close()
        print("[CyberLive] Memory file already exists: " .. filename)
        return filename
    end
    
    -- Create new memory structure
    local memory_data = {
        character_name = name,
        character_hash = hash,
        created_at = os.date("%Y-%m-%d %H:%M:%S"),
        last_interaction = os.date("%Y-%m-%d %H:%M:%S"),
        conversation_history = {},
        character_info = {
            personality = "",
            background = "",
            relationship_to_player = "",
            notes = ""
        },
        stats = {
            total_interactions = 0,
            first_met = os.date("%Y-%m-%d"),
            last_seen = os.date("%Y-%m-%d")
        },
        custom_data = {}
    }
    
    -- Write JSON file
    local file = io.open(filename, "w")
    if file then
        -- Manual JSON serialization (basic but works)
        file:write("{\n")
        file:write('  "character_name": "' .. name .. '",\n')
        file:write('  "character_hash": "' .. hash .. '",\n')
        file:write('  "created_at": "' .. memory_data.created_at .. '",\n')
        file:write('  "last_interaction": "' .. memory_data.last_interaction .. '",\n')
        file:write('  "conversation_history": [],\n')
        file:write('  "character_info": {\n')
        file:write('    "personality": "",\n')
        file:write('    "background": "",\n')
        file:write('    "relationship_to_player": "",\n')
        file:write('    "notes": ""\n')
        file:write('  },\n')
        file:write('  "stats": {\n')
        file:write('    "total_interactions": 0,\n')
        file:write('    "first_met": "' .. memory_data.stats.first_met .. '",\n')
        file:write('    "last_seen": "' .. memory_data.stats.last_seen .. '"\n')
        file:write('  },\n')
        file:write('  "custom_data": {}\n')
        file:write("}\n")
        file:close()
        print("[CyberLive] Memory file created: " .. filename)
        return filename
    else
        print("[CyberLive] ERROR: Could not create memory file")
        return nil
    end
end

-- Update memory file when target is selected
local function UpdateMemoryTimestamp(name)
    local safe_name = name:gsub("[^%w%s-]", ""):gsub("%s+", "_")
    local filename = "memory_" .. safe_name .. ".json"
    
    -- Note: Full JSON parsing would require a library
    -- For now, we just note that brain.exe should handle updates
    print("[CyberLive] Memory file for interaction: " .. filename)
    return filename
end

-- Get memory filename for current target
local function GetCurrentMemoryFile()
    if bridge.selected_npc and bridge.selected_npc ~= "None" then
        local safe_name = bridge.selected_npc:gsub("[^%w%s-]", ""):gsub("%s+", "_")
        return "memory_" .. safe_name .. ".json"
    end
    return nil
end

-- Remove NPC from preset list
local function RemoveFromPresetList(name)
    for i, npc in ipairs(bridge.npc_list) do
        if npc.name == name then
            table.remove(bridge.npc_list, i)
            print("[CyberLive] Removed from presets: " .. name)
            SavePresetList() -- Auto-save when removing
            return true
        end
    end
    return false
end

-- Save preset list to file (persistent between sessions)
local function SavePresetList()
    local file = io.open("cyberlive_presets.txt", "w")
    if file then
        for _, npc in ipairs(bridge.npc_list) do
            file:write(npc.name .. "|" .. npc.hash .. "\n")
        end
        file:close()
        print("[CyberLive] Preset list saved (" .. #bridge.npc_list .. " entries)")
        return true
    end
    return false
end

-- Load preset list from file
local function LoadPresetList()
    local file = io.open("cyberlive_presets.txt", "r")
    if file then
        local loaded_list = {}
        for line in file:lines() do
            local name, hash = line:match("([^|]+)|([^|]+)")
            if name and hash then
                table.insert(loaded_list, { name = name, hash = hash })
                -- Ensure memory file exists for loaded presets
                CreateMemoryFile(name, hash)
            end
        end
        file:close()
        
        if #loaded_list > 0 then
            bridge.npc_list = loaded_list
            print("[CyberLive] Loaded " .. #bridge.npc_list .. " presets from file")
        end
        return true
    else
        print("[CyberLive] No saved presets found, using defaults")
        -- Create memory files for default NPCs
        for _, npc in ipairs(bridge.npc_list) do
            CreateMemoryFile(npc.name, npc.hash)
        end
        return false
    end
end

-- Main scan function (with debug logging)
local function ScanTarget()
    local currentTime = os.clock()
    
    -- Cooldown check
    if currentTime - targeting.last_scan_time < targeting.scan_cooldown then
        return
    end
    
    targeting.last_scan_time = currentTime
    
    print("[CyberLive] Attempting to scan target...")
    
    local target = GetTargetFromCrosshair()
    
    if target then
        print("[CyberLive] Target detected!")
        targeting.current_target = target
        targeting.scanned_name = GetNPCName(target)
        targeting.scanned_hash = GetEntityHash(target)
        
        print("[CyberLive] Name: " .. targeting.scanned_name)
        print("[CyberLive] Hash: " .. targeting.scanned_hash)
        
        -- Check if this matches a known NPC
        local matchedNPC = FindMatchingNPC(targeting.scanned_name)
        
        if matchedNPC then
            -- Auto-select the matched NPC in the UI
            bridge.selected_npc = matchedNPC.name
            bridge.active_hash = matchedNPC.hash
            WriteToBrain(matchedNPC.name, matchedNPC.hash, "TRUE")
            
            Game.GetPlayer():SetWarningMessage("Neural Link: " .. matchedNPC.name)
            print("[CyberLive] Matched Known NPC: " .. matchedNPC.name)
        else
            -- Write scanned unknown target
            bridge.selected_npc = targeting.scanned_name
            bridge.active_hash = targeting.scanned_hash
            WriteToBrain(targeting.scanned_name, targeting.scanned_hash, "TRUE")
            
            Game.GetPlayer():SetWarningMessage("Target Scanned: " .. targeting.scanned_name)
            print("[CyberLive] Scanned Unknown: " .. targeting.scanned_name)
        end
    else
        Game.GetPlayer():SetWarningMessage("No Target Found - Try getting closer or using Custom Entry")
        print("[CyberLive] No target detected. Methods tried:")
        print("  - TargetingSystem:GetLookAtObject")
        print("  - TargetTrackerComponent")
        print("  - ScanningController")
        print("  - VisionModeSystem")
        print("[CyberLive] Tip: Use Custom Target Entry in overlay or try AMM's spawn menu")
    end
end

-- Clear target
local function ClearTarget()
    targeting.current_target = nil
    targeting.scanned_name = "None"
    targeting.scanned_hash = "0"
    bridge.selected_npc = "None"
    bridge.active_hash = "0"
    WriteToBrain("None", "0", "FALSE")
    Game.GetPlayer():SetWarningMessage("Neural Link Disconnected")
end

-- ============================================================================
-- EVENT HANDLERS
-- ============================================================================

-- Initialize
registerForEvent("onInit", function()
    -- Load saved presets from previous sessions
    LoadPresetList()
    
    WriteToBrain("None", "0", "FALSE")
    print("[CyberLive] Neural Uplink v7.2.0 Initialized")
    print("[CyberLive] Press Numpad 7 to scan target")
    print("[CyberLive] Press F10 to clear target")
    print("[CyberLive] Custom entries can be saved as preset buttons!")
end)

-- UI visibility control
registerForEvent("onOverlayOpen", function()
    bridge.is_open = true
    print("[CyberLive] UI Enabled")
end)

registerForEvent("onOverlayClose", function()
    bridge.is_open = false
    print("[CyberLive] UI Disabled")
end)

-- Update loop for key detection
registerForEvent("onUpdate", function(delta)
    -- Numpad 7 - Scan target (integrates with voice system)
    if not targeting.is_scanning and ImGui.IsKeyPressed(ImGuiKey.Keypad7) then
        targeting.is_scanning = true
        ScanTarget()
    elseif not ImGui.IsKeyPressed(ImGuiKey.Keypad7) then
        targeting.is_scanning = false
    end
    
    -- F10 - Clear target
    if ImGui.IsKeyPressed(ImGuiKey.F10) then
        ClearTarget()
    end
end)

-- UI Drawing
registerForEvent("onDraw", function()
    if bridge.is_open then
        if ImGui.Begin("CyberLive Neural Uplink") then
            -- Targeting instructions
            ImGui.TextColored(1.0, 1.0, 0.0, 1.0, "[ Numpad 7 ] Scan Target  |  [ F10 ] Disconnect")
            ImGui.Separator()
            
            -- Custom Target Input Section
            ImGui.TextColored(0.8, 0.4, 1.0, 1.0, "Custom Target Entry:")
            ImGui.Spacing()
            
            bridge.custom_name_input = ImGui.InputText("Name", bridge.custom_name_input, 100)
            bridge.custom_hash_input = ImGui.InputText("Hash (optional)", bridge.custom_hash_input, 100)
            
            -- Checkbox to save as preset
            bridge.save_as_preset = ImGui.Checkbox("Save as Preset Button", bridge.save_as_preset)
            ImGui.Spacing()
            
            if ImGui.Button("SET CUSTOM TARGET") then
                if bridge.custom_name_input ~= "" then
                    local hash = bridge.custom_hash_input
                    if hash == "" then
                        hash = "0xCUSTOM"
                    end
                    
                    bridge.selected_npc = bridge.custom_name_input
                    bridge.active_hash = hash
                    WriteToBrain(bridge.custom_name_input, hash, "TRUE")
                    
                    -- Add to preset list if checkbox is checked
                    if bridge.save_as_preset then
                        AddToPresetList(bridge.custom_name_input, hash)
                        Game.GetPlayer():SetWarningMessage("Custom Target Saved: " .. bridge.custom_name_input)
                    else
                        Game.GetPlayer():SetWarningMessage("Custom Target: " .. bridge.custom_name_input)
                    end
                    
                    -- Clear input fields after setting
                    bridge.custom_name_input = ""
                    bridge.custom_hash_input = ""
                end
            end
            
            ImGui.Separator()
            
            -- Manual selection section with scroll for many entries
            ImGui.Text("Preset Buttons:")
            ImGui.TextColored(0.6, 0.6, 0.6, 1.0, "(" .. #bridge.npc_list .. " saved)")
            ImGui.Spacing()

            -- Add scrollable region if there are many NPCs
            if #bridge.npc_list > 8 then
                ImGui.BeginChild("PresetScroll", 0, 200, true)
            end

            for i, npc in ipairs(bridge.npc_list) do
                -- Visual highlight for active selection
                if bridge.selected_npc == npc.name then
                    ImGui.PushStyleColor(ImGuiCol.Button, 0.2, 0.7, 0.2, 1.0)
                end

                if ImGui.Button(npc.name .. "##" .. i) then
                    bridge.selected_npc = npc.name
                    bridge.active_hash = npc.hash
                    WriteToBrain(npc.name, npc.hash, "TRUE")
                end

                if bridge.selected_npc == npc.name then
                    ImGui.PopStyleColor(1)
                end
                
                -- Add delete button next to each preset (small red X)
                ImGui.SameLine()
                ImGui.PushStyleColor(ImGuiCol.Button, 0.8, 0.2, 0.2, 1.0)
                if ImGui.SmallButton("X##" .. i) then
                    RemoveFromPresetList(npc.name)
                end
                ImGui.PopStyleColor(1)
            end
            
            if #bridge.npc_list > 8 then
                ImGui.EndChild()
            end

            ImGui.Separator()

            -- Disconnect button
            if ImGui.Button("DISCONNECT LINK") then
                ClearTarget()
            end

            ImGui.Separator()
            
            -- Status display
            ImGui.TextColored(0.4, 0.8, 1.0, 1.0, "Active Link: " .. bridge.selected_npc)
            ImGui.TextColored(0.7, 0.7, 0.7, 1.0, "Hash: " .. bridge.active_hash)
            
            -- Last scanned info
            if targeting.scanned_name ~= "None" then
                ImGui.Spacing()
                ImGui.TextColored(0.8, 0.8, 0.4, 1.0, "Last Scan: " .. targeting.scanned_name)
            end
        end
        ImGui.End()
    end
end)

-- ============================================================================
-- CONSOLE COMMANDS (for debugging)
-- ============================================================================

function ScanCurrentTarget()
    ScanTarget()
end

function ClearCurrentTarget()
    ClearTarget()
end

function GetTargetInfo()
    print("Selected NPC: " .. bridge.selected_npc)
    print("Hash: " .. bridge.active_hash)
    print("Last Scanned: " .. targeting.scanned_name)
    print("Total Presets: " .. #bridge.npc_list)
end

function AddCustomNPC(name, hash)
    AddToPresetList(name, hash or "0xCUSTOM")
    print("[CyberLive] Added custom NPC: " .. name)
end

function RemoveNPC(name)
    if RemoveFromPresetList(name) then
        print("[CyberLive] Removed: " .. name)
    else
        print("[CyberLive] Not found: " .. name)
    end
end

function ListAllPresets()
    print("=== Current Presets ===")
    for i, npc in ipairs(bridge.npc_list) do
        print(i .. ". " .. npc.name .. " (" .. npc.hash .. ")")
    end
    print("Total: " .. #bridge.npc_list)
end

function SavePresets()
    SavePresetList()
    print("[CyberLive] Presets saved to cyberlive_presets.txt")
end

function LoadPresets()
    LoadPresetList()
    print("[CyberLive] Presets loaded from file")
end

print("=============================================================================")
print("CyberLive Neural Uplink v7.2.0 - LOADED")
print("Controls: Numpad 7=Scan | F10=Clear | ~/Home=Toggle UI")
print("Console Commands:")
print("  ScanCurrentTarget(), ClearCurrentTarget(), GetTargetInfo()")
print("  AddCustomNPC('Name', '0xHASH'), RemoveNPC('Name')")
print("  ListAllPresets(), SavePresets(), LoadPresets()")
print("=============================================================================")

return {}