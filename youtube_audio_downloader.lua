-- YouTube Audio Downloader ReaScript
-- Downloads audio from YouTube URL and adds it as a new track in Reaper

function log_msg(msg)
    local log_file = reaper.GetResourcePath() .. "/youtube_downloader.log"
    local file = io.open(log_file, "a")
    if file then
        file:write(os.date("[%Y-%m-%d %H:%M:%S] ") .. msg)
        file:close()
    end
end

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

function find_ffmpeg()
    local common_paths = {
        "ffmpeg",
        "/usr/local/bin/ffmpeg",
        "/opt/homebrew/bin/ffmpeg",
        "/usr/bin/ffmpeg"
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
    
    local which_handle = io.popen("which ffmpeg 2>/dev/null")
    if which_handle then
        local which_result = which_handle:read("*a")
        local success, exit_type, exit_code = which_handle:close()
        if success and exit_code == 0 and which_result:match("%S") then
            return which_result:gsub("%s+$", "")
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
        return os.getenv("HOME") .. "/Desktop"
    end
end

function download_youtube_audio(url, yt_dlp_path, ffmpeg_path)
    local project_dir = get_project_directory()
    local output_template = project_dir .. "/%(title)s.%(ext)s"
    
    log_msg("Download directory: " .. project_dir .. "\n")
    
    local command = string.format('%s -x --audio-format wav --audio-quality 0 -o "%s"', 
                                  yt_dlp_path, output_template)
    
    if ffmpeg_path then
        local ffmpeg_dir = ffmpeg_path:match("(.+)/[^/]+$")
        command = command .. ' --ffmpeg-location "' .. ffmpeg_dir .. '"'
        log_msg("Using ffmpeg from: " .. ffmpeg_path .. "\n")
    end
    
    command = command .. ' "' .. url .. '"'
    
    log_msg("Executing: " .. command .. "\n")
    log_msg("Downloading audio... This may take a moment.\n")
    reaper.SetExtState("youtube_downloader", "status", "Downloading and converting audio...", false)
    reaper.UpdateArrange()
    
    local handle = io.popen(command .. " 2>&1")
    if not handle then
        return nil, "Could not execute yt-dlp command"
    end
    
    local output = handle:read("*a")
    local success, exit_type, exit_code = handle:close()
    
    log_msg("yt-dlp output:\n" .. output .. "\n")
    
    if not success or exit_code ~= 0 then
        return nil, "Download failed with exit code: " .. tostring(exit_code)
    end
    
    local filename = nil
    
    filename = output:match("%[ExtractAudio%] Destination: ([^\n\r]+%.wav)")
    
    if not filename then
        filename = output:match("%[download%] Destination: ([^\n\r]+%.wav)")
    end
    
    if not filename then
        filename = output:match("%[download%] ([^\n\r]+%.wav) has already been downloaded")
    end
    
    if not filename then
        local lines = {}
        for line in output:gmatch("[^\r\n]+") do
            table.insert(lines, line)
        end
        
        for i = #lines, 1, -1 do
            local line = lines[i]
            if line:match("%.wav") and not line:match("%[") then
                filename = line:match("([^\n\r]+%.wav)")
                if filename then
                    break
                end
            end
        end
    end
    
    if not filename then
        local title_match = output:match("%[info%] [^:]+: (.+)")
        if title_match then
            local sanitized_title = sanitize_filename(title_match)
            filename = project_dir .. "/" .. sanitized_title .. ".wav"
        end
    end
    
    if filename then
        filename = filename:gsub("^%s+", ""):gsub("%s+$", "")
        log_msg("Parsed filename: " .. filename .. "\n")
    else
        log_msg("Could not parse filename from output, searching directory...\n")
        
        local handle = io.popen('find "' .. project_dir .. '" -name "*.wav" -newer /tmp -type f 2>/dev/null | head -1')
        if handle then
            local found_file = handle:read("*a")
            handle:close()
            if found_file and found_file:match("%S") then
                filename = found_file:gsub("^%s+", ""):gsub("%s+$", "")
                log_msg("Found recent WAV file: " .. filename .. "\n")
            end
        end
        
        if not filename then
            local handle2 = io.popen('ls -t "' .. project_dir .. '"/*.wav 2>/dev/null | head -1')
            if handle2 then
                local found_file = handle2:read("*a")
                handle2:close()
                if found_file and found_file:match("%S") then
                    filename = found_file:gsub("^%s+", ""):gsub("%s+$", "")
                    log_msg("Found most recent WAV file: " .. filename .. "\n")
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
    
    local file_handle = io.open(audio_file, "r")
    if not file_handle then
        return false, "Audio file not found: " .. audio_file
    end
    file_handle:close()
    
    log_msg("Importing audio file: " .. audio_file .. "\n")
    
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
    
    log_msg("Audio file info:\n")
    log_msg("  Length: " .. string.format("%.2f", source_length) .. " seconds\n")
    log_msg("  Channels: " .. num_channels .. "\n")
    log_msg("  Sample Rate: " .. sample_rate .. " Hz\n")
    
    if source_length <= 0 then
        return false, "Audio file appears to be empty or corrupted (length: " .. source_length .. ")"
    end
    
    reaper.SetMediaItemLength(item, source_length, false)
    
    local filename_only = audio_file:match("([^/\\]+)$") or audio_file
    local track_name = filename_only:gsub("%.wav$", "")
    
    reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", track_name, true)
    reaper.GetSetMediaTrackInfo_String(track, "P_NAME", track_name, true)
    
    reaper.SetMediaItemPosition(item, 0, false)
    
    reaper.PCM_Source_BuildPeaks(source, 0)
    
    reaper.UpdateArrange()
    reaper.TrackList_AdjustWindows(false)
    
    reaper.Main_OnCommand(40047, 0)
    
    log_msg("Audio import completed. Forcing peak rebuild...\n")
    
    local retval = reaper.UpdateTimeline()
    log_msg("Timeline update result: " .. tostring(retval) .. "\n")
    
    return true, "Audio added successfully to new track"
end

function main()
    local yt_dlp_path = find_yt_dlp()
    
    if not yt_dlp_path then
        reaper.ShowMessageBox("yt-dlp not found. Please ensure it's installed and accessible.", "Error", 0)
        return
    end
    
    log_msg("Found yt-dlp at: " .. yt_dlp_path .. "\n")
    
    local ffmpeg_path = find_ffmpeg()
    if ffmpeg_path then
        log_msg("Found ffmpeg at: " .. ffmpeg_path .. "\n")
    else
        log_msg("Warning: ffmpeg not found - may cause issues with some audio formats\n")
    end
    
    local retval, url = reaper.GetUserInputs("YouTube Audio Downloader", 1, "YouTube URL:,extrawidth=200", "")
    
    if not retval or not url or url == "" then
        log_msg("Download cancelled or no URL provided\n")
        return
    end
    
    log_msg("Starting download for: " .. url .. "\n")
    reaper.SetExtState("youtube_downloader", "status", "Downloading audio from YouTube...", false)
    reaper.UpdateArrange()
    
    local audio_file, error_msg = download_youtube_audio(url, yt_dlp_path, ffmpeg_path)
    
    if error_msg then
        reaper.SetExtState("youtube_downloader", "status", "Download failed", false)
        reaper.ShowMessageBox("Download failed: " .. error_msg, "Error", 0)
        log_msg("Download failed: " .. error_msg .. "\n")
        return
    end
    
    if not audio_file then
        reaper.SetExtState("youtube_downloader", "status", "Download failed", false)
        reaper.ShowMessageBox("Could not determine downloaded file location", "Error", 0)
        return
    end
    
    log_msg("Downloaded to: " .. audio_file .. "\n")
    reaper.SetExtState("youtube_downloader", "status", "Adding audio to project...", false)
    reaper.UpdateArrange()
    
    local success, result_msg = add_audio_to_project(audio_file)
    
    if success then
        reaper.SetExtState("youtube_downloader", "status", "Download complete!", false)
        log_msg(result_msg .. "\n")
    else
        reaper.SetExtState("youtube_downloader", "status", "Import failed", false)
        reaper.ShowMessageBox("Failed to add audio to project: " .. result_msg, "Error", 0)
        log_msg("Failed to add audio: " .. result_msg .. "\n")
    end
end

reaper.defer(main)
