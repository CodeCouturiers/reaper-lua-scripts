
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
function createFolderStructure()
    reaper.ShowConsoleMsg("\n=== Creating Folder Structure ===\n")
    
    -- Create Master Group folder
    reaper.InsertTrackAtIndex(0, true)
    local masterGroupTrack = reaper.GetTrack(0, 0)
    reaper.GetSetMediaTrackInfo_String(masterGroupTrack, "P_NAME", "[MASTER GROUP]", true)
    reaper.SetMediaTrackInfo_Value(masterGroupTrack, "I_FOLDERDEPTH", 1)
    colorizeTrack(masterGroupTrack, "[MASTER GROUP]")
    
    local currentIndex = 1
    
    -- Create 5 groups
    for groupNum = 1, 5 do
        -- Create Group folder
        reaper.InsertTrackAtIndex(currentIndex, true)
        local groupTrack = reaper.GetTrack(0, currentIndex)
        local groupName = string.format("[GROUP %d]", groupNum)
        reaper.GetSetMediaTrackInfo_String(groupTrack, "P_NAME", groupName, true)
        reaper.SetMediaTrackInfo_Value(groupTrack, "I_FOLDERDEPTH", 1)
        colorizeTrack(groupTrack, groupName)
        currentIndex = currentIndex + 1
        
        -- Create INST GROUP folder
        reaper.InsertTrackAtIndex(currentIndex, true)
        local instGroupTrack = reaper.GetTrack(0, currentIndex)
        local instGroupName = string.format("[INST GROUP %d]", groupNum)
        reaper.GetSetMediaTrackInfo_String(instGroupTrack, "P_NAME", instGroupName, true)
        reaper.SetMediaTrackInfo_Value(instGroupTrack, "I_FOLDERDEPTH", 1)
        colorizeTrack(instGroupTrack, instGroupName) -- Используем собственный цвет группы
        currentIndex = currentIndex + 1
        
        -- Create INST tracks
        for i = 1, 5 do
            reaper.InsertTrackAtIndex(currentIndex, true)
            local instTrack = reaper.GetTrack(0, currentIndex)
            local instNum = (groupNum - 1) * 5 + i
            local instName = string.format("[INST %d]", instNum)
            reaper.GetSetMediaTrackInfo_String(instTrack, "P_NAME", instName, true)
            colorizeTrack(instTrack, instName)
            currentIndex = currentIndex + 1
        end
        reaper.SetMediaTrackInfo_Value(reaper.GetTrack(0, currentIndex - 1), "I_FOLDERDEPTH", -1)
        
        -- Create BUS GROUP folder
        reaper.InsertTrackAtIndex(currentIndex, true)
        local busGroupTrack = reaper.GetTrack(0, currentIndex)
        local busGroupName = string.format("[BUS GROUP %d]", groupNum)
        reaper.GetSetMediaTrackInfo_String(busGroupTrack, "P_NAME", busGroupName, true)
        reaper.SetMediaTrackInfo_Value(busGroupTrack, "I_FOLDERDEPTH", 1)
        colorizeTrack(busGroupTrack, busGroupName) -- Используем собственный цвет группы
        currentIndex = currentIndex + 1
        
        -- Create BUS tracks
        for i = 1, 5 do
            reaper.InsertTrackAtIndex(currentIndex, true)
            local busTrack = reaper.GetTrack(0, currentIndex)
            local busNum = (groupNum - 1) * 5 + i
            local busName = string.format("[BUS %d]", busNum)
            reaper.GetSetMediaTrackInfo_String(busTrack, "P_NAME", busName, true)
            colorizeTrack(busTrack, busName)
            currentIndex = currentIndex + 1
        end
        reaper.SetMediaTrackInfo_Value(reaper.GetTrack(0, currentIndex - 1), "I_FOLDERDEPTH", -2)
    end
    
    -- Create Master Section folder with proper color
    reaper.InsertTrackAtIndex(currentIndex, true)
    local masterSectionTrack = reaper.GetTrack(0, currentIndex)
    reaper.GetSetMediaTrackInfo_String(masterSectionTrack, "P_NAME", "[MASTER SECTION]", true)
    reaper.SetMediaTrackInfo_Value(masterSectionTrack, "I_FOLDERDEPTH", 1)
    colorizeTrack(masterSectionTrack, "[MASTER SECTION]")
    currentIndex = currentIndex + 1
    
    -- Create master section tracks with proper colors
    local masterTracks = {"[ANALOG]", "[MFIT]", "[ENDCHAIN]"}
    for i, name in ipairs(masterTracks) do
        reaper.InsertTrackAtIndex(currentIndex, true)
        local track = reaper.GetTrack(0, currentIndex)
        reaper.GetSetMediaTrackInfo_String(track, "P_NAME", name, true)
        colorizeTrack(track, name)
        currentIndex = currentIndex + 1
    end
    
    -- Close the master section folder
    reaper.SetMediaTrackInfo_Value(reaper.GetTrack(0, currentIndex - 1), "I_FOLDERDEPTH", -2)
    
    reaper.ShowConsoleMsg("Folder structure created successfully\n")
    return true
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
        -- Группа 1 (красные оттенки)
        [1] = {235, 87, 87},     -- Красный
        [2] = {231, 76, 60},     -- Темно-красный
        [3] = {192, 57, 43},     -- Бордовый
        [4] = {211, 84, 0},      -- Темно-оранжевый
        [5] = {242, 153, 74},    -- Оранжевый
        
        -- Группа 2 (зеленые оттенки)
        [6] = {39, 174, 96},     -- Зеленый
        [7] = {46, 204, 113},    -- Ярко-зеленый
        [8] = {147, 196, 125},   -- Светло-зеленый
        [9] = {22, 160, 133},    -- Бирюзово-зеленый
        [10] = {0, 148, 50},     -- Темно-зеленый
        
        -- Группа 3 (синие оттенки)
        [11] = {47, 128, 237},   -- Синий
        [12] = {52, 152, 219},   -- Светло-синий
        [13] = {41, 128, 185},   -- Темно-голубой
        [14] = {111, 168, 220},  -- Голубой
        [15] = {44, 62, 80},     -- Темно-синий
        
        -- Группа 4 (фиолетовые оттенки)
        [16] = {155, 81, 224},   -- Фиолетовый
        [17] = {142, 68, 173},   -- Темно-фиолетовый
        [18] = {184, 153, 218},  -- Светло-фиолетовый
        [19] = {165, 105, 189},  -- Аметистовый
        [20] = {125, 60, 152},   -- Глубокий фиолетовый
        
        -- Группа 5 (золотистые оттенки)
        [21] = {243, 156, 18},   -- Золотой
        [22] = {246, 178, 107},  -- Светло-золотой
        [23] = {230, 126, 34},   -- Темно-золотой
        [24] = {211, 84, 0},     -- Янтарный
        [25] = {243, 156, 18}    -- Золотой
    }
    
    -- Цвета для групп и мастер-секции
    local specialColors = {
        ["[GROUP 1]"] = {235, 87, 87},       -- Красный
        ["[GROUP 2]"] = {39, 174, 96},       -- Зеленый
        ["[GROUP 3]"] = {47, 128, 237},      -- Синий
        ["[GROUP 4]"] = {155, 81, 224},      -- Фиолетовый
        ["[GROUP 5]"] = {243, 156, 18},      -- Золотой
        ["[MASTER GROUP]"] = {88, 134, 255}, -- Светло-синий
        ["[MASTER SECTION]"] = {123, 97, 255}, -- Индиго
        ["[ANALOG]"] = {123, 97, 255},       -- Индиго
        ["[MFIT]"] = {88, 134, 255},         -- Светло-синий
        ["[ENDCHAIN]"] = {155, 81, 224}      -- Фиолетовый
    }
    
    -- Цвета для группировки треков
    local groupColors = {
        ["[INST GROUP 1]"] = {235, 87, 87},   -- Красный
        ["[BUS GROUP 1]"] = {235, 87, 87},    -- Красный
        ["[INST GROUP 2]"] = {39, 174, 96},   -- Зеленый
        ["[BUS GROUP 2]"] = {39, 174, 96},    -- Зеленый
        ["[INST GROUP 3]"] = {47, 128, 237},  -- Синий
        ["[BUS GROUP 3]"] = {47, 128, 237},   -- Синий
        ["[INST GROUP 4]"] = {155, 81, 224},  -- Фиолетовый
        ["[BUS GROUP 4]"] = {155, 81, 224},   -- Фиолетовый
        ["[INST GROUP 5]"] = {243, 156, 18},  -- Золотой
        ["[BUS GROUP 5]"] = {243, 156, 18}    -- Золотой
    }
    
    -- Проверяем специальные цвета для групп и мастер-секции
    if specialColors[trackName] then
        return reaper.ColorToNative(
            specialColors[trackName][1],
            specialColors[trackName][2],
            specialColors[trackName][3]
        )
    end
    
    -- Проверяем цвета для группировки треков
    if groupColors[trackName] then
        return reaper.ColorToNative(
            groupColors[trackName][1],
            groupColors[trackName][2],
            groupColors[trackName][3]
        )
    end
    
    -- Определяем номер инструмента/шины из имени
    local number = tonumber(string.match(trackName, "%d+"))
    
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
    reaper.ShowConsoleMsg("\n=== Создание структуры маршрутизации ===\n")
    
    -- Инициализация треков с их номерами
    local tracks = {
        -- Master Group
        ["[MASTER GROUP]"] = 1,
        
        -- Groups
        ["[GROUP 1]"] = 2,
        ["[GROUP 2]"] = 15,
        ["[GROUP 3]"] = 28,
        ["[GROUP 4]"] = 41,
        ["[GROUP 5]"] = 54,
        
        -- Inst Groups
        ["[INST GROUP 1]"] = 3,
        ["[INST GROUP 2]"] = 16,
        ["[INST GROUP 3]"] = 29,
        ["[INST GROUP 4]"] = 42,
        ["[INST GROUP 5]"] = 55,
        
        -- Bus Groups
        ["[BUS GROUP 1]"] = 9,
        ["[BUS GROUP 2]"] = 22,
        ["[BUS GROUP 3]"] = 35,
        ["[BUS GROUP 4]"] = 48,
        ["[BUS GROUP 5]"] = 61,
        
        -- Instruments (1-25)
        ["[INST 1]"] = 4, ["[INST 2]"] = 5, ["[INST 3]"] = 6, ["[INST 4]"] = 7, ["[INST 5]"] = 8,
        ["[INST 6]"] = 17, ["[INST 7]"] = 18, ["[INST 8]"] = 19, ["[INST 9]"] = 20, ["[INST 10]"] = 21,
        ["[INST 11]"] = 30, ["[INST 12]"] = 31, ["[INST 13]"] = 32, ["[INST 14]"] = 33, ["[INST 15]"] = 34,
        ["[INST 16]"] = 43, ["[INST 17]"] = 44, ["[INST 18]"] = 45, ["[INST 19]"] = 46, ["[INST 20]"] = 47,
        ["[INST 21]"] = 56, ["[INST 22]"] = 57, ["[INST 23]"] = 58, ["[INST 24]"] = 59, ["[INST 25]"] = 60,
        
        -- Buses (1-25)
        ["[BUS 1]"] = 10, ["[BUS 2]"] = 11, ["[BUS 3]"] = 12, ["[BUS 4]"] = 13, ["[BUS 5]"] = 14,
        ["[BUS 6]"] = 23, ["[BUS 7]"] = 24, ["[BUS 8]"] = 25, ["[BUS 9]"] = 26, ["[BUS 10]"] = 27,
        ["[BUS 11]"] = 36, ["[BUS 12]"] = 37, ["[BUS 13]"] = 38, ["[BUS 14]"] = 39, ["[BUS 15]"] = 40,
        ["[BUS 16]"] = 49, ["[BUS 17]"] = 50, ["[BUS 18]"] = 51, ["[BUS 19]"] = 52, ["[BUS 20]"] = 53,
        ["[BUS 21]"] = 62, ["[BUS 22]"] = 63, ["[BUS 23]"] = 64, ["[BUS 24]"] = 65, ["[BUS 25]"] = 66,
        
        -- Master Section
        ["[MASTER SECTION]"] = 67,
        ["[ANALOG]"] = 68,
        ["[MFIT]"] = 69,
        ["[ENDCHAIN]"] = 70
    }
    
    reaper.ShowConsoleMsg("Инициализация треков...\n")
    
    -- Создаем ссылки на треки и применяем базовые настройки
    local trackRefs = {}
    for name, number in pairs(tracks) do
        trackRefs[name] = getTrackByNumber(number)
        if not trackRefs[name] then
            reaper.ShowConsoleMsg(string.format("ОШИБКА: Не найден трек %s (номер %d)\n", name, number))
            return false, tracks
        end
        
        -- Базовые настройки
        colorizeTrack(trackRefs[name], name)
        reaper.SetMediaTrackInfo_Value(trackRefs[name], "B_MUTE", 0)
        reaper.SetMediaTrackInfo_Value(trackRefs[name], "D_VOL", 1.0)
        
        -- Очистка существующих отправок
        local numSends = reaper.GetTrackNumSends(trackRefs[name], 0)
        for i = numSends - 1, 0, -1 do
            reaper.RemoveTrackSend(trackRefs[name], 0, i)
        end
    end
    
    reaper.ShowConsoleMsg("\n=== Создание маршрутизации INST -> INST GROUP ===\n")
    -- Routing: INST -> INST GROUP
    for i = 1, 20 do
        local groupNum = math.ceil(i/4)
        local instName = string.format("[INST %d]", i)
        local instGroupName = string.format("[INST GROUP %d]", groupNum)
        if trackRefs[instName] and trackRefs[instGroupName] then
            createSend(trackRefs[instName], trackRefs[instGroupName], 0.0, 0)
            reaper.ShowConsoleMsg(string.format("Создан маршрут: %s -> %s\n", instName, instGroupName))
        end
    end
    
    reaper.ShowConsoleMsg("\n=== Создание маршрутизации INST GROUP -> BUS GROUP ===\n")
    -- Routing: INST GROUP -> BUS GROUP
    for i = 1, 5 do
        local instGroupName = string.format("[INST GROUP %d]", i)
        local busGroupName = string.format("[BUS GROUP %d]", i)
        if trackRefs[instGroupName] and trackRefs[busGroupName] then
            createSend(trackRefs[instGroupName], trackRefs[busGroupName], 0.0, 0)
            reaper.ShowConsoleMsg(string.format("Создан маршрут: %s -> %s\n", instGroupName, busGroupName))
        end
    end
    
    reaper.ShowConsoleMsg("\n=== Создание маршрутизации BUS GROUP -> GROUP ===\n")
    -- Routing: BUS GROUP -> GROUP
    for i = 1, 5 do
        local busGroupName = string.format("[BUS GROUP %d]", i)
        local groupName = string.format("[GROUP %d]", i)
        if trackRefs[busGroupName] and trackRefs[groupName] then
            createSend(trackRefs[busGroupName], trackRefs[groupName], 0.0, 0)
            reaper.ShowConsoleMsg(string.format("Создан маршрут: %s -> %s\n", busGroupName, groupName))
        end
    end
    
    reaper.ShowConsoleMsg("\n=== Создание маршрутизации GROUP -> ANALOG ===\n")
    -- Routing: GROUP -> ANALOG
    for i = 1, 5 do
        local groupName = string.format("[GROUP %d]", i)
        if trackRefs[groupName] and trackRefs["[ANALOG]"] then
            createSend(trackRefs[groupName], trackRefs["[ANALOG]"], -6.0, 0)
            reaper.ShowConsoleMsg(string.format("Создан маршрут: %s -> ANALOG\n", groupName))
        end
    end
    
    reaper.ShowConsoleMsg("\n=== Создание цепочки мастер-секции ===\n")
    -- Master chain
    if trackRefs["[ANALOG]"] and trackRefs["[MFIT]"] then
        createSend(trackRefs["[ANALOG]"], trackRefs["[MFIT]"], -6.0, 0)
        reaper.ShowConsoleMsg("Создан маршрут: ANALOG -> MFIT\n")
    end
    if trackRefs["[MFIT]"] and trackRefs["[ENDCHAIN]"] then
        createSend(trackRefs["[MFIT]"], trackRefs["[ENDCHAIN]"], -6.0, 0)
        reaper.ShowConsoleMsg("Создан маршрут: MFIT -> ENDCHAIN\n")
    end
    
    reaper.ShowConsoleMsg("\n=== Настройка мониторинга ===\n")
    -- Настройка мониторинга
    for name, track in pairs(trackRefs) do
        if string.find(name, "BUS") or string.find(name, "GROUP") or name == "[ANALOG]" or name == "[MFIT]" then
            setupMonitoring(track, "bus")
        end
    end
    if trackRefs["[ENDCHAIN]"] then
        setupMonitoring(trackRefs["[ENDCHAIN]"], "final-output")
    end
    
    reaper.ShowConsoleMsg("\n=== Настройка MainSend ===\n")
    -- MainSend настройки
    for name, track in pairs(trackRefs) do
        if string.find(name, "BUS") or string.find(name, "GROUP") or 
           name == "[ANALOG]" or name == "[MFIT]" or name == "[ENDCHAIN]" then
            reaper.SetMediaTrackInfo_Value(track, "B_MAINSEND", 0)
            reaper.ShowConsoleMsg(string.format("MainSend отключен для %s\n", name))
        else
            reaper.SetMediaTrackInfo_Value(track, "B_MAINSEND", 1)
            reaper.ShowConsoleMsg(string.format("MainSend включен для %s\n", name))
        end
    end
    
    -- Группировка треков
    reaper.ShowConsoleMsg("\n=== Настройка групп ===\n")
    setupTrackGrouping(trackRefs)
    
    reaper.ShowConsoleMsg("\n=== Структура маршрутизации создана успешно ===\n")
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
    
    -- Calculate total number of tracks needed:
    -- 1 Master Group track
    -- 5 Group tracks
    -- 5 INST GROUP tracks
    -- 25 INST tracks
    -- 5 BUS GROUP tracks
    -- 25 BUS tracks
    -- 1 MASTER SECTION track
    -- 3 master section tracks (ANALOG, MFIT, ENDCHAIN)
    -- Total: 70 tracks
    local requiredTracks = 70
    
    if reaper.CountTracks(0) < requiredTracks then
        local create = reaper.ShowMessageBox(
            string.format("Project requires %d tracks. Create tracks automatically?", requiredTracks), 
            "Create Tracks", 
            4)
        
        if create == 6 then
            return createFolderStructure()
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
    reaper.ShowConsoleMsg("=== Starting Script Execution ===\n")

    local reset = reaper.ShowMessageBox(
        "Reset track colors before creating routing?", 
        "Reset Colors", 
        4)

    if reset == 6 then
        local trackCount = reaper.CountTracks(0)
        for i = 0, trackCount - 1 do
            local track = reaper.GetTrack(0, i)
            reaper.SetTrackColor(track, 0)
        end
        reaper.ShowConsoleMsg("Track colors have been reset.\n")
    end

    -- Create routing structure
    local success, trackRefs = createRoutingStructure()
    if not success then
        reaper.ShowConsoleMsg("\nERROR: Not all tracks were found!\n")
        reaper.ShowMessageBox(
            "One or more tracks were not found. Check track numbers.", 
            "Error", 
            0)
        return
    end

    -- Remove duplicate sends
    for name, track in pairs(trackRefs) do
        if track then
            removeDuplicateSends(track)
        end
    end

    reaper.TrackList_AdjustWindows(false)
    reaper.UpdateArrange()

    reaper.ShowMessageBox(
        "Routing created successfully.", 
        "Success", 
        0)

    reaper.ShowConsoleMsg("=== Script Execution Complete ===\n")
end

-- Запускаем скрипт
reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Create Routing Structure", -1)
