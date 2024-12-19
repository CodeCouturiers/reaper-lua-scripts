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

    addToDebugLog("Calculating dynamic range for track...")
    
    for i = 1, numSamples do
        local peakL = reaper.Track_GetPeakInfo(track, 0) or 0
        local peakR = reaper.Track_GetPeakInfo(track, 1) or 0
        local level = math.max(peakL, peakR)

        addToDebugLog(string.format("Sample %d: Peak L = %.6f, Peak R = %.6f, Level = %.6f", i, peakL, peakR, level))

        if level > maxLevel then
            maxLevel = level
            addToDebugLog(string.format("New max level: %.6f", maxLevel))
        end
        if level < minLevel then
            minLevel = level
            addToDebugLog(string.format("New min level: %.6f", minLevel))
        end
    end

    -- Calculate dynamic range in dB
    local dynamicRange = 20 * (math.log(maxLevel > 0 and maxLevel or 1e-7) / math.log(10)) -
                         20 * (math.log(minLevel > 0 and minLevel or 1e-7) / math.log(10))

    addToDebugLog(string.format("Dynamic range calculated: %.2f dB", dynamicRange))
    
    return dynamicRange
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
        local dynamicRange = calculateDynamicRange(track)

        local warning = ""
        if dynamicRange < 6 or dynamicRange > 24 then
            warning = " [Needs Fix]"
            table.insert(issuesData, {
                trackNumber = trackNumber,
                trackName = trackName,
                dynamicRange = dynamicRange,
                suggestion = "Adjust compression or gain staging"
            })
        end

        table.insert(logData, {
            trackNumber = trackNumber,
            trackName = trackName,
            dynamicRange = dynamicRange,
            warning = warning
        })
    end

    -- Analyze master track
    local masterTrack = reaper.GetMasterTrack(0)
    local masterDynamicRange = calculateDynamicRange(masterTrack)
    local warning = ""
    if masterDynamicRange < 6 or masterDynamicRange > 24 then
        warning = " [Needs Fix]"
        table.insert(issuesData, {
            trackNumber = "Master",
            trackName = "Master Track",
            dynamicRange = masterDynamicRange,
            suggestion = "Adjust compression or limiting"
        })
    end

    table.insert(logData, {
        trackNumber = "Master",
        trackName = "Master Track",
        dynamicRange = masterDynamicRange,
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
                        ImGui.Text(ctx, string.format("Dynamic Range: %.1f dB%s", log.dynamicRange, log.warning))
                        ImGui.Text(ctx, createMeter(log.dynamicRange))
                        ImGui.Separator(ctx)
                    end
                end

                if #issuesData > 0 then
                    ImGui.Text(ctx, "Tracks with Dynamics Issues:")
                    for _, issue in ipairs(issuesData) do
                        ImGui.Text(ctx, string.format("Track %s: %s", issue.trackNumber, issue.trackName))
                        ImGui.Text(ctx, string.format("Dynamic Range: %.1f dB | Suggestion: %s", issue.dynamicRange, issue.suggestion))
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
