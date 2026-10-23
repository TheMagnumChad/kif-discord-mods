###################################################################################################
# Xorron Mod Menu - Central Hub (Version 4.7 - Speed Control Edition)                         #
###################################################################################################

module XorronModSettings

  @settings = {
    "xorron_mod_enabled" => true,
    "wandering_trainers_enabled" => true,
    "wandering_trainers_limit" => 10,
    "infinite_safari_enabled" => true,
    "graphic_fps_mode" => 0,
    "follower_system_enabled" => false,
    "follower_formation_enabled" => true,
    "follower_idle_enabled" => true,
    "f_auto_refresh_enabled" => true,
    "follower_shapeshift_enabled" => true,
    "follower_shapeshift_speed" => 1, # 0:Fast, 1:Normal, 2:Slow, 3:Very Slow
    "follower_limit" => 6,
    "f_slot_mode_0" => "body",
    "f_slot_mode_1" => "body",
    "f_slot_mode_2" => "body",
    "f_slot_mode_3" => "body",
    "f_slot_mode_4" => "body",
    "f_slot_mode_5" => "body",
    "auto_capture_enabled" => true,
    "auto_capture_shinies_always" => false,
    "catch_multiple_wild_enabled" => true,
    "100_catch_rate_enabled" => true
  }

  # KIF fix: values live in KIF's ModSettingsMenu (Options > KIF Settings > Mods, kept in the
  # save folder) instead of Mods/ModData/xorron_global_settings.txt. @settings above holds the
  # defaults, and is the store only when there is no ModSettingsMenu.
  SLOT_MODES = ["body", "head", "auto", "off"]

  def self.ms?
    defined?(ModSettingsMenu) && ModSettingsMenu.respond_to?(:get)
  end

  def self.ms_key(key)
    key.start_with?("xorron_") ? key : "xorron_#{key}"
  end

  # KIF fix: ModSettingsMenu keeps toggles as 0/1 and choices as indexes
  def self.from_store(key, v)
    d = @settings[key]
    return d if v.nil?
    return (v == true || v == 1) if d == true || d == false
    return (SLOT_MODES[v.to_i] || d) if key.start_with?("f_slot_mode_") && v.is_a?(Integer)
    return v
  end

  def self.to_store(key, value)
    d = @settings[key]
    return (value ? 1 : 0) if d == true || d == false
    return (SLOT_MODES.index(value) || 0) if key.start_with?("f_slot_mode_")
    return value
  end

  def self.enabled?(key)
    get(key) == true
  end

  def self.get(key)
    return @settings[key] unless ms?
    from_store(key, ModSettingsMenu.get(ms_key(key)))
  end

  def self.get_slot_mode(i)
    get("f_slot_mode_#{i}") || "body"
  end

  def self.set(key, value)
    if ms?
      ModSettingsMenu.set(ms_key(key), to_store(key, value))   # KIF fix: on_change runs apply_change
    else
      @settings[key] = value
      apply_change(key, value)
    end
  end

  def self.apply_change(key, value)
    # Sofort-Update fuer das Follower-System bei Aenderungen
    if key.start_with?("f_") || key == "follower_system_enabled" || key == "follower_limit"
      XorronsPokePetSystem.refresh_followers if defined?(XorronsPokePetSystem)
    end

    if key == "follower_system_enabled" && value == false
      # KIF fix: remove only this mod's followers, not the game's own dependent events (quest partners)
      (0..5).each { |i| pbRemoveDependency2("XF_#{i}") rescue nil } if $PokemonTemp && $PokemonGlobal
      $game_map.need_refresh = true if $game_map
    end
    if key == "graphic_fps_mode"
      if value == 1; XorronGraphics.apply_fps(60) if defined?(XorronGraphics)
      elsif value == 2; XorronGraphics.apply_fps(90) if defined?(XorronGraphics)
      else XorronGraphics.restore_classic if defined?(XorronGraphics) end
    end
    XorronSafari.apply if key == "infinite_safari_enabled" && defined?(XorronSafari)   # KIF fix: toggle works at once
  end

  def self.reset_all_dismissals
    (0..5).each { |i| set("f_slot_mode_#{i}", "body") if get_slot_mode(i) == "off" }   # KIF fix: through set
  end

  # KIF fix: rows for Options > KIF Settings > Mods; the hub opens from the "Xorron Mod Menu" button there
  ROWS = [
    ["xorron_mod_enabled", "Xorrons Map Progress", :toggle, "Encounters", "Wild Pokemon on a map get stronger after 5 wins there."],
    ["wandering_trainers_enabled", "Wandering Trainers", :toggle, "Major Systems", "Trainers with their Pokemon roam outdoor maps and can be battled."],
    ["wandering_trainers_limit", "Wandering Trainer Limit", [1, 10], "Major Systems", "How many wandering trainers a map can have."],
    ["infinite_safari_enabled", "Infinite Safari", :toggle, "Quality of Life", "No step limit in the Safari Zone."],
    ["graphic_fps_mode", "Graphic Overhaul (FPS)", ["Off", "60 FPS", "90 FPS"], "Interface", "Draws the overworld at 60 or 90 frames a second."],
    ["follower_system_enabled", "Follower System", :toggle, "Interface", "Party Pokemon follow you on the map."],
    ["follower_formation_enabled", "Follower Formation (V-Shape)", :toggle, "Interface", "With 3 or more followers they walk in a V formation."],
    ["follower_limit", "Follower Limit", [1, 6], "Interface", "How many party Pokemon follow you."],
    ["follower_shapeshift_enabled", "Follower Shapeshift", :toggle, "Interface", "Fused followers switch between head and body sprites."],
    ["follower_shapeshift_speed", "Shapeshift Speed", ["Fast", "Normal", "Slow", "Very Slow"], "Interface", "How often fused followers switch sprites."],
    ["follower_idle_enabled", "Follower Idle Anim", :toggle, "Interface", "Followers animate while standing."],
    ["f_auto_refresh_enabled", "Auto Refresh Slots", :toggle, "Interface", "Followers update when the party changes."],
    ["auto_capture_enabled", "Auto-Capture", :toggle, "Battle Mechanics", "With Auto-Battle on, throws a ball at species you don't own."],
    ["auto_capture_shinies_always", "Catch All Shinies", :toggle, "Battle Mechanics", "Auto-Capture also targets shinies of species you own."],
    ["catch_multiple_wild_enabled", "Catch Multi-Wild", :toggle, "Battle Mechanics", "Balls can be thrown when there are several wild Pokemon."],
    ["100_catch_rate_enabled", "100% Catch Rate", :toggle, "Battle Mechanics", "Species you don't own (and shinies with Catch All Shinies) are always caught."]
  ] + (0..5).map { |i| ["f_slot_mode_#{i}", "Follower Slot #{i + 1} Mode", ["Body", "Head", "Auto", "Off"], "Interface", "Sprite this party slot's follower uses."] }

  def self.register_settings
    return unless defined?(ModSettingsMenu) && ModSettingsMenu.respond_to?(:register)
    ModSettingsMenu.register(:xorron_mod_menu, { :name => "Xorron Mod Menu", :type => :button, :category => "Interface",
      :description => "Opens the Xorron Mod Menu.", :on_press => proc { XorronModSettings.open_menu } })
    ROWS.each do |key, name, kind, cat, desc|
      opts = { :name => name, :category => cat, :description => desc, :default => to_store(key, @settings[key]),
               :on_change => proc { |v| XorronModSettings.apply_change(key, XorronModSettings.from_store(key, v)) } }
      if kind == :toggle then opts[:type] = :toggle
      elsif kind[0].is_a?(Integer) then opts[:type] = :number; opts[:min] = kind[0]; opts[:max] = kind[1]
      else opts[:type] = :enum; opts[:values] = kind
      end
      ModSettingsMenu.register(ms_key(key).to_sym, opts)
    end
  end

  def self.open_menu
    loop do
      fps_text = case get("graphic_fps_mode"); when 1 then "[60 FPS]"; when 2 then "[90 FPS]"; else "[OFF]"; end
      shift_speed = case get("follower_shapeshift_speed"); when 0 then "Fast"; when 1 then "Normal"; when 2 then "Slow"; else "V. Slow"; end

      commands = [
        _INTL("Xorrons Map Progress: {1}", enabled?("xorron_mod_enabled") ? "[ON]" : "[OFF]"),
        _INTL("Wandering Trainers: {1}", enabled?("wandering_trainers_enabled") ? "[ON]" : "[OFF]"),
        _INTL("Wandering Trainer Limit: {1}", get("wandering_trainers_limit") || 10),
        _INTL("Infinite Safari: {1}", enabled?("infinite_safari_enabled") ? "[ON]" : "[OFF]"),
        _INTL("Graphic Overhaul (FPS): {1}", fps_text),
        _INTL("--- Xorrons PokePetSystem ---"),
        _INTL("Follower System: {1}", enabled?("follower_system_enabled") ? "[ACTIVE]" : "[OFF]"),
        _INTL("Follower Formation: {1}", enabled?("follower_formation_enabled") ? "[V-SHAPE]" : "[LINE]"),
        _INTL("Follower Limit: {1} PKMN", get("follower_limit") || 6),
        _INTL("Follower Shapeshift: {1}", enabled?("follower_shapeshift_enabled") ? "[ON]" : "[OFF]"),
        _INTL("Shapeshift Speed: {1}", shift_speed), # NEU
        _INTL("Follower Idle Anim: {1}", enabled?("follower_idle_enabled") ? "[ON]" : "[OFF]"),
        _INTL("Auto Refresh Slots: {1}", enabled?("f_auto_refresh_enabled") ? "[ON]" : "[OFF]"),
        _INTL("--- Kuray Auto-Capture ---"),
        _INTL("Auto-Capture: {1}", enabled?("auto_capture_enabled") ? "[ON]" : "[OFF]"),
        _INTL("Catch All Shinies: {1}", enabled?("auto_capture_shinies_always") ? "[ON]" : "[OFF]"),
        _INTL("Catch Multi-Wild: {1}", enabled?("catch_multiple_wild_enabled") ? "[ON]" : "[OFF]"),
        _INTL("100% Catch Rate: {1}", enabled?("100_catch_rate_enabled") ? "[ON]" : "[OFF]"),
        _INTL("Configure Follower Modes"),
        _INTL("Back")
      ]
      
      if defined?(XorronMapProgress); commands.insert(11, _INTL("--- Data Reset ---"), _INTL("Reset Xorrons Map Progress")); end

      choice = pbMessage(_INTL("Xorron Mod Menu:"), commands, -1)
      break if choice < 0
      
      cmd = commands[choice]
      case cmd
      when /Xorrons Map Progress/ then set("xorron_mod_enabled", !enabled?("xorron_mod_enabled"))
      when /Wandering Trainers:/ then set("wandering_trainers_enabled", !enabled?("wandering_trainers_enabled"))
      when /Wandering Trainer Limit/ 
        new_limit = (get("wandering_trainers_limit") || 10) % 10 + 1
        set("wandering_trainers_limit", new_limit)
      when /Infinite Safari/ then set("infinite_safari_enabled", !enabled?("infinite_safari_enabled"))
      when /Graphic Overhaul/ then set("graphic_fps_mode", ((get("graphic_fps_mode") || 0) + 1) % 3)
      when /Follower System/ then set("follower_system_enabled", !enabled?("follower_system_enabled"))
      when /Follower Formation/ then set("follower_formation_enabled", !enabled?("follower_formation_enabled"))
      when /Follower Limit/ then set("follower_limit", (get("follower_limit") || 6) % 6 + 1)
      when /Follower Shapeshift/ then set("follower_shapeshift_enabled", !enabled?("follower_shapeshift_enabled"))
      when /Shapeshift Speed/ then set("follower_shapeshift_speed", ((get("follower_shapeshift_speed") || 1) + 1) % 4) # NEU
      when /Follower Idle Anim/ then set("follower_idle_enabled", !enabled?("follower_idle_enabled"))
      when /Auto Refresh Slots/ then set("f_auto_refresh_enabled", !enabled?("f_auto_refresh_enabled"))
      when /Auto-Capture:/ then set("auto_capture_enabled", !enabled?("auto_capture_enabled"))
      when /Catch All Shinies:/ then set("auto_capture_shinies_always", !enabled?("auto_capture_shinies_always"))
      when /Catch Multi-Wild:/ then set("catch_multiple_wild_enabled", !enabled?("catch_multiple_wild_enabled"))
      when /100% Catch Rate:/ then set("100_catch_rate_enabled", !enabled?("100_catch_rate_enabled"))
      when /Configure Follower Modes/ then self.open_follower_config
      when /Reset Xorrons Map Progress/
        if pbConfirmMessage(_INTL("Do you really want to RESET all map progress data?"))
          XorronMapProgress.reset_all_data if defined?(XorronMapProgress)
          pbMessage(_INTL("All map progress has been reset."))
        end
      when /Back/ then break
      end
    end
  end

  def self.open_follower_config
    loop do
      commands = []
      (0..5).each do |i|
        pkmn = $Trainer.party[i] rescue nil; name = pkmn ? pkmn.name : "---"
        hp_status = (pkmn && pkmn.hp <= 0) ? "[FAINTED]" : ""
        raw_mode = get_slot_mode(i); mode_text = (raw_mode == "off") ? "DEACTIVATED" : raw_mode.upcase
        commands << _INTL("Slot {1}: {2} ({3}) {4}", i+1, name, mode_text, hp_status)
      end
      commands << _INTL("Back")
      slot = pbMessage(_INTL("Change mode for slot:"), commands, -1)
      break if slot < 0 || slot == 6
      current = get_slot_mode(slot)
      new_mode = case current; when "body" then "head"; when "head" then "auto"; when "auto" then "off"; else "body"; end
      set("f_slot_mode_#{slot}", new_mode)
    end
  end
end

# KIF fix: keeps saves loadable with and without this mod. While the game writes a save, the
# mod's own map events (wandering trainers, follower placeholders), its followers (dependent
# events XF_*) and the old Wandering Trainers save data are taken out, then put back.
# Both systems make them again after a load.
module XorronSaveGuard
  def self.mod_event?(ev)
    ev && ev.instance_variable_get(:@xorron_mod_event)
  end

  def self.without_mod_data
    deps = nil; kept_deps = nil; events = []
    if $PokemonGlobal
      deps = $PokemonGlobal.dependentEvents
      kept_deps = deps.dup
      deps.reject! { |d| d && d[8].is_a?(String) && d[8].start_with?("XF_") }
      if $PokemonGlobal.instance_variable_defined?(:@wandering_trainers)
        $PokemonGlobal.remove_instance_variable(:@wandering_trainers)
      end
    end
    maps = ($MapFactory && $MapFactory.maps) || [$game_map].compact
    maps.each do |m|
      next if !m || !m.events
      m.events.keys.each { |id| events << [m, id, m.events.delete(id)] if mod_event?(m.events[id]) }
    end
    yield
  ensure
    deps.replace(kept_deps) if deps && kept_deps
    events.each { |m, id, ev| m.events[id] = ev }
    # an old save's Wandering Trainers data (@wandering_trainers) is not put back: it is not used any more
  end
end

module SaveData
  class << self
    alias xorron_save_to_file save_to_file unless method_defined?(:xorron_save_to_file)
    def save_to_file(file_path)
      XorronSaveGuard.without_mod_data { xorron_save_to_file(file_path) }
    end
  end
end

# KIF fix: 6.8.2's options screens never call PokemonOption_Scene#pbGetOptions, so the hub is a
# ModSettingsMenu button and the settings are ModSettingsMenu rows (no settings file).
XorronModSettings.register_settings
