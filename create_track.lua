-- Diagnostic functions
function checkSend(sourceTrack, sendIdx)
    local _, sourceName = reaper.GetTrackName(sourceTrack)
    local destTrack = reaper.GetTrackSendInfo_Value(sourceTrack, 0, sendIdx, "P_DESTTRACK")
    local _, destName = reaper.GetTrackName(destTrack)
    
    local sendMode = reaper.GetTrackSendInfo_Value(sourceTrack, 0, sendIdx, "I_SENDMODE")
    local sendVol = reaper.GetTrackSendInfo_Value(sourceTrack, 0, sendIdx, "D_VOL")
    local sendVolDB = 20 * math.log(sendVol, 10)
    
    reaper.ShowConsoleMsg(string.format("\nПроверка send: %s -> %s\n", sourceName, destName))
    reaper.ShowConsoleMsg(string.format("Режим send: %s\n", 
        sendMode == 0 and "Post-Fader (OK)" or "WARNING: Не Post-Fader!"))
    reaper.ShowConsoleMsg(string.format("Громкость send: %.1f dB\n", sendVolDB))
    
    return sendMode == 0
end

function checkTrackSignalFlow(track)
    local _, name = reaper.GetTrackName(track)
    local volume = reaper.GetMediaTrackInfo_Value(track, "D_VOL")
    local volumeDB = 20 * math.log(volume, 10)
    local pan = reaper.GetMediaTrackInfo_Value(track, "D_PAN")
    local mute = reaper.GetMediaTrackInfo_Value(track, "B_MUTE")
    local phase = reaper.GetMediaTrackInfo_Value(track, "B_PHASE")
    
    reaper.ShowConsoleMsg(string.format("\n=== Проверка трека: %s ===\n", name))
    reaper.ShowConsoleMsg(string.format("Громкость: %.1f dB\n", volumeDB))
    reaper.ShowConsoleMsg(string.format("Панорама: %.0f%%\n", pan * 100))
    reaper.ShowConsoleMsg(string.format("Мьют: %s\n", mute == 1 and "ДА (WARNING!)" or "нет"))
    reaper.ShowConsoleMsg(string.format("Фаза: %s\n", phase == 1 and "Инвертирована (WARNING!)" or "норма"))
    
    -- Check FX chain status
    local fxCount = reaper.TrackFX_GetCount(track)
    reaper.ShowConsoleMsg(string.format("Количество FX: %d\n", fxCount))
    
    -- Check if FX chain is enabled
    local fxEnabled = reaper.GetMediaTrackInfo_Value(track, "I_FXEN")
    reaper.ShowConsoleMsg(string.format("FX цепь: %s\n", fxEnabled == 1 and "включена" or "ВЫКЛЮЧЕНА (WARNING!)"))
    
    -- Check sends
    local numSends = reaper.GetTrackNumSends(track, 0)
    for i = 0, numSends - 1 do
        checkSend(track, i)
    end
    
    return not (mute == 1 or phase == 1 or fxEnabled == 0)
end
function getTrackColor(trackType)
    -- Определяем палитру цветов для разных типов треков
    local colors = {
        source = {  -- Источники (violin, bass и т.д.)
            {242, 153, 74},   -- Оранжевый
            {235, 87, 87},    -- Красный
            {47, 128, 237},   -- Синий
            {39, 174, 96}     -- Зеленый
        },
        bus = {    -- Шины (piano_bus, bass_bus и т.д.)
            {111, 168, 220},  -- Светло-синий
            {147, 196, 125},  -- Светло-зеленый
            {246, 178, 107},  -- Светло-оранжевый
            {184, 153, 218}   -- Светло-фиолетовый
        },
        master = { -- Мастер секция
            {155, 81, 224},   -- Фиолетовый
            {123, 97, 255},   -- Индиго
            {58, 134, 255}    -- Голубой
        }
    }
    
    local color
    if trackType == "source" then
        color = colors.source[math.random(1, #colors.source)]
    elseif trackType == "bus" then
        color = colors.bus[math.random(1, #colors.bus)]
    else -- master
        color = colors.master[math.random(1, #colors.master)]
    end
    
    return reaper.ColorToNative(color[1], color[2], color[3])
end

function colorizeTrack(track, name)
    local trackType = "source"
    
    -- Определяем тип трека по имени
    if string.find(name, "bus") or string.find(name, "Bus") then
        trackType = "bus"
    elseif name == "master" or name == "analog_master" or name == "mfit" then
        trackType = "master"
    end
    
    reaper.SetTrackColor(track, getTrackColor(trackType))
end

function diagnoseMixRouting(tracks)
    reaper.ShowConsoleMsg("\n====== ДИАГНОСТИКА МАРШРУТИЗАЦИИ ======\n")
    
    local allOK = true
    
    for name, number in pairs(tracks) do
        local track = reaper.GetTrack(0, number - 1)
        if track then
            if not checkTrackSignalFlow(track) then
                allOK = false
            end
        else
            reaper.ShowConsoleMsg(string.format("\nОШИБКА: Трек %s (#%d) не найден!\n", 
                name, number))
            allOK = false
        end
    end
    
    reaper.ShowConsoleMsg("\n====== ИТОГ ДИАГНОСТИКИ ======\n")
    if allOK then
        reaper.ShowConsoleMsg("Все проверки пройдены успешно!\n")
    else
        reaper.ShowConsoleMsg("ВНИМАНИЕ: Обнаружены проблемы в маршрутизации!\n")
        reaper.ShowMessageBox(
            "В маршрутизации обнаружены проблемы. Проверьте консоль REAPER для деталей.", 
            "Результат диагностики", 
            0)
    end
    
    return allOK
end

-- Function to check if FX is available
function isFXAvailable(fxName)
    -- Get first track to check available FX
    local track = reaper.GetTrack(0, 0)
    if not track then return false end
    
    -- Try to add FX temporarily to check if it exists
    local fxIndex = reaper.TrackFX_AddByName(track, fxName, false, -1)
    if fxIndex >= 0 then
        -- Remove test FX
        reaper.TrackFX_Delete(track, fxIndex)
        return true
    end
    return false
end

-- Function to add FX to track if available
function addFXToTrack(track, fxName)
    if isFXAvailable(fxName) then
        local fxIndex = reaper.TrackFX_AddByName(track, fxName, false, -1)
        if fxIndex >= 0 then
            reaper.ShowConsoleMsg(string.format("Добавлен FX: %s\n", fxName))
            return true
        end
    end
    reaper.ShowConsoleMsg(string.format("ПРЕДУПРЕЖДЕНИЕ: FX не найден: %s\n", fxName))
    return false
end

-- Function to setup group bus processing
function setupGroupBusProcessing(groupTrack)
    reaper.ShowConsoleMsg("\n=== Настройка групповой обработки ===\n")
    
    -- Clear existing FX
    local fxCount = reaper.TrackFX_GetCount(groupTrack)
    for i = fxCount - 1, 0, -1 do
        reaper.TrackFX_Delete(groupTrack, i)
    end
    
    -- Add group processing chain
    local fxChain = {
        "SSL Native Bus Compressor 2",  -- или точное название вашего плагина SSL
        "J37 Stereo"            -- или точное название вашего tape плагина
    }
    
    -- Add FX one by one
    for i, fxName in ipairs(fxChain) do
        if addFXToTrack(groupTrack, fxName) then
            -- Enable FX
            reaper.TrackFX_SetEnabled(groupTrack, i-1, true)
            reaper.ShowConsoleMsg(string.format("Добавлен и включен FX: %s\n", fxName))
        else
            reaper.ShowConsoleMsg(string.format("ОШИБКА: Не удалось добавить FX: %s\n", fxName))
        end
    end
    
    -- Ensure FX chain is enabled
    reaper.SetMediaTrackInfo_Value(groupTrack, "I_FXEN", 1)
    
    -- Ensure the track is not muted
    reaper.SetMediaTrackInfo_Value(groupTrack, "B_MUTE", 0)
    
    -- Set proper volume (unity gain)
    reaper.SetMediaTrackInfo_Value(groupTrack, "D_VOL", 1.0)
    
    reaper.ShowConsoleMsg("Групповая обработка настроена\n")
end

-- Original routing functions remain the same
function getRandomColor()
    local r = math.random(60, 240)
    local g = math.random(60, 240)
    local b = math.random(60, 240)
    return reaper.ColorToNative(r, g, b)
end

function getTrackName(track)
    local _, name = reaper.GetTrackName(track)
    return name
end

function getTrackByNumber(number)
    local track = reaper.GetTrack(0, number - 1)
    if track then
        reaper.ShowConsoleMsg(string.format("Найден трек %d: %s\n", number, getTrackName(track)))
    else
        reaper.ShowConsoleMsg(string.format("Трек %d не найден!\n", number))
    end
    return track
end

function createSend(sourceTrack, destTrack, sendVolDB)
    local sourceName = getTrackName(sourceTrack)
    local destName = getTrackName(destTrack)
    
    -- Check if send already exists
    local numSends = reaper.GetTrackNumSends(sourceTrack, 0)
    for i = 0, numSends - 1 do
        local destTrackExisting = reaper.GetTrackSendInfo_Value(sourceTrack, 0, i, "P_DESTTRACK")
        if destTrackExisting == destTrack then
            reaper.ShowConsoleMsg(string.format("Send уже существует: %s -> %s\n", 
                sourceName, destName))
            return
        end
    end
    
    local sendIdx = reaper.CreateTrackSend(sourceTrack, destTrack)
    local vol = math.exp(sendVolDB * 0.11512925464970229)
    reaper.SetTrackSendInfo_Value(sourceTrack, 0, sendIdx, "D_VOL", vol)
    reaper.SetTrackSendInfo_Value(sourceTrack, 0, sendIdx, "I_SENDMODE", 0)
    
    -- Unmute both source and destination tracks
    reaper.SetMediaTrackInfo_Value(sourceTrack, "B_MUTE", 0)
    reaper.SetMediaTrackInfo_Value(destTrack, "B_MUTE", 0)
    
    reaper.ShowConsoleMsg(string.format("Создан send: %s -> %s (%.1f dB)\n", 
        sourceName, destName, sendVolDB))
end

function createRoutingStructure()
    local tracks = {
        violin = 8,
        bass = 9,
        timpani = 7,
        drums = 10,
        piano_bus = 2,
        bass_bus = 3,
        arp_bus = 4,
        drums_bus = 11,
        groups = 1,
        analog_master = 5,
        mfit = 6,
        master = 12
    }
    
    local trackRefs = {}
    for name, number in pairs(tracks) do
        trackRefs[name] = getTrackByNumber(number)
        if not trackRefs[name] then
            return false, tracks
        end
        
        -- Устанавливаем цвет в зависимости от типа трека
        colorizeTrack(trackRefs[name], name)
        
        -- Важно: сначала включаем все треки!
        reaper.SetMediaTrackInfo_Value(trackRefs[name], "B_MUTE", 0)
        reaper.SetMediaTrackInfo_Value(trackRefs[name], "D_VOL", 1.0)

        
        -- Убираем все существующие sends
        local numSends = reaper.GetTrackNumSends(trackRefs[name], 0)
        for i = numSends - 1, 0, -1 do
            reaper.RemoveTrackSend(trackRefs[name], 0, i)
        end
    end
    
    reaper.ShowConsoleMsg("\nСоздание маршрутизации...\n")
    
    -- 1. Источники -> шины (и ТОЛЬКО в шины)
    createSend(trackRefs.violin, trackRefs.piano_bus, 0)
    createSend(trackRefs.bass, trackRefs.bass_bus, 0)
    createSend(trackRefs.timpani, trackRefs.arp_bus, 0)
    createSend(trackRefs.drums, trackRefs.drums_bus, 0)
    
    -- 2. Шины -> Groups
    createSend(trackRefs.piano_bus, trackRefs.groups, 0)
    createSend(trackRefs.bass_bus, trackRefs.groups, 0)
    createSend(trackRefs.arp_bus, trackRefs.groups, 0)
    createSend(trackRefs.drums_bus, trackRefs.groups, 0)
    
    -- 3. Мастеринг цепь
    createSend(trackRefs.groups, trackRefs.analog_master, 0)
    createSend(trackRefs.analog_master, trackRefs.mfit, 0)
    createSend(trackRefs.mfit, trackRefs.master, -16)
    
    -- 4. Отключаем MainSend только для шин и промежуточных треков
    local busses = {
        trackRefs.piano_bus,
        trackRefs.bass_bus,
        trackRefs.arp_bus,
        trackRefs.drums_bus,
        trackRefs.groups,
        trackRefs.analog_master,
        trackRefs.mfit
    }
    
    for _, bus in ipairs(busses) do
        reaper.SetMediaTrackInfo_Value(bus, "B_MAINSEND", 0)
    end
    
    -- 5. Включаем MainSend для источников и мастера
    reaper.SetMediaTrackInfo_Value(trackRefs.violin, "B_MAINSEND", 1)
    reaper.SetMediaTrackInfo_Value(trackRefs.bass, "B_MAINSEND", 1)
    reaper.SetMediaTrackInfo_Value(trackRefs.timpani, "B_MAINSEND", 1)
    reaper.SetMediaTrackInfo_Value(trackRefs.drums, "B_MAINSEND", 1)
    reaper.SetMediaTrackInfo_Value(trackRefs.master, "B_MAINSEND", 1)
    
    return true, tracks
end


function removeDuplicateSends(sourceTrack)
    local sends = {}
    local numSends = reaper.GetTrackNumSends(sourceTrack, 0)
    
    -- Collect all unique destinations
    for i = numSends - 1, 0, -1 do
        local destTrack = reaper.GetTrackSendInfo_Value(sourceTrack, 0, i, "P_DESTTRACK")
        if sends[destTrack] then
            -- Remove duplicate send
            reaper.RemoveTrackSend(sourceTrack, 0, i)
        else
            sends[destTrack] = true
        end
    end
end

function unmuteCriticalBuses(trackRefs)
    -- List of buses that should never be muted
    local criticalBuses = {
        trackRefs.drums_bus,
        trackRefs.groups,
        trackRefs.analog_master,
        trackRefs.mfit,
        trackRefs.master
    }
    
    for _, bus in ipairs(criticalBuses) do
        if bus then
            reaper.SetMediaTrackInfo_Value(bus, "B_MUTE", 0)
        end
    end
end

function verifyInitialState()
    -- Check if project exists
    if reaper.GetProjectName(0, "") == "" then
        reaper.ShowMessageBox(
            "No project is open. Please open a project first.", 
            "Error", 
            0)
        return false
    end
    
    -- Check if there are enough tracks
    if reaper.CountTracks(0) < 12 then
        reaper.ShowMessageBox(
            "Project needs at least 12 tracks. Please create required tracks first.", 
            "Error", 
            0)
        return false
    end
    
    return true
end

function main()
    if not verifyInitialState() then
        return
    end

    math.randomseed(os.time())
    
    reaper.ShowConsoleMsg("=== Начало выполнения скрипта ===\n")
    
    -- Ask about color reset
    local reset = reaper.ShowMessageBox(
        "Сбросить цвета треков перед созданием маршрутизации?", 
        "Сброс цветов", 
        4)
    
    if reset == 6 then
        local trackCount = reaper.CountTracks(0)
        for i = 0, trackCount - 1 do
            local track = reaper.GetTrack(0, i)
            reaper.SetTrackColor(track, 0)
        end
        reaper.ShowConsoleMsg("Цвета треков сброшены\n")
    end
    
    -- Create routing structure
    local success, tracks = createRoutingStructure()
    if not success then
        reaper.ShowConsoleMsg("\nОШИБКА: Не все треки найдены!\n")
        reaper.ShowMessageBox(
            "Один или несколько треков не найдены. Проверьте номера треков.", 
            "Ошибка", 
            0)
        return
    end
    
    -- Get track references for cleanup
    local trackRefs = {}
    for name, number in pairs(tracks) do
        trackRefs[name] = reaper.GetTrack(0, number - 1)
    end
    
    -- Clean up duplicate sends
    reaper.ShowConsoleMsg("\nУдаление дублирующихся send...\n")
    for name, track in pairs(trackRefs) do
        if track then
            removeDuplicateSends(track)
            reaper.ShowConsoleMsg(string.format("Очищены дубликаты send для: %s\n", name))
        end
    end
    
    -- Ensure critical buses are unmuted
    unmuteCriticalBuses(trackRefs)
    
    -- Update UI
    reaper.TrackList_AdjustWindows(false)
    reaper.UpdateArrange()
    
    reaper.ShowConsoleMsg("\nМаршрутизация успешно создана!\n")
    if reset == 6 then
        reaper.ShowConsoleMsg("Все треки окрашены в случайные цвета\n")
    end
    
    -- Run diagnostic after setup
    local diagnosticResult = diagnoseMixRouting(tracks)
    
    -- Final status message
    if diagnosticResult then
        reaper.ShowMessageBox(
            "Маршрутизация успешно создана и проверена.", 
            "Успех", 
            0)
    end
    
    reaper.ShowConsoleMsg("=== Завершение выполнения скрипта ===\n")
end

-- Wrap the main execution in an undo block
reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Create Mix Routing Structure", -1)
