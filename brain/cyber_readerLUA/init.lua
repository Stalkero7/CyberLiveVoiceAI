-- =============================================================================
-- CyberLive Neural Uplink Display v8.5.0 PREMIUM
-- Maximum Cyberpunk 2077 authenticity with holographic effects
-- =============================================================================

local mod = {
    display_text = "",
    last_text = "",
    read_timer = 0,
    popup_timer = 0,
    is_visible = false,
    show_duration = 7.0,
    
    -- Advanced animation states
    fade_in = 0.0,
    fade_out = 1.0,
    glitch_timer = 0.0,
    glitch_intensity = 0.0,
    scan_line_pos = 0.0,
    flicker_alpha = 1.0,
    hologram_wave = 0.0,
    typing_progress = 0.0,
    
    -- Character info
    npc_name = "UNKNOWN",
    npc_message = "",
    displayed_message = "",
    
    -- Settings
    enable_typing_effect = true,
    enable_glitch = true,
    enable_corners = true,
    position = "bottom-left" -- Options: "bottom-left", "top-left", "center"
}

-- Enhanced Color Palette
local colors = {
    cyber_yellow = {1.0, 0.95, 0.0, 1.0},
    kiroshi_cyan = {0.0, 0.95, 1.0, 1.0},
    hot_pink = {1.0, 0.0, 0.6, 1.0},
    corpo_blue = {0.2, 0.6, 1.0, 1.0},
    warning_red = {1.0, 0.1, 0.2, 1.0},
    success_green = {0.0, 1.0, 0.5, 1.0},
    bg_dark = {0.01, 0.01, 0.01, 0.95},
    bg_gradient = {0.05, 0.05, 0.1, 0.8},
    text_white = {0.95, 0.95, 0.95, 1.0},
    text_dim = {0.4, 0.4, 0.4, 1.0},
    glitch_red = {1.0, 0.0, 0.0, 0.4},
    glitch_green = {0.0, 1.0, 0.0, 0.4},
    glitch_blue = {0.0, 0.0, 1.0, 0.4},
    hologram = {0.0, 0.8, 1.0, 0.15}
}

-- Parse message format
local function ParseMessage(text)
    -- Handle status messages
    if text:match("^UPLINK:") then
        mod.npc_name = "SYSTEM"
        mod.npc_message = text:gsub("^UPLINK:%s*", "")
        return
    end
    
    -- Parse "Name: Message" format
    local name, message = text:match("^([^:]+):%s*(.+)$")
    if name and message then
        mod.npc_name = name:upper()
        mod.npc_message = message
    else
        mod.npc_name = "NEURAL UPLINK"
        mod.npc_message = text
    end
end

-- Typing effect
local function UpdateTypingEffect(delta)
    if mod.enable_typing_effect and mod.typing_progress < 1.0 then
        mod.typing_progress = math.min(1.0, mod.typing_progress + delta * 3)
        local target_length = math.floor(#mod.npc_message * mod.typing_progress)
        mod.displayed_message = mod.npc_message:sub(1, target_length)
    else
        mod.displayed_message = mod.npc_message
    end
end

-- Advanced glitch effect
local function UpdateGlitch(delta)
    if not mod.enable_glitch then return end
    
    mod.glitch_timer = mod.glitch_timer + delta
    
    -- Intense glitch burst occasionally
    if math.random() < 0.005 then
        mod.glitch_intensity = 1.0
    end
    
    -- Decay glitch intensity
    mod.glitch_intensity = mod.glitch_intensity * 0.95
    
    -- Flicker effect
    if mod.glitch_intensity > 0.5 then
        mod.flicker_alpha = 0.5 + math.random() * 0.5
    else
        mod.flicker_alpha = math.min(1.0, mod.flicker_alpha + delta * 3)
    end
end

-- Holographic wave effect
local function UpdateHologram(delta)
    mod.hologram_wave = mod.hologram_wave + delta * 2
    if mod.hologram_wave > math.pi * 2 then
        mod.hologram_wave = 0
    end
end

-- Calculate window position based on setting
local function GetWindowPosition()
    local screen_width, screen_height = GetDisplayResolution()
    local window_width = 550
    local window_height = 200 -- Approximate
    
    if mod.position == "bottom-left" then
        return 40, screen_height - 320, window_width
    elseif mod.position == "top-left" then
        return 40, 80, window_width
    elseif mod.position == "center" then
        return (screen_width - window_width) / 2, (screen_height - window_height) / 2, window_width
    else
        return 40, screen_height - 320, window_width -- Default
    end
end

registerForEvent("onUpdate", function(delta)
    -- Check for new text
    mod.read_timer = mod.read_timer + delta
    if mod.read_timer > 0.2 then
        mod.read_timer = 0
        local file = io.open("output.txt", "r")
        if file then
            local content = file:read("*all")
            file:close()
            
            if content and content ~= "" and content ~= mod.last_text then
                mod.display_text = content
                mod.last_text = content
                mod.is_visible = true
                mod.popup_timer = mod.show_duration
                mod.fade_in = 0.0
                mod.typing_progress = 0.0
                mod.glitch_intensity = 0.8 -- Initial glitch burst
                
                ParseMessage(content)
            end
        end
    end

    if mod.is_visible then
        mod.popup_timer = mod.popup_timer - delta
        
        -- Fade in/out
        if mod.popup_timer > 1.0 then
            mod.fade_in = math.min(1.0, mod.fade_in + delta * 5)
            mod.fade_out = 1.0
        else
            -- Fade out in last second
            mod.fade_out = mod.popup_timer
        end
        
        -- Update effects
        UpdateTypingEffect(delta)
        UpdateGlitch(delta)
        UpdateHologram(delta)
        
        if mod.popup_timer <= 0 then
            mod.is_visible = false
        end
    end
end)

registerForEvent("onDraw", function()
    if not mod.is_visible then return end
    
    local window_x, window_y, window_width = GetWindowPosition()
    local master_alpha = mod.fade_in * mod.fade_out
    
    ImGui.SetNextWindowPos(window_x, window_y)
    ImGui.SetNextWindowSize(window_width, 0)

    -- Styling
    ImGui.PushStyleColor(ImGuiCol.WindowBg, colors.bg_dark[1], colors.bg_dark[2], colors.bg_dark[3], colors.bg_dark[4] * master_alpha)
    ImGui.PushStyleColor(ImGuiCol.Border, colors.kiroshi_cyan[1], colors.kiroshi_cyan[2], colors.kiroshi_cyan[3], mod.flicker_alpha * master_alpha)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 0.0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowBorderSize, 3.0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 20, 18)

    local flags = ImGuiWindowFlags.NoTitleBar + 
                  ImGuiWindowFlags.NoResize + 
                  ImGuiWindowFlags.NoMove + 
                  ImGuiWindowFlags.NoCollapse +
                  ImGuiWindowFlags.AlwaysAutoResize

    if ImGui.Begin("CyberLive_Neural_Premium", true, flags) then
        local draw_list = ImGui.GetWindowDrawList()
        local win_pos_x, win_pos_y = ImGui.GetWindowPos()
        local win_size_x, win_size_y = ImGui.GetWindowSize()
        
        -- Holographic background waves
        for i = 0, 3 do
            local wave_y = win_pos_y + (i * 80) + math.sin(mod.hologram_wave + i) * 10
            local wave_alpha = 0.05 * master_alpha
            local wave_color = ImGui.ColorConvertFloat4ToU32(colors.kiroshi_cyan[1], colors.kiroshi_cyan[2], colors.kiroshi_cyan[3], wave_alpha)
            draw_list:AddLine(win_pos_x, wave_y, win_pos_x + win_size_x, wave_y, wave_color, 1)
        end
        
        -- Glitch effect layers
        if mod.glitch_intensity > 0.3 then
            local glitch_offset = (math.random() - 0.5) * mod.glitch_intensity * 8
            ImGui.SetCursorPos(glitch_offset, 0)
            ImGui.TextColored(colors.glitch_red[1], colors.glitch_red[2], colors.glitch_red[3], colors.glitch_red[4] * mod.glitch_intensity, "▼ NEURAL LINK ESTABLISHED")
        end
        
        -- Main header
        ImGui.TextColored(colors.kiroshi_cyan[1], colors.kiroshi_cyan[2], colors.kiroshi_cyan[3], master_alpha, "▼ NEURAL LINK ESTABLISHED")
        
        -- Animated separator
        local sep_alpha = (0.5 + math.sin(mod.hologram_wave * 2) * 0.2) * master_alpha
        ImGui.PushStyleColor(ImGuiCol.Separator, colors.hot_pink[1], colors.hot_pink[2], colors.hot_pink[3], sep_alpha)
        ImGui.Separator()
        ImGui.PopStyleColor()
        
        ImGui.Spacing()
        ImGui.Spacing()
        
        -- Connection status indicator (animated dot)
        local dot_color = colors.success_green
        local dot_size = 8 + math.sin(mod.hologram_wave * 3) * 2
        local cursor_x, cursor_y = ImGui.GetCursorScreenPos()
        local dot_color_u32 = ImGui.ColorConvertFloat4ToU32(dot_color[1], dot_color[2], dot_color[3], master_alpha)
        draw_list:AddCircleFilled(cursor_x + 5, cursor_y + 8, dot_size, dot_color_u32, 16)
        
        ImGui.SetCursorPos(20, ImGui.GetCursorPosY())
        
        -- NPC Name with designation
        local name_color = mod.npc_name == "SYSTEM" and colors.warning_red or colors.cyber_yellow
        ImGui.TextColored(name_color[1], name_color[2], name_color[3], master_alpha, "◢ " .. mod.npc_name)
        
        ImGui.Spacing()
        
        -- Message with typing effect
        ImGui.PushTextWrapPos(window_width - 40)
        
        local text_alpha = mod.flicker_alpha * master_alpha
        ImGui.TextColored(colors.text_white[1], colors.text_white[2], colors.text_white[3], text_alpha, mod.displayed_message)
        
        -- Cursor blink during typing
        if mod.typing_progress < 1.0 and math.floor(mod.hologram_wave * 4) % 2 == 0 then
            ImGui.SameLine()
            ImGui.TextColored(colors.kiroshi_cyan[1], colors.kiroshi_cyan[2], colors.kiroshi_cyan[3], master_alpha, "█")
        end
        
        ImGui.PopTextWrapPos()
        
        ImGui.Spacing()
        ImGui.Spacing()
        
        -- Progress bar with glow
        ImGui.PushStyleColor(ImGuiCol.Separator, colors.corpo_blue[1], colors.corpo_blue[2], colors.corpo_blue[3], 0.3 * master_alpha)
        ImGui.Separator()
        ImGui.PopStyleColor()
        
        local remaining_ratio = mod.popup_timer / mod.show_duration
        
        -- Animated progress bar
        ImGui.PushStyleColor(ImGuiCol.PlotHistogram, colors.kiroshi_cyan[1], colors.kiroshi_cyan[2], colors.kiroshi_cyan[3], 0.6 * master_alpha)
        ImGui.PushStyleColor(ImGuiCol.FrameBg, colors.bg_gradient[1], colors.bg_gradient[2], colors.bg_gradient[3], 0.5 * master_alpha)
        ImGui.ProgressBar(remaining_ratio, window_width - 40, 4)
        ImGui.PopStyleColor(2)
        
        -- Status line
        local status_icon = remaining_ratio > 0.3 and "●" or "⚠"
        local status_color = remaining_ratio > 0.3 and colors.text_dim or colors.warning_red
        local status_text = string.format("%s CONNECTION • %.1fs", status_icon, mod.popup_timer)
        
        ImGui.TextColored(status_color[1], status_color[2], status_color[3], master_alpha, status_text)
        
        -- Corner brackets (CP77 signature style)
        if mod.enable_corners then
            local corner_size = 18
            local corner_thick = 2.5
            local corner_alpha = (0.7 + math.sin(mod.hologram_wave) * 0.3) * master_alpha
            local corner_color = ImGui.ColorConvertFloat4ToU32(colors.kiroshi_cyan[1], colors.kiroshi_cyan[2], colors.kiroshi_cyan[3], corner_alpha)
            
            -- Top-left
            draw_list:AddLine(win_pos_x, win_pos_y, win_pos_x + corner_size, win_pos_y, corner_color, corner_thick)
            draw_list:AddLine(win_pos_x, win_pos_y, win_pos_x, win_pos_y + corner_size, corner_color, corner_thick)
            
            -- Top-right
            draw_list:AddLine(win_pos_x + win_size_x, win_pos_y, win_pos_x + win_size_x - corner_size, win_pos_y, corner_color, corner_thick)
            draw_list:AddLine(win_pos_x + win_size_x, win_pos_y, win_pos_x + win_size_x, win_pos_y + corner_size, corner_color, corner_thick)
            
            -- Bottom-left
            draw_list:AddLine(win_pos_x, win_pos_y + win_size_y, win_pos_x + corner_size, win_pos_y + win_size_y, corner_color, corner_thick)
            draw_list:AddLine(win_pos_x, win_pos_y + win_size_y, win_pos_x, win_pos_y + win_size_y - corner_size, corner_color, corner_thick)
            
            -- Bottom-right
            draw_list:AddLine(win_pos_x + win_size_x, win_pos_y + win_size_y, win_pos_x + win_size_x - corner_size, win_pos_y + win_size_y, corner_color, corner_thick)
            draw_list:AddLine(win_pos_x + win_size_x, win_pos_y + win_size_y, win_pos_x + win_size_x, win_pos_y + win_size_y - corner_size, corner_color, corner_thick)
            
            -- Extra accent lines
            local accent_color = ImGui.ColorConvertFloat4ToU32(colors.hot_pink[1], colors.hot_pink[2], colors.hot_pink[3], corner_alpha * 0.5)
            draw_list:AddLine(win_pos_x + corner_size, win_pos_y, win_pos_x + corner_size + 5, win_pos_y, accent_color, 1.5)
            draw_list:AddLine(win_pos_x, win_pos_y + corner_size, win_pos_x, win_pos_y + corner_size + 5, accent_color, 1.5)
        end
    end
    ImGui.End()

    ImGui.PopStyleVar(3)
    ImGui.PopStyleColor(2)
end)

-- Console commands for customization
function SetDisplayPosition(pos)
    if pos == "bottom-left" or pos == "top-left" or pos == "center" then
        mod.position = pos
        print("[CyberLive] Display position set to: " .. pos)
    else
        print("[CyberLive] Invalid position. Use: bottom-left, top-left, or center")
    end
end

function ToggleTypingEffect()
    mod.enable_typing_effect = not mod.enable_typing_effect
    print("[CyberLive] Typing effect: " .. (mod.enable_typing_effect and "ON" or "OFF"))
end

function ToggleGlitch()
    mod.enable_glitch = not mod.enable_glitch
    print("[CyberLive] Glitch effect: " .. (mod.enable_glitch and "ON" or "OFF"))
end

function SetDisplayDuration(seconds)
    mod.show_duration = seconds
    print("[CyberLive] Display duration set to: " .. seconds .. "s")
end

print("=== CyberLive Neural Display v8.5.0 Premium ===")
print("Console Commands:")
print("  SetDisplayPosition('bottom-left' / 'top-left' / 'center')")
print("  ToggleTypingEffect()")
print("  ToggleGlitch()")
print("  SetDisplayDuration(seconds)")

return mod
