module HoennNativeKIFMapTransitionCleanup
  def self.cleanup_map(map_id)
    return unless map_id && map_id > 0 && $MapFactory && $PokemonTemp
    map = $MapFactory.getMapNoAdd(map_id)
    return unless map && map.respond_to?(:events) && map.events
    removed_ids = []
    map.events.keys.each do |id|
      event = map.events[id]
      next unless event.is_a?(DynamicOverworldPokemonEvent)
      next unless event.instance_variable_get(:@event) && event.instance_variable_get(:@event).name == "HoennNativeWild"
      begin
        event.erase
      rescue StandardError
      end
      map.events.delete(id)
      removed_ids << id
    end
    return if removed_ids.empty?
    if $PokemonTemp.overworld_pokemon_on_map
      $PokemonTemp.overworld_pokemon_on_map -= removed_ids
    end
    if $PokemonTemp.tempEvents
      $PokemonTemp.tempEvents.each_value do |events|
        events.delete_if do |event|
          event && event.respond_to?(:map_id) && event.map_id == map_id && removed_ids.include?(event.id)
        end
      end
      $PokemonTemp.tempEvents.delete_if { |_, events| events.empty? }
    end
    HoennNativeKIF.log("Cleared #{removed_ids.length} old overworld events from map #{map_id}")
  rescue StandardError => e
    HoennNativeKIF.log("Map cleanup error: #{e.class}: #{e.message}")
  end
end

Events.onMapChange += proc { |_sender, args|
  old_map_id = args && args[0]
  if old_map_id && $game_map && old_map_id != $game_map.map_id
    HoennNativeKIFMapTransitionCleanup.cleanup_map(old_map_id)
  end
}


# Personality-weighted social reactions; native Hoenn AI remains in charge of roaming
