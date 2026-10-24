module HoennNativeKIFTownOptionalBattles
  def should_start_battle?
    return false if instance_variable_get(:@hoenn_native_town_wildlife)
    super
  end
end
OverworldPokemonEvent.prepend(HoennNativeKIFTownOptionalBattles)

# Town water Pokémon are passive when the player is standing on land,
module HoennNativeKIFShoreBattleSafety
  def should_start_battle?
    if instance_variable_get(:@hoenn_native_town_water)
      return false unless $PokemonGlobal && ($PokemonGlobal.surfing || $PokemonGlobal.boat)
    end
    super
  end
end
OverworldPokemonEvent.prepend(HoennNativeKIFShoreBattleSafety)

# keep swimming Pokémon within genuine exposed water tiles
module HoennNativeKIFWaterMovement
  def passable?(x, y, d, strict = false)
    if instance_variable_get(:@hoenn_native_town_water)
      nx = x + (d == 6 ? 1 : d == 4 ? -1 : 0)
      ny = y + (d == 2 ? 1 : d == 8 ? -1 : 0)
      return false unless HoennNativeKIF.open_water_tile?(nx, ny)
    end
    super
  end
end
OverworldPokemonEvent.prepend(HoennNativeKIFWaterMovement)


# Deferred shiny chime and map-lifetime shiny protection
