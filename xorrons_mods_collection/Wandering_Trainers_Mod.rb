#===============================================================================
# Wandering Trainers Mod 9.47 (Based on 9.43 - Full Restoration & Fast Shift)
#===============================================================================

class WanderingTrainersSaveData
  attr_accessor :spawned_ids, :trainer_data, :last_map_id, :noticed_player, :follower_mode, :follower_timers
  def initialize
    @spawned_ids = []; @trainer_data = {}; @last_map_id = 0; @noticed_player = {}; @follower_mode = {}; @follower_timers = {}
  end
end

# KIF fix: the data was kept in $PokemonGlobal (a mod class inside the save, so the save could not
# load once the mod was removed). It is now kept in memory for the loaded game only; trainers
# spawn anew after loading a save.

class Game_Character
  attr_accessor :xorron_flash_color, :xorron_flash_duration
  def xorron_hop; @jump_peak = 10; @jump_distance = 0; @jump_count = 20; end
  def xorron_request_flash(color, duration); @xorron_flash_color = color; @xorron_flash_duration = duration; end
end

class Game_Event
  alias xorron_wt_start_v947 start unless method_defined?(:xorron_wt_start_v947)
  def start
    # KIF fix: only this mod's events (the game's temporary events can get ids in these ranges too)
    if @xorron_wt
      WanderingTrainersMod.interact(@id); return
    end
    xorron_wt_start_v947
  end
end

# Engine-Patch fuer den Sprite-Blitz (Hoch-intensiv)
class Sprite_Character < RPG::Sprite
  alias xorron_flash_update_wt update unless method_defined?(:xorron_flash_update_wt)
  def update
    xorron_flash_update_wt rescue super
    if @character && @character.respond_to?(:xorron_flash_duration) && @character.xorron_flash_duration && @character.xorron_flash_duration > 0
      self.flash(@character.xorron_flash_color, @character.xorron_flash_duration)
      @character.xorron_flash_duration = 0
    end
  end
end

module WanderingTrainersMod
  @spawn_cooldown = 60
  def self.data
    return nil if !$PokemonGlobal
    # KIF fix: fresh data for each loaded game (see above)
    if !@data || !@data_owner.equal?($PokemonGlobal)
      @data = WanderingTrainersSaveData.new; @data_owner = $PokemonGlobal
    end
    @data
  end

  # KIF fix: new events get a sprite in the current spriteset instead of every spriteset being rebuilt
  def self.add_sprites(events)
    ss = ($scene.spriteset rescue nil)
    return unless ss && ss.respond_to?(:character_sprites) && ss.map == $game_map
    events.each { |ev| ss.character_sprites.push(Sprite_Character.new(ss.viewport1, ev)) }
  end

  def self.remove_sprites(events)
    ss = ($scene.spriteset rescue nil)
    return unless ss && ss.respond_to?(:character_sprites)
    ss.character_sprites.reject! { |s| events.include?(s.character) && (s.dispose; true) }
  end
  def self.spawned_ids; d = self.data; d ? d.spawned_ids : []; end

  def self.move_toward(char, target)
    return if !char || !target || char.erased || target.erased
    sx = char.x - target.x; sy = char.y - target.y; return if sx == 0 && sy == 0
    if sx.abs > sy.abs; (sx > 0) ? char.move_left : char.move_right; else; (sy > 0) ? char.move_up : char.move_down; end
  end

  ALLOWED_TAGS = [0, 2, 3, 4, 13, 24, 25, 26]
  TRAINER_VARIANTS = [
    { :id => :YOUNGSTER,   :sprite => "YOUNGSTER_LeagueHat", :name => "Youngster" },
    { :id => :LASS,        :sprite => "LASS_blue",           :name => "Lass" },
    { :id => :HIKER,       :sprite => "BWHiker",             :name => "Hiker" },
    { :id => :CAMPER,      :sprite => "BW001",               :name => "Camper" },
    { :id => :PICNICKER,   :sprite => "BW002",               :name => "Picnicker" },
    { :id => :BIRDKEEPER,  :sprite => "BW010",               :name => "Bird Keeper" },
    { :id => :SAILOR,      :sprite => "BWSailor",            :name => "Sailor" },
    { :id => :BUGCATCHER,  :sprite => "BWBugCatcher_male",   :name => "Bug Catcher" },
    { :id => :LADY,        :sprite => "BWLady",              :name => "Lady" },
    { :id => :BEAUTY,      :sprite => "BW006",               :name => "Beauty" },
    { :id => :COOLTRAINER_M, :sprite => "BW014",             :name => "Ace Trainer" },
    { :id => :COOLTRAINER_F, :sprite => "BW013",             :name => "Ace Trainer" },
    { :id => :POKEMONTRAINER_Red, :sprite => "trainer_POKEMONTRAINER_Red", :name => "Trainer Red" },
    { :id => :POKEMONTRAINER_Leaf, :sprite => "trainer_POKEMONTRAINER_Leaf", :name => "Trainer Leaf" },
    { :id => :RIVAL1,      :sprite => "gary_oak_overworld_bw_completed_by_malice936-d5ruwuc", :name => "Rival Gary" },
    { :id => :SWIMMER_M,   :sprite => "BWSwimmerLand",       :name => "Swimmer", :water => true },
    { :id => :SWIMMER_F,   :sprite => "BWSwimmer_female",    :name => "Swimmer", :water => true },
    { :id => :GENTLEMAN,   :sprite => "BWGentleman", :name => "Gentleman" },
    { :id => :PSYCHIC_M,   :sprite => "BW017",               :name => "Psychic" },
    { :id => :PSYCHIC_F,   :sprite => "BW018",               :name => "Psychic" },
    { :id => :SCIENTIST,   :sprite => "BWAssistant_male",    :name => "Scientist" },
    { :id => :TEAMROCKET_M, :sprite => "BW2_rocket(male)",   :name => "Rocket Grunt" },
    { :id => :TEAMROCKET_F, :sprite => "BW2_rocket(female)", :name => "Rocket Grunt" },
    { :id => :BIKER,       :sprite => "BWBiker",             :name => "Biker" },
    { :id => :BLACKBELT,   :sprite => "BWBlackbelt",         :name => "Black Belt" },
    { :id => :CRUSHGIRL,   :sprite => "BWBattleGirl",        :name => "Battle Girl" },
    { :id => :DOCTOR,      :sprite => "BWDoctor",            :name => "Doctor" },
    { :id => :NURSE,       :sprite => "BWNurse",             :name => "Nurse" },
    { :id => :FISHERMAN,   :sprite => "BWFisherman",         :name => "Fisherman" },
    { :id => :POKEMONRANGER_M, :sprite => "BWRanger_male",   :name => "Pokemon Ranger" },
    { :id => :POKEMONRANGER_F, :sprite => "BWRanger_female", :name => "Pokemon Ranger" },
    { :id => :POKEMANIAC,  :sprite => "BW035",               :name => "Pokemaniac" },
    { :id => :TUBER_M,     :sprite => "BWTuber_male",        :name => "Tuber" },
    { :id => :TUBER_F,     :sprite => "BWTuber_female",      :name => "Tuber" },
    { :id => :JUGGLER,     :sprite => "BWHarlequin",         :name => "Juggler" },
    { :id => :BACKPACKER_M, :sprite => "BWBackpacker_male",  :name => "Backpacker" },
    { :id => :BACKPACKER_F, :sprite => "BWBackpacker_female",:name => "Backpacker" },
    { :id => :LEADER_Brock, :sprite => "BW_brock", :name => "Leader Brock" },
    { :id => :LEADER_Misty, :sprite => "BWLeaderMisty",      :name => "Leader Misty" },
    { :id => :LEADER_Surge, :sprite => "BW_surge",           :name => "Leader Surge" },
    { :id => :LEADER_Erika, :sprite => "BW_Erika",           :name => "Leader Erika" },
    { :id => :LEADER_Sabrina, :sprite => "BW_Sabrina",       :name => "Leader Sabrina" }
  ]
  # KIF fix: 6.8.2 has no DOCTOR, BACKPACKER_M or BACKPACKER_F trainer type (a battle with one
  # crashes), so only types the game has are used
  def self.variants
    @variants ||= TRAINER_VARIANTS.select { |v| GameData::TrainerType.exists?(v[:id]) rescue false }
  end

  NAME_POOL = ["Alex", "Logan", "Jordan", "Terry", "Kim", "Sam", "Chris", "Pat", "Robin", "Casey", "Skyler", "Taylor", "Morgan", "Riley", "Quinn", "Sacha", "Ash", "Gary", "Blue", "Red", "Zorron", "Kuray", "René", "Misty", "Brock", "Erika", "Sabrina", "Blaine", "Giovanni"]

  def self.resolve_single_pkmn_sprite(pkmn_data)
    return nil if !pkmn_data; species_id = pkmn_data.id rescue (pkmn_data.species rescue nil); return nil if !species_id
    id_num = pkmn_data.id_number rescue 1; id_3 = sprintf("%03d", id_num); name_up = species_id.to_s.upcase
    folders = ["Followers/", "Overworld/", ""]; patterns = [name_up, id_3, id_num.to_s]
    # 1. Standard-Pfade in Graphics/Characters/
    folders.each { |f| patterns.each { |p| next if p.to_s.empty?; path = f + p; return path if pbResolveBitmap("Graphics/Characters/" + path) } }
    
    # 2. Random-Disguise Fallback (Erweitert bis Gen 7 / ID 800)
    [13, 7, 19, 3, 31].each do |mult|
      pseudo_id = (id_num.to_i * mult) % 800 + 1 
      p_3 = sprintf("%03d", pseudo_id)
      ["Overworld/#{p_3}", "Followers/#{p_3}"].each do |path|
        return path if pbResolveBitmap("Graphics/Characters/" + path)
      end
    end
    
    return "133" 
  end

  def self.get_pkmn_sprite(pkmn, force_mode = nil)
    return "133" if !pkmn
    begin
      mode = force_mode || :body
      is_fusion = (pkmn.isFusion? rescue false)
      target_data = is_fusion ? ((mode == :head) ? pkmn.species_data.head_pokemon : pkmn.species_data.body_pokemon) : pkmn
      sprite = self.resolve_single_pkmn_sprite(target_data); return sprite if sprite
      
      if is_fusion; alt_data = (mode == :head) ? pkmn.species_data.body_pokemon : pkmn.species_data.head_pokemon; sprite = self.resolve_single_pkmn_sprite(alt_data); return sprite if sprite; end
      if defined?(pbPokemonCharName); engine_name = pbPokemonCharName(pkmn).to_s; return engine_name if !engine_name.empty? && pbResolveBitmap("Graphics/Characters/" + engine_name); end
    rescue; end; return "133" 
  end

  LEGENDARY_IDS = [144, 145, 146, 150, 151, 243, 244, 245, 249, 250, 251, 377, 378, 379, 380, 381, 382, 383, 384, 385, 386, 480, 481, 482, 483, 484, 485, 486, 487, 488, 489, 490, 491, 492, 493, 494, 638, 639, 640, 641, 642, 643, 644, 645, 646, 647, 648, 649, 716, 717, 718, 719, 720, 721, 772, 773, 785, 786, 787, 788, 789, 790, 791, 792, 793, 794, 795, 796, 797, 798, 799, 800, 801, 802, 807, 803, 804, 805, 806, 888, 889, 890, 891, 892, 893, 894, 895, 896, 897, 898, 905]
  def self.is_legendary?(id); LEGENDARY_IDS.include?(id); end
  def self.get_random_id(allow_legendary = true); loop do; id = rand(Settings::NB_POKEMON) + 1; return id if allow_legendary || !is_legendary?(id); end; end

  def self.generate_smart_pkmn(level)
    is_legendary_roll = (rand(100) < 5) 
    if rand(100) < 50
      head = is_legendary_roll ? LEGENDARY_IDS.sample : self.get_random_id(false); body = self.get_random_id(false); body = self.get_random_id(false) while body == head
      fused_id = defined?(getSpeciesIdForFusion) ? getSpeciesIdForFusion(head, body) : (body * Settings::NB_POKEMON) + head rescue head
      pkmn = Pokemon.new(fused_id, level)
    else; id = is_legendary_roll ? LEGENDARY_IDS.sample : self.get_random_id(false); pkmn = Pokemon.new(id, level); end
    pkmn.shiny = true if rand(100) < 10; return pkmn
  end

  def self.update
    return if !self.data; return unless defined?(XorronModSettings) && XorronModSettings.enabled?("wandering_trainers_enabled")
    # Starte anstehende Kämpfe sicher ausserhalb des Spieler-Triggers
    self.execute_pending_battle if @pending_battle
    
    if @spawn_cooldown > 0; @spawn_cooldown -= 1; else; self.setup_map_spawn; @spawn_cooldown = 120; end
    self.check_player_proximity if $game_player && Graphics.frame_count % 20 == 0
    self.update_shapeshifting
  end

  def self.update_shapeshifting
    return if !self.data || !$game_map; self.spawned_ids.each do |id|
      next if id < 7000 || id > 7015; event = $game_map.events[id]; next if !event || event.erased
      self.data.follower_timers[id] = 0 if !self.data.follower_timers[id]
      if self.data.follower_timers[id] > 0; self.data.follower_timers[id] -= 1; next; end
      t_id = id + 1000; data = self.data.trainer_data[t_id]; next if !data
      pkmn = data[:team][0]; is_fusion = (pkmn.isFusion? rescue false); next unless is_fusion
      current_mode = self.data.follower_mode[id] || :body; new_mode = (current_mode == :head) ? :body : :head
      self.data.follower_mode[id] = new_mode; 
      
      # FAST INTERVALL: 15-30 Sekunden
      self.data.follower_timers[id] = 600 + rand(601)
      
      event.character_name = self.get_pkmn_sprite(pkmn, new_mode).to_s
      # Pokémon Referenz fuer den Shiny Sprite Fix speichern
      event.instance_variable_set(:@xorron_pkmn_ref, pkmn)

      if $scene.is_a?(Scene_Map) && $scene.respond_to?(:spriteset) && $scene.spriteset
        pbSEPlay("Battle recall") rescue nil; event.xorron_hop rescue nil
        rnd_col = Color.new(rand(256), rand(256), rand(256), 255)
        event.xorron_request_flash(rnd_col, 50) rescue nil
        ss = $scene.spriteset
        ss.addUserAnimation(2, event.x, event.y, true, 1) rescue nil
        ss.addUserAnimation(7, event.x, event.y, true, 1) rescue nil
      end
    end
  end

  def self.check_player_proximity
    return if !self.data || !$game_map || !$scene.is_a?(Scene_Map)
    self.spawned_ids.each do |id|
      next if id < 8000; event = $game_map.events[id]
      next if !event || event.erased || self.data.noticed_player[id]
      if (event.x - $game_player.x).abs + (event.y - $game_player.y).abs <= 3
        self.data.noticed_player[id] = true; $scene.spriteset.addUserAnimation(3, event.x, event.y, true, 3) rescue nil; pbSEPlay("Notice") rescue nil
      end
    end
  end

  def self.setup_map_spawn
    return if !self.data || !$game_map; map_name = $game_map.name rescue ""; is_house = ["Center", "Mart", "Gym", "Lab", "House", "Room", "Gate", "Elevator", "Hotel", "Department", "Office", "Clinic", "Floor", "Basement", "Attic"].any? { |s| map_name.include?(s) }
    return if is_house || ($game_map.width < 28 && $game_map.height < 28); if self.data.last_map_id != $game_map.map_id; self.clear_all_spawns; self.data.last_map_id = $game_map.map_id; end
    limit = defined?(XorronModSettings) ? (XorronModSettings.get("wandering_trainers_limit") || 10) : 10
    # KIF fix: sprites are added for the new events only (was: all spritesets rebuilt)
    (0...limit).each { |i| t_id = 8000 + i; next if self.data.trainer_data[t_id]; if self.spawn_duo(i) && $scene.is_a?(Scene_Map); d = self.data.trainer_data[t_id]; self.add_sprites([$game_map.events[t_id], $game_map.events[d[:p_id]]]); end }
  end

  def self.spawn_duo(index)
    # KIF fix: never replace one of the map's own events that already uses these ids
    return false if [8000 + index, 7000 + index].any? { |id| (e = $game_map.events[id]) && !e.instance_variable_get(:@xorron_wt) }
    tr_variant = self.variants.sample; spawn_pos = self.find_spawn_point(tr_variant); return false unless spawn_pos
    t_id = 8000 + index; t_event = self.create_virtual_event(t_id, spawn_pos[0], spawn_pos[1], tr_variant[:sprite].to_s, 1)
    $game_map.events[t_id] = t_event; self.spawned_ids.push(t_id); team_levels = $Trainer.party.map { |p| p.level }; avg_level = (team_levels.sum / team_levels.size.to_f).round rescue 5
    level_offset = (tr_variant[:id].to_s.include?("ACE") || tr_variant[:id].to_s.include?("LEADER") || tr_variant[:id].to_s.include?("POKEMONTRAINER") || tr_variant[:id].to_s.include?("RIVAL")) ? (1 + rand(3)) : -(2 + rand(3))
    final_level = [[avg_level + level_offset, 100].min, 1].max
    team = []; has_shiny = false; is_elite = (tr_variant[:id].to_s.include?("ACE") || tr_variant[:id].to_s.include?("LEADER") || tr_variant[:id].to_s.include?("POKEMONTRAINER") || tr_variant[:id].to_s.include?("RIVAL"))
    num_pkmn = is_elite ? (4 + rand(3)) : (1 + rand(4))
    num_pkmn.times do |i|; p_level = [[(i == 0) ? final_level + 1 + rand(2) : final_level + rand(3) - 1, 100].min, 1].max; pkmn = self.generate_smart_pkmn(p_level); has_shiny = true if pkmn.shiny?; team << pkmn; end
    p_id = 7000 + index; initial_mode = (rand(2) == 0 ? :head : :body); self.data.follower_mode[p_id] = initial_mode; self.data.follower_timers[p_id] = 600 + rand(601)
    char_name = self.get_pkmn_sprite(team[0], initial_mode).to_s
    p_event = self.create_virtual_event(p_id, spawn_pos[0], spawn_pos[1], char_name, 0); p_event.through = true
    # Pokémon Referenz fuer den Shiny Sprite Fix speichern
    p_event.instance_variable_set(:@xorron_pkmn_ref, team[0])
    $game_map.events[p_id] = p_event; self.spawned_ids.push(p_id)
    self.data.trainer_data[t_id] = { :name => "#{tr_variant[:name]} #{NAME_POOL.sample}", :tr_type => tr_variant[:id], :team => team, :p_id => p_id, :has_shiny => has_shiny }; return true
  end

  def self.create_virtual_event(id, x, y, char_name, move_type)
    rpg_event = RPG::Event.new(x, y); rpg_event.id = id; page = RPG::Event::Page.new; page.graphic.character_name = char_name.to_s; page.move_type = move_type; page.move_frequency = 3; page.move_speed = 3; page.trigger = 0; rpg_event.pages = [page]
    ev = Game_Event.new($game_map.map_id, rpg_event, $game_map); ev.character_name = char_name.to_s; ev.set_opacity(255)
    ev.instance_variable_set(:@xorron_wt, true); ev.instance_variable_set(:@xorron_mod_event, true)   # KIF fix: marks this mod's events
    return ev
  end

  def self.find_spawn_point(variant = nil)
    return nil unless $game_map; 500.times do; rx = rand($game_map.width); ry = rand($game_map.height); next unless $game_map.valid?(rx, ry); next if (rx - $game_player.x).abs + (ry - $game_player.y).abs < 6
      tag = $game_map.terrain_tag(rx, ry) rescue nil; tag_id = tag.is_a?(Integer) ? tag : (tag.id_number rescue 0); next if tag_id > 15 || tag_id == 14
      if tag_id == 10; next unless variant && variant[:water]; end; next unless $game_map.passable?(rx, ry, 0, $game_player)
      occupied = false; $game_map.events.values.each { |e| if e.x == rx && e.y == ry && !e.erased; occupied = true; break; end }; next if occupied || !ALLOWED_TAGS.include?(tag_id)
      passable_neighbors = 0; [2, 4, 6, 8].each { |d| passable_neighbors += 1 if $game_map.passable?(rx, ry, d, $game_player) }; return [rx, ry] if passable_neighbors >= 2; end; return nil
  end

  def self.clear_all_spawns
    return if !self.data || !$game_map
    # KIF fix: only delete events that are still this mod's, and drop their sprites
    gone = []; self.spawned_ids.each { |id| ev = $game_map.events[id]; gone << $game_map.events.delete(id) if ev && ev.instance_variable_get(:@xorron_wt) }
    self.remove_sprites(gone) if $scene.is_a?(Scene_Map)
    self.data.spawned_ids = []; self.data.trainer_data = {}; self.data.noticed_player = {}; self.data.follower_mode = {}; self.data.follower_timers = {}
  end

  FAREWELL_POOL = [
    "My Pokemon are fainted, just like my will to live.",
    "Take the money. I’ll just tell my kids we’re skipping dinner tonight.",
    "I hope you run out of Repels in a cave full of Zubats.",
    "I spent years training. You spent seconds winning. Life is fair.",
    "Winning against a hobo... you must be so proud of yourself.",
    "I'd say 'good game', but I'm not a pathological liar.",
    "Go away before I report you for animal cruelty.",
    "I hope your next Shiny has the worst nature possible.",
    "My life is a joke, but at least it's shorter than this conversation.",
    "At least my medical bill is cheaper than your personality.",
    "I’d call you a loser, but you actually won. How embarrassing for me.",
    "Is beating up strangers your only hobby? Seek professional help.",
    "Don't worry about me, I'll just starve here until the next player spawns.",
    "Your Pokemon look like they hate you. I don't blame them.",
    "Death is temporary, but the shame of losing to you is forever.",
    "I hope your Pokedex deletes itself while you sleep.",
    "I'm not crying, it's just my eyes leaking out my last bit of dignity.",
    "Great, now I have to sell my shoes to pay you. Enjoy the walk.",
    "I hope you find a Shiny and your game crashes before you can save.",
    "Go find a Gym Leader to bother. I'm busy being depressed.",
    "I was having a good day. Then you happened. Thanks for that.",
    "My Pokemon are in therapy now. And I'm paying for it.",
    "I hope every wild encounter you have is a Rattata. For eternity.",
    "You win money, I win a lifetime of regret. Everyone wins!",
    "I’d tell you to have a nice day, but I don’t want to lie twice today.",
    "Oh look, another person better than me. How incredibly original.",
    "I hope your charger only works at a very specific, impossible angle.",
    "My team is trash, but at least they're better company than you.",
    "I hope you drop your ice cream on the sidewalk in front of a kid.",
    "You’re the reason people avoid tall grass. Truly.",
    "Just take my money and leave. I need to contemplate my existence.",
    "I hope your favorite Pokemon gets nerfed into oblivion.",
    "I used to be a trainer like you, then I realized I was garbage.",
    "My Pokemon were faking it. They just wanted to leave this battle.",
    "I hope you step on a sharp d4 die in the dark.",
    "Being a trainer is fun, they said. You won't get bullied, they said.",
    "I'm going to go eat my feelings. It's going to be a very long meal.",
    "I hope your internet lags during your most important battle.",
    "You won. Do you want a medal? Because I only have unpaid bills.",
    "I’d give you my number, but I’ve already suffered enough today.",
    "My Pokemon are fainted. I’m fainted. Everything is just... fainted.",
    "I hope you accidentally use your only Master Ball on a Magikarp.",
    "Go show off your skills to someone who actually gives a damn.",
    "I hope your pillow is uncomfortably warm on both sides tonight.",
    "I’m not a loser, I’m just 'victoriously challenged'.",
    "I hope you forget to save after catching a rare legendary.",
    "I spent my last Pokedollars on Potions that didn't even work.",
    "Your victory is as hollow as my bank account. And my soul.",
    "I hope your socks are always slightly damp. Forever.",
    "Is it lonely up there on your high horse, oh mighty champion?",
    "I'm going to tell my Magikarp about this. He'll do nothing, as usual.",
    "I hope you always get the '3-shake and break' on every capture.",
    "My Pokemon are resting. Permanently, at this rate.",
    "I hope you get stuck in a door in every building you enter.",
    "You battle like a machine. A very annoying, loud, broken machine.",
    "I hope your coffee is always just a little bit too cold to enjoy.",
    "I’m going to start a new career in something I’m good at. Like failing.",
    "I hope you get an 'Internal Battery has run out' message right now.",
    "Take the money. I didn't really feel like eating this week anyway.",
    "I hope you run into a Shiny Golem that immediately uses Self-Destruct.",
    "My Pokemon are fainted. My spirit is broken. Are you happy now?",
    "I hope you always find the stairs on the very last tile of a floor.",
    "I’d ask for a rematch, but I prefer my dignity in small pieces.",
    "I hope you get confused and hit yourself in confusion five times.",
    "You’re like a Zubat. Annoying, persistent, and everywhere I go.",
    "I hope your next egg is a Smeargle with the worst possible stats.",
    "I'm going to go cry in the Pokemon Center. They have free tissues.",
    "I hope you always lose your 50/50 chances in every game.",
    "My life is just a series of fainted Pokemon and bad decisions.",
    "Just go. I have nothing left but this empty, useless Poke Ball."
  ]

  def self.interact(id)
    return if !self.data; t_id = (id >= 7000 && id <= 7015) ? id + 1000 : id; data = self.data.trainer_data[t_id]; return if !data; pbPlayCry(data[:team][0]) rescue nil
    nearby = []; self.spawned_ids.each { |oid| next if oid < 8000 || oid == t_id; ev = $game_map.events[oid]; tev = $game_map.events[t_id]; next if !ev || ev.erased || !tev; nearby << oid if (ev.x - tev.x).abs + (ev.y - tev.y).abs <= 3 }; nearby = nearby.first(2)
    party_size = $Trainer.party.readable_count rescue $Trainer.party.size; b_text = "Challenge Trainer"; b_text = "Challenge Duo (2 vs 2)" if nearby.size == 1 && party_size >= 2; b_text = "Challenge Trio (3 vs 3)" if nearby.size == 2 && party_size >= 3
    commands = [_INTL(b_text), _INTL("Scan Team Stats"), _INTL("Cancel")]; choice = pbMessage(_INTL("{1}\n{2}", data[:name], data[:has_shiny] ? "✨ SHINY DETECTED ✨" : ""), commands, 2)
    case choice; when 0 then self.trigger_multi_battle(t_id, nearby); when 1; pbMessage(_INTL("Scanning {1}'s team...", data[:name])); temp_team = data[:team].map { |p| p.clone }; pbFadeOutIn { scene = PokemonSummary_Scene.new; screen = PokemonSummaryScreen.new(scene); screen.pbStartScreen(temp_team, 0) }; end
  end

  @battle_starting = false
  @pending_battle = nil
  
  def self.trigger_multi_battle(main_id, extra_ids)
    return if !self.data || @battle_starting
    # Statt Kampf sofort zu starten, merken wir uns die Daten und beenden das Gespräch
    @pending_battle = { :main => main_id, :extra => extra_ids }
  end

  def self.execute_pending_battle
    return if !@pending_battle || @battle_starting
    data_to_use = @pending_battle; @pending_battle = nil; @battle_starting = true
    
    main_id = data_to_use[:main]; extra_ids = data_to_use[:extra]
    all_data = [self.data.trainer_data[main_id]]
    extra_ids.each { |id| all_data << self.data.trainer_data[id] if self.data.trainer_data[id] }
    
    # KIF fix: the original switched off the game's argument checks (Kernel#validate) and message
    # loading (Messages#delayedLoad) for the whole battle. Removed; nothing in the battle needs it.

    battle_result = false
    begin
      # KIF ENGINE FIX: Wir fusionieren alle Trainer zu einem Objekt um UI-Freezes zu vermeiden
      main_d = all_data[0]
      clean_name = main_d[:name].split(" ").last.gsub(/[^a-zA-Z]/, "")
      clean_name = "Group " + clean_name if all_data.size > 1
      
      consolidated_t = NPCTrainer.new(clean_name, main_d[:tr_type] || :YOUNGSTER)
      consolidated_t.lose_text = "..."
      
      # Pokémon hinzufügen, aber LIMIT von 6 beachten (Engine-Stabilität)
      all_pokemon = []
      all_data.each { |d| d[:team].each { |p| all_pokemon << p } }
      all_pokemon.first(6).each { |p| consolidated_t.party.push(p) }

      # Multi-Battle Regeln setzen - Die Engine skaliert die Battler automatisch
      if all_data.size == 2
        setBattleRule("double")
      elsif all_data.size == 3
        setBattleRule("triple")
      end
      
      # Start des Kampfes mit dem konsolidierten Trainer
      battle_result = (pbTrainerBattleCore(consolidated_t) == 1)
    rescue => e
      KIF.log("Wandering Trainers battle failed: #{e.class}: #{e.message} @ #{(e.backtrace || [])[0]}") if defined?(KIF) && KIF.respond_to?(:log)   # KIF fix: logged
      pbMessage(_INTL("Battle Error: {1}", e.message))
      battle_result = false
    ensure
      @battle_starting = false
      $PokemonTemp.clearBattleRules rescue nil
    end
    
    if battle_result
      pbMessage(_INTL(FAREWELL_POOL.sample))
      self.remove_duo(main_id)
      extra_ids.each { |eid| self.remove_duo(eid) }
    end
  end

  def self.remove_duo(t_id)
    return if !self.data; data = self.data.trainer_data[t_id]; return if !data; p_id = data[:p_id]
    # KIF fix: only this mod's events are erased/deleted, and their sprites are freed
    gone = [t_id, p_id].map { |id| ev = id && $game_map.events[id]; ev if ev && ev.instance_variable_get(:@xorron_wt) }.compact
    gone.each { |ev| ev.erase; $game_map.events.delete(ev.id) }
    self.remove_sprites(gone) if $scene.is_a?(Scene_Map)
    self.data.trainer_data.delete(t_id); self.data.noticed_player.delete(t_id); self.data.spawned_ids.delete(t_id); self.data.spawned_ids.delete(p_id); self.data.follower_mode.delete(p_id); self.data.follower_timers.delete(p_id)
  end
end

Events.onMapUpdate += proc { |_sender, e| WanderingTrainersMod.update; if $game_map; WanderingTrainersMod.spawned_ids.each { |id| if id >= 7000 && id <= 7015; t_id = id + 1000; t = $game_map.events[t_id]; p = $game_map.events[id]; if p && t && !p.erased && !t.erased; WanderingTrainersMod.move_toward(p, t) if (t.x - p.x).abs > 1 || (t.y - p.y).abs > 1; end; end }; end }
Events.onMapSceneChange += proc { |_sender, e| WanderingTrainersMod.instance_variable_set(:@spawn_cooldown, 40) }

class Game_Player
  alias xorron_wt_v946_check check_event_trigger_there unless method_defined?(:xorron_wt_v946_check)
  def check_event_trigger_there(triggers)
    return false if $game_system.map_interpreter.running? || (defined?(WanderingTrainersMod) && WanderingTrainersMod.instance_variable_get(:@battle_starting))
    # KIF fix: an error in the game's own check is logged (was silently swallowed by `rescue false`)
    begin
      result = xorron_wt_v946_check(triggers)
    rescue => e
      KIF.log("Wandering Trainers: check_event_trigger_there failed: #{e.class}: #{e.message} @ #{(e.backtrace || [])[0]}") if defined?(KIF) && KIF.respond_to?(:log)
      result = false
    end
    return result if result
    new_x = @x + (@direction == 6 ? 1 : @direction == 4 ? -1 : 0); new_y = @y + (@direction == 2 ? 1 : @direction == 8 ? -1 : 0)
    $game_map.events.values.each { |event| if event && !event.erased && event.instance_variable_get(:@xorron_wt); if event.at_coordinate?(new_x, new_y) || ((event.real_x / 128.0 - new_x).abs < 0.8 && (event.real_y / 128.0 - new_y).abs < 0.8); WanderingTrainersMod.interact(event.id); return true; end; end }; return false
  end
end
