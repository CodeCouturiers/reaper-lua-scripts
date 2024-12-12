function getTrackPlugins(track)
    local plugins = {}
    local fxCount = reaper.TrackFX_GetCount(track)
    
    for i = 0, fxCount - 1 do
        local retval, fxName = reaper.TrackFX_GetFXName(track, i, "")
        local enabled = reaper.TrackFX_GetEnabled(track, i)
        table.insert(plugins, {
            name = fxName,
            enabled = enabled
        })
    end
    
    return plugins
end

function getTrackName(track)
    if track == reaper.GetMasterTrack(0) then
        return "Master Output"
    end
    local _, name = reaper.GetTrackName(track)
    return name
end

function getTrackSends(track)
    local sends = {}
    local numSends = reaper.GetTrackNumSends(track, 0)
    
    for i = 0, numSends - 1 do
        local destTrack = reaper.GetTrackSendInfo_Value(track, 0, i, "P_DESTTRACK")
        local vol = reaper.GetTrackSendInfo_Value(track, 0, i, "D_VOL")
        local volDB = 20 * math.log(vol, 10)
        local sendMode = reaper.GetTrackSendInfo_Value(track, 0, i, "I_SENDMODE")
        
        table.insert(sends, {
            track = destTrack,
            volume = volDB,
            mode = sendMode
        })
    end
    
    return sends
end

function getTrackInputs(targetTrack)
    local inputs = {}
    local numTracks = reaper.CountTracks(0)
    
    for i = 0, numTracks - 1 do
        local track = reaper.GetTrack(0, i)
        local sends = getTrackSends(track)
        
        for _, send in ipairs(sends) do
            if send.track == targetTrack then
                table.insert(inputs, {
                    track = track,
                    volume = send.volume,
                    mode = send.mode
                })
            end
        end
    end
    
    return inputs
end

function printRoutingTreeFromMaster()
    reaper.ShowConsoleMsg("\n====== ROUTING TREE ======\n\n")
    local printed = {}
    
    local function printTrackRecursive(track, level, isLast, sendVol)
        if printed[track] then return end
        printed[track] = true
        
        -- Подготовка отступа
        local indent = string.rep("    ", level)
        local prefix = level > 0 and "→ " or ""
        local volStr = sendVol and string.format(" (%.1f dB)", sendVol) or ""
        
        -- Вывод имени трека
        local name = getTrackName(track)
        reaper.ShowConsoleMsg(string.format("%s%s%s%s\n", indent, prefix, name, volStr))
        
        -- Вывод плагинов
        local plugins = getTrackPlugins(track)
        if #plugins > 0 then
            -- Разделитель перед плагинами
            reaper.ShowConsoleMsg(string.format("%s   ↓\n", indent))
            
            for i, plugin in ipairs(plugins) do
                -- Для последнего плагина используем другую стрелку
                local pluginPrefix = (i == #plugins) and "   ⤷ " or "   ↓ "
                reaper.ShowConsoleMsg(string.format("%s%s%s [%s]\n",
                    indent,
                    pluginPrefix,
                    plugin.name,
                    plugin.enabled and "ON" or "OFF"))
            end
            
            -- Если есть входящие треки, добавляем разделитель после плагинов
            local inputs = getTrackInputs(track)
            if #inputs > 0 then
                reaper.ShowConsoleMsg(string.format("%s   ↑\n", indent))
            end
        end
        
        -- Получение и сортировка входящих треков
        local inputs = getTrackInputs(track)
        for i, input in ipairs(inputs) do
            printTrackRecursive(input.track, level + 1, i == #inputs, input.volume)
        end
    end
    
    -- Начинаем с мастер-трека
    local master = reaper.GetMasterTrack(0)
    printTrackRecursive(master, 0, true)
    
    reaper.ShowConsoleMsg("\n====== END OF ROUTING MAP ======\n")
end

function generateRoutingMap()
    reaper.ClearConsole()
    reaper.ShowConsoleMsg("====== ROUTING MAP AND PLUGIN REPORT ======\n\n")
    
    local numTracks = reaper.CountTracks(0)
    
    for i = 0, numTracks - 1 do
        local track = reaper.GetTrack(0, numTracks - 1 - i)
        local _, name = reaper.GetTrackName(track)
        local volume = reaper.GetMediaTrackInfo_Value(track, "D_VOL")
        local volumeDB = 20 * math.log(volume, 10)
        local mainSend = reaper.GetMediaTrackInfo_Value(track, "B_MAINSEND")
        
        -- Track Header
        reaper.ShowConsoleMsg(string.format("\n=== TRACK: %s ===\n", name))
        reaper.ShowConsoleMsg(string.format("Volume: %.1f dB\n", volumeDB))
        reaper.ShowConsoleMsg(string.format("Main Send: %s\n", mainSend == 1 and "Enabled" or "Disabled"))
        
        -- Plugin Chain
        local plugins = getTrackPlugins(track)
        if #plugins > 0 then
            reaper.ShowConsoleMsg("\nPlugin Chain:\n")
            for j, plugin in ipairs(plugins) do
                reaper.ShowConsoleMsg(string.format("%d. %s [%s]\n", 
                    j, 
                    plugin.name, 
                    plugin.enabled and "Enabled" or "Bypassed"))
            end
        else
            reaper.ShowConsoleMsg("\nNo plugins on this track\n")
        end
        
        -- Sends
        local sends = getTrackSends(track)
        if #sends > 0 then
            reaper.ShowConsoleMsg("\nSends:\n")
            for _, send in ipairs(sends) do
                local destName = getTrackName(send.track)
                reaper.ShowConsoleMsg(string.format("→ To: %s (%.1f dB) [%s]\n", 
                    destName,
                    send.volume,
                    send.mode == 0 and "Post-Fader" or "Pre-Fader"))
            end
        else
            reaper.ShowConsoleMsg("\nNo sends from this track\n")
        end
        
        reaper.ShowConsoleMsg("\n" .. string.rep("-", 40) .. "\n")
    end
    
    -- Добавляем древовидную схему
    printRoutingTreeFromMaster()
end

-- Run the script
reaper.PreventUIRefresh(1)
generateRoutingMap()
reaper.PreventUIRefresh(-1)
