local reaper = reaper
package.path = reaper.ImGui_GetBuiltinPath() .. '/?.lua'
local ImGui = require 'imgui' '0.9.2'

-- ReaImGui settings
local ImGui_ConfigFlags_AlwaysAutoResize = 0x00000020
local ctx = ImGui.CreateContext("Dynamic Range Monitor", ImGui_ConfigFlags_AlwaysAutoResize)
local meterLength = 30 -- Length of the meter
local isRunning = false
local isPaused = false
local logData = {} -- Store dynamics logs
local issuesData = {} -- Tracks with dynamics issues

-- Добавляем переменные для хранения лога
local debugLog = {}

-- Функция для добавления сообщений в лог
local function addToDebugLog(message)
    table.insert(debugLog, message)
    if #debugLog > 1000 then
        table.remove(debugLog, 1) -- Ограничиваем размер лога
    end
end

-- Модифицированная функция calculateDynamicRange с логированием в дебаг-лог
local function calculateDynamicRange(track)
    local numSamples = 100 -- Number of samples to analyze
    local minLevel = math.huge
    local maxLevel = -math.huge
    local sumSquares = 0

    addToDebugLog("Calculating dynamic range for track...")
    
    for i = 1, numSamples do
        local peakL = reaper.Track_GetPeakInfo(track, 0) or 0
        local peakR = reaper.Track_GetPeakInfo(track, 1) or 0
        local rmsL = reaper.Track_GetPeakInfo(track, 0, true) or 0 
        local rmsR = reaper.Track_GetPeakInfo(track, 1, true) or 0
        local peakLevel = math.max(peakL, peakR)
        local rmsLevel = math.max(rmsL, rmsR)

        addToDebugLog(string.format("Sample %d: Peak L = %.6f, Peak R = %.6f, RMS L = %.6f, RMS R = %.6f", i, peakL, peakR, rmsL, rmsR))

        if peakLevel > maxLevel then
            maxLevel = peakLevel
            addToDebugLog(string.format("New max peak level: %.6f", maxLevel))
        end
        if rmsLevel < minLevel then
            minLevel = rmsLevel
            addToDebugLog(string.format("New min RMS level: %.6f", minLevel))
        end

        sumSquares = sumSquares + (rmsLevel * rmsLevel)
    end

    local rmsAvg = math.sqrt(sumSquares / numSamples)

    -- Calculate peak dynamic range in dB
    local peakRange = 20 * (math.log(maxLevel > 0 and maxLevel or 1e-7) / math.log(10))

    -- Calculate RMS dynamic range in dB 
    local rmsRange = 20 * (math.log(rmsAvg > 0 and rmsAvg or 1e-7) / math.log(10)) -
                     20 * (math.log(minLevel > 0 and minLevel or 1e-7) / math.log(10))

    addToDebugLog(string.format("Peak range calculated: %.2f dB", peakRange)) 
    addToDebugLog(string.format("RMS range calculated: %.2f dB", rmsRange))

    return peakRange, rmsRange
end

-- Function to log track dynamics
local function logTrackDynamics()
    logData = {}
    issuesData = {}
    local numTracks = reaper.CountTracks(0)

    -- Analyze all tracks
    for i = 0, numTracks - 1 do
        local track = reaper.GetTrack(0, i)
        local _, trackName = reaper.GetTrackName(track)
        local trackNumber = reaper.GetMediaTrackInfo_Value(track, "IP_TRACKNUMBER")
        local peakRange, rmsRange = calculateDynamicRange(track)

        local warning = ""
        if peakRange > 6 then
            warning = warning .. "High peak levels. "
        end
        if rmsRange < 6 or rmsRange > 18 then 
            warning = warning .. "RMS range outside recommended 6-18 dB."
        end

        if warning ~= "" then
            warning = warning .. " [Needs Fix]"
            table.insert(issuesData, {
                trackNumber = trackNumber,
                trackName = trackName,
                peakRange = peakRange,
                rmsRange = rmsRange,
                suggestion = "Adjust compression, limiting, or gain staging"
            })
        end
        
        table.insert(logData, {
            trackNumber = trackNumber,            
            trackName = trackName,
            peakRange = peakRange,
            rmsRange = rmsRange,
            warning = warning            
        })
    end

    -- Analyze master track
    local masterTrack = reaper.GetMasterTrack(0)
    local masterPeakRange, masterRMSRange = calculateDynamicRange(masterTrack)
    local warning = ""
    if masterPeakRange > 6 then
        warning = warning .. "High peak levels on master. "  
    end
    if masterRMSRange < 6 or masterRMSRange > 18 then
        warning = warning .. "Master RMS range outside recommended 6-18 dB."
    end

    if warning ~= "" then 
        warning = warning .. " [Needs Fix]"
        table.insert(issuesData, {
            trackNumber = "Master",
            trackName = "Master Track", 
            peakRange = masterPeakRange,
            rmsRange = masterRMSRange,
            suggestion = "Adjust compression, limiting, or gain staging on master"
        })
    end
    
    table.insert(logData, {
        trackNumber = "Master",
        trackName = "Master Track",
        peakRange = masterPeakRange, 
        rmsRange = masterRMSRange,
        warning = warning
    })
end

-- Function to create a dynamic range meter 
local function createMeter(dynamicRange)
    local meterLength = 30 -- Length of the meter
    local level = math.floor((dynamicRange / 24) * meterLength) -- Normalize dynamic range to meter length
    level = math.max(0, math.min(level, meterLength)) -- Clamp level to meter length
    return string.rep("=", level) .. string.rep("-", meterLength - level) 
end

-- Модифицируем функцию main для отображения вкладки Debug
local function main()
    local isOpen = true 
    ImGui.SetNextWindowSize(ctx, 600, 800, ImGui.Cond_FirstUseEver)
    isOpen, _ = ImGui.Begin(ctx, "Dynamic Range Monitor", true)

    if isOpen then
        if ImGui.BeginTabBar(ctx, "MainTabs") then
            -- Вкладка Monitor  
            if ImGui.BeginTabItem(ctx, "Monitor") then
                if ImGui.Button(ctx, "Start") then
                    isRunning = true
                    isPaused = false
                    logData = {}
                    issuesData = {}  
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

                if isRunning and not isPaused then 
                    logTrackDynamics()
                end

                if #logData > 0 then
                    ImGui.Text(ctx, "Track Logs:")
                    for _, log in ipairs(logData) do
                        ImGui.Text(ctx, string.format("Track %s: %s", log.trackNumber, log.trackName))
                        ImGui.Text(ctx, string.format("Peak Range: %.1f dB | RMS Range: %.1f dB %s", log.peakRange, log.rmsRange, log.warning))    
                        ImGui.Text(ctx, "Peak: " .. createMeter(log.peakRange)) 
                        ImGui.Text(ctx, "RMS:  " .. createMeter(log.rmsRange))
                        ImGui.Separator(ctx)
                    end
                end

                if #issuesData > 0 then
                    ImGui.Text(ctx, "Tracks with Dynamics Issues:")   
                    for _, issue in ipairs(issuesData) do
                        ImGui.Text(ctx, string.format("Track %s: %s", issue.trackNumber, issue.trackName))
                        ImGui.Text(ctx, string.format("Peak Range: %.1f dB | RMS Range: %.1f dB", issue.peakRange, issue.rmsRange))
                        ImGui.Text(ctx, "Suggestion: " .. issue.suggestion)  
                        ImGui.Separator(ctx) 
                    end
                end

                ImGui.EndTabItem(ctx)  
            end

            -- Вкладка Debug
            if ImGui.BeginTabItem(ctx, "Debug") then  
                if ImGui.Button(ctx, "Clear Log") then
                    debugLog = {} 
                end
                ImGui.Separator(ctx)

                ImGui.Text(ctx, "Debug Log:")
                for _, message in ipairs(debugLog) do
                    ImGui.Text(ctx, message)   
                end

                ImGui.EndTabItem(ctx)
            end
            
            ImGui.EndTabBar(ctx)
        end
        
        ImGui.End(ctx)   
    end

    if isOpen then 
        reaper.defer(main)
    else
        if ImGui and ImGui.DestroyContext then
            ImGui.DestroyContext(ctx) 
        end
    end
end

-- Start script  
main()
