###################################################################################################
# Xorron's Map Progress (Local Edition) - STACK PROTECTED                                                  #
###################################################################################################

module XorronMapProgress
  DATA_PATH = "Mods/ModData/xorron_mod_local_data.txt"

  @map_data = {}
  @current_battle_map_id = 0
  @fainted_at_start = 0
  @processing = false # SAFETY GUARD

  def self.load_data
    @map_data = {}
    if File.exist?(DATA_PATH)   # KIF fix: File.exists? is gone in newer Ruby
      begin
        File.open(DATA_PATH, "r") do |f|
          f.each_line do |line|
            if line =~ /map_(\d+)_(\w+)=(\d+)/
              map_id = $1.to_i
              type = $2
              value = $3.to_i
              @map_data[map_id] ||= { "wins" => 0, "level" => 0 }
              if type == "wins"
                @map_data[map_id]["wins"] = value
              elsif type == "level"
                @map_data[map_id]["level"] = value
              end
            end
          end
        end
      rescue
      end
    end
  end

  def self.save_data
    # KIF fix: folder creation moved inside the rescue, so a write problem cannot crash a battle
    begin
      Dir.mkdir("Mods/ModData") unless Dir.exist?("Mods/ModData")
      File.open(DATA_PATH, "w") do |f|
        @map_data.each do |map_id, data|
          f.puts("map_#{map_id}_wins=#{data['wins']}")
          f.puts("map_#{map_id}_level=#{data['level']}")
        end
      end
    rescue
    end
  end

  def self.get_map_info(map_id)
    @map_data[map_id] ||= { "wins" => 0, "level" => 0 }
    return @map_data[map_id]
  end

  def self.set_battle_start_info(map_id)
    @current_battle_map_id = map_id
    @fainted_at_start = 0
    if $Trainer && $Trainer.party
      $Trainer.party.each do |pkmn|
        @fainted_at_start += 1 if pkmn && pkmn.hp <= 0
      end
    end
  end

  def self.add_win
    map_id = @current_battle_map_id
    return if map_id <= 0
    data = self.get_map_info(map_id)
    data["wins"] += 1
    if data["wins"] >= 5
      data["level"] += 1
      data["wins"] = 0
      self.save_data
      map_name = pbGetMapNameFromId(map_id)
      pbMessage(_INTL("Xorron's Map Progress: Flawless victory in {1}! Wild Pokémon here are now Level +{2} stronger.", map_name, data["level"]))
    else
      self.save_data
    end
  end

  def self.add_loss(reason_faint = false)
    map_id = @current_battle_map_id
    return if map_id <= 0
    data = self.get_map_info(map_id)
    if data["level"] > 0
      data["level"] -= 1
      data["wins"] = 0 
      self.save_data
      map_name = pbGetMapNameFromId(map_id)
      if reason_faint
        pbMessage(_INTL("Xorron's Map Progress: A Pokémon fainted during battle in {1}! Wild Pokémon here are now Level +{2}.", map_name, data["level"]))
      else
        pbMessage(_INTL("Xorron's Map Progress: A defeat in {1}... Wild Pokémon here are now Level +{2}.", map_name, data["level"]))
      end
    else
      data["wins"] = 0
      self.save_data
    end
  end

  def self.get_offset(map_id)
    return 0 if map_id <= 0
    return self.get_map_info(map_id)["level"]
  end

  def self.is_processing?
    @processing
  end

  def self.set_processing(val)
    @processing = val
  end

  def self.get_fainted_count_at_start
    @fainted_at_start
  end

  def self.reset_all_data
    @map_data = {}
    self.save_data
  end
end

# Load data
XorronMapProgress.load_data

# Hook: Level adjustment
Events.onWildPokemonCreate += proc { |_sender, e|
  next if XorronMapProgress.is_processing?
  next unless defined?(XorronModSettings) && XorronModSettings.enabled?("xorron_mod_enabled")
  XorronMapProgress.set_processing(true)
  begin
    pokemon = e[0]
    map_id = $game_map ? $game_map.map_id : 0
    offset = XorronMapProgress.get_offset(map_id)
    if offset != 0
      new_level = pokemon.level + offset
      new_level = 100 if new_level > 100
      new_level = 1 if new_level < 1
      pokemon.level = new_level
      pokemon.calc_stats
    end
  ensure
    XorronMapProgress.set_processing(false)
  end
}

# Hook: Battle Start
Events.onStartBattle += proc { |_sender, e|
  next unless defined?(XorronModSettings) && XorronModSettings.enabled?("xorron_mod_enabled")
  map_id = $game_map ? $game_map.map_id : 0
  XorronMapProgress.set_battle_start_info(map_id)
}

# Hook: Battle End
Events.onEndBattle += proc { |_sender, e|
  next unless defined?(XorronModSettings) && XorronModSettings.enabled?("xorron_mod_enabled")
  result = e[0]
  fainted_at_end = 0
  if $Trainer && $Trainer.party
    $Trainer.party.each { |pkmn| fainted_at_end += 1 if pkmn && pkmn.hp <= 0 }
  end
  newly_fainted = fainted_at_end > XorronMapProgress.get_fainted_count_at_start
  if result == 2
    XorronMapProgress.add_loss(false)
  elsif newly_fainted
    XorronMapProgress.add_loss(true)
  elsif result == 1 || result == 4
    XorronMapProgress.add_win
  end
}
