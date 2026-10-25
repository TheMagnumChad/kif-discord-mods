# KIF weather: local forecasts, time of day, and occasional moving fronts.
module HoennWeatherKIF
  CHANGE_SECONDS = 300
  CHANCE_TO_CHANGE = 30
  @elapsed_active_seconds = 0.0
  @last_display = nil
  @loaded_global = nil

  # Store only plain data in KIF's existing save object.
  def self.load_saved_state
    return unless $PokemonGlobal
    return if @loaded_global.equal?($PokemonGlobal)
    @loaded_global = $PokemonGlobal
    @last_display = nil
    @elapsed_active_seconds = 0.0
    saved = $PokemonGlobal.instance_variable_get(:@hoenn_weather_state)
    return unless saved.is_a?(Hash)
    maps = saved[:maps]
    return unless maps.is_a?(Hash)
    $game_weather ||= GameWeather.new
    $game_weather.current_weather = maps.each_with_object({}) do |(id, value), result|
      next unless id.is_a?(Integer) && value.is_a?(Array) && value.length == 2
      next unless value[0].is_a?(Symbol) && value[1].is_a?(Numeric)
      result[id] = [value[0], [[value[1].to_i, 0].max, 10].min]
    end
    @elapsed_active_seconds = [[saved[:elapsed].to_f, 0.0].max, CHANGE_SECONDS].min
  rescue StandardError => e
    echoln "HoennWeather restore error: #{e.class}: #{e.message}"
  end

  def self.persist_state
    return unless $PokemonGlobal && $game_weather && $game_weather.current_weather
    # SaveData already serializes PokemonGlobal; no extra save field needed.
    maps = {}
    $game_weather.current_weather.each do |id, value|
      next unless id.is_a?(Integer) && value.is_a?(Array) && value.length == 2
      maps[id] = [value[0], value[1].to_i]
    end
    $PokemonGlobal.instance_variable_set(:@hoenn_weather_state, {
      :maps => maps, :elapsed => @elapsed_active_seconds.to_f
    })
  rescue StandardError => e
    echoln "HoennWeather save error: #{e.class}: #{e.message}"
  end

  def self.outdoors?(id)
    meta = GameData::MapMetadata.try_get(id)
    meta && meta.outdoor_map
  end

  def self.hour
    pbGetTimeNow.hour
  rescue StandardError
    Time.now.hour
  end

  def self.supported?(type)
    return true if type == :None
    !!GameData::Weather.try_get(type)
  rescue StandardError
    false
  end

  def self.map_name(id)
    info = pbLoadMapInfos[id]
    info ? info.name.to_s.downcase : ""
  rescue StandardError
    ""
  end

  # Kanto and Johto are temperate. Special weather belongs in special places.
  def self.weights(id)
    name = map_name(id)
    h = hour
    month = pbGetTimeNow.month rescue Time.now.month
    winter = [12, 1, 2].include?(month)
    morning = h >= 5 && h < 11
    night = h < 6 || h >= 19
    w = { :None => 42, :Rain => 26, :Sunny => (night ? 0 : 18),
          :Wind => 12, :Fog => (morning ? 12 : 5), :Storm => 4 }
    # Seasonal snowfall is plausible in the temperate towns and routes.
    if winter
      w[:Snow] = 12
      w[:Blizzard] = 1
      w[:Rain] = 18
    end
    route = name[/\\broute\\s*0*(\\d+)\\b/, 1].to_i
    if name.match?(/forest|woods|grove|ilex|national park|safari/)
      w[:Rain] += 10
      w[:Fog] += 14
      w[:Sunny] = 6 unless night
    elsif name.match?(/sea|ocean|coast|beach|island|whirl|cianwood|vermilion|olivine|cinnabar/)
      w[:Rain] += 12
      w[:Wind] += 16
      w[:Storm] += 4
    elsif name.match?(/mount|mt\\.?|peak|summit|silver|ice path|seafoam|blackthorn|indigo plateau/)
      w[:Snow] = winter ? 35 : 12
      w[:Blizzard] = winter ? 10 : 2
      w[:Wind] += 15
      w[:Fog] += 6
    end
    # Route-specific geography, not an indiscriminate region-wide roll.
    if route.between?(1, 48)
      case route
      when 10, 33, 43
        w[:Rain] += 24
        w[:Storm] += 5
      when 19, 20, 21, 40, 41
        w[:Wind] += 22
        w[:Rain] += 12
      when 26, 27, 28, 42, 44, 45, 46, 47, 48
        w[:Wind] += 12
        w[:Snow] = winter ? 22 : 3
      when 2, 30, 31, 34, 35, 36, 37
        w[:Fog] += 10
        w[:Rain] += 8
      end
    end
    if name.include?("lake of rage")
      w[:Rain] += 28
      w[:Storm] += 6
    end
    # Only volcanic ground can produce airborne ash in this region.
    if name.match?(/cinnabar|volcano|volcanic|ember|burned tower/)
      w[:Ash] = 9
    end
    # No natural deserts in Kanto or Johto: sandstorms are never generated.
    w.delete(:Sandstorm)
    w.select { |type, weight| weight > 0 && supported?(type) }
  end

  def self.pick(id)
    options = weights(id)
    return [:None, 0] if options.empty?
    total = options.values.inject(0, :+)
    roll = rand(total)
    options.each do |type, weight|
      roll -= weight
      return [type, type == :None ? 0 : rand(2..6)] if roll < 0
    end
    [:None, 0]
  end

  def self.ensure_state
    return unless $game_map
    load_saved_state
    $game_weather ||= GameWeather.new
    $game_weather.current_weather ||= {}
    id = $game_map.map_id
    if outdoors?(id)
      old = $game_weather.current_weather[id]
      $game_weather.current_weather[id] = pick(id) if !old || !weights(id).key?(old[0])
    end
  rescue StandardError => e
    echoln "HoennWeather state error: #{e.class}: #{e.message}"
  end

  def self.tick(force = false)
    return unless $game_map && $game_screen
    ensure_state
    return unless $game_weather
    # Count only overworld update frames, never wall-clock time.
    # Menus, battles and paused windows do not advance this clock.
    if !force
      @elapsed_active_seconds ||= 0.0
      @elapsed_active_seconds += 1.0 / [Graphics.frame_rate.to_f, 1.0].max
    end
    if @elapsed_active_seconds.to_f >= (CHANGE_SECONDS / HoennEssentialsSettings.multiplier(:hs_weather_rate))
      @elapsed_active_seconds -= (CHANGE_SECONDS / HoennEssentialsSettings.multiplier(:hs_weather_rate))
      if true
        # Existing fronts can linger, change intensity, or fade.
        weather = $game_weather.current_weather
        weather.keys.each do |id|
          next unless outdoors?(id)
          weather[id] = pick(id) unless weights(id).key?(weather[id][0])
          next unless rand(100) < CHANCE_TO_CHANGE
          if rand(100) < 65
            weather[id] = pick(id)
          else
            type, strength = weather[id]
            weather[id] = [type, [[strength.to_i + rand(-2..2), 1].max, 10].min] if type != :None
          end
        end
        id = $game_map.map_id
        weather[id] = pick(id) if outdoors?(id) && rand(100) < 8
      end
    end
    id = $game_map.map_id
    type, intensity = outdoors?(id) ? ($game_weather.current_weather[id] || [:None, 0]) : [:None, 0]
    type, intensity = :None, 0 unless supported?(type)
    type, intensity = :None, 0 if type == :Sunny && (hour >= 19 || hour < 6)
    persist_state
    display = [id, type, intensity]
    if @last_display != display
      $game_screen.weather(type, intensity, 20)
      @last_display = display
    end
  rescue StandardError => e
    echoln "HoennWeather update error: #{e.class}: #{e.message}"
  end
end

Events.onMapChange += proc { |_old_map_id| HoennWeatherKIF.tick(true); HoennWeatherKIF.update_fog_overlay }
# Run the clock in the overworld, not only when changing maps.
Events.onMapUpdate += proc { |_sender, _args|
  if !$game_map || !$game_screen
    next
  end
  HoennWeatherKIF.tick
  HoennWeatherKIF.update_fog_overlay
}

# A soft veil for fog. KIF doesn't draw the original Hoenn fog on every build.
module HoennWeatherKIF
  @fog_sprite = nil
  @fog_viewport = nil

  def self.foggy_here?
    return false unless $game_map && outdoors?($game_map.map_id)
    return false unless $game_weather && $game_weather.current_weather
    data = $game_weather.current_weather[$game_map.map_id]
    data && data[0] == :Fog
  rescue StandardError
    false
  end

  def self.clear_fog_overlay
    @fog_sprite.dispose if @fog_sprite && !@fog_sprite.disposed?
    @fog_viewport.dispose if @fog_viewport && !@fog_viewport.disposed?
    @fog_sprite = nil
    @fog_viewport = nil
  rescue StandardError
    @fog_sprite = nil
    @fog_viewport = nil
  end

  def self.update_fog_overlay
    visible = foggy_here? && defined?(Scene_Map) && $scene.is_a?(Scene_Map)
    unless visible
      clear_fog_overlay
      return
    end
    if !@fog_sprite || @fog_sprite.disposed?
      @fog_viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
      @fog_viewport.z = 100
      @fog_sprite = Sprite.new(@fog_viewport)
      @fog_sprite.bitmap = Bitmap.new(Graphics.width, Graphics.height)
      @fog_sprite.bitmap.fill_rect(0, 0, Graphics.width, Graphics.height, Color.new(210, 218, 222))
    end
    intensity = $game_weather.current_weather[$game_map.map_id][1].to_i
    @fog_sprite.opacity = [[42 + intensity * 7, 50].max, 120].min
  rescue StandardError => e
    echoln "HoennWeather fog overlay: #{e.class}: #{e.message}"
    clear_fog_overlay
  end
end

# Fog reduces accuracy of moves in outdoor battles, without affecting indoor fights.
if defined?(PokeBattle_Move) && PokeBattle_Move.method_defined?(:pbAccuracyCheck)
  class PokeBattle_Move
    alias_method :hoenn_weather_original_accuracy_check, :pbAccuracyCheck
    def pbAccuracyCheck(*args)
      hit = hoenn_weather_original_accuracy_check(*args)
      return hit unless hit && HoennWeatherKIF.foggy_here?
      # Moves which ignore accuracy should keep doing so.
      return hit if respond_to?(:pbBaseAccuracy) && pbBaseAccuracy(args[0], args[1]) == 0
      return false if rand(100) < 35
      hit
    end
  end
end
