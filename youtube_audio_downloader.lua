-- YouTube Audio Downloader ReaScript
-- Downloads audio from YouTube URL and adds it as a new track in Reaper

-- Configuration
local ENABLE_CONSOLE_LOGGING = false

-- Utility Functions
function is_windows()
    return package.config:sub(1,1) == '\\'
end

function get_path_separator()
    return is_windows() and '\\' or '/'
end

-- Command Execution Functions
function run_command_silent(command)
    if is_windows() then
        return io.popen('cmd /c "' .. command .. '" 2>nul', 'r')
    else
        return io.popen(command .. " 2>/dev/null", 'r')
    end
end

function run_command_with_stderr(command)
    if is_windows() then
        return io.popen('cmd /c "' .. command .. '" 2>&1', 'r')
    else
        return io.popen(command .. " 2>&1", 'r')
    end
end


-- Visible Command Window Execution (Windows only)
function run_command_visible(command)
    if is_windows() then
        local temp_dir = os.getenv("TEMP") or os.getenv("TMP") or "."
        local temp_bat = temp_dir .. "\\yt_dlp_temp_" .. os.time() .. ".bat"
        local temp_result = temp_dir .. "\\yt_dlp_result_" .. os.time() .. ".txt"
        
        local file = io.open(temp_bat, "w")
        if not file then
            return false
        end
        
        file:write('@echo off\n')
        file:write('title yt-dlp Download Progress\n')
        file:write('echo ========================================\n')
        file:write('echo    YouTube Audio Downloader\n')
        file:write('echo ========================================\n')
        file:write('echo.\n')
        file:write('echo Starting download...\n')
        file:write('echo.\n')
        file:write(command .. '\n')
        file:write('set exit_code=%errorlevel%\n')
        file:write('echo %exit_code% > "' .. temp_result .. '"\n')
        file:write('echo.\n')
        file:write('echo ========================================\n')
        file:write('exit /b %exit_code%\n')
        file:close()
        
        local result = os.execute('"' .. temp_bat .. '"')
        os.remove(temp_bat)
        
        -- Read the exit code from the result file
        local exit_code = 1
        local result_file = io.open(temp_result, "r")
        if result_file then
            local code_str = result_file:read("*l")
            if code_str then
                exit_code = tonumber(code_str) or 1
            end
            result_file:close()
            os.remove(temp_result)
        end
        
        return exit_code == 0
    else
        return io.popen(command .. " 2>&1", 'r')
    end
end

-- yt-dlp Validation and Execution
function validate_yt_dlp()
    local yt_dlp_path = find_yt_dlp()
    
    if not yt_dlp_path then
        return false, "yt-dlp not found. Please ensure it's installed and accessible."
    end
    
    local command = yt_dlp_path .. " --version"
    log_info("Validating yt-dlp: " .. command)
    
    local handle = run_command_with_stderr(command)
    if not handle then
        return false, "Could not execute yt-dlp version check"
    end
    
    local output = handle:read("*a")
    local success, exit_type, exit_code = handle:close()
    
    if not success or exit_code ~= 0 then
        return false, "yt-dlp validation failed with exit code: " .. tostring(exit_code) .. "\nOutput: " .. (output or "No output")
    end
    
    local version = output:match("([%d%.]+)")
    if version then
        log_info("yt-dlp version: " .. version)
        return true, "yt-dlp version " .. version .. " is working correctly"
    else
        return false, "Could not determine yt-dlp version"
    end
end

function yt_dlp(args)
    local yt_dlp_path = find_yt_dlp()
    
    if not yt_dlp_path then
        return nil, "yt-dlp not found. Please ensure it's installed and accessible."
    end
    
    local command = yt_dlp_path .. " " .. args
    log_info("Executing yt-dlp: " .. command)
    
    log_info("Opening yt-dlp in visible command window...")
    local success = run_command_visible(command)
    if success then
        log_success("yt-dlp download completed successfully!")
        return "Download completed in visible window", nil
    else
        return nil, "yt-dlp download failed in visible window"
    end
end


-- Logging Functions
function log_msg(msg)
    if ENABLE_CONSOLE_LOGGING then
        local timestamp = os.date("[%Y-%m-%d %H:%M:%S] ")
        reaper.ShowConsoleMsg(timestamp .. msg)
    end
end

function log_error(msg)
    if ENABLE_CONSOLE_LOGGING then
        reaper.ShowConsoleMsg("ERROR: " .. msg .. "\n")
    end
end

function log_warning(msg)
    if ENABLE_CONSOLE_LOGGING then
        reaper.ShowConsoleMsg("WARNING: " .. msg .. "\n")
    end
end

function log_info(msg)
    if ENABLE_CONSOLE_LOGGING then
        reaper.ShowConsoleMsg("INFO: " .. msg .. "\n")
    end
end

function log_success(msg)
    if ENABLE_CONSOLE_LOGGING then
        reaper.ShowConsoleMsg("SUCCESS: " .. msg .. "\n")
    end
end

function clear_console()
    if ENABLE_CONSOLE_LOGGING then
        reaper.ClearConsole()
        reaper.ShowConsoleMsg("=== YouTube Downloader Console ===\n")
        reaper.ShowConsoleMsg("===================================\n")
    end
end

-- Executable Path Finding
function find_executable(name, custom_paths)
    local common_paths = custom_paths or {}
    
    if is_windows() then
        local home = os.getenv("USERPROFILE") or os.getenv("HOME")
        local program_files = os.getenv("PROGRAMFILES") or "C:\\Program Files"
        local program_files_x86 = os.getenv("PROGRAMFILES(X86)") or "C:\\Program Files (x86)"
        
        if name == "yt-dlp" then
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
        elseif name == "ffmpeg" then
            common_paths = {
                home .. "\\scoop\\shims\\ffmpeg.exe",
                "ffmpeg.exe",
                "ffmpeg",
                home .. "\\AppData\\Local\\Programs\\ffmpeg\\bin\\ffmpeg.exe",
                program_files .. "\\ffmpeg\\bin\\ffmpeg.exe",
                program_files_x86 .. "\\ffmpeg\\bin\\ffmpeg.exe",
                "C:\\ffmpeg\\bin\\ffmpeg.exe"
            }
        end
    else
        local home = os.getenv("HOME")
        if name == "yt-dlp" then
            common_paths = {
                "yt-dlp",
                "/usr/local/bin/yt-dlp",
                "/opt/homebrew/bin/yt-dlp",
                "/usr/bin/yt-dlp",
                home .. "/.local/bin/yt-dlp"
            }
        elseif name == "ffmpeg" then
            common_paths = {
                "ffmpeg",
                "/usr/local/bin/ffmpeg",
                "/opt/homebrew/bin/ffmpeg",
                "/usr/bin/ffmpeg"
            }
        end
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
        local where_handle = run_command_silent('where ' .. name)
        if where_handle then
            local where_result = where_handle:read("*a")
            local success, exit_type, exit_code = where_handle:close()
            if success and exit_code == 0 and where_result:match("%S") then
                return where_result:gsub("%s+$", "")
            end
        end
    else
        local which_handle = io.popen("which " .. name .. " 2>/dev/null")
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

function find_yt_dlp()
    return find_executable("yt-dlp")
end

function ffmpeg()
    return find_executable("ffmpeg")
end

-- File and Path Utilities
function sanitize_filename(filename)
    return filename:gsub("[^%w%s%-_%.%(%)]", ""):gsub("%s+", "_")
end

function get_project_directory()
    local project_path = reaper.GetProjectPath("")
    if project_path and project_path ~= "" then
        return project_path
    else
        if is_windows() then
            local home = os.getenv("USERPROFILE") or os.getenv("HOME")
            return home .. "\\Desktop"
        else
            return os.getenv("HOME") .. "/Desktop"
        end
    end
end

function generate_random_string(length)
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    local result = ""
    for i = 1, length do
        local rand = math.random(1, #chars)
        result = result .. chars:sub(rand, rand)
    end
    return result
end

function find_audio_file(directory, suffix)
    if is_windows() then
        local handle = run_command_silent('dir /b /o-d "' .. directory .. '\\*' .. suffix .. '*.wav"')
        if handle then
            local files = handle:read("*a")
            handle:close()
            
            for file in files:gmatch("[^\r\n]+") do
                if file:match(suffix) then
                    return directory .. "\\" .. file
                end
            end
        end
        
        handle = run_command_silent('dir /b /o-d "' .. directory .. '\\*.wav"')
        if handle then
            local all_files = handle:read("*a")
            handle:close()
            if all_files and all_files:match("%S") then
                local first_file = all_files:match("([^\r\n]+)")
                if first_file then
                    return directory .. "\\" .. first_file:gsub("^%s+", ""):gsub("%s+$", "")
                end
            end
        end
    else
        local handle = io.popen('ls -t "' .. directory .. '"/*' .. suffix .. '*.wav 2>/dev/null | head -1')
        if handle then
            local filename = handle:read("*a"):gsub("^%s+", ""):gsub("%s+$", "")
            handle:close()
            if filename and filename ~= "" then
                return filename
            end
        end
        
        handle = io.popen('ls -t "' .. directory .. '"/*.wav 2>/dev/null | head -1')
        if handle then
            local found_file = handle:read("*a")
            handle:close()
            if found_file and found_file:match("%S") then
                return found_file:gsub("^%s+", ""):gsub("%s+$", "")
            end
        end
    end
    
    return nil
end

-- YouTube Download Functions
function download_youtube_audio(url)
    local project_dir = get_project_directory()
    local path_sep = get_path_separator()
    local random_suffix = "_" .. generate_random_string(8)
    local temp_template = project_dir .. path_sep .. "%(title)s_temp" .. random_suffix .. ".%(ext)s"
    local final_template = project_dir .. path_sep .. "%(title)s_final" .. random_suffix .. ".%(ext)s"
    
    log_info("Download directory: " .. project_dir)
    log_info("Using random suffix: " .. random_suffix)
    
    local args = string.format('-x --audio-format wav --audio-quality 0 --no-playlist -v -o "%s"', temp_template)
    
    local ffmpeg_path = ffmpeg()
    if ffmpeg_path then
        local path_sep = get_path_separator()
        local ffmpeg_dir = ffmpeg_path:match("(.+)" .. path_sep .. "[^" .. path_sep .. "]+$")
        args = args .. ' --ffmpeg-location "' .. ffmpeg_dir .. '"'
        log_info("Using ffmpeg from: " .. ffmpeg_path)
    end
    
    args = args .. ' "' .. url .. '"'
    
    log_info("Downloading audio... This may take a moment.")
    reaper.SetExtState("youtube_downloader", "status", "Downloading and converting audio...", false)
    reaper.UpdateArrange()
    
    local output, error_msg = yt_dlp(args)
    if error_msg then
        return nil, error_msg
    end
    
    log_info("Looking for downloaded audio file...")
    
    local filename = find_audio_file(project_dir, random_suffix)
    if filename then
        log_success("Found WAV file with random suffix: " .. filename)
    else
        log_warning("Could not find WAV file with random suffix, looking for any recent WAV file...")
        filename = find_audio_file(project_dir, "")
        if filename then
            log_info("Found most recent WAV file: " .. filename)
        end
    end
    
    if filename then
        filename = filename:gsub("^%s+", ""):gsub("%s+$", "")
        log_info("Final filename to use: " .. filename)
        
        local file_exists = io.open(filename, "r")
        if file_exists then
            file_exists:close()
            log_success("File exists and is accessible: " .. filename)
        else
            log_error("File does not exist or is not accessible: " .. filename)
            
            if is_windows() then
                log_info("Trying PowerShell to get exact filename...")
                local handle = run_command_silent('powershell -Command "Get-ChildItem -Path \'' .. project_dir .. '\' -Filter \'*.wav\' | Where-Object {$_.Name -like \'*' .. random_suffix .. '*\'} | Select-Object -First 1 -ExpandProperty FullName"')
                if handle then
                    local result = handle:read("*a"):gsub("^%s+", ""):gsub("%s+$", "")
                    handle:close()
                    if result and result ~= "" and io.open(result, "r") then
                        log_success("Found file using PowerShell: " .. result)
                        filename = result
                    else
                        return nil, "Could not find any accessible audio file"
                    end
                else
                    return nil, "Could not find any accessible audio file"
                end
            else
                return nil, "Could not find any accessible audio file"
            end
        end
    end
    
    return filename, nil
end

-- Reaper Integration Functions
function add_audio_to_project(audio_file)
    if not audio_file or audio_file == "" then
        return false, "No audio file specified"
    end
    
    log_info("Importing audio file: " .. audio_file)
    
    local file_handle = io.open(audio_file, "r")
    if not file_handle then
        return false, "Audio file not found: " .. audio_file
    end
    file_handle:close()
    
    reaper.InsertTrackAtIndex(reaper.CountTracks(0), false)
    local track = reaper.GetTrack(0, reaper.CountTracks(0) - 1)
    
    if not track then
        return false, "Could not create new track"
    end
    
    local item = reaper.AddMediaItemToTrack(track)
    if not item then
        return false, "Could not create media item"
    end
    
    local take = reaper.AddTakeToMediaItem(item)
    if not take then
        return false, "Could not create take"
    end
    
    local source = reaper.PCM_Source_CreateFromFile(audio_file)
    if not source then
        return false, "Could not create audio source from file"
    end
    
    reaper.SetMediaItemTake_Source(take, source)
    
    local source_length = reaper.GetMediaSourceLength(source, false)
    local num_channels = reaper.GetMediaSourceNumChannels(source)
    local sample_rate = reaper.GetMediaSourceSampleRate(source)
    
    log_info("Audio file info:")
    log_info("  Length: " .. string.format("%.2f", source_length) .. " seconds")
    log_info("  Channels: " .. num_channels)
    log_info("  Sample Rate: " .. sample_rate .. " Hz")
    
    if source_length <= 0 then
        return false, "Audio file appears to be empty or corrupted (length: " .. source_length .. ")"
    end
    
    reaper.SetMediaItemLength(item, source_length, false)
    
    local path_sep = get_path_separator()
    local filename_only = audio_file:match("([^" .. path_sep .. "]+)$") or audio_file
    local track_name = filename_only:gsub("%.wav$", "")
    
    reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", track_name, true)
    reaper.GetSetMediaTrackInfo_String(track, "P_NAME", track_name, true)
    
    reaper.SetMediaItemPosition(item, 0, false)
    
    reaper.PCM_Source_BuildPeaks(source, 0)
    
    reaper.UpdateArrange()
    reaper.TrackList_AdjustWindows(false)
    reaper.Main_OnCommand(40047, 0)
    
    return true, "Audio added successfully to new track"
end

-- Main Application Entry Point
function main()
    clear_console()

    local retval, url = reaper.GetUserInputs("YouTube Audio Downloader", 1, "YouTube URL:,extrawidth=200", "")
    
    if not retval or not url or url == "" then
        log_info("Download cancelled or no URL provided")
        return
    end
    
    log_info("Starting download for: " .. url)
    reaper.SetExtState("youtube_downloader", "status", "Downloading audio from YouTube...", false)
    reaper.UpdateArrange()
    
    local audio_file, error_msg = download_youtube_audio(url)
    
    if error_msg then
        reaper.SetExtState("youtube_downloader", "status", "Download failed", false)
        log_error("Download failed: " .. error_msg)
        reaper.ShowMessageBox("Download failed: " .. error_msg, "Error", 0)
        return
    end
    
    if not audio_file then
        reaper.SetExtState("youtube_downloader", "status", "Download failed", false)
        log_error("Could not determine downloaded file location")
        reaper.ShowMessageBox("Could not determine downloaded file location", "Error", 0)
        return
    end
    
    log_success("Downloaded to: " .. audio_file)
    reaper.SetExtState("youtube_downloader", "status", "Adding audio to project...", false)
    reaper.UpdateArrange()
    
    local success, result_msg = add_audio_to_project(audio_file)
    
    if success then
        reaper.SetExtState("youtube_downloader", "status", "Download complete!", false)
        log_success(result_msg)
        log_success("=== Download completed successfully ===")
    else
        reaper.SetExtState("youtube_downloader", "status", "Import failed", false)
        log_error("Failed to add audio: " .. result_msg)
        reaper.ShowMessageBox("Failed to add audio to project: " .. result_msg, "Error", 0)
        log_error("=== Download failed ===")
    end
end

reaper.defer(main)
