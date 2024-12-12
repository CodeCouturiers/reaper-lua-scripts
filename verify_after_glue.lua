-- Post-bounce verification script
function verifyTrackStructure()
    reaper.ClearConsole()
    reaper.ShowConsoleMsg("=== НАЧАЛО ПРОВЕРКИ ПОСЛЕ СКЛЕЙКИ ===\n")
    
    local expectedTracks = {
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
    
    local issues = {}
    
    -- Verify track count
    local trackCount = reaper.CountTracks(0)
    if trackCount < 12 then
        table.insert(issues, string.format("Недостаточно треков: найдено %d, ожидается минимум 12", trackCount))
        return issues
    end
    
    -- Check each expected track
    for name, number in pairs(expectedTracks) do
        local track = reaper.GetTrack(0, number - 1)
        if not track then
            table.insert(issues, string.format("Трек %s (#%d) не найден", name, number))
            goto continue
        end
        
        -- Get track name
        local _, trackName = reaper.GetTrackName(track)
        
        -- Check track properties
        local volume = reaper.GetMediaTrackInfo_Value(track, "D_VOL")
        local volumeDB = 20 * math.log(volume, 10)
        local mute = reaper.GetMediaTrackInfo_Value(track, "B_MUTE")
        local phase = reaper.GetMediaTrackInfo_Value(track, "B_PHASE")
        local fxEnabled = reaper.GetMediaTrackInfo_Value(track, "I_FXEN")
        
        -- Volume check (warning if too low or too high)
        if volumeDB < -60 then
            table.insert(issues, string.format("Трек %s: очень низкая громкость (%.1f dB)", name, volumeDB))
        elseif volumeDB > 12 then
            table.insert(issues, string.format("Трек %s: очень высокая громкость (%.1f dB)", name, volumeDB))
        end
        
        -- Mute check
        if mute == 1 then
            table.insert(issues, string.format("Трек %s замьючен", name))
        end
        
        -- Phase check
        if phase == 1 then
            table.insert(issues, string.format("Трек %s: инвертирована фаза", name))
        end
        
        -- FX chain check
        if fxEnabled == 0 then
            table.insert(issues, string.format("Трек %s: FX цепь отключена", name))
        end
        
        -- Check for media items if it's a source track
        if name == "violin" or name == "bass" or name == "timpani" or name == "drums" then
            local itemCount = reaper.GetTrackNumMediaItems(track)
            if itemCount == 0 then
                table.insert(issues, string.format("Трек %s: нет медиа айтемов после склейки", name))
            end
        end
        
        -- Check sends for buses
        if string.find(name, "bus") then
            local numSends = reaper.GetTrackNumSends(track, 0)
            if numSends == 0 then
                table.insert(issues, string.format("Шина %s: нет отправок (sends)", name))
            end
        end
        
        ::continue::
    end
    
    -- Additional checks for master section
    local masterTrack = reaper.GetTrack(0, 11) -- track 12 (index 11)
    if masterTrack then
        local masterVolume = reaper.GetMediaTrackInfo_Value(masterTrack, "D_VOL")
        local masterVolumeDB = 20 * math.log(masterVolume, 10)
        
        if masterVolumeDB > 0 then
            table.insert(issues, string.format("Master: громкость выше 0 dB (%.1f dB)", masterVolumeDB))
        end
    end
    
    -- Print results
    reaper.ShowConsoleMsg("\n=== РЕЗУЛЬТАТЫ ПРОВЕРКИ ===\n")
    
    if #issues == 0 then
        reaper.ShowConsoleMsg("\nВсе проверки пройдены успешно!\n")
        reaper.ShowMessageBox("Все проверки пройдены успешно!", "Результат проверки", 0)
    else
        reaper.ShowConsoleMsg("\nНайдены проблемы:\n")
        for _, issue in ipairs(issues) do
            reaper.ShowConsoleMsg("- " .. issue .. "\n")
        end
        
        reaper.ShowMessageBox(
            string.format("Найдено %d проблем. Проверьте консоль REAPER для деталей.", #issues),
            "Результат проверки",
            0)
    end
    
    return issues
end

-- Execute verification
reaper.PreventUIRefresh(1)
local issues = verifyTrackStructure()
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()
