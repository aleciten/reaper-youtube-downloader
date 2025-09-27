-- yt-dlp Version Check ReaScript
-- This script calls yt-dlp --version and displays the result

function is_windows()
    return package.config:sub(1,1) == '\\'
end

function run_command_silent(command)
    if is_windows() then
        return io.popen('cmd /c "' .. command .. '" 2>nul', 'r')
    else
        return io.popen(command .. " 2>/dev/null", 'r')
    end
end

function yt_dlp(args)
    local yt_dlp_path = find_yt_dlp()
    
    if not yt_dlp_path then
        return nil, "yt-dlp not found. Please ensure it's installed and accessible."
    end
    
    local command = yt_dlp_path .. " " .. args
    reaper.ShowConsoleMsg("Executing yt-dlp: " .. command .. "\n")
    
    local handle = run_command_silent(command)
    if not handle then
        return nil, "Could not execute yt-dlp command"
    end
    
    local output = handle:read("*a")
    local success, exit_type, exit_code = handle:close()
    
    if not success or exit_code ~= 0 then
        return nil, "yt-dlp failed with exit code: " .. tostring(exit_code)
    end
    
    return output, nil
end

function find_yt_dlp()
    local common_paths = {}
    
    if is_windows() then
        local home = os.getenv("USERPROFILE") or os.getenv("HOME")
        local program_files = os.getenv("PROGRAMFILES") or "C:\\Program Files"
        local program_files_x86 = os.getenv("PROGRAMFILES(X86)") or "C:\\Program Files (x86)"
        
        common_paths = {
            home .. "\\scoop\\shims\\yt-dlp.exe",
            "yt-dlp.exe",
            "yt-dlp",
            home .. "\\AppData\\Local\\Programs\\Python\\Python*\\Scripts\\yt-dlp.exe",
            home .. "\\AppData\\Local\\Programs\\Python\\Scripts\\yt-dlp.exe",
            program_files .. "\\yt-dlp\\yt-dlp.exe",
            program_files_x86 .. "\\yt-dlp\\yt-dlp.exe",
            "C:\\yt-dlp\\yt-dlp.exe",
            "C:\\Python*\\Scripts\\yt-dlp.exe"
        }
    else
        local home = os.getenv("HOME")
        common_paths = {
            "yt-dlp",
            "/usr/local/bin/yt-dlp",
            "/opt/homebrew/bin/yt-dlp",
            "/usr/bin/yt-dlp",
            home .. "/.local/bin/yt-dlp"
        }
    end
    
    for _, path in ipairs(common_paths) do
        if is_windows() then
            local file = io.open(path, "r")
            if file then
                file:close()
                return path
            end
            
            local handle = run_command_silent('where "' .. path .. '"')
            if handle then
                local result = handle:read("*a")
                local success, exit_type, exit_code = handle:close()
                if success and exit_code == 0 and result:match("%S") then
                    return result:gsub("%s+$", "")
                end
            end
        else
            local handle = io.popen("command -v " .. path .. " 2>/dev/null")
            if handle then
                local result = handle:read("*a")
                local success, exit_type, exit_code = handle:close()
                if success and exit_code == 0 and result:match("%S") then
                    return result:gsub("%s+$", "")
                end
            end
        end
    end
    
    if is_windows() then
        local where_handle = run_command_silent('where yt-dlp')
        if where_handle then
            local where_result = where_handle:read("*a")
            local success, exit_type, exit_code = where_handle:close()
            if success and exit_code == 0 and where_result:match("%S") then
                return where_result:gsub("%s+$", "")
            end
        end
    else
        local which_handle = io.popen("which yt-dlp 2>/dev/null")
        if which_handle then
            local which_result = which_handle:read("*a")
            local success, exit_type, exit_code = which_handle:close()
            if success and exit_code == 0 and which_result:match("%S") then
                return which_result:gsub("%s+$", "")
            end
        end
    end
    
    return nil
end

function main()
    reaper.ShowConsoleMsg("Checking yt-dlp version...\n")
    
    local result, error_msg = yt_dlp("--version")
    
    if error_msg then
        reaper.ShowConsoleMsg("Error: " .. error_msg .. "\n")
        reaper.ShowConsoleMsg("Tried:\n")
        reaper.ShowConsoleMsg("  - System PATH\n")
        if is_windows() then
            local home = os.getenv("USERPROFILE") or os.getenv("HOME")
            local program_files = os.getenv("PROGRAMFILES") or "C:\\Program Files"
            local program_files_x86 = os.getenv("PROGRAMFILES(X86)") or "C:\\Program Files (x86)"
            reaper.ShowConsoleMsg("  - " .. home .. "\\scoop\\shims\\yt-dlp.exe\n")
            reaper.ShowConsoleMsg("  - " .. home .. "\\AppData\\Local\\Programs\\Python\\Scripts\\yt-dlp.exe\n")
            reaper.ShowConsoleMsg("  - " .. program_files .. "\\yt-dlp\\yt-dlp.exe\n")
            reaper.ShowConsoleMsg("  - " .. program_files_x86 .. "\\yt-dlp\\yt-dlp.exe\n")
            reaper.ShowConsoleMsg("  - C:\\yt-dlp\\yt-dlp.exe\n")
        else
            reaper.ShowConsoleMsg("  - /usr/local/bin/yt-dlp\n")
            reaper.ShowConsoleMsg("  - /opt/homebrew/bin/yt-dlp\n")
            reaper.ShowConsoleMsg("  - /usr/bin/yt-dlp\n")
            reaper.ShowConsoleMsg("  - ~/.local/bin/yt-dlp\n")
        end
        reaper.ShowConsoleMsg("\nPlease ensure yt-dlp is installed and accessible\n")
        return
    end
    
    reaper.ShowConsoleMsg("Command executed successfully!\n")
    reaper.ShowConsoleMsg("yt-dlp version: " .. result)
end

reaper.defer(main)
