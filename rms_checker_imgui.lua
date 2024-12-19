local reaper = reaper
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.9.2'

-- ReaImGui settings
local ImGui_ConfigFlags_AlwaysAutoResize = 0x00000020
local ctx = ImGui.CreateContext("Realtime RMS/Peak Levels Monitor", ImGui_ConfigFlags_AlwaysAutoResize)
local meterLength = 30 -- Length of the meter

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

-- Main script function
local function main()
    ImGui.SetNextWindowSize(ctx, 500, 500, ImGui.Cond_FirstUseEver)
    if ImGui.Begin(ctx, "RMS Levels Monitor", true) then
        local numTracks = reaper.CountTracks(0)
        if numTracks == 0 then
            ImGui.Text(ctx, "No tracks found.")
        else
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

                -- Display track info
                ImGui.Text(ctx, string.format("Track %d: %s", trackNumber, trackName))
                ImGui.Text(ctx, string.format("RMS: %.1f dB | Peak: %.1f dB | CF: %.1f dB%s", rmsDB, peakDB, crestFactor, warning))

                -- Display meters
                ImGui.Text(ctx, meter)
                ImGui.Separator(ctx)
            end
        end
        ImGui.End(ctx)
    end

    reaper.defer(main) -- Repeat continuously
end

-- Start script
main()
