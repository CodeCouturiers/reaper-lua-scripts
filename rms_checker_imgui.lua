local reaper = reaper
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.9.2'

-- ReaImGui settings
local ImGui_ConfigFlags_AlwaysAutoResize = 0x00000020
local ctx = ImGui.CreateContext("Realtime RMS/Peak Levels Monitor", ImGui_ConfigFlags_AlwaysAutoResize)
local meterLength = 30 -- Length of the meter
local isRunning = false -- Controls whether the monitoring is active
local isPaused = false -- Controls whether monitoring is paused
local logData = {} -- Store peak and RMS logs for display

-- Function to format seconds into HH:MM:SS
local function formatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", hours, minutes, secs)
end

-- Function to calculate RMS and peak values
local function getTrackRMSAndPeak(track)
    local peakL = reaper.Track_GetPeakInfo(track, 0) or 0
    local peakR = reaper.Track_GetPeakInfo(track, 1) or 0
    local rmsL = reaper.Track_GetPeakInfo(track, 2) or 0
    local rmsR = reaper.Track_GetPeakInfo(track, 3) or 0

    local rmsAvg = (rmsL + rmsR) / 2
    local peakAvg = math.max(peakL, peakR)
    local rmsDB = 20 * math.log(rmsAvg > 0 and rmsAvg or 1e-7, 10)
    local peakDB = 20 * math.log(peakAvg > 0 and peakAvg or 1e-7, 10)
    local crestFactor = peakDB - rmsDB

    return rmsDB, peakDB, crestFactor
end

-- Function to create meters
local function createMeter(peakDB)
    local level = math.floor(((peakDB + 60) / 60) * meterLength)
    level = math.max(0, math.min(level, meterLength))
    return string.rep("=", level) .. string.rep("-", meterLength - level)
end

-- Function to log data
local function logTrackData()
    logData = {} -- Clear previous logs if not paused
    local numTracks = reaper.CountTracks(0)
    for i = 0, numTracks - 1 do
        local track = reaper.GetTrack(0, i)
        local _, trackName = reaper.GetTrackName(track)
        local trackNumber = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
        local rmsDB, peakDB, crestFactor = getTrackRMSAndPeak(track)
        local meter = createMeter(peakDB)

        -- Warnings
        local warning = ""
        if rmsDB > -18 then warning = warning .. " [HOT RMS]" end
        if peakDB > -6 then warning = warning .. " [HOT PEAK]" end

        -- Save to log
        table.insert(logData, {
            trackNumber = trackNumber,
            trackName = trackName,
            rmsDB = rmsDB,
            peakDB = peakDB,
            crestFactor = crestFactor,
            meter = meter,
            warning = warning
        })
    end
end

-- Main script function
local function main()
    -- Variable to track if the window is open
    local isOpen = true

    ImGui.SetNextWindowSize(ctx, 600, 600, ImGui.Cond_FirstUseEver)
    isOpen, _ = ImGui.Begin(ctx, "RMS Levels Monitor", true)
    if isOpen then
        -- Buttons
        if ImGui.Button(ctx, "Start") then
            isRunning = true
            isPaused = false
            logData = {} -- Clear logs on start
        end
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "Pause") then
            isPaused = not isPaused
        end
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "Stop") then
            isRunning = false
        end
        ImGui.SameLine(ctx)
        if ImGui.Button(ctx, "Close") then
            isOpen = false
        end

        ImGui.Separator(ctx)

        -- Display status
        if isRunning then
            if isPaused then
                ImGui.Text(ctx, "Status: Paused")
            else
                ImGui.Text(ctx, "Status: Running")
            end
        else
            ImGui.Text(ctx, "Status: Stopped")
        end

        -- Get playback position and format it as time
        local playPosition = reaper.GetPlayPosition()
        local formattedTime = formatTime(playPosition)

        -- Display timeline
        ImGui.Text(ctx, string.format("Timeline: %s (Current Position)", formattedTime))
        local projectLength = reaper.GetProjectLength()
        local progress = playPosition / projectLength
        ImGui.ProgressBar(ctx, progress, 1.0, 20)

        -- Log data if running and not paused
        if isRunning and not isPaused then
            logTrackData()
        end

        -- Display logs
        if #logData > 0 then
            ImGui.Separator(ctx)
            ImGui.Text(ctx, "Track Logs:")
            for _, log in ipairs(logData) do
                ImGui.Text(ctx, string.format("Track %d: %s", log.trackNumber, log.trackName))
                ImGui.Text(ctx, string.format("RMS: %.1f dB | Peak: %.1f dB | CF: %.1f dB%s", log.rmsDB, log.peakDB, log.crestFactor, log.warning))
                ImGui.Text(ctx, log.meter)
                ImGui.Separator(ctx)
            end
        end

        ImGui.End(ctx)
    end

    -- Cleanup when window is closed
    if isOpen then
        reaper.defer(main)
    else
        if ImGui and ImGui.DestroyContext then
            ImGui.DestroyContext(ctx) -- Safely destroy the ImGui context
        end
    end
end

-- Start script
main()
