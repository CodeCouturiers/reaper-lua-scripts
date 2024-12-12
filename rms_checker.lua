local function clearScreen()
    reaper.ShowConsoleMsg("")
end

local function loop()
    clearScreen()
    reaper.ShowConsoleMsg("\n=== RMS LEVELS ANALYSIS (REALTIME) ===\n\n")
    
    local numTracks = reaper.CountTracks(0)
    
    for i = 0, numTracks - 1 do
        local track = reaper.GetTrack(0, i)
        local _, trackName = reaper.GetTrackName(track)
        local trackNumber = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
        
        -- Get peak/RMS values
        local peakL = reaper.Track_GetPeakInfo(track, 0)
        local peakR = reaper.Track_GetPeakInfo(track, 1)
        local rmsL = reaper.Track_GetPeakInfo(track, 2)
        local rmsR = reaper.Track_GetPeakInfo(track, 3)
        
        -- Calculate averages
        local rmsAvg = (rmsL + rmsR) / 2
        local peakAvg = math.max(peakL, peakR)
        
        -- Convert to dB
        local rmsDB = 20 * math.log(rmsAvg > 0 and rmsAvg or 0.0000001, 10)
        local peakDB = 20 * math.log(peakAvg > 0 and peakAvg or 0.0000001, 10)
        local crestFactor = peakDB - rmsDB
        
        -- Create meter visualization
        local meterLength = 30
        local level = math.floor(((peakDB + 60) / 60) * meterLength)
        level = math.max(0, math.min(level, meterLength))
        local meter = string.rep("=", level) .. string.rep("-", meterLength - level)
        
        -- Format output with meter
        local trackInfo = string.format(
            "Track %2d: %-20s |%s| RMS: %6.1f dB | Peak: %6.1f dB | CF: %4.1f dB",
            trackNumber,
            trackName,
            meter,
            rmsDB,
            peakDB,
            crestFactor
        )
        
        -- Add warning indicators
        if rmsDB > -18 then
            trackInfo = trackInfo .. " [!!! HOT RMS !!!]"
        end
        if peakDB > -6 then
            trackInfo = trackInfo .. " [!!! HOT PEAKS !!!]"
        end
        
        reaper.ShowConsoleMsg(trackInfo .. "\n")
    end
    
    reaper.ShowConsoleMsg("\nRestart script to refresh values\n")
end

reaper.ClearConsole()
loop()
