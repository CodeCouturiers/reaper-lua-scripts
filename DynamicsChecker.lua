-- Профессиональный скрипт анализа динамики инструментов
local dynamics_targets = {
  vocal = {
    rms_min = -24, rms_max = -12,
    peak_min = -6, peak_max = -0.5,
    description = "Вокал должен быть разборчивым и экспрессивным",
    compression_tips = {
      "Используйте многополосную компрессию для контроля разных частотных диапазонов",
      "Ratio 2:1 - 4:1 для основной компрессии",
      "Быстрая атака (1-5ms) для контроля пиков",
      "Среднее восстановление (50-100ms) для естественности"
    }
  },
  drums = {
    rms_min = -18, rms_max = -10,
    peak_min = -4, peak_max = -0.5,
    description = "Ударные требуют чёткой и контролируемой динамики",
    compression_tips = {
      "Параллельная компрессия для плотности",
      "Ratio 4:1 - 8:1 для контроля пиков",
      "Быстрая атака (0.1-1ms) для точности",
      "Быстрое восстановление (10-50ms) для энергичности"
    }
  }
  -- Остальные инструменты по аналогии...
}

-- Расширенные типы инструментов для определения
local instrument_patterns = {
  vocal = {"voc", "вок", "lead", "лид", "voice", "голос"},
  drums = {"drum", "удар", "beat", "бит"},
  bass = {"bass", "бас"},
  guitar = {"git", "гит"},
  synth = {"synth", "син", "pad", "пэд"},
  keys = {"key", "клав", "piano", "пиан"}
}

-- Функция для определения типа инструмента
local function detectInstrumentType(track_name)
  local lower_name = string.lower(track_name)
  for type, patterns in pairs(instrument_patterns) do
    for _, pattern in ipairs(patterns) do
      if string.match(lower_name, pattern) then
        return type
      end
    end
  end
  return nil
end

-- Функция для анализа фазовых проблем
local function analyzePhaseIssues(track)
  local phase_problems = false
  local correlation = reaper.Track_GetPeakHoldDB(track, 2, false)
  if correlation and correlation < 0 then
    phase_problems = true
  end
  return phase_problems
end

function AnalyzeTrackDynamics(track)
  local retval, track_name = reaper.GetTrackName(track)
  
  -- Сохраняем текущую позицию
  local cur_pos = reaper.GetCursorPosition()
  reaper.PreventUIRefresh(1)
  
  -- Получаем базовые параметры трека
  local peak_val = reaper.Track_GetPeakInfo(track, 0)
  local rms_l = reaper.Track_GetPeakHoldDB(track, 0, true)
  local rms_r = reaper.Track_GetPeakHoldDB(track, 1, true)
  local avg_rms = (rms_l + rms_r) / 2
  
  -- Анализируем фазу
  local phase_issues = analyzePhaseIssues(track)
  
  -- Получаем параметры громкости
  local volume = reaper.GetMediaTrackInfo_Value(track, "D_VOL")
  local pan = reaper.GetMediaTrackInfo_Value(track, "D_PAN")
  local width = reaper.GetMediaTrackInfo_Value(track, "D_WIDTH")
  
  -- Определяем тип инструмента
  local track_type = detectInstrumentType(track_name)
  
  -- Анализируем эффекты на треке
  local fx_count = reaper.TrackFX_GetCount(track)
  local has_compressor = false
  local has_limiter = false
  
  for fx = 0, fx_count - 1 do
    local retval, fx_name = reaper.TrackFX_GetFXName(track, fx, "")
    local fx_lower = string.lower(fx_name)
    if string.match(fx_lower, "comp") then
      has_compressor = true
    elseif string.match(fx_lower, "limit") then
      has_limiter = true
    end
  end
  
  -- Формируем результат анализа
  local result = {
    name = track_name,
    type = track_type,
    peak = 20 * math.log(peak_val, 10),
    rms = avg_rms,
    volume = 20 * math.log(volume, 10),
    pan = pan,
    width = width,
    phase_issues = phase_issues,
    has_compressor = has_compressor,
    has_limiter = has_limiter
  }
  
  return result
end

function GenerateReport(analysis_results)
  local report = "📊 АНАЛИЗ ДИНАМИКИ\n\n"
  
  for _, result in ipairs(analysis_results) do
    report = report .. string.format("🎵 Дорожка: %s\n", result.name)
    report = report .. string.format("📈 Пиковый уровень: %.1f dB\n", result.peak)
    report = report .. string.format("📊 RMS уровень: %.1f dB\n", result.rms)
    report = report .. string.format("🎚️ Громкость: %.1f dB\n", result.volume)
    
    if math.abs(result.pan) > 0.5 then
      report = report .. string.format("↔️ Панорама: %.0f%%\n", result.pan * 100)
    end
    
    if result.width ~= 1.0 then
      report = report .. string.format("↔️ Ширина стерео: %.0f%%\n", result.width * 100)
    end
    
    if result.phase_issues then
      report = report .. "⚠️ Обнаружены проблемы с фазой!\n"
    end
    
    -- Информация об эффектах
    if result.has_compressor then
      report = report .. "🔸 Есть компрессор\n"
    else
      report = report .. "⚠️ Нет компрессора\n"
    end
    
    if result.has_limiter then
      report = report .. "🔸 Есть лимитер\n"
    end
    
    if result.type and dynamics_targets[result.type] then
      local target = dynamics_targets[result.type]
      report = report .. "\n📝 РЕКОМЕНДАЦИИ:\n"
      report = report .. target.description .. "\n"
      
      -- Проверка RMS
      if result.rms < target.rms_min then
        report = report .. string.format("⚠️ RMS слишком низкий (%.1f dB). Рекомендуется поднять на %.1f dB\n", 
          result.rms, target.rms_min - result.rms)
      elseif result.rms > target.rms_max then
        report = report .. string.format("⚠️ RMS слишком высокий (%.1f dB). Рекомендуется снизить на %.1f dB\n",
          result.rms, result.rms - target.rms_max)
      end
      
      -- Советы по компрессии
      if not result.has_compressor then
        report = report .. "\nРекомендации по компрессии:\n"
        for _, tip in ipairs(target.compression_tips) do
          report = report .. "  • " .. tip .. "\n"
        end
      end
    end
    
    report = report .. "\n" .. string.rep("━", 50) .. "\n\n"
  end
  
  return report
end

function Main()
  local project = 0
  local track_count = reaper.CountTracks(project)
  local results = {}
  
  -- Начинаем анализ
  reaper.PreventUIRefresh(1)
  reaper.Undo_BeginBlock()
  
  for i = 0, track_count - 1 do
    local track = reaper.GetTrack(project, i)
    local analysis = AnalyzeTrackDynamics(track)
    table.insert(results, analysis)
  end
  
  -- Генерируем и показываем отчет
  local report = GenerateReport(results)
  reaper.ShowMessageBox(report, "Анализ динамики", 0)
  
  reaper.Undo_EndBlock("Анализ динамики", -1)
  reaper.PreventUIRefresh(-1)
  reaper.UpdateArrange()
end

-- Запускаем скрипт
Main()