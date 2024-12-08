-- Скрипт для сброса настроек дорожек в оптимальное состояние для сведения/мастеринга
function ResetMixingSettings()
  local project = 0
  local track_count = reaper.CountTracks(project)
  local reset_count = 0
  local master_reset = false
  
  -- Функция для безопасного сброса значения
  local function safeResetValue(track, param, default_value)
    local current_value = reaper.GetMediaTrackInfo_Value(track, param)
    if current_value ~= default_value then
      reaper.SetMediaTrackInfo_Value(track, param, default_value)
      return true
    end
    return false
  end
  
  -- Сброс настроек мастер-шины
  local master = reaper.GetMasterTrack(project)
  
  -- Сброс громкости мастера в 0 dB
  if safeResetValue(master, "D_VOL", 1.0) then
    master_reset = true
  end
  
  -- Сброс панорамы мастера в центр
  if safeResetValue(master, "D_PAN", 0.0) then
    master_reset = true
  end
  
  -- Сброс ширины стерео мастера
  if safeResetValue(master, "D_WIDTH", 1.0) then
    master_reset = true
  end
  
  -- Отключение соло/мьюта на мастере
  if safeResetValue(master, "B_MUTE", 0) then
    master_reset = true
  end
  if safeResetValue(master, "I_SOLO", 0) then
    master_reset = true
  end
  
  -- Сброс настроек отдельных дорожек
  for i = 0, track_count - 1 do
    local track = reaper.GetTrack(project, i)
    local retval, track_name = reaper.GetTrackName(track)
    local track_reset = false
    
    -- Сброс основных параметров
    if safeResetValue(track, "D_VOL", 1.0) then track_reset = true end -- Громкость в 0 dB
    if safeResetValue(track, "D_PAN", 0.0) then track_reset = true end -- Панорама в центр
    if safeResetValue(track, "D_WIDTH", 1.0) then track_reset = true end -- Стерео-ширина в норму
    if safeResetValue(track, "B_MUTE", 0) then track_reset = true end -- Отключение мьюта
    if safeResetValue(track, "I_SOLO", 0) then track_reset = true end -- Отключение соло
    
    -- Сброс посылов на мастер
    if safeResetValue(track, "B_MAINSEND", 1) then track_reset = true end
    
    -- Включение всех эффектов
    local fx_count = reaper.TrackFX_GetCount(track)
    for fx = 0, fx_count - 1 do
      if not reaper.TrackFX_GetEnabled(track, fx) then
        reaper.TrackFX_SetEnabled(track, fx, true)
        track_reset = true
      end
    end
    
    -- Сброс огибающих автоматизации (опционально)
    -- reaper.DeleteTrackEnvelope(track, reaper.GetTrackEnvelopeByName(track, "Volume"))
    -- reaper.DeleteTrackEnvelope(track, reaper.GetTrackEnvelopeByName(track, "Pan"))
    
    if track_reset then
      reset_count = reset_count + 1
    end
  end
  
  -- Формирование сообщения о результатах
  local message = "Сброс настроек выполнен:\n\n"
  
  if master_reset then
    message = message .. "✓ Мастер-шина сброшена в дефолтное состояние\n"
  else
    message = message .. "✓ Настройки мастер-шины уже были в дефолтном состоянии\n"
  end
  
  message = message .. string.format("\n✓ Обработано дорожек: %d", track_count)
  message = message .. string.format("\n✓ Сброшено настроек: %d", reset_count)
  
  message = message .. "\n\nВыполненные действия:\n"
  message = message .. "• Громкость всех дорожек установлена в 0 dB\n"
  message = message .. "• Панорама сброшена в центр\n"
  message = message .. "• Стерео-ширина установлена в значение 100%\n"
  message = message .. "• Отключены все мьюты и соло\n"
  message = message .. "• Включены все эффекты\n"
  message = message .. "• Проверены посылы на мастер\n"
  
  -- Показ результатов
  reaper.ShowMessageBox(message, "Результаты сброса настроек", 0)
  
  -- Обновление интерфейса
  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
end

-- Добавление действия отмены
reaper.Undo_BeginBlock()
ResetMixingSettings()
reaper.Undo_EndBlock("Сброс настроек для сведения", -1)