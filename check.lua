-- Профессиональный скрипт проверки проекта перед мастерингом
local function Main()
  local project = 0
  local issues = {}
  local warnings = {}
  
  -- Константы для проверок
  local LIMITS = {
    PEAK_CEILING = -1.0,    -- True Peak предел
    MAX_RMS = -12.0,        -- Максимальный RMS
    MIN_RMS = -18.0,        -- Минимальный RMS
    MAX_SWIDTH = 1.0,       -- Максимальная ширина стерео
    MIN_CORR = 0.0,         -- Минимальная корреляция
    PAN_LIMIT = 0.9,        -- Предел панорамирования
  }

  -- Улучшенная функция конвертации в dB
  local function toDB(value)
    if value <= 0 then return -math.huge end
    return 20 * math.log(value, 10)
  end

  -- Получение RMS значения
  local function getRMSValue(track, take_index)
    local rms_l = reaper.Track_GetPeakHoldDB(track, take_index * 2, true)
    local rms_r = reaper.Track_GetPeakHoldDB(track, take_index * 2 + 1, true)
    if rms_l == -math.huge or rms_r == -math.huge then return -math.huge end
    return (rms_l + rms_r) / 2
  end

  -- Получение корреляции фаз
  local function getPhaseCorrelation(track)
    local retval, corrValue = reaper.Track_GetPeakHoldDB(track, 2, false)
    return corrValue or 0
  end

  -- Анализ эффектов на треке
  local function analyzeFX(track, track_name)
    local fx_count = reaper.TrackFX_GetCount(track)
    if fx_count == 0 then return end
    
    local has_limiter = false
    local last_eq = -1
    local last_comp = -1
    
    for fx = 0, fx_count - 1 do
      local retval, fx_name = reaper.TrackFX_GetFXName(track, fx, "")
      local enabled = reaper.TrackFX_GetEnabled(track, fx)
      
      -- Проверка состояния эффекта
      if not enabled then
        table.insert(warnings, string.format("🔌 %s: Отключен эффект '%s'", track_name, fx_name))
      end
      
      -- Определение типов эффектов
      local fx_lower = fx_name:lower()
      if fx_lower:find("eq") then
        last_eq = fx
      elseif fx_lower:find("comp") then
        last_comp = fx
      elseif fx_lower:find("limit") then
        has_limiter = true
      end
    end
    
    -- Анализ цепочки эффектов
    if last_eq > last_comp and last_comp ~= -1 then
      table.insert(warnings, string.format("⚡ %s: EQ после компрессора может быть неоптимально", track_name))
    end
    
    return has_limiter
  end

  -- Анализ трека
  local function analyzeTrack(track, is_master)
    local retval, track_name = reaper.GetTrackName(track)
    if is_master then track_name = "MASTER" end
    
    -- Базовые параметры
    local volume = reaper.GetMediaTrackInfo_Value(track, "D_VOL")
    local pan = reaper.GetMediaTrackInfo_Value(track, "D_PAN")
    local width = reaper.GetMediaTrackInfo_Value(track, "D_WIDTH")
    local is_muted = reaper.GetMediaTrackInfo_Value(track, "B_MUTE") == 1
    local is_soloed = reaper.GetMediaTrackInfo_Value(track, "I_SOLO") > 0
    
    -- Измерения
    local peak_val = reaper.Track_GetPeakInfo(track, 0)
    local rms = getRMSValue(track, 0)
    local correlation = getPhaseCorrelation(track)
    
    -- Проверки уровней
    if peak_val > 10^(LIMITS.PEAK_CEILING/20) then
      table.insert(issues, string.format("📊 %s: Пики выше %.1f dB (%.1f dB)", 
        track_name, LIMITS.PEAK_CEILING, toDB(peak_val)))
    end
    
    if volume > 1.0 then
      table.insert(issues, string.format("🔊 %s: Громкость выше 0 dB (%.1f dB)", 
        track_name, toDB(volume)))
    end
    
    -- RMS проверки
    if rms > LIMITS.MAX_RMS then
      table.insert(issues, string.format("📈 %s: RMS слишком высокий (%.1f dB)", 
        track_name, rms))
    elseif rms < LIMITS.MIN_RMS and rms > -math.huge then
      table.insert(warnings, string.format("📉 %s: RMS слишком низкий (%.1f dB)", 
        track_name, rms))
    end
    
    -- Проверки стерео
    if math.abs(pan) > LIMITS.PAN_LIMIT then
      table.insert(warnings, string.format("↔️ %s: Экстремальное панорамирование (%.0f%%)", 
        track_name, pan * 100))
    end
    
    if width > LIMITS.MAX_SWIDTH then
      table.insert(warnings, string.format("↔️ %s: Слишком широкая стерео-база (%.0f%%)", 
        track_name, width * 100))
    end
    
    -- Фазовые проблемы
    if correlation < LIMITS.MIN_CORR then
      table.insert(warnings, string.format("⚠️ %s: Возможные фазовые проблемы (%.2f)", 
        track_name, correlation))
    end
    
    -- Проверка мьюта/соло
    if is_muted then
      table.insert(issues, string.format("🔇 %s: Включен мьют", track_name))
    end
    if is_soloed then
      table.insert(issues, string.format("👂 %s: Включено соло", track_name))
    end
    
    return analyzeFX(track, track_name)
  end

  -- Анализ всего проекта
  local function analyzeProject()
    local master = reaper.GetMasterTrack(project)
    local track_count = reaper.CountTracks(project)
    local has_master_limiter = false
    
    -- Сначала анализируем все треки
    for i = 0, track_count - 1 do
      local track = reaper.GetTrack(project, i)
      analyzeTrack(track, false)
    end
    
    -- Затем анализируем мастер
    has_master_limiter = analyzeTrack(master, true)
    
    -- Проверяем наличие лимитера на мастере
    if not has_master_limiter then
      table.insert(warnings, "⚠️ MASTER: Не найден лимитер на мастер-шине")
    end
  end

  -- Запуск анализа
  analyzeProject()

  -- Формирование отчета
  local report = ""
  
  -- Добавляем критические проблемы
  if #issues > 0 then
    report = report .. "❌ КРИТИЧЕСКИЕ ПРОБЛЕМЫ:\n\n"
    for _, issue in ipairs(issues) do
      report = report .. issue .. "\n"
    end
    report = report .. "\n"
  end
  
  -- Добавляем предупреждения
  if #warnings > 0 then
    report = report .. "⚠️ ПРЕДУПРЕЖДЕНИЯ:\n\n"
    for _, warning in ipairs(warnings) do
      report = report .. warning .. "\n"
    end
    report = report .. "\n"
  end
  
  -- Если проблем нет
  if #issues == 0 and #warnings == 0 then
    report = "✅ ПРОЕКТ ГОТОВ К МАСТЕРИНГУ!\n\n"
    report = report .. "Рекомендации перед рендерингом:\n"
    report = report .. "1. Сделайте финальное прослушивание\n"
    report = report .. "2. Проверьте на разных мониторах/наушниках\n"
    report = report .. "3. Убедитесь, что пики не превышают -1 dB\n"
    report = report .. "4. Проверьте фазовую корреляцию\n"
    report = report .. "5. Создайте резервную копию проекта\n"
    report = report .. "6. Проверьте настройки рендеринга\n"
    report = report .. "7. Прослушайте результат после экспорта\n"
  end
  
  -- Показываем результаты
  reaper.ShowMessageBox(report, "🎚️ Анализ проекта перед мастерингом", 0)
end

-- Добавляем возможность отмены
reaper.Undo_BeginBlock()
Main()
reaper.Undo_EndBlock("Проверка проекта перед мастерингом", -1)