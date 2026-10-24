# Restore Hoenn's native sneak-up battle behavior for our dynamic events
module HoennNativeKIFSurprise
  def self.start_battle(event)
    return event.overworldPokemonBattle unless surprise_eligible?(event)

    # Native battle rule: the wild Pokemon cannot act on the first turn
    $PokemonTemp.recordBattleRule("surprise")
    begin
      event.set_noticed_sprite if event.respond_to?(:set_noticed_sprite)
      pbSEPlay("jump")
      event.turn_away_from_player if event.respond_to?(:turn_away_from_player)
      event.jump(0, 0)
      pbWait(8)
      event.set_roaming_sprite if event.respond_to?(:set_roaming_sprite)
      $Trainer.stats&.incr_nb_pokemon_surprised if $Trainer && $Trainer.respond_to?(:stats)
      check_offguard_challenge(event) if defined?(check_offguard_challenge)
    rescue StandardError => e
      HoennNativeKIF.log("Catch-off-guard visual failed: #{e.class}: #{e.message}")
      event.set_roaming_sprite if event.respond_to?(:set_roaming_sprite)
    end
    # overworldPokemonBattle provides the native exclamation animation, cry, and battle transition
    event.overworldPokemonBattle
  end

  def self.surprise_eligible?(event)
    return false unless $game_player && $PokemonTemp
    return false if $PokemonTemp.prevent_ow_battles || $PokemonTemp.overworld_wild_battle_triggered
    return false if event.lock? || event.instance_variable_get(:@_triggered)
    return false unless event.current_state == :ROAMING
    return false if event.noticed_player_once
    # The player must be immediately behind the Pokemon and face its back
    return false unless (event.x - $game_player.x).abs + (event.y - $game_player.y).abs == 1
    return event.last_facing_direction == $game_player.direction
  end
end
