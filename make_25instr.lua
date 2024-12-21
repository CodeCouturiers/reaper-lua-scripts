
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

function isFXAvailable(fxName)
    -- Создаем временный трек для проверки
    reaper.InsertTrackAtIndex(0, false)
    local tempTrack = reaper.GetTrack(0, 0)
    
    -- Пробуем добавить эффект
    local fxIndex = reaper.TrackFX_AddByName(tempTrack, fxName, false, -1)
    local isAvailable = fxIndex >= 0
    
    -- Если эффект добавился, удаляем его
    if isAvailable then
        reaper.TrackFX_Delete(tempTrack, fxIndex)
    end
    
    -- Удаляем временный трек
    reaper.DeleteTrack(tempTrack)
    
    return isAvailable
end

function createTracks()
    reaper.ShowConsoleMsg("\n=== Создание треков ===\n")
    
    local trackNames = {
        -- Инструменты (1-25)
        "[INST 1]", "[INST 2]", "[INST 3]", "[INST 4]", "[INST 5]",
        "[INST 6]", "[INST 7]", "[INST 8]", "[INST 9]", "[INST 10]",
        "[INST 11]", "[INST 12]", "[INST 13]", "[INST 14]", "[INST 15]",
        "[INST 16]", "[INST 17]", "[INST 18]", "[INST 19]", "[INST 20]",
        "[INST 21]", "[INST 22]", "[INST 23]", "[INST 24]", "[INST 25]",
        -- Шины (26-50)
        "[BUS 1]", "[BUS 2]", "[BUS 3]", "[BUS 4]", "[BUS 5]",
        "[BUS 6]", "[BUS 7]", "[BUS 8]", "[BUS 9]", "[BUS 10]",
        "[BUS 11]", "[BUS 12]", "[BUS 13]", "[BUS 14]", "[BUS 15]",
        "[BUS 16]", "[BUS 17]", "[BUS 18]", "[BUS 19]", "[BUS 20]",
        "[BUS 21]", "[BUS 22]", "[BUS 23]", "[BUS 24]", "[BUS 25]",
        -- Мастер секция (51-53)
        "[ANALOG]", "[MFIT]", "[ENDCHAIN]"
    }
    
    -- Создаем треки
    for _, name in ipairs(trackNames) do
        reaper.InsertTrackAtIndex(reaper.GetNumTracks(), true)
        local newTrack = reaper.GetTrack(0, reaper.GetNumTracks() - 1)
        if newTrack then
            reaper.GetSetMediaTrackInfo_String(newTrack, "P_NAME", name, true)
            reaper.ShowConsoleMsg(string.format("Создан трек: %s\n", name))
        end
    end
    
    reaper.ShowConsoleMsg("Треки созданы успешно\n")
    return true
end

function addFolderMarkers()
    local _, markerName
    
    -- Добавляем новые треки-разделители перед каждой группой
    for i = 1, 5 do
        markerName = string.format("=== GROUP %d ===", i)
        reaper.InsertTrackAtIndex((i-1)*10, true)  -- Вставляем перед каждой группой из 10 треков
        local markerTrack = reaper.GetTrack(0, (i-1)*10)
        
        if markerTrack then
            -- Настраиваем трек-маркер
            reaper.GetSetMediaTrackInfo_String(markerTrack, "P_NAME", markerName, true)
            reaper.SetMediaTrackInfo_Value(markerTrack, "I_FOLDERDEPTH", 1)  -- Делаем его папкой
            reaper.SetMediaTrackInfo_Value(markerTrack, "I_FOLDERCOMPACT", 2)  -- Компактный вид
            reaper.SetMediaTrackInfo_Value(markerTrack, "B_SHOWINTCP", 0)  -- Скрываем в TCP
            reaper.SetMediaTrackInfo_Value(markerTrack, "B_SHOWINMIXER", 1)  -- Показываем в микшере
            reaper.SetMediaTrackInfo_Value(markerTrack, "D_VOL", 0)  -- Устанавливаем громкость в -inf dB
            
            -- Закрашиваем трек-маркер в цвет группы
            local color = getMatchingColor(string.format("[INST %d]", (i-1)*5 + 1))
            reaper.SetTrackColor(markerTrack, color)
        end
    end
    
    -- Добавляем маркер для мастер-секции
    reaper.InsertTrackAtIndex(50, true)
    local masterMarkerTrack = reaper.GetTrack(0, 50)
    if masterMarkerTrack then
        reaper.GetSetMediaTrackInfo_String(masterMarkerTrack, "P_NAME", "=== MASTER ===", true)
        reaper.SetMediaTrackInfo_Value(masterMarkerTrack, "I_FOLDERDEPTH", 1)
        reaper.SetMediaTrackInfo_Value(masterMarkerTrack, "I_FOLDERCOMPACT", 2)
        reaper.SetMediaTrackInfo_Value(masterMarkerTrack, "B_SHOWINTCP", 0)
        reaper.SetMediaTrackInfo_Value(masterMarkerTrack, "B_SHOWINMIXER", 1)
        reaper.SetMediaTrackInfo_Value(masterMarkerTrack, "D_VOL", 0)
        reaper.SetTrackColor(masterMarkerTrack, getMatchingColor("[ANALOG]"))
    end
end


function setupTrackGrouping(tracks)
    reaper.ShowConsoleMsg("\n=== Начало создания групп ===\n")
    reaper.ShowConsoleMsg("Будет создано 6 групп:\n")
    reaper.ShowConsoleMsg("- Группы 1-5: по 5 пар INST+BUS в каждой\n")
    reaper.ShowConsoleMsg("- Группа 6: мастер-секция (ANALOG, MFIT, ENDCHAIN)\n\n")
    
    local function setTrackGroup(track, groupId)
        local _, name = reaper.GetTrackName(track)
        reaper.GetSetTrackGroupMembership(track, "VOLUME_LEAD", -1, 2^(groupId-1))
        reaper.GetSetTrackGroupMembership(track, "MUTE_LEAD", -1, 2^(groupId-1))
        reaper.GetSetTrackGroupMembership(track, "SOLO_LEAD", -1, 2^(groupId-1))
        
        -- Проверяем успешность группировки
        local volGroup = reaper.GetSetTrackGroupMembership(track, "VOLUME_LEAD", 0, 0)
        local muteGroup = reaper.GetSetTrackGroupMembership(track, "MUTE_LEAD", 0, 0)
        local soloGroup = reaper.GetSetTrackGroupMembership(track, "SOLO_LEAD", 0, 0)
        
        reaper.ShowConsoleMsg(string.format("    %s -> Группа %d\n", name, groupId))
        reaper.ShowConsoleMsg(string.format("      Volume: %d, Mute: %d, Solo: %d\n", 
            volGroup, muteGroup, soloGroup))
    end

    -- Создаем 5 основных групп
    for groupNum = 1, 5 do
        reaper.ShowConsoleMsg(string.format("\nГруппа %d (Треки %d-%d + их шины):\n", 
            groupNum, (groupNum-1)*5 + 1, groupNum*5))
        
        local startIdx = (groupNum-1) * 5 + 1
        local endIdx = startIdx + 4
        
        for i = startIdx, endIdx do
            local inst = tracks[string.format("[INST %d]", i)]
            local bus = tracks[string.format("[BUS %d]", i)]
            
            if inst and bus then
                setTrackGroup(inst, groupNum)
                setTrackGroup(bus, groupNum)
            else
                reaper.ShowConsoleMsg(string.format("  ОШИБКА: Не найдены треки INST %d или BUS %d\n", i, i))
            end
        end
        reaper.ShowConsoleMsg(string.format("  >> Группа %d создана\n", groupNum))
    end

    -- Создаем группу для мастер-секции (группа 6)
    reaper.ShowConsoleMsg("\nГруппа 6 (Мастер-секция):\n")
    local masterTracks = {
        {track = tracks["[ANALOG]"], name = "ANALOG"},
        {track = tracks["[MFIT]"], name = "MFIT"},
        {track = tracks["[ENDCHAIN]"], name = "ENDCHAIN"}
    }
    
    for _, trackInfo in ipairs(masterTracks) do
        if trackInfo.track then
            setTrackGroup(trackInfo.track, 6)
        else
            reaper.ShowConsoleMsg(string.format("  ОШИБКА: Не найден трек %s\n", trackInfo.name))
        end
    end
    reaper.ShowConsoleMsg("  >> Мастер-группа создана\n")

    -- Включаем группировку глобально
    reaper.Main_OnCommand(40729, 0)
    reaper.ShowConsoleMsg("\n=== Группировка завершена ===\n")
    reaper.ShowConsoleMsg("Всего создано групп: 6\n")
    reaper.ShowConsoleMsg("Группировка включена глобально\n")
    
    -- Выводим итоговую структуру
    reaper.ShowConsoleMsg("\n=== Структура групп ===\n")
    for i = 1, 5 do
        reaper.ShowConsoleMsg(string.format("Группа %d: INST %d-%d + BUS %d-%d\n", 
            i, (i-1)*5 + 1, i*5, (i-1)*5 + 1, i*5))
    end
    reaper.ShowConsoleMsg("Группа 6: ANALOG -> MFIT -> ENDCHAIN\n")
end

function getMatchingColor(trackName)
    -- Предопределенные цвета для пар инструмент-шина (R, G, B)
    -- Сгруппированы по семействам цветов
    local colors = {
        -- Струнная группа (красные оттенки)
        [1] = {235, 87, 87},     -- Красный
        [2] = {231, 76, 60},     -- Темно-красный
        [3] = {192, 57, 43},     -- Бордовый
        [4] = {211, 84, 0},     -- Темно-оранжевый
        [5] = {242, 153, 74},   -- Оранжевый
        
        -- Деревянные духовые (зеленые оттенки)
        [6] = {39, 174, 96},    -- Зеленый
        [7] = {46, 204, 113},   -- Ярко-зеленый
        [8] = {147, 196, 125},  -- Светло-зеленый
        [9] = {22, 160, 133},   -- Бирюзово-зеленый
        [10] = {0, 148, 50},    -- Темно-зеленый
        
        -- Медные духовые (синие оттенки)
        [11] = {47, 128, 237},   -- Синий
        [12] = {52, 152, 219},   -- Светло-синий
        [13] = {41, 128, 185},   -- Темно-голубой
        [14] = {111, 168, 220},  -- Голубой
        [15] = {44, 62, 80},     -- Темно-синий
        
        -- Ударные (фиолетовые оттенки)
        [16] = {155, 81, 224},   -- Фиолетовый
        [17] = {142, 68, 173},   -- Темно-фиолетовый
        [18] = {184, 153, 218},  -- Светло-фиолетовый
        [19] = {165, 105, 189},  -- Аметистовый
        [20] = {125, 60, 152},   -- Глубокий фиолетовый
        
        -- Дополнительная группа (теплые оттенки)
        [21] = {243, 156, 18},   -- Желтый
        [22] = {246, 178, 107},  -- Светло-оранжевый
        [23] = {230, 126, 34},   -- Мандариновый
        [24] = {211, 84, 0},     -- Тыквенный
        [25] = {120, 111, 166}   -- Серо-фиолетовый
    }
    
    -- Цвета для мастер-секции (градиент от синего к фиолетовому)
    local masterColors = {
        ["[ANALOG]"] = {123, 97, 255},     -- Индиго
        ["[MFIT]"] = {88, 134, 255},       -- Синий
        ["[ENDCHAIN]"] = {155, 81, 224}    -- Фиолетовый
    }
    
    -- Определяем номер инструмента/шины из имени
    local number = tonumber(string.match(trackName, "%d+"))
    
    -- Если это мастер-секция
    if masterColors[trackName] then
        return reaper.ColorToNative(
            masterColors[trackName][1],
            masterColors[trackName][2],
            masterColors[trackName][3]
        )
    end
    
    -- Если нашли номер и есть соответствующий цвет
    if number and colors[number] then
        return reaper.ColorToNative(
            colors[number][1],
            colors[number][2],
            colors[number][3]
        )
    end
    
    -- Возвращаем дефолтный цвет, если ничего не подошло
    return reaper.ColorToNative(180, 180, 180)
end



function colorizeTrack(track, name)
    if track then
        local color = getMatchingColor(name)
        reaper.SetTrackColor(track, color)
    end
end

function hasFX(track, fxName)
    local fxCount = reaper.TrackFX_GetCount(track)
    for i = 0, fxCount - 1 do
        local retval, buf = reaper.TrackFX_GetFXName(track, i, "")
        if retval and buf:find(fxName) then
            return true
        end
    end
    return false
end

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

function setupMonitoring(track, position)
    local _, name = reaper.GetTrackName(track)
    reaper.ShowConsoleMsg(string.format("\nНастройка мониторинга для %s (%s)...\n", name, position))
    
    -- Сначала удалим все существующие SPAN Plus
    local fxCount = reaper.TrackFX_GetCount(track)
    for i = fxCount - 1, 0, -1 do
        local retval, buf = reaper.TrackFX_GetFXName(track, i, "")
        if buf:find("SPAN Plus") then
            reaper.TrackFX_Delete(track, i)
        end
    end
    
    -- Добавляем один SPAN Plus
    if addFXToTrack(track, "SPAN Plus") then
        local fxCount = reaper.TrackFX_GetCount(track)
        local spanIndex = fxCount - 1
        
        reaper.TrackFX_SetEnabled(track, spanIndex, false)
        reaper.ShowConsoleMsg("SPAN Plus добавлен и настроен в bypassed режиме\n")
    end
end

function getTrackName(track)
    if not track then
        reaper.ShowConsoleMsg("Ошибка: передан недопустимый трек в getTrackName.\n")
        return "Неизвестный трек"
    end
    if not reaper.ValidatePtr(track, "MediaTrack*") then
        reaper.ShowConsoleMsg("Ошибка: Недействительный трек передан в GetTrackName.\n")
        return "Неизвестный трек"
    end
    local _, name = reaper.GetTrackName(track)
    return name
end

function getTrackByNumber(number)
    local track = reaper.GetTrack(0, number - 1)
    if not reaper.ValidatePtr(track, "MediaTrack*") then
        reaper.ShowConsoleMsg(string.format("Ошибка: Track #%d не является MediaTrack.\n", number))
        return nil
    end
    return track
end

function createSend(sourceTrack, destTrack, sendVolDB, sendMode)
    if not reaper.ValidatePtr(sourceTrack, "MediaTrack*") or not reaper.ValidatePtr(destTrack, "MediaTrack*") then
        reaper.ShowConsoleMsg("Ошибка: один из треков недействителен в createSend.\n")
        return
    end

    if not sourceTrack or not destTrack then
        reaper.ShowConsoleMsg("Ошибка: один из треков отсутствует!\n")
        return
    end

    local sourceName = getTrackName(sourceTrack)
    local destName = getTrackName(destTrack)

    -- Проверяем существующие sends
    local numSends = reaper.GetTrackNumSends(sourceTrack, 0)
    for i = 0, numSends - 1 do
        local destTrackExisting = reaper.GetTrackSendInfo_Value(sourceTrack, 0, i, "P_DESTTRACK")
        if destTrackExisting == destTrack then
            -- Обновляем существующую отправку
            local vol = math.exp(sendVolDB * 0.11512925464970229)
            reaper.SetTrackSendInfo_Value(sourceTrack, 0, i, "D_VOL", vol)
            reaper.SetTrackSendInfo_Value(sourceTrack, 0, i, "I_SENDMODE", sendMode or 0)
            reaper.ShowConsoleMsg(string.format("Обновлен send: %s -> %s (%.1f dB, режим: %d)\n", 
                sourceName, destName, sendVolDB, sendMode or 0))
            return
        end
    end

    -- Создаем новую отправку
    local sendIdx = reaper.CreateTrackSend(sourceTrack, destTrack)
    local vol = math.exp(sendVolDB * 0.11512925464970229)
    reaper.SetTrackSendInfo_Value(sourceTrack, 0, sendIdx, "D_VOL", vol)
    reaper.SetTrackSendInfo_Value(sourceTrack, 0, sendIdx, "I_SENDMODE", sendMode or 0)
    
    reaper.ShowConsoleMsg(string.format("Создан send: %s -> %s (%.1f dB, режим: %d)\n", 
        sourceName, destName, sendVolDB, sendMode or 0))
end

function removeDuplicateSends(sourceTrack)
    if not sourceTrack then return end
    
    local destMap = {}
    local _, sourceName = reaper.GetTrackName(sourceTrack)
    local numSends = reaper.GetTrackNumSends(sourceTrack, 0)
    
    local sends = {}
    for i = 0, numSends - 1 do
        local destTrack = reaper.GetTrackSendInfo_Value(sourceTrack, 0, i, "P_DESTTRACK")
        if destTrack then
            local sendMode = reaper.GetTrackSendInfo_Value(sourceTrack, 0, i, "I_SENDMODE")
            local sendVol = reaper.GetTrackSendInfo_Value(sourceTrack, 0, i, "D_VOL")
            
            if not destMap[tostring(destTrack)] then
                destMap[tostring(destTrack)] = {
                    index = i,
                    mode = sendMode,
                    volume = sendVol,
                    track = destTrack
                }
            else
                local existingVol = destMap[tostring(destTrack)].volume
                if sendVol > existingVol then
                    table.insert(sends, destMap[tostring(destTrack)].index)
                    destMap[tostring(destTrack)] = {
                        index = i,
                        mode = sendMode,
                        volume = sendVol,
                        track = destTrack
                    }
                else
                    table.insert(sends, i)
                end
            end
        end
    end

    table.sort(sends, function(a, b) return a > b end)

    for _, sendIdx in ipairs(sends) do
        local destTrack = reaper.GetTrackSendInfo_Value(sourceTrack, 0, sendIdx, "P_DESTTRACK")
        local _, destName = reaper.GetTrackName(destTrack)
        reaper.RemoveTrackSend(sourceTrack, 0, sendIdx)
        reaper.ShowConsoleMsg(string.format("Удалена дублирующаяся отправка: %s -> %s\n", 
            sourceName, destName))
    end
end

function createRoutingStructure()
   -- Инициализация треков с их номерами
   local tracks = {
       -- Инструменты (1-25)
       ["[INST 1]"] = 1, ["[INST 2]"] = 2, ["[INST 3]"] = 3, ["[INST 4]"] = 4, ["[INST 5]"] = 5,
       ["[INST 6]"] = 6, ["[INST 7]"] = 7, ["[INST 8]"] = 8, ["[INST 9]"] = 9, ["[INST 10]"] = 10,
       ["[INST 11]"] = 11, ["[INST 12]"] = 12, ["[INST 13]"] = 13, ["[INST 14]"] = 14, ["[INST 15]"] = 15,
       ["[INST 16]"] = 16, ["[INST 17]"] = 17, ["[INST 18]"] = 18, ["[INST 19]"] = 19, ["[INST 20]"] = 20,
       ["[INST 21]"] = 21, ["[INST 22]"] = 22, ["[INST 23]"] = 23, ["[INST 24]"] = 24, ["[INST 25]"] = 25,
       
       -- Шины (26-50)
       ["[BUS 1]"] = 26, ["[BUS 2]"] = 27, ["[BUS 3]"] = 28, ["[BUS 4]"] = 29, ["[BUS 5]"] = 30,
       ["[BUS 6]"] = 31, ["[BUS 7]"] = 32, ["[BUS 8]"] = 33, ["[BUS 9]"] = 34, ["[BUS 10]"] = 35,
       ["[BUS 11]"] = 36, ["[BUS 12]"] = 37, ["[BUS 13]"] = 38, ["[BUS 14]"] = 39, ["[BUS 15]"] = 40,
       ["[BUS 16]"] = 41, ["[BUS 17]"] = 42, ["[BUS 18]"] = 43, ["[BUS 19]"] = 44, ["[BUS 20]"] = 45,
       ["[BUS 21]"] = 46, ["[BUS 22]"] = 47, ["[BUS 23]"] = 48, ["[BUS 24]"] = 49, ["[BUS 25]"] = 50,
       
       -- Мастер секция (51-53)
       ["[ANALOG]"] = 51,
       ["[MFIT]"] = 52,
       ["[ENDCHAIN]"] = 53
   }
   
   -- Создаем ссылки на треки и применяем базовые настройки
   local trackRefs = {}
   for name, number in pairs(tracks) do
       trackRefs[name] = getTrackByNumber(number)
       if not trackRefs[name] then
           return false, tracks
       end
       
       colorizeTrack(trackRefs[name], name)
       reaper.SetMediaTrackInfo_Value(trackRefs[name], "B_MUTE", 0)
       reaper.SetMediaTrackInfo_Value(trackRefs[name], "D_VOL", 1.0)
       
       -- Очистка существующих отправок
       local numSends = reaper.GetTrackNumSends(trackRefs[name], 0)
       for i = numSends - 1, 0, -1 do
           reaper.RemoveTrackSend(trackRefs[name], 0, i)
       end
   end

   -- Маршрутизация источников на шины
   for i = 1, 25 do
       local source = trackRefs[string.format("[INST %d]", i)]
       local dest = trackRefs[string.format("[BUS %d]", i)]
       if source and dest then
           createSend(source, dest, 0, 0)  -- Post-Fader
       end
   end

   -- Маршрутизация шин в analog_master
   for i = 1, 25 do
       local source = trackRefs[string.format("[BUS %d]", i)]
       if source then
           createSend(source, trackRefs["[ANALOG]"], -6, 0)  -- Post-Fader
       end
   end

   -- Маршрутизация мастер-цепи
   createSend(trackRefs["[ANALOG]"], trackRefs["[MFIT]"], -6, 0)
   createSend(trackRefs["[MFIT]"], trackRefs["[ENDCHAIN]"], -6, 0)

   -- Настройка мониторинга
   for name, track in pairs(trackRefs) do
       if string.find(name, "BUS") or name == "[ANALOG]" or name == "[MFIT]" then
           setupMonitoring(track, "bus")
       end
   end
   setupMonitoring(trackRefs["[ENDCHAIN]"], "final-output")

   -- MainSend настройки
   for name, track in pairs(trackRefs) do
       if string.find(name, "BUS") or name == "[ANALOG]" or name == "[MFIT]" then
           reaper.SetMediaTrackInfo_Value(track, "B_MAINSEND", 0)
       else
           reaper.SetMediaTrackInfo_Value(track, "B_MAINSEND", 1)
       end
   end
    -- После настройки всех треков и маршрутизации
    setupTrackGrouping(trackRefs, 1, 25)  -- 25 пар INST/BUS

    return true, trackRefs
end

function verifyInitialState()
    if reaper.GetProjectName(0, "") == "" then
        reaper.ShowMessageBox(
            "No project is open. Please open a project first.", 
            "Error", 
            0)
        return false
    end
    
    if reaper.CountTracks(0) < 53 then  -- Обновленное количество треков
        local create = reaper.ShowMessageBox(
            "Проект требует 53 трека. Создать треки автоматически?", 
            "Создание треков", 
            4)
        
        if create == 6 then
            return createTracks()
        else
            return false
        end
    end
    
    return true
end

function main()
    if not verifyInitialState() then
        return
    end

    math.randomseed(os.time())
    reaper.ShowConsoleMsg("=== Начало выполнения скрипта ===\n")

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
        reaper.ShowConsoleMsg("Цвета треков сброшены.\n")
    end

    -- Создаем структуру маршрутизации
    local success, trackRefs = createRoutingStructure()
    if not success then
        reaper.ShowConsoleMsg("\nОШИБКА: Не все треки найдены!\n")
        reaper.ShowMessageBox(
            "Один или несколько треков не найдены. Проверьте номера треков.", 
            "Ошибка", 
            0)
        return
    end

    -- Убираем дубликаты отправок
    for name, track in pairs(trackRefs) do
        if track then
            removeDuplicateSends(track)
        end
    end

    reaper.TrackList_AdjustWindows(false)
    reaper.UpdateArrange()

    reaper.ShowMessageBox(
        "Маршрутизация успешно создана.", 
        "Успех", 
        0)

    reaper.ShowConsoleMsg("=== Завершение выполнения скрипта ===\n")
end

-- Запускаем скрипт
reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Create Routing Structure", -1)
