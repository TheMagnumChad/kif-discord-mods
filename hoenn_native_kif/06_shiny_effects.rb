module HoennNativeKIFShinyAura
  ENABLED = true
  SPARKLE_INTERVAL = 240
  VISUAL_RADIUS = 9
end

module HoennNativeKIFShinyAuraEvent
  def setup_pokemon(*args)
    result = super
    # Queue once for a later map frame, after event registration and audio readiness
    @kif_shiny_chime_due = Graphics.frame_count + 12
    @kif_shiny_chime_done = false
    if @pokemon && @pokemon.shiny?
      # Native Hoenn performs shiny rerolls after its first sprite selection
      begin
        initialize_sprite(@terrain, GameData::Species.get(@species))
      rescue StandardError
      end
    end
    result
  end

  def update_behavior(*args)
    # Hoenn's distance-based despawn is gated by @manual_ow_pokemon
    if HoennNativeKIFSettings.shiny_persistence? && @pokemon && @pokemon.shiny?
      original_manual = @manual_ow_pokemon
      begin
        @manual_ow_pokemon = true
        return super
      ensure
        @manual_ow_pokemon = original_manual
      end
    end
    super
  end

  def update(*args)
    result = super
    # Never play at spawn initialization: audio can be interrupted while creating/registering the dynamic event
    if @kif_shiny_chime_due && !@kif_shiny_chime_done &&
       Graphics.frame_count >= @kif_shiny_chime_due &&
       $game_map && @map_id == $game_map.map_id &&
       $scene && $scene.is_a?(Scene_Map) && !@erased
      @kif_shiny_chime_done = true
      @kif_shiny_chime_due = nil
      if HoennNativeKIFSettings.shiny_chime? && @pokemon && @pokemon.shiny?
        begin
          pbSEPlay("shiny", 80)
          HoennNativeKIF.log("Deferred shiny chime: #{@species} at #{@x},#{@y}")
        rescue StandardError => e
          HoennNativeKIF.log("Deferred shiny chime error: #{e.class}: #{e.message}")
        end
      end
    end
    return result unless HoennNativeKIFShinyAura::ENABLED && HoennNativeKIFSettings.sparkles?
    return result unless @pokemon && @pokemon.shiny?
    return result unless $game_map && $game_player && $scene && $scene.is_a?(Scene_Map)
    return result unless @map_id == $game_map.map_id
    return result if @erased || (respond_to?(:transparent) && transparent)
    return result if $game_temp && ($game_temp.in_menu || $game_temp.message_window_showing)
    return result if $game_map.respond_to?(:interpreter) &&
                     $game_map.interpreter && $game_map.interpreter.running?
    distance = ($game_player.x - @x).abs + ($game_player.y - @y).abs
    if distance <= HoennNativeKIFShinyAura::VISUAL_RADIUS
      frame = Graphics.frame_count
      if !@kif_shiny_next_sparkle || frame >= @kif_shiny_next_sparkle
        begin
          playAnimation(Settings::SPARKLE_SHORT_ANIMATION_ID, @x, @y)
        rescue StandardError
        end
        @kif_shiny_next_sparkle = frame + HoennNativeKIFShinyAura::SPARKLE_INTERVAL
      end
    end
    result
  end
end
OverworldPokemonEvent.prepend(HoennNativeKIFShinyAuraEvent)

# Native Hoenn's eviction helper can rotate a shiny to the back and then evict a different event
module HoennNativeKIFShinyEviction
  def despawn_overworld_pokemon(event_id, terrain)
    event = $game_map && $game_map.events[event_id]
    if HoennNativeKIFSettings.shiny_persistence? && event && event.respond_to?(:pokemon) && event.pokemon && event.pokemon.shiny?
      ids = ($PokemonTemp.overworld_pokemon_on_map || [])
      replacement = ids.find do |id|
        candidate = $game_map.events[id]
        candidate && candidate.respond_to?(:pokemon) && candidate.pokemon && !candidate.pokemon.shiny?
      end
      return unless replacement
      event_id = replacement
    end
    super(event_id, terrain)
  end
end
Object.prepend(HoennNativeKIFShinyEviction)


# Temporary overworld events must NOT survive map transfers
