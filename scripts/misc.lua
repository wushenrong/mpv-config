
--[[

https://github.com/stax76/mpv-scripts

This script consist of various small unrelated features.

Not used code sections can be removed.

Bindings must be added manually to input.conf.



Show media info on screen
-------------------------
Prints detailed media info on the screen.

Depends on the CLI tool mediainfo:
https://mediaarea.net/en/MediaInfo/Download
On Ubuntu: sudo apt install mediainfo

In input.conf add:
i script-message-to misc print-media-info

]]--

----- string

function is_empty(input)
    if input == nil or input == "" then
        return true
    end
end

function contains(input, find)
    if not is_empty(input) and not is_empty(find) then
        return input:find(find, 1, true)
    end
end

----- file

function file_exists(path)
    if is_empty(path) then return false end
    local file = io.open(path, "r")

    if file ~= nil then
        io.close(file)
        return true
    end
end

function file_write(path, content)
    local file = assert(io.open(path, "w"))
    file:write(content)
    file:close()
end

----- shared

local is_windows = package.config:sub(1,1) == "\\"
local msg = require "mp.msg"
local utils = require "mp.utils"

function get_temp_dir()
    if is_windows then
        return os.getenv("TEMP") .. "\\"
    else
        return "/tmp/"
    end
end

----- Print media info on screen

local media_info_cache = {}

function show_text(text, duration, font_size)
    if text ~= "" and text ~= nil then
        mp.command('show-text "${osd-ass-cc/0}{\\\\fs' .. font_size ..
            '}${osd-ass-cc/1}' .. text .. '" ' .. duration)
    end
end

function get_media_info()
    local path = mp.get_property("path")

    if media_info_cache[path] then
        return media_info_cache[path]
    end

    local media_info_format = [[General;N: %FileNameExtension%\\nG: %Format%, %FileSize/String%, %Duration/String%, %OverallBitRate/String%, %Recorded_Date%\\n
Video;V: %Format%, %Format_Profile%, %Width%x%Height%, %BitRate/String%, %FrameRate% FPS\\n
Audio;A: %Language/String%, %Format%, %Format_Profile%, %BitRate/String%, %Channel(s)% ch, %SamplingRate/String%, %Title%\\n
Text;S: %Language/String%, %Format%, %Format_Profile%, %Title%\\n]]

    local format_file = get_temp_dir() .. "media-info-format-2.txt"

    if not file_exists(format_file) then
        file_write(format_file, media_info_format)
    end

    if contains(path, "://") or not file_exists(path) then
        return
    end

    local proc_result = mp.command_native({
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        args = {"mediainfo", "--inform=file://" .. format_file, path},
    })

    if proc_result.status == 0 then
        local output = proc_result.stdout

        output = string.gsub(output, ", , ,", ",")
        output = string.gsub(output, ", ,", ",")
        output = string.gsub(output, ": , ", ": ")
        output = string.gsub(output, ", \\n\r*\n", "\\n")
        output = string.gsub(output, "\\n\r*\n", "\\n")
        output = string.gsub(output, ", \\n", "\\n")
        output = string.gsub(output, "%.000 FPS", " FPS")
        output = string.gsub(output, "MPEG Audio, Layer 3", "MP3")

        media_info_cache[path] = output

        return output
    else
        mp.osd_message("mediainfo failed to run")
    end
end

mp.register_script_message("print-media-info", function ()
    show_text(get_media_info(), 5000, 16)
end)
