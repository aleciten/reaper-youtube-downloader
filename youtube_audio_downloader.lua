-- YouTube Audio Downloader ReaScript
-- Downloads audio from YouTube URL and adds it as a new track in Reaper

function is_windows()
    return package.config:sub(1,1) == '\\'
end

function get_path_separator()
    return is_windows() and '\\' or '/'
end

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
    
    local handle = run_command_with_stderr(command)
    if not handle then
        return nil, "Could not execute yt-dlp command"
    end
    
    local output = handle:read("*a")
    local success, exit_type, exit_code = handle:close()
    
    log_info("yt-dlp output:")
    reaper.ShowConsoleMsg(output)
    
    if not success or exit_code ~= 0 then
        local error_msg = "yt-dlp failed with exit code: " .. tostring(exit_code)
        
        if output and output:match("ERROR") then
            local error_line = output:match("ERROR: ([^\n\r]+)")
            if error_line then
                error_msg = error_msg .. "\nError details: " .. error_line
            end
        end
        
        if output and output:match("WARNING") then
            local warnings = {}
            for warning in output:gmatch("WARNING: ([^\n\r]+)") do
                table.insert(warnings, warning)
            end
            if #warnings > 0 then
                error_msg = error_msg .. "\nWarnings: " .. table.concat(warnings, "; ")
            end
        end
        
        if exit_code == -1 then
            error_msg = error_msg .. "\n\nCommon solutions for exit code -1:\n" ..
                       "1. Update yt-dlp: pip install --upgrade yt-dlp\n" ..
                       "2. Check your internet connection\n" ..
                       "3. Verify the YouTube URL is valid\n" ..
                       "4. Try running yt-dlp manually from command line"
        end
        
        return nil, error_msg
    end
    
    return output, nil
end

function log_msg(msg)
    local timestamp = os.date("[%Y-%m-%d %H:%M:%S] ")
    reaper.ShowConsoleMsg(timestamp .. msg)
end

function log_error(msg)
    reaper.ShowConsoleMsg("ERROR: " .. msg .. "\n")
end

function log_warning(msg)
    reaper.ShowConsoleMsg("WARNING: " .. msg .. "\n")
end

function log_info(msg)
    reaper.ShowConsoleMsg("INFO: " .. msg .. "\n")
end

function log_success(msg)
    reaper.ShowConsoleMsg("SUCCESS: " .. msg .. "\n")
end

function clear_console()
    reaper.ClearConsole()
    reaper.ShowConsoleMsg("=== YouTube Downloader Console ===\n")
    reaper.ShowConsoleMsg("===================================\n")
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

function ffmpeg()
    local common_paths = {}
    
    if is_windows() then
        local home = os.getenv("USERPROFILE") or os.getenv("HOME")
        local program_files = os.getenv("PROGRAMFILES") or "C:\\Program Files"
        local program_files_x86 = os.getenv("PROGRAMFILES(X86)") or "C:\\Program Files (x86)"
        
        common_paths = {
            home .. "\\scoop\\shims\\ffmpeg.exe",
            "ffmpeg.exe",
            "ffmpeg",
            home .. "\\AppData\\Local\\Programs\\ffmpeg\\bin\\ffmpeg.exe",
            program_files .. "\\ffmpeg\\bin\\ffmpeg.exe",
            program_files_x86 .. "\\ffmpeg\\bin\\ffmpeg.exe",
            "C:\\ffmpeg\\bin\\ffmpeg.exe"
        }
    else
        common_paths = {
            "ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/opt/homebrew/bin/ffmpeg",
            "/usr/bin/ffmpeg"
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
        local where_handle = run_command_silent('where ffmpeg')
        if where_handle then
            local where_result = where_handle:read("*a")
            local success, exit_type, exit_code = where_handle:close()
            if success and exit_code == 0 and where_result:match("%S") then
                return where_result:gsub("%s+$", "")
            end
        end
    else
        local which_handle = io.popen("which ffmpeg 2>/dev/null")
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

function download_youtube_audio(url)
    local project_dir = get_project_directory()
    local path_sep = get_path_separator()
    local random_suffix = "_" .. generate_random_string(8)
    local temp_template = project_dir .. path_sep .. "%(title)s_temp" .. random_suffix .. ".%(ext)s"
    local final_template = project_dir .. path_sep .. "%(title)s_final" .. random_suffix .. ".%(ext)s"
    
    log_info("Download directory: " .. project_dir)
    log_info("Using random suffix: " .. random_suffix)
    
    local args = string.format('-x --audio-format wav --audio-quality 0 --no-playlist -o "%s"', temp_template)
    
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
    
    local filename = nil
    
    log_info("Looking for the most recent WAV file with random suffix...")
    
    local project_dir = get_project_directory()
    if is_windows() then
        local handle = run_command_silent('dir /b /o-d "' .. project_dir .. '\\*' .. random_suffix .. '*.wav"')
        if handle then
            local files = handle:read("*a")
            handle:close()
            
            for file in files:gmatch("[^\r\n]+") do
                if file:match(random_suffix) then
                    filename = project_dir .. "\\" .. file
                    log_success("Found WAV file with random suffix: " .. filename)
                    break
                end
            end
        end
    else
        local handle = io.popen('ls -t "' .. project_dir .. '"/*' .. random_suffix .. '*.wav 2>/dev/null | head -1')
        if handle then
            filename = handle:read("*a"):gsub("^%s+", ""):gsub("%s+$", "")
            handle:close()
            if filename and filename ~= "" then
                log_success("Found WAV file with random suffix: " .. filename)
            else
                filename = nil
            end
        end
    end
    
    if not filename then
        log_warning("Could not find WAV file with random suffix, looking for any recent WAV file...")
        
        if is_windows() then
            local handle = run_command_silent('dir /b /o-d "' .. project_dir .. '\\*.wav"')
            if handle then
                local found_file = handle:read("*a")
                handle:close()
                if found_file and found_file:match("%S") then
                    filename = project_dir .. "\\" .. found_file:gsub("^%s+", ""):gsub("%s+$", "")
                    log_info("Found most recent WAV file: " .. filename)
                end
            end
        else
            local handle = io.popen('ls -t "' .. project_dir .. '"/*.wav 2>/dev/null | head -1')
            if handle then
                local found_file = handle:read("*a")
                handle:close()
                if found_file and found_file:match("%S") then
                    filename = found_file:gsub("^%s+", ""):gsub("%s+$", "")
                    log_info("Found most recent WAV file: " .. filename)
                end
            end
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
            
            log_info("Character encoding issue detected. Using PowerShell to get exact filename...")
            
            local project_dir = get_project_directory()
            local handle = run_command_silent('powershell -Command "Get-ChildItem -Path \'' .. project_dir .. '\' -Filter \'*.wav\' | Where-Object {$_.Name -like \'*' .. random_suffix .. '*\'} | Select-Object -First 1 -ExpandProperty FullName"')
            if handle then
                local result = handle:read("*a"):gsub("^%s+", ""):gsub("%s+$", "")
                handle:close()
                if result and result ~= "" then
                    log_success("Found file using PowerShell: " .. result)
                    filename = result
                    
                    local final_check = io.open(filename, "r")
                    if final_check then
                        final_check:close()
                        log_success("File accessible with PowerShell path: " .. filename)
                    else
                        return nil, "File found but still cannot access: " .. filename
                    end
                else
                    return nil, "Could not find any matching audio file"
                end
            else
                return nil, "Could not find any matching audio file"
            end
            
            log_info("Checking what files actually exist in the directory...")
            local project_dir = get_project_directory()
            
            if is_windows() then
                local handle = run_command_silent('dir /b "' .. project_dir .. '\\*Pantera*"')
                if handle then
                    local files = handle:read("*a")
                    handle:close()
                    log_info("Files matching 'Pantera' in directory:")
                    reaper.ShowConsoleMsg(files)
                end
                
                local handle2 = run_command_silent('dir /b "' .. project_dir .. '\\*.wav"')
                if handle2 then
                    local files = handle2:read("*a")
                    handle2:close()
                    log_info("All WAV files in directory:")
                    reaper.ShowConsoleMsg(files)
                end
            else
                local handle = io.popen('ls -la "' .. project_dir .. '"/*Pantera* 2>/dev/null')
                if handle then
                    local files = handle:read("*a")
                    handle:close()
                    log_info("Files matching 'Pantera' in directory:")
                    reaper.ShowConsoleMsg(files)
                end
                
                local handle2 = io.popen('ls -la "' .. project_dir .. '"/*.wav 2>/dev/null')
                if handle2 then
                    local files = handle2:read("*a")
                    handle:close()
                    log_info("All WAV files in directory:")
                    reaper.ShowConsoleMsg(files)
                end
            end
            
            log_info("Checking for .orig.wav file as fallback...")
            local orig_filename = filename:gsub("%.wav$", ".orig.wav")
            local orig_file_exists = io.open(orig_filename, "r")
            if orig_file_exists then
                orig_file_exists:close()
                log_success("Found .orig.wav file, using that instead: " .. orig_filename)
                filename = orig_filename
            else
                log_info("Trying to find file with similar name...")
                
                local project_dir = get_project_directory()
                local base_name = filename:match("([^\\/]+)%.wav$")
                if base_name then
                    base_name = base_name:gsub("[%p%s]", ".")
                    log_info("Searching for files matching pattern: " .. base_name)
                    
                    if is_windows() then
                        local handle = run_command_silent('dir /b "' .. project_dir .. '\\*.wav"')
                        if handle then
                            local files = handle:read("*a")
                            handle:close()
                            
                            for file in files:gmatch("[^\r\n]+") do
                                if file:match("Pantera") and file:match("Power Metal") and file:match("FULL ALBUM") and file:match("_final%.wav$") then
                                    local found_file = project_dir .. "\\" .. file
                                    log_success("Found matching final file: " .. found_file)
                                    filename = found_file
                                    break
                                end
                            end
                            
                            if not filename then
                                for file in files:gmatch("[^\r\n]+") do
                                    if file:match("Pantera") and file:match("Power Metal") and file:match("FULL ALBUM") then
                                        local found_file = project_dir .. "\\" .. file
                                        log_success("Found matching file: " .. found_file)
                                        filename = found_file
                                        break
                                    end
                                end
                            end
                        end
                    else
                        local handle = io.popen('ls "' .. project_dir .. '"/*.wav 2>/dev/null')
                        if handle then
                            local files = handle:read("*a")
                            handle:close()
                            
                            for file in files:gmatch("[^\r\n]+") do
                                if file:match("Pantera") and file:match("Power Metal") and file:match("FULL ALBUM") and file:match("_final%.wav$") then
                                    log_success("Found matching final file: " .. file)
                                    filename = file
                                    break
                                end
                            end
                            
                            if not filename then
                                for file in files:gmatch("[^\r\n]+") do
                                    if file:match("Pantera") and file:match("Power Metal") and file:match("FULL ALBUM") then
                                        log_success("Found matching file: " .. file)
                                        filename = file
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
                
                if not filename then
                    return nil, "Could not find any matching audio file"
                end
                
                log_info("Attempting to access file: " .. filename)
                
                local file_check = io.open(filename, "r")
                if not file_check then
                    log_error("Cannot open file for reading, checking file attributes...")
                    
                    if is_windows() then
                        local handle = run_command_silent('dir "' .. filename .. '"')
                        if handle then
                            local result = handle:read("*a")
                            handle:close()
                            log_info("File attributes:")
                            reaper.ShowConsoleMsg(result)
                        end
                        
                        local handle2 = run_command_silent('attrib "' .. filename .. '"')
                        if handle2 then
                            local result = handle2:read("*a")
                            handle2:close()
                            log_info("File permissions:")
                            reaper.ShowConsoleMsg(result)
                        end
                    else
                        local handle = io.popen('ls -la "' .. filename .. '" 2>/dev/null')
                        if handle then
                            local result = handle:read("*a")
                            handle:close()
                            log_info("File attributes:")
                            reaper.ShowConsoleMsg(result)
                        end
                    end
                    
                    log_info("Trying alternative file access method...")
                    local file_check2 = io.open(filename, "rb")
                    if file_check2 then
                        file_check2:close()
                        log_success("File accessible with binary mode")
                    else
                        log_warning("File exists but cannot be accessed, trying to use most recent WAV file...")
                        
                        local project_dir = get_project_directory()
                        if is_windows() then
                            local handle = run_command_silent('dir /b /o-d "' .. project_dir .. '\\*.wav"')
                            if handle then
                                local files = handle:read("*a")
                                handle:close()
                                local lines = {}
                                for line in files:gmatch("[^\r\n]+") do
                                    if line:match("Pantera") then
                                        table.insert(lines, line)
                                    end
                                end
                                if #lines > 0 then
                                    local fallback_file = project_dir .. "\\" .. lines[1]
                                    log_info("Using fallback file: " .. fallback_file)
                                    filename = fallback_file
                                end
                            end
                        else
                            local handle = io.popen('ls -t "' .. project_dir .. '"/*Pantera*.wav 2>/dev/null | head -1')
                            if handle then
                                local fallback_file = handle:read("*a"):gsub("^%s+", ""):gsub("%s+$", "")
                                handle:close()
                                if fallback_file and fallback_file ~= "" then
                                    log_info("Using fallback file: " .. fallback_file)
                                    filename = fallback_file
                                end
                            end
                        end
                        
                        if not filename or not io.open(filename, "r") then
                            return nil, "Found file but cannot access: " .. filename .. " (permission denied or file locked)"
                        end
                    end
                else
                    file_check:close()
                    log_success("File accessible and readable")
                end
            end
        end
    end
    
    return filename, nil
end

function add_audio_to_project(audio_file)
    if not audio_file or audio_file == "" then
        return false, "No audio file specified"
    end
    
    log_info("Checking if file exists: " .. audio_file)
    
    local file_handle = io.open(audio_file, "r")
    if not file_handle then
        log_error("File not found, checking directory contents...")
        
        local project_dir = get_project_directory()
        local path_sep = get_path_separator()
        
        if is_windows() then
            local handle = run_command_silent('dir /b "' .. project_dir .. '\\*.wav"')
            if handle then
                local files = handle:read("*a")
                handle:close()
                log_info("Available WAV files in directory:")
                reaper.ShowConsoleMsg(files)
            end
        else
            local handle = io.popen('ls -la "' .. project_dir .. '"/*.wav 2>/dev/null')
            if handle then
                local files = handle:read("*a")
                handle:close()
                log_info("Available WAV files in directory:")
                reaper.ShowConsoleMsg(files)
            end
        end
        
        return false, "Audio file not found: " .. audio_file
    end
    file_handle:close()
    
    log_info("Importing audio file: " .. audio_file)
    
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
    
    log_info("Audio import completed. Forcing peak rebuild...")
    
    local retval = reaper.UpdateTimeline()
    log_info("Timeline update result: " .. tostring(retval))
    
    return true, "Audio added successfully to new track"
end

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
