-- Constants
local MIN_VELOCITY = 1
local MAX_VELOCITY = 127
local DEFAULT_COMPRESSION_RATIO = 4
local VELOCITY_THRESHOLD = 100

-- Note ranges for analysis with suggested frequency ranges for EQ
local NOTE_RANGES = {
    {name = "Sub Bass", range = {0, 35}, freq = {20, 60}, q = 0.7},     -- C-1 to B1
    {name = "Bass", range = {36, 47}, freq = {60, 250}, q = 0.8},       -- C2 to B2
    {name = "Low Mid", range = {48, 59}, freq = {250, 500}, q = 0.7},   -- C3 to B3
    {name = "Mid", range = {60, 71}, freq = {500, 2000}, q = 0.6},      -- C4 to B4
    {name = "High Mid", range = {72, 83}, freq = {2000, 4000}, q = 0.6},-- C5 to B5
    {name = "Presence", range = {84, 95}, freq = {4000, 8000}, q = 0.5},-- C6 to B6
    {name = "Brilliance", range = {96, 127}, freq = {8000, 20000}, q = 0.4} -- C7+
}

-- Compression presets based on dynamics
local COMPRESSION_PRESETS = {
    {name = "Soft", ratio = 2, attack = 25, release = 150},
    {name = "Medium", ratio = 4, attack = 15, release = 100},
    {name = "Hard", ratio = 8, attack = 10, release = 80}
}

-- Error handling wrapper
local function protected_call(fn, ...)
    local status, result = pcall(fn, ...)
    if not status then
        reaper.ShowMessageBox(result, "Error", 0)
        return nil
    end
    return result
end

-- Get all MIDI tracks
local function get_all_midi_tracks()
    local tracks = {}
    local track_count = reaper.GetNumTracks()
    
    for i = 0, track_count - 1 do
        local track = reaper.GetTrack(0, i)
        if track then
            local _, track_name = reaper.GetTrackName(track)
            table.insert(tracks, {track = track, name = track_name})
        end
    end
    
    return tracks
end

-- Get all media items from track
local function get_track_items(track)
    local items = {}
    local item_count = reaper.GetTrackNumMediaItems(track)
    
    for i = 0, item_count - 1 do
        local item = reaper.GetTrackMediaItem(track, i)
        if item then
            table.insert(items, item)
        end
    end
    
    return items
end

-- Get active take and validate
local function get_active_take(item)
    local take = reaper.GetActiveTake(item)
    if take and reaper.TakeIsMIDI(take) then
        return take
    end
    return nil
end

-- Get MIDI data from take
local function get_midi_data(take)
    local _, notecnt = reaper.MIDI_CountEvts(take)
    if notecnt == 0 then return nil end
    
    local notes = {}
    for i = 0, notecnt - 1 do
        local _, selected, muted, startppqpos, endppqpos, chan, pitch, vel = reaper.MIDI_GetNote(take, i)
        table.insert(notes, {
            pitch = pitch,
            velocity = vel,
            start = startppqpos,
            length = endppqpos - startppqpos,
            channel = chan,
            muted = muted
        })
    end
    
    return notes
end

-- Analyze velocity distribution with more detailed statistics
local function analyze_velocity(notes)
    if #notes == 0 then return nil end
    
    local velocities = {}
    local total = 0
    local peak = 0
    local lowest = MAX_VELOCITY
    local histogram = {}
    
    for i = MIN_VELOCITY, MAX_VELOCITY do
        histogram[i] = 0
    end
    
    for _, note in ipairs(notes) do
        if not note.muted then
            total = total + note.velocity
            peak = math.max(peak, note.velocity)
            lowest = math.min(lowest, note.velocity)
            velocities[#velocities + 1] = note.velocity
            histogram[note.velocity] = histogram[note.velocity] + 1
        end
    end
    
    local avg = total / #velocities
    
    -- Calculate RMS and variance
    local rms = 0
    local variance = 0
    for _, vel in ipairs(velocities) do
        rms = rms + (vel * vel)
        variance = variance + (vel - avg) * (vel - avg)
    end
    rms = math.sqrt(rms / #velocities)
    variance = variance / #velocities
    
    -- Find most common velocity (mode)
    local mode = MIN_VELOCITY
    local mode_count = 0
    for vel, count in pairs(histogram) do
        if count > mode_count then
            mode = vel
            mode_count = count
        end
    end
    
    -- Calculate dynamic range and suggest compression
    local dynamic_range = peak - lowest
    local threshold = avg * 0.8
    local suggested_preset = "Soft"
    
    if dynamic_range > 60 then
        suggested_preset = "Hard"
    elseif dynamic_range > 40 then
        suggested_preset = "Medium"
    end
    
    return {
        average = avg,
        peak = peak,
        lowest = lowest,
        rms = rms,
        variance = math.sqrt(variance),
        mode = mode,
        dynamic_range = dynamic_range,
        threshold = threshold,
        suggested_preset = suggested_preset
    }
end

-- Analyze note distribution across ranges with detailed EQ suggestions
local function analyze_note_ranges(notes)
    local distributions = {}
    
    for _, range in ipairs(NOTE_RANGES) do
        local count = 0
        local total_vel = 0
        local peak_vel = 0
        local note_histogram = {}
        
        for note = range.range[1], range.range[2] do
            note_histogram[note] = 0
        end
        
        for _, note in ipairs(notes) do
            if not note.muted and 
               note.pitch >= range.range[1] and 
               note.pitch <= range.range[2] then
                count = count + 1
                total_vel = total_vel + note.velocity
                peak_vel = math.max(peak_vel, note.velocity)
                note_histogram[note.pitch] = note_histogram[note.pitch] + 1
            end
        end
        
        local avg_vel = count > 0 and total_vel / count or 0
        local density = count / #notes * 100
        
        -- Advanced EQ suggestions based on density and velocity
        local suggested_gain = 0
        local suggested_q = range.q
        local center_freq = math.sqrt(range.freq[1] * range.freq[2])
        
        if density < 10 and avg_vel < 70 then
            suggested_gain = 3
        elseif density < 20 and avg_vel < 85 then
            suggested_gain = 1.5
        elseif density > 40 or avg_vel > 100 then
            suggested_gain = -2
            suggested_q = suggested_q * 1.2 -- Make Q slightly wider for reduction
        end
        
        table.insert(distributions, {
            name = range.name,
            count = count,
            density = density,
            average_velocity = avg_vel,
            peak_velocity = peak_vel,
            gain = suggested_gain,
            freq = center_freq,
            q = suggested_q
        })
    end
    
    return distributions
end

-- Format note name
local function get_note_name(pitch)
    local notes = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"}
    local note = notes[(pitch % 12) + 1]
    local octave = math.floor(pitch / 12) - 1
    return string.format("%s%d", note, octave)
end

-- Format results for display with track name
-- Analyze track role based on note distribution
local function analyze_track_role(distributions)
    local total_notes = 0
    local range_percentages = {}
    
    -- Calculate total notes and percentages per range
    for _, dist in ipairs(distributions) do
        total_notes = total_notes + dist.count
    end
    
    for _, dist in ipairs(distributions) do
        local percentage = (dist.count / total_notes) * 100
        range_percentages[dist.name] = percentage
    end
    
    -- Determine likely role
    if range_percentages["Bass"] and range_percentages["Bass"] > 50 then
        return "Bass/Sub Bass"
    elseif range_percentages["Low Mid"] and range_percentages["Low Mid"] > 40 then
        return "Low/Mid Lead"
    elseif range_percentages["High Mid"] and range_percentages["High Mid"] > 40 then
        return "Lead/Melody"
    elseif range_percentages["Presence"] and range_percentages["Presence"] > 30 then
        return "High Lead/Arp"
    else
        return "Mixed/Pad"
    end
end

-- Generate mixing suggestions based on track role and analysis
local function get_mixing_suggestions(track_role, velocity_analysis, distributions)
    local suggestions = {
        eq = {},
        dynamics = {},
        stereo = {},
        effects = {}
    }
    
    -- EQ suggestions based on role
    if track_role == "Bass/Sub Bass" then
        suggestions.eq = {
            "High-pass filter below 30Hz to remove sub-rumble",
            "Boost around 60-80Hz for fundamental",
            "Gentle boost around 700Hz-1kHz for clarity",
            "Consider cutting competing frequencies in other tracks"
        }
        suggestions.stereo = {
            "Keep bass frequencies mono",
            "Consider subtle stereo widening above 300Hz"
        }
    elseif track_role == "Low/Mid Lead" then
        suggestions.eq = {
            "High-pass around 100Hz",
            "Consider cuts around 300-500Hz to avoid muddiness",
            "Potential boost around 2-3kHz for presence"
        }
        suggestions.stereo = {
            "Moderate stereo width",
            "Consider auto-pan for movement"
        }
    elseif track_role == "Lead/Melody" then
        suggestions.eq = {
            "High-pass around 150-200Hz",
            "Boost presence region (2-5kHz) for clarity",
            "Consider air boost around 10kHz"
        }
        suggestions.stereo = {
            "Wide stereo image acceptable",
            "Consider stereo delay effects"
        }
    end
    
    -- Dynamic suggestions based on velocity analysis
    if velocity_analysis.dynamic_range > 40 then
        suggestions.dynamics = {
            "Consider parallel compression to maintain dynamics while adding consistency",
            string.format("Multi-band compression might help, focus on %d-%d range", 
                math.floor(velocity_analysis.lowest * 0.8), 
                math.floor(velocity_analysis.peak * 1.2))
        }
    else
        suggestions.dynamics = {
            "Gentle compression should suffice",
            "Consider saturation for harmonic enhancement"
        }
    end
    
    -- Effects suggestions based on role and dynamics
    if track_role == "Lead/Melody" then
        suggestions.effects = {
            "Consider short room reverb (0.8-1.2s)",
            "Subtle delay (1/8 or 1/16 with feedback around 20%)",
            "Potential chorus or ensemble for thickening"
        }
    elseif track_role == "Bass/Sub Bass" then
        suggestions.effects = {
            "Minimal reverb, keep it dry",
            "Consider subtle saturation or drive",
            "Potential sidechain compression if needed"
        }
    end
    
    return suggestions
end

local function format_track_results(track_name, velocity_analysis, distributions)
    local track_role = analyze_track_role(distributions)
    local mixing_suggestions = get_mixing_suggestions(track_role, velocity_analysis, distributions)
    
    local result = string.format("\nTrack: %s\n", track_name) ..
                  string.format("Track Role: %s\n", track_role) ..
                  string.format("================================================\n") ..
                  "\nDynamics Analysis:\n" ..
                  string.format("Average Velocity: %.1f\n", velocity_analysis.average) ..
                  string.format("Peak Velocity: %d\n", velocity_analysis.peak) ..
                  string.format("Lowest Velocity: %d\n", velocity_analysis.lowest) ..
                  string.format("RMS Velocity: %.1f\n", velocity_analysis.rms) ..
                  string.format("Velocity Variance: %.1f\n", velocity_analysis.variance) ..
                  string.format("Most Common Velocity: %d\n", velocity_analysis.mode) ..
                  string.format("Dynamic Range: %.1f\n", velocity_analysis.dynamic_range) ..
                  "\nMixing & Processing Suggestions:\n" ..
                  "\nCompressor Settings:\n"
    
    -- Add compression preset details
    local preset = nil
    for _, p in ipairs(COMPRESSION_PRESETS) do
        if p.name == velocity_analysis.suggested_preset then
            preset = p
            break
        end
    end
    
    if preset then
        result = result .. string.format("Preset: %s\n", preset.name) ..
                         string.format("Threshold: %.1f\n", velocity_analysis.threshold) ..
                         string.format("Ratio: %d:1\n", preset.ratio) ..
                         string.format("Attack: %d ms\n", preset.attack) ..
                         string.format("Release: %d ms\n", preset.release)
    end
    
    result = result .. "\nEQ Analysis & Suggestions:\n"
    
    for _, dist in ipairs(distributions) do
        if dist.count > 0 then
            result = result .. string.format(
                "%s:\n" ..
                "  Notes: %d (%.1f%% density)\n" ..
                "  Velocity: Avg=%.1f, Peak=%d\n" ..
                "  EQ: %.0f Hz, Q=%.1f, Gain=%+.1f dB\n",
                dist.name, dist.count, dist.density,
                dist.average_velocity, dist.peak_velocity,
                dist.freq, dist.q, dist.gain
            )
        end
    end
    
    return result
end

-- Main execution
local function main()
    local tracks = get_all_midi_tracks()
    if #tracks == 0 then
        reaper.ShowMessageBox("No tracks found in project.", "Error", 0)
        return
    end
    
    local all_results = "=== MIDI Analysis Results ===\n"
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    all_results = all_results .. "Analyzed at: " .. timestamp .. "\n"
    
    for _, track_info in ipairs(tracks) do
        local track_data = {}
        local items = get_track_items(track_info.track)
        
        for _, item in ipairs(items) do
            local take = get_active_take(item)
            if take then
                local notes = get_midi_data(take)
                if notes then
                    local velocity_analysis = analyze_velocity(notes)
                    local distributions = analyze_note_ranges(notes)
                    
                    if velocity_analysis and distributions then
                        all_results = all_results .. 
                            format_track_results(track_info.name, velocity_analysis, distributions)
                    end
                end
            end
        end
    end
    
    -- Write results to file
    local results_file = reaper.GetProjectPath("") .. "/midi_analysis_results.txt"
    local file = io.open(results_file, "a")
    if file then
        file:write(all_results)
        file:write("\n\n" .. string.rep("=", 50) .. "\n\n")
        file:close()
        
        -- Open the results file
        reaper.CF_ShellExecute(results_file)
    else
        reaper.ShowMessageBox("Could not write to results file.", "Error", 0)
    end
end

-- Generate mastering suggestions based on all tracks
local function generate_mastering_suggestions(all_track_data)
    local suggestions = {
        frequency_balance = {},
        dynamics = {},
        stereo = {},
        processing = {}
    }
    
    local total_dynamic_range = 0
    local track_count = 0
    local has_bass = false
    local has_lead = false
    local has_high_content = false
    
    -- Analyze overall project characteristics
    for _, track in ipairs(all_track_data) do
        if track.role == "Bass/Sub Bass" then has_bass = true end
        if track.role == "Lead/Melody" then has_lead = true end
        if track.role == "High Lead/Arp" then has_high_content = true end
        
        total_dynamic_range = total_dynamic_range + track.velocity_analysis.dynamic_range
        track_count = track_count + 1
    end
    
    local avg_dynamic_range = total_dynamic_range / track_count
    
    -- Frequency balance suggestions
    if not has_bass then
        table.insert(suggestions.frequency_balance, "Consider adding sub bass content (30-60Hz)")
    end
    if not has_high_content then
        table.insert(suggestions.frequency_balance, "Mix might benefit from more high-frequency content")
    end
    
    table.insert(suggestions.frequency_balance, "Suggested master EQ moves:")
    table.insert(suggestions.frequency_balance, "- High-pass entire mix at 20Hz")
    table.insert(suggestions.frequency_balance, "- Check 250-350Hz for potential mud")
    table.insert(suggestions.frequency_balance, "- Consider gentle 2-3dB shelf boost above 10kHz for air")
    
    -- Dynamics suggestions
    if avg_dynamic_range > 50 then
        table.insert(suggestions.dynamics, "Mix has wide dynamic range - consider master bus compression")
        table.insert(suggestions.dynamics, "Suggested settings: 2:1 ratio, slow attack (30ms), auto release")
    else
        table.insert(suggestions.dynamics, "Dynamic range is controlled - light limiting might suffice")
        table.insert(suggestions.dynamics, "Consider parallel compression for punch")
    end
    
    -- Stereo suggestions
    table.insert(suggestions.stereo, "Check mono compatibility")
    table.insert(suggestions.stereo, "Consider M/S processing:")
    table.insert(suggestions.stereo, "- Keep below 150Hz mono")
    table.insert(suggestions.stereo, "- Potential width enhancement 2-8kHz")
    
    -- Processing chain suggestions
    table.insert(suggestions.processing, "Suggested mastering chain:")
    table.insert(suggestions.processing, "1. Linear phase EQ for surgical cuts")
    table.insert(suggestions.processing, "2. Dynamic EQ for frequency control")
    table.insert(suggestions.processing, "3. Glue compression (2:1, slow attack)")
    table.insert(suggestions.processing, "4. Multiband compression if needed")
    table.insert(suggestions.processing, "5. Stereo processing")
    table.insert(suggestions.processing, "6. Final limiter (2-3dB reduction max)")
    
    return suggestions
end

-- Format mastering suggestions
local function format_mastering_suggestions(suggestions)
    local result = "\n\n=== MASTERING RECOMMENDATIONS ===\n\n"
    
    result = result .. "Frequency Balance:\n"
    for _, suggestion in ipairs(suggestions.frequency_balance) do
        result = result .. "- " .. suggestion .. "\n"
    end
    
    result = result .. "\nDynamics:\n"
    for _, suggestion in ipairs(suggestions.dynamics) do
        result = result .. "- " .. suggestion .. "\n"
    end
    
    result = result .. "\nStereo Image:\n"
    for _, suggestion in ipairs(suggestions.stereo) do
        result = result .. "- " .. suggestion .. "\n"
    end
    
    result = result .. "\nProcessing Chain:\n"
    for _, suggestion in ipairs(suggestions.processing) do
        result = result .. "- " .. suggestion .. "\n"
    end
    
    return result
end

-- Modified main function to include mastering suggestions
local function main()
    local tracks = get_all_midi_tracks()
    if #tracks == 0 then
        reaper.ShowMessageBox("No tracks found in project.", "Error", 0)
        return
    end
    
    local all_results = "=== MIDI Analysis Results ===\n"
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    all_results = all_results .. "Analyzed at: " .. timestamp .. "\n"
    
    local all_track_data = {}
    
    for _, track_info in ipairs(tracks) do
        local items = get_track_items(track_info.track)
        
        for _, item in ipairs(items) do
            local take = get_active_take(item)
            if take then
                local notes = get_midi_data(take)
                if notes then
                    local velocity_analysis = analyze_velocity(notes)
                    local distributions = analyze_note_ranges(notes)
                    
                    if velocity_analysis and distributions then
                        local track_role = analyze_track_role(distributions)
                        table.insert(all_track_data, {
                            name = track_info.name,
                            role = track_role,
                            velocity_analysis = velocity_analysis,
                            distributions = distributions
                        })
                        
                        all_results = all_results .. 
                            format_track_results(track_info.name, velocity_analysis, distributions)
                    end
                end
            end
        end
    end
    
    -- Add mastering suggestions if we have analyzed tracks
    if #all_track_data > 0 then
        local mastering_suggestions = generate_mastering_suggestions(all_track_data)
        all_results = all_results .. format_mastering_suggestions(mastering_suggestions)
    end
    
    -- Write results to file
    local results_file = reaper.GetProjectPath("") .. "/midi_analysis_results.txt"
    local file = io.open(results_file, "a")
    if file then
        file:write(all_results)
        file:write("\n\n" .. string.rep("=", 50) .. "\n\n")
        file:close()
        
        -- Open the results file
        reaper.CF_ShellExecute(results_file)
    else
        reaper.ShowMessageBox("Could not write to results file.", "Error", 0)
    end
end

-- Run the script
reaper.defer(main)
