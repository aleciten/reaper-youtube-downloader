-- yt-dlp Version Check ReaScript
-- This script calls yt-dlp --version and displays the result

function find_yt_dlp()
    local common_paths = {
        "yt-dlp",
        "/usr/local/bin/yt-dlp",
        "/opt/homebrew/bin/yt-dlp",
        "/usr/bin/yt-dlp",
        os.getenv("HOME") .. "/.local/bin/yt-dlp"
    }
    
    for _, path in ipairs(common_paths) do
        local handle = io.popen("command -v " .. path .. " 2>/dev/null")
        if handle then
            local result = handle:read("*a")
            local success, exit_type, exit_code = handle:close()
            if success and exit_code == 0 and result:match("%S") then
                return result:gsub("%s+$", "")
            end
        end
    end
    
    local which_handle = io.popen("which yt-dlp 2>/dev/null")
    if which_handle then
        local which_result = which_handle:read("*a")
        local success, exit_type, exit_code = which_handle:close()
        if success and exit_code == 0 and which_result:match("%S") then
            return which_result:gsub("%s+$", "")
        end
    end
    
    return nil
end

function main()
    reaper.ShowConsoleMsg("Searching for yt-dlp...\n")
    
    local yt_dlp_path = find_yt_dlp()
    
    if not yt_dlp_path then
        reaper.ShowConsoleMsg("Error: yt-dlp not found in common locations\n")
        reaper.ShowConsoleMsg("Tried:\n")
        reaper.ShowConsoleMsg("  - System PATH\n")
        reaper.ShowConsoleMsg("  - /usr/local/bin/yt-dlp\n")
        reaper.ShowConsoleMsg("  - /opt/homebrew/bin/yt-dlp\n")
        reaper.ShowConsoleMsg("  - /usr/bin/yt-dlp\n")
        reaper.ShowConsoleMsg("  - ~/.local/bin/yt-dlp\n")
        reaper.ShowConsoleMsg("\nPlease ensure yt-dlp is installed and accessible\n")
        return
    end
    
    reaper.ShowConsoleMsg("Found yt-dlp at: " .. yt_dlp_path .. "\n")
    
    local command = yt_dlp_path .. " --version"
    reaper.ShowConsoleMsg("Executing command: " .. command .. "\n")
    
    local handle = io.popen(command)
    
    if not handle then
        reaper.ShowConsoleMsg("Error: Could not execute yt-dlp command\n")
        return
    end
    
    local result = handle:read("*a")
    local success, exit_type, exit_code = handle:close()
    
    if success and exit_code == 0 then
        reaper.ShowConsoleMsg("Command executed successfully!\n")
        reaper.ShowConsoleMsg("yt-dlp version: " .. result)
    else
        reaper.ShowConsoleMsg("Error executing yt-dlp --version\n")
        reaper.ShowConsoleMsg("Exit code: " .. tostring(exit_code) .. "\n")
    end
end

reaper.defer(main)
