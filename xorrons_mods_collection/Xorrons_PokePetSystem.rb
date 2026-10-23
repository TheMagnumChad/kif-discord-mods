#===============================================================================
# Xorron's PokePetSystem 12.19 (Interaction Menu Restoration)
#===============================================================================

class Game_Character
  attr_accessor :step_anime unless method_defined?(:step_anime=)
  attr_accessor :move_type unless method_defined?(:move_type=)
  attr_accessor :move_frequency unless method_defined?(:move_frequency=)
  attr_accessor :xorron_flash_color
  attr_accessor :xorron_flash_duration

  def xorron_hop; @jump_peak = 10; @jump_distance = 0; @jump_count = 20; end
  def xorron_request_flash(color, duration); @xorron_flash_color = color; @xorron_flash_duration = duration; end
end

class Sprite_Character < RPG::Sprite
  alias xorron_flash_update update unless method_defined?(:xorron_flash_update)
  def update
    xorron_flash_update rescue super
    if @character && @character.respond_to?(:xorron_flash_duration) && @character.xorron_flash_duration && @character.xorron_flash_duration > 0
      self.flash(@character.xorron_flash_color, @character.xorron_flash_duration)
      @character.xorron_flash_duration = 0
    end
  end
end

if defined?(pbFancyMoveTo) && !defined?(xorron_original_pbFancyMoveTo)
  alias xorron_original_pbFancyMoveTo pbFancyMoveTo
  def pbFancyMoveTo(follower, newX, newY, leader)
    if follower && follower.id >= 9000 && follower.id <= 9005
      return if XorronsPokePetSystem.is_wandering?(follower.id - 9000)
    end
    xorron_original_pbFancyMoveTo(follower, newX, newY, leader)
  end
end

class Game_Player
  # FIX 12.19: Neuer Alias Name zur Sicherheit
  alias xorron_check_trigger_v1219 check_event_trigger_there unless method_defined?(:xorron_check_trigger_v1219)
  def check_event_trigger_there(triggers)
    result = xorron_check_trigger_v1219(triggers)
    return result if result 
    return false if !$PokemonTemp || !$PokemonTemp.dependentEvents
    
    # Zielkoordinaten vor dem Spieler
    new_x = @x + (@direction == 6 ? 1 : @direction == 4 ? -1 : 0)
    new_y = @y + (@direction == 2 ? 1 : @direction == 8 ? -1 : 0)
    
    # Suche in allen Dependent Events
    $PokemonTemp.dependentEvents.eachEvent do |event, data|
      next unless event
      # Interaktion via Name (sicherer als ID)
      if data[8] && data[8].start_with?("XF_")
        slot = data[8].split("_")[1].to_i
        # Prüfe Position mit kleiner Toleranz für flüssige Bewegung
        if (event.x == new_x && event.y == new_y) || 
           ((event.real_x / 128.0 - new_x).abs < 0.7 && (event.real_y / 128.0 - new_y).abs < 0.7)
          XorronsPokePetSystem.interact(slot, event)
          return true
        end
      end
    end
    return false
  end
end

module XorronsPokePetSystem
  @initialized_map = 0
  @shapeshift_timers = {}
  @current_mode = {}
  @wandering_state = {}
  @player_idle_ticks = 0

  def self.is_wandering?(slot); @wandering_state[slot] == true; end

  def self.refresh_followers
    @last_party_checksum = 0
    @initialized_map = 0
  end

  def self.get_pkmn_sprite(pkmn, force_mode = nil)
    return "133" if !pkmn
    begin
      mode = force_mode || :body
      is_fusion = (pkmn.isFusion? rescue false)
      target_data = is_fusion ? ((mode == :head) ? pkmn.species_data.head_pokemon : pkmn.species_data.body_pokemon) : pkmn
      sprite = WanderingTrainersMod.resolve_single_pkmn_sprite(target_data) if defined?(WanderingTrainersMod)
      return sprite if sprite
      
      # Lokaler Fallback Kostüm-Logik (Pool bis Gen 7)
      id_num = target_data.id_number rescue 1
      [13, 7, 19, 3, 31].each do |mult|
        pseudo_id = (id_num.to_i * mult) % 800 + 1 
        p_3 = sprintf("%03d", pseudo_id)
        ["Overworld/#{p_3}", "Followers/#{p_3}"].each do |path|
          return path if pbResolveBitmap("Graphics/Characters/" + path)
        end
      end
      
      if defined?(pbPokemonCharName); name = pbPokemonCharName(pkmn).to_s; return name if !name.empty? && pbResolveBitmap("Graphics/Characters/" + name); end
    rescue; end; return "133" 
  end

  # Erweiterte Formations-Logik (Bodyguard-Squad)
  def self.get_formation_pos(slot)
    p = $game_player
    d = p.direction
    # Vektoren berechnen
    bx = (d == 6 ? -1 : d == 4 ? 1 : 0) # Hinter-Vektor
    by = (d == 2 ? -1 : d == 8 ? 1 : 0)
    sx = (d == 2 ? 1 : d == 4 ? 0 : d == 6 ? 0 : -1) # Seiten-Vektor (Rechts)
    sy = (d == 2 ? 0 : d == 4 ? -1 : d == 6 ? 1 : 0)

    case slot
    when 0 # Follower 1: Direkt hinter Spieler
      return [p.x + bx, p.y + by]
    when 1 # Follower 2: Links neben Spieler
      return [p.x - sx, p.y - sy]
    when 2 # Follower 3: Rechts neben Spieler
      return [p.x + sx, p.y + sy]
    when 3 # Follower 4: Hinter Nummer 2
      return [p.x - sx + bx, p.y - sy + by]
    when 4 # Follower 5: Hinter Nummer 3
      return [p.x + sx + bx, p.y + sy + by]
    when 5 # Follower 6: Hinter Nummer 1 (Zentrum hinten)
      return [p.x + 2*bx, p.y + 2*by]
    end
    return [p.x, p.y]
  end

  def self.update
    return unless defined?(XorronModSettings) && XorronModSettings.enabled?("follower_system_enabled")
    return if !$game_map || !$scene.is_a?(Scene_Map)
    
    # Party-Change Detection (Check for Species, HP, and Party size)
    current_party_checksum = $Trainer.party.map { |p| [p.species, p.hp, p.shiny?] }.hash rescue 0
    @last_party_checksum ||= current_party_checksum

    if @initialized_map != $game_map.map_id || @last_party_checksum != current_party_checksum
      @initialized_map = $game_map.map_id
      @last_party_checksum = current_party_checksum
      self.setup_followers
    end
    
    self.update_movement_logic
    self.update_shapeshifting
  end

  def self.update_movement_logic
    player_moving = ($game_player.real_x != $game_player.x * 128 || $game_player.real_y != $game_player.y * 128)
    (0..5).each do |i|
      ev = $PokemonTemp.dependentEvents.getEventByName("XF_#{i}")
      next unless ev
      if player_moving
        if @wandering_state[i]; @wandering_state[i] = false; ev.move_type = 0; end
      else
        @player_idle_ticks += 1
        if @player_idle_ticks > 600 && !@wandering_state[i] && rand(100) < 5
          @wandering_state[i] = true; ev.move_type = 1
        end
      end
    end
    @player_idle_ticks = 0 if player_moving
  end

  def self.update_shapeshifting
    return unless XorronModSettings.enabled?("follower_shapeshift_enabled")
    speed_mode = XorronModSettings.get("follower_shapeshift_speed") || 1
    base_time = case speed_mode; when 0 then 600; when 1 then 1200; when 2 then 2400; else 4800; end
    (0..5).each do |slot|
      ev = $PokemonTemp.dependentEvents.getEventByName("XF_#{slot}"); next if !ev || ev.erased
      pkmn = $Trainer.party[slot] rescue nil; next if !pkmn || !(pkmn.isFusion? rescue false)
      @shapeshift_timers[slot] ||= base_time + rand(601); @shapeshift_timers[slot] -= 1
      if @shapeshift_timers[slot] <= 0
        @shapeshift_timers[slot] = base_time + rand(601); @current_mode[slot] = (@current_mode[slot] == :head) ? :body : :head
        ev.character_name = self.get_pkmn_sprite(pkmn, @current_mode[slot]).to_s
        # Pokémon Referenz fuer den Shiny Sprite Fix speichern
        ev.instance_variable_set(:@xorron_pkmn_ref, pkmn)
        pbSEPlay("Battle recall") rescue nil; ev.xorron_hop rescue nil
        rnd_col = Color.new(rand(256), rand(256), rand(256), 255); ev.xorron_request_flash(rnd_col, 50)
        if $scene.spriteset; ss = $scene.spriteset; ss.addUserAnimation(2, ev.x, ev.y, true, 1) rescue nil; ss.addUserAnimation(7, ev.x, ev.y, true, 1) rescue nil; end
      end
    end
  end

  def self.setup_followers
    return unless $game_map && $PokemonTemp && $PokemonTemp.dependentEvents
    (0..5).each { |i| pbRemoveDependency2("XF_#{i}") rescue nil }
    limit = XorronModSettings.get("follower_limit") || 6
    (0...limit).each do |i|
      pkmn = $Trainer.party[i] rescue nil; slot_mode = XorronModSettings.get_slot_mode(i)
      next if !pkmn || pkmn.hp <= 0 || slot_mode == "off"
      @current_mode[i] = (slot_mode == "auto") ? :body : slot_mode.to_sym
      char_name = self.get_pkmn_sprite(pkmn, @current_mode[i])
      # KIF fix: never replace one of the map's own events that already uses this id
      old = $game_map.events[9000+i]; next if old && !old.instance_variable_get(:@xorron_mod_event)
      rpg_ev = RPG::Event.new($game_player.x, $game_player.y); rpg_ev.id = 9000 + i
      page = RPG::Event::Page.new; page.graphic.character_name = char_name.to_s; rpg_ev.pages = [page]
      $game_map.events[9000+i] = Game_Event.new($game_map.map_id, rpg_ev, $game_map)
      $game_map.events[9000+i].instance_variable_set(:@xorron_mod_event, true)   # KIF fix: left out of saves
      pbAddDependency2(9000+i, "XF_#{i}", nil)
      real_ev = pbGetDependency("XF_#{i}")
      if real_ev
        # Pokémon Referenz fuer den Shiny Sprite Fix speichern
        real_ev.instance_variable_set(:@xorron_pkmn_ref, pkmn)
        real_ev.step_anime = XorronModSettings.enabled?("follower_idle_enabled") rescue false
        real_ev.move_frequency = 3; real_ev.move_speed = $game_player.move_speed
      end
    end
    $game_map.need_refresh = true
  end

  def self.interact(slot, event)
    pkmn = $Trainer.party[slot] rescue nil; return if !pkmn
    pbPlayCry(pkmn) rescue nil
    commands = [_INTL("Pet"), _INTL("Recall to Ball"), _INTL("Cancel")]
    choice = pbMessage(_INTL("What would you like to do with {1}?", pkmn.name), commands, 2)
    case choice
    when 0; pbSEPlay("Ice1") rescue nil; event.xorron_hop; pbMessage(_INTL("You petted {1}.", pkmn.name))
    when 1; if pbConfirmMessage(_INTL("Recall {1}?")); XorronModSettings.set("f_slot_mode_#{slot}", "off"); pbRemoveDependency2("XF_#{slot}") rescue nil; $game_map.need_refresh = true; end
    end
  end
end

Events.onMapUpdate += proc { |_sender, e| XorronsPokePetSystem.update if $game_map }
Events.onMapSceneChange += proc { |_sender, e| XorronsPokePetSystem.instance_variable_set(:@initialized_map, 0) }

# KIF fix: a follower whose placeholder map event is gone (a save made by the original version of
# this mod, or a map that was reloaded) is dropped instead of crashing in the game's
# DependentEventSprites#refresh (nil.erase); the follower system makes it again.
class DependentEventSprites
  alias xorron_pet_refresh refresh unless method_defined?(:xorron_pet_refresh)
  def refresh
    stale = []
    $PokemonTemp.dependentEvents.eachEvent do |_event, data|
      next unless data && data[8].is_a?(String) && data[8].start_with?("XF_")
      stale << data[8] if data[0] == @map.map_id && !@map.events[data[1]]
    end
    stale.each { |name| pbRemoveDependency2(name) }
    XorronsPokePetSystem.refresh_followers if !stale.empty?
    xorron_pet_refresh
  end
end

#===============================================================================
# Formations-Logik Patch fuer DependentEvents
#===============================================================================
class DependentEvents
  alias xorron_formation_move pbMoveDependentEvents
  def pbMoveDependentEvents
    events = $PokemonGlobal.dependentEvents
    return xorron_formation_move if events.length < 3
    return xorron_formation_move if !@follows_player   # KIF fix: keep the game's own non-following dependents
    
    # Check if formation is enabled in Mod Menu
    formation_active = XorronModSettings.enabled?("follower_formation_enabled") rescue true
    return xorron_formation_move if !formation_active
    
    # Check for Xorron followers
    xf_active = false
    for i in 0...events.length
      if events[i][8] && events[i][8].start_with?("XF_")
        xf_active = true; break
      end
    end
    
    return xorron_formation_move if !xf_active
    
    updateDependentEvents
    leader = $game_player
    for i in 0...events.length
      event = @realEvents[i]
      next if !event
      
      is_xf = events[i][8] && events[i][8].start_with?("XF_")
      slot = is_xf ? events[i][8].split("_")[1].to_i : -1
      
      # Formation fuer Slots 0 bis 5 (Follower 1 bis 6)
      if slot >= 0 && slot <= 5 && !XorronsPokePetSystem.is_wandering?(slot)
        target = XorronsPokePetSystem.get_formation_pos(slot)
        
        # Pruefe ob das Feld begehbar ist
        if $game_map.passable?(target[0], target[1], 0, event)
          event.move_speed = $game_player.move_speed
          
          # Weiche Bewegung nur wenn nötig
          if event.x != target[0] || event.y != target[1]
            if (event.x - target[0]).abs > 3 || (event.y - target[1]).abs > 3
              event.moveto(target[0], target[1])
            else
              pbFancyMoveTo(event, target[0], target[1], $game_player)
            end
          end
          
          # Blickrichtung: Nur wenn das Event nicht gerade läuft
          is_moving = (event.real_x != event.x * 128 || event.real_y != event.y * 128)
          if !is_moving
            if slot == 0
              pbTurnTowardEvent(event, $game_player)
            elsif event.direction != $game_player.direction
              event.direction = $game_player.direction
            end
          end
          
          events[i][3] = event.x
          events[i][4] = event.y
          events[i][5] = event.direction
          next
        end
      end
      
      # Standard-Bewegung als Fallback
      pbFollowEventAcrossMaps(leader, event, false, i == 0)
      events[i][3] = event.x
      events[i][4] = event.y
      events[i][5] = event.direction
      leader = event
    end
  end

  #===============================================================================
  # Verhindert das automatische Umdrehen zum Spieler in Formation
  #===============================================================================
  alias xorron_formation_turn pbTurnDependentEvents
  def pbTurnDependentEvents
    events = $PokemonGlobal.dependentEvents
    formation_active = XorronModSettings.enabled?("follower_formation_enabled") rescue true
    
    # Falls Formation aus oder zu wenige PKMN, nutze Standard-Logik
    return xorron_formation_turn if !formation_active || events.length < 3
    
    updateDependentEvents
    leader = $game_player
    for i in 0...events.length
      event = @realEvents[i]
      next if !event
      
      is_xf = events[i][8] && events[i][8].start_with?("XF_")
      slot = is_xf ? events[i][8].split("_")[1].to_i : -1
      
      if slot == 0
        # Nummer 1 schaut weiterhin zum Spieler
        pbTurnTowardEvent(event, $game_player)
      elsif slot > 0 && slot <= 5
        # Alle anderen schauen in Laufrichtung des Spielers
        event.direction = $game_player.direction
      else
        # Fallback für Nicht-XF Events oder andere Slots
        pbTurnTowardEvent(event, leader)
      end
      
      events[i][5] = event.direction
      leader = event
    end
  end
end

