# Target older Essentials versions (Infinite Fusion base)
if defined?(PokeBattle_Pokemon)
  class PokeBattle_Pokemon
    # Remove original constants to avoid console warnings
    remove_const(:EV_LIMIT) if defined?(EV_LIMIT)
    remove_const(:EV_STAT_LIMIT) if defined?(EV_STAT_LIMIT)
    
    # Cap total EVs at 5994 (allows 999 in all 6 stats)
    EV_LIMIT = 5994
    # Cap individual stats at 999
    EV_STAT_LIMIT = 999
  end
end

# Target newer Essentials classes just in case
if defined?(Pokemon)
  class Pokemon
    remove_const(:EV_LIMIT) if defined?(EV_LIMIT)
    remove_const(:EV_STAT_LIMIT) if defined?(EV_STAT_LIMIT)
    
    EV_LIMIT = 5994
    EV_STAT_LIMIT = 999
  end
end