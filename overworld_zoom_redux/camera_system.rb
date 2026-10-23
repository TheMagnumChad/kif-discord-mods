if defined?($overworld_zoom_redux_camera_loaded) && $overworld_zoom_redux_camera_loaded
  puts "[Overworld Zoom Redux] Journey camera gameplay duplicate load skipped."
else
  $overworld_zoom_redux_camera_loaded = true

module LocationCamera
  CAMERA_ITEM_NAME = "Journey Camera"
  CAMERA_ITEM_PLURAL = "Journey Cameras"
  CAMERA_PC_NAME = "Journey Camera"
  CAMERA_MENU_NAME = "Camera"
  CAMERA_COLLECTION_NAME = "Journey Collection"
  CAMERA_ALBUM_NAME = "Journey Album"
  CAMERA_PRICE = 12
  CAMERA_ITEM_ID = :LOCATIONCAMERA
  CAMERA_ITEM_NUMBER = 9401
  PHOTO_FOLDER = "LocationPhotos"
  SHUTTER_SE = "GUI save choice"
  SHUTTER_FLASH_COLOR = Color.new(255, 255, 255, 176)
  SHUTTER_FLASH_FRAMES = 3
  LANDMARK_TAG = /\APhotoSpot\|([^|]+)\|([^|]+)(?:\|(.+))?\z/i
  LANDMARK_SHORT_TAG = /\APhotoSpot:(.+)\z/i
  GENERIC_EVENT_NAME = /\A(?:EV\d+|HiddenItem|trainer\(|counter\(|door|warp|transfer|exit|reflection|through|cuttree|rocksmash|strengthboulder|berryplant|npc|event)\b/i

  CUSTOM_LANDMARKS = {}
  @landmark_cache = {}
  @map_ids_cache = nil

  module_function

  def register_camera_item
    return if !defined?(GameData) || !defined?(GameData::Item)
    if !GameData::Item.exists?(CAMERA_ITEM_ID)
      GameData::Item.register({
        :id          => CAMERA_ITEM_ID,
        :id_number   => CAMERA_ITEM_NUMBER,
        :name        => CAMERA_ITEM_NAME,
        :name_plural => CAMERA_ITEM_PLURAL,
        :pocket      => 8,
        :price       => 0,
        :description => "A travel camera for capturing scenic routes, memorable landmarks, and major battle moments.",
        :field_use   => 2,
        :battle_use  => 10,
        :type        => 6
      })
    end
    if defined?(MessageTypes)
      MessageTypes.set(MessageTypes::Items, CAMERA_ITEM_NUMBER, CAMERA_ITEM_NAME)
      MessageTypes.set(MessageTypes::ItemPlurals, CAMERA_ITEM_NUMBER, CAMERA_ITEM_PLURAL)
      MessageTypes.set(MessageTypes::ItemDescriptions, CAMERA_ITEM_NUMBER, "A travel camera for capturing scenic routes, memorable landmarks, and major battle moments.")
    end
  rescue
    nil
  end

  def ensure_bag_item
    return false if !$PokemonBag
    register_camera_item
    return false if !GameData::Item.exists?(CAMERA_ITEM_ID)
    return true if $PokemonBag.pbHasItem?(CAMERA_ITEM_ID)
    return $PokemonBag.pbStoreItem(CAMERA_ITEM_ID, 1)
  rescue
    return false
  end

  def ensure_data
    register_camera_item
    return if !$PokemonGlobal
    $PokemonGlobal.location_camera_owned = false if !$PokemonGlobal.respond_to?(:location_camera_owned) || $PokemonGlobal.location_camera_owned.nil?
    $PokemonGlobal.location_camera_records = {} if !$PokemonGlobal.respond_to?(:location_camera_records) || !$PokemonGlobal.location_camera_records.is_a?(Hash)
    $PokemonGlobal.location_camera_photos = [] if !$PokemonGlobal.respond_to?(:location_camera_photos) || !$PokemonGlobal.location_camera_photos.is_a?(Array)
    $PokemonGlobal.location_camera_next_id = 1 if !$PokemonGlobal.respond_to?(:location_camera_next_id) || $PokemonGlobal.location_camera_next_id.to_i <= 0
    ensure_bag_item if $PokemonGlobal.location_camera_owned
  end

  def camera_owned?
    ensure_data
    return true if $PokemonBag && $PokemonBag.pbHasItem?(CAMERA_ITEM_ID)
    return $PokemonGlobal && $PokemonGlobal.location_camera_owned
  end

  def camera_owned=(value)
    ensure_data
    if $PokemonGlobal
      $PokemonGlobal.location_camera_owned = value ? true : false
      ensure_bag_item if value
    end
  end

  def records
    ensure_data
    return $PokemonGlobal.location_camera_records
  end

  def photos
    ensure_data
    return $PokemonGlobal.location_camera_photos
  end

  def next_photo_id
    ensure_data
    current = $PokemonGlobal.location_camera_next_id
    $PokemonGlobal.location_camera_next_id += 1
    return current
  end

  def current_map_id
    return $game_map ? $game_map.map_id : 0
  end

  def map_name(map_id)
    name = pbGetMessage(MessageTypes::MapNames, map_id) rescue nil
    return (name && !name.empty?) ? name : sprintf("Map %03d", map_id)
  end

  def all_map_ids
    return @map_ids_cache if @map_ids_cache
    infos = pbLoadMapInfos rescue {}
    @map_ids_cache = infos.keys.select do |map_id|
      next false if map_id.to_i <= 0
      next false if !File.exist?(map_file_path(map_id))
      name = map_name(map_id)
      next !name.to_s.strip.empty?
    end.sort_by { |map_id| [map_name(map_id).downcase, map_id] }
    return @map_ids_cache
  end

  def map_groups
    groups = {}
    all_map_ids.each do |map_id|
      name = map_name(map_id)
      key = name.to_s.strip
      key = sprintf("Map %03d", map_id) if key.empty?
      groups[key] ||= { :name => key, :map_ids => [] }
      groups[key][:map_ids] << map_id
    end
    return groups.values.sort_by { |group| [group[:name].downcase, group[:map_ids].min] }
  end

  def grouped_progress(map_ids)
    total_captured = 0
    total_targets = 0
    map_ids.each do |map_id|
      captured, total = summary_for_map(map_id)
      total_captured += captured
      total_targets += total
    end
    return [total_captured, total_targets]
  end

  def open_map_group_collection(group)
    map_ids = group[:map_ids]
    return open_map_collection(map_ids[0]) if map_ids.length <= 1
    command = 0
    loop do
      commands = map_ids.map do |map_id|
        captured, total = summary_for_map(map_id)
        sprintf("[%d/%d] %s #%03d", captured, total, map_name(map_id), map_id)
      end
      helps = map_ids.map do |map_id|
        captured, total = summary_for_map(map_id)
        _INTL("Open the collection details for map {1} ({2}/{3} complete).", map_id, captured, total)
      end
      commands << _INTL("Back")
      helps << _INTL("Return to the previous menu.")
      choice = pbShowCommandsWithHelp(nil, commands, helps, -1, command)
      return if choice < 0 || choice >= map_ids.length
      command = choice
      open_map_collection(map_ids[choice])
    end
  end

  def map_file_path(map_id)
    return sprintf("Data/Map%03d.rxdata", map_id)
  end

  def map_record(map_id)
    key = map_id.to_i
    records[key] ||= { "location" => nil, "landmarks" => {} }
    records[key]["landmarks"] ||= {}
    return records[key]
  end

  def clamp_value(value, min_value, max_value)
    return min_value if value < min_value
    return max_value if value > max_value
    return value
  end

  def sanitize_filename(text)
    safe = text.to_s.gsub(/[^0-9A-Za-z._-]+/, "_")
    safe = safe.gsub(/_+/, "_")
    safe = safe.gsub(/\A_+|_+\z/, "")
    return safe.empty? ? "photo" : safe
  end

  def photo_root_dir
    save_dir = defined?(SaveData::SAVE_DIR) ? SaveData::SAVE_DIR : File.dirname(SaveData::FILE_PATH)
    root = File.join(save_dir, PHOTO_FOLDER)
    Dir.mkdir(root) unless Dir.exist?(root)
    trainer_key = if $Trainer
      trainer_name = sanitize_filename($Trainer.name)
      trainer_id = ($Trainer.respond_to?(:public_ID) ? sprintf("%05d", $Trainer.public_ID) : "00000")
      "#{trainer_name}_#{trainer_id}"
    else
      "guest"
    end
    folder = File.join(root, trainer_key)
    Dir.mkdir(folder) unless Dir.exist?(folder)
    return folder
  rescue
    return "."
  end

  def build_photo_path(entry_id, target)
    subject = sanitize_filename(target[:name])
    map_id = target[:map_id].to_i
    filename = sprintf("%03d_%04d_%s.png", map_id, entry_id, subject)
    return File.join(photo_root_dir, filename)
  end

  def meaningful_landmark_name(name)
    raw = name.to_s.strip
    return nil if raw.empty?
    return nil if raw =~ GENERIC_EVENT_NAME
    return nil if raw.include?("||")
    clean = raw.gsub(/[()]/, " ").gsub(/[_-]+/, " ").gsub(/\s+/, " ").strip
    return nil if clean.empty?
    return clean
  end

  def parse_landmark_from_event_name(name, event_id, x, y, map_id)
    raw = name.to_s.strip
    return nil if raw.empty?
    if raw =~ LANDMARK_TAG
      return {
        :type => :landmark,
        :map_id => map_id.to_i,
        :key => $1.strip,
        :name => $2.strip,
        :description => ($3 || "A notable landmark on #{map_name(map_id)}.").strip,
        :x => x,
        :y => y,
        :radius => 1,
        :event_id => event_id
      }
    end
    if raw =~ LANDMARK_SHORT_TAG
      display_name = meaningful_landmark_name($1)
      return nil if !display_name
      return {
        :type => :landmark,
        :map_id => map_id.to_i,
        :key => "event_#{event_id}",
        :name => display_name,
        :description => "A notable landmark on #{map_name(map_id)}.",
        :x => x,
        :y => y,
        :radius => 1,
        :event_id => event_id
      }
    end
    display_name = meaningful_landmark_name(raw)
    return nil if !display_name
    return {
      :type => :landmark,
      :map_id => map_id.to_i,
      :key => "event_#{event_id}",
      :name => display_name,
      :description => "A notable landmark on #{map_name(map_id)}.",
      :x => x,
      :y => y,
      :radius => 1,
      :event_id => event_id
    }
  end

  def landmarks_for_map(map_id)
    map_id = map_id.to_i
    return @landmark_cache[map_id] if @landmark_cache[map_id]
    spots = []
    if CUSTOM_LANDMARKS[map_id]
      CUSTOM_LANDMARKS[map_id].each { |entry| spots << entry.clone }
    end
    begin
      map_data = load_data(map_file_path(map_id))
      if map_data && map_data.events
        map_data.events.keys.sort.each do |event_id|
          event = map_data.events[event_id]
          next if !event
          parsed = parse_landmark_from_event_name(event.name, event_id, event.x, event.y, map_id)
          next if !parsed
          next if spots.any? { |spot| spot[:key].to_s == parsed[:key].to_s }
          spots << parsed
        end
      end
    rescue
      nil
    end
    @landmark_cache[map_id] = spots
    return @landmark_cache[map_id]
  end

  def location_target(map_id = current_map_id)
    return {
      :type => :location,
      :map_id => map_id.to_i,
      :key => "location",
      :name => map_name(map_id),
      :description => "A scenic travel shot from #{map_name(map_id)}."
    }
  end

  def overall_progress
    total_captured = 0
    total_targets = 0
    completed_maps = 0
    all_map_ids.each do |map_id|
      captured, total = summary_for_map(map_id)
      total_captured += captured
      total_targets += total
      completed_maps += 1 if total > 0 && captured >= total
    end
    return [total_captured, total_targets, completed_maps, all_map_ids.length]
  end

  def nearby_target_summary
    targets = current_landmark_targets
    return _INTL("No nearby landmarks are framed right now. You can still log a scenic shot for {1}.", map_name(current_map_id)) if targets.empty?
    names = targets.map { |target| target[:name].to_s }.reject(&:empty?).uniq
    names = names[0, 3]
    joined = names.join(", ")
    suffix = targets.length > names.length ? _INTL(" and more") : ""
    return _INTL("Nearby landmark subjects: {1}{2}.", joined, suffix)
  end

  def overview_text
    map_id = current_map_id
    local_captured, local_total = summary_for_map(map_id)
    total_captured, total_targets, completed_maps, area_count = overall_progress
    album_total = photos.length
    return _INTL("Current area: {1}\nLocal progress: {2}/{3}\nWorld progress: {4}/{5} targets across {6}/{7} areas\nAlbum photos saved: {8}\n{9}",
      map_name(map_id), local_captured, local_total, total_captured, total_targets, completed_maps, area_count, album_total, nearby_target_summary)
  end

  def tips_text
    return _INTL("Use scenic shots to log each area on your journey.\nFace a named event or a tagged PhotoSpot to capture a landmark entry.\nBattle photos are saved to the same album for big moments.\nPerspective and widescreen settings can help you frame larger scenes before snapping the photo.")
  end

  def post_capture_text(entry)
    captured, total = summary_for_map(entry["map_id"])
    completion_note = (total > 0 && captured >= total) ? _INTL(" {1} is now fully documented.", entry["map_name"]) : ""
    return _INTL("Saved a shot of {1}. {2}: {3}/{4} targets logged. {5} now holds {6} photos.{7}",
      entry["subject_name"], entry["map_name"], captured, total, CAMERA_ALBUM_NAME, photos.length, completion_note)
  end

  def purchase_pitch_text
    return _INTL("The {1} turns your adventure into a visual travel log. It adds a Camera shortcut to the pause menu, can be opened from the Bag, and can capture battlefield moments too.", CAMERA_ITEM_NAME)
  end

  def purchase_success_text
    return _INTL("You purchased the {1}. Start documenting routes, landmarks, and memorable battles throughout the full journey.", CAMERA_ITEM_NAME)
  end

  def current_landmark_targets
    targets = []
    return targets if !$game_player || !$game_map
    facing = $game_player.pbFacingEvent(true) rescue nil
    if facing
      parsed = parse_landmark_from_event_name(facing.name, facing.id, facing.x, facing.y, $game_map.map_id)
      targets << parsed if parsed
    end
    landmarks_for_map($game_map.map_id).each do |spot|
      next if targets.any? { |target| target[:key].to_s == spot[:key].to_s }
      next if !spot[:x] || !spot[:y]
      radius = clamp_value((spot[:radius] || 1).to_i, 1, 4)
      dx = ($game_player.x - spot[:x]).abs
      dy = ($game_player.y - spot[:y]).abs
      targets << spot if dx <= radius && dy <= radius
    end
    return targets
  end

  def subject_choices
    choices = [location_target]
    current_landmark_targets.each { |target| choices << target }
    return choices
  end

  def select_photo_target
    targets = subject_choices
    return targets[0] if targets.length <= 1
    commands = targets.map do |target|
      target[:type] == :location ? _INTL("Scenic Shot: {1}", target[:name]) : _INTL("Landmark Shot: {1}", target[:name])
    end
    helps = targets.map { |target| target[:description].to_s }
    commands << _INTL("Cancel")
    helps << _INTL("Return to the previous menu.")
    choice = pbShowCommandsWithHelp(nil, commands, helps, -1, 0)
    return nil if choice < 0 || choice >= targets.length
    return targets[choice]
  end

  def battle_subject_name(battler)
    return _INTL("Battle Scene") if !battler
    pokemon_name = (battler.respond_to?(:name) && battler.name) ? battler.name : nil
    pokemon_name = (battler.pokemon.name rescue nil) if !pokemon_name || pokemon_name.empty?
    trainer_name = nil
    if battler.respond_to?(:pbOwnedByPlayer?) && battler.pbOwnedByPlayer?
      trainer_name = $Trainer ? $Trainer.name : _INTL("Player")
    elsif battler.respond_to?(:pbThis)
      trainer_name = battler.pbThis(true)
    end
    return trainer_name if !pokemon_name || pokemon_name.empty?
    return _INTL("{1} and {2}", trainer_name, pokemon_name) if trainer_name && !trainer_name.empty?
    return pokemon_name
  rescue
    return _INTL("Battle Scene")
  end

  def battle_metadata(battler)
    metadata = {}
    return metadata if !battler || !battler.respond_to?(:pokemon)
    pokemon = battler.pokemon rescue nil
    return metadata if !pokemon
    metadata[:battle_dex_number] = (pokemon.dexNum rescue nil)
    metadata[:battle_species] = (pokemon.species.to_s rescue nil)
    metadata[:battle_shiny] = (pokemon.shiny? rescue false)
    metadata[:battle_custom_file] = (pokemon.kuraycustomfile? rescue nil)
    return metadata
  rescue
    return metadata
  end

  def battle_scene_catalog(battle)
    return [] if !battle || !battle.respond_to?(:battlers)
    allies = 0
    foes = 0
    catalog = []
    battle.battlers.each do |candidate|
      next if !candidate || !candidate.respond_to?(:pokemon)
      pokemon = candidate.pokemon rescue nil
      next if !pokemon
      next if candidate.respond_to?(:fainted?) && candidate.fainted?
      owned_by_player = candidate.respond_to?(:pbOwnedByPlayer?) && candidate.pbOwnedByPlayer?
      if owned_by_player
        allies += 1
        slot = _INTL("Ally {1}", allies)
      else
        foes += 1
        slot = _INTL("Foe {1}", foes)
      end
      catalog << {
        "slot" => slot,
        "side" => owned_by_player ? "ally" : "foe",
        "display_name" => (pokemon.name rescue battle_subject_name(candidate)).to_s,
        "battle_subject" => battle_subject_name(candidate).to_s,
        "species_name" => (pokemon.speciesName rescue pokemon.species.to_s).to_s,
        "dex_number" => (pokemon.dexNum rescue nil),
        "species" => (pokemon.species.to_s rescue nil),
        "shiny" => !!(pokemon.shiny? rescue false),
        "custom_file" => (pokemon.kuraycustomfile? rescue nil)
      }
    end
    return catalog
  rescue
    return []
  end

  def battle_scene_summary(catalog)
    return "" if !catalog.is_a?(Array) || catalog.empty?
    ally_names = catalog.select { |member| member["side"] == "ally" }.map { |member| member["display_name"].to_s }.reject(&:empty?)
    foe_names = catalog.select { |member| member["side"] == "foe" }.map { |member| member["display_name"].to_s }.reject(&:empty?)
    if !ally_names.empty? && !foe_names.empty?
      return _INTL("Field: {1} vs {2}", ally_names.join(", "), foe_names.join(", "))
    end
    names = catalog.map { |member| member["display_name"].to_s }.reject(&:empty?)
    return names.empty? ? "" : _INTL("Field: {1}", names.join(", "))
  rescue
    return ""
  end

  def battle_target(battle = nil, battler = nil)
    active_battler = battler
    if !active_battler && battle && battle.respond_to?(:battlers)
      active_battler = battle.battlers.find { |candidate| candidate && candidate.respond_to?(:pbOwnedByPlayer?) && candidate.pbOwnedByPlayer? }
    end
    map_id = current_map_id
    subject_name = battle_subject_name(active_battler)
    catalog = battle_scene_catalog(battle)
    return {
      :type => :battle,
      :map_id => map_id,
      :key => "battlefield",
      :name => _INTL("Battlefield: {1}", subject_name),
      :description => _INTL("A battle memory captured at {1}.", map_name(map_id)),
      :battle_subject => subject_name,
      :battle_scene_roster => catalog,
      :battle_scene_summary => battle_scene_summary(catalog)
    }.merge(battle_metadata(active_battler))
  end

  def build_photo_entry(photo_id, target)
    entry = {
      "id" => photo_id,
      "map_id" => target[:map_id].to_i,
      "map_name" => map_name(target[:map_id]),
      "subject_type" => target[:type].to_s,
      "subject_key" => target[:key].to_s,
      "subject_name" => target[:name].to_s,
      "description" => target[:description].to_s,
      "path" => build_photo_path(photo_id, target),
      "x" => ($game_player ? $game_player.x : 0),
      "y" => ($game_player ? $game_player.y : 0),
      "captured_at" => Time.now.to_i
    }
    entry["battle_subject"] = target[:battle_subject].to_s if target[:battle_subject]
    entry["battle_scene_roster"] = target[:battle_scene_roster] if target[:battle_scene_roster].is_a?(Array)
    entry["battle_scene_summary"] = target[:battle_scene_summary].to_s if target[:battle_scene_summary]
    entry["battle_dex_number"] = target[:battle_dex_number] if target[:battle_dex_number]
    entry["battle_species"] = target[:battle_species].to_s if target[:battle_species]
    entry["battle_shiny"] = !!target[:battle_shiny] if target.key?(:battle_shiny)
    entry["battle_custom_file"] = target[:battle_custom_file].to_s if target[:battle_custom_file]
    return entry
  end

  def resolve_photo_path(entry)
    return nil if !entry
    candidates = []
    stored_path = entry["path"].to_s
    candidates << stored_path if !stored_path.empty?
    begin
      expanded = File.expand_path(stored_path)
      candidates << expanded if !stored_path.empty? && expanded != stored_path
    rescue
      nil
    end
    if entry["id"] && entry["map_id"]
      target = {
        :name => entry["subject_name"].to_s,
        :map_id => entry["map_id"].to_i
      }
      candidates << build_photo_path(entry["id"].to_i, target)
    end
    if !stored_path.empty?
      basename = File.basename(stored_path)
      candidates << File.join(photo_root_dir, basename)
    end
    resolved = candidates.compact.find { |candidate| !candidate.to_s.empty? && File.file?(candidate) }
    entry["path"] = resolved if resolved && entry["path"] != resolved
    return resolved
  rescue
    return nil
  end

  def save_capture(target)
    photo_id = next_photo_id
    entry = build_photo_entry(photo_id, target)
    bitmap = Graphics.snap_to_bitmap
    begin
      bitmap.save_to_png(entry["path"])
    ensure
      bitmap.dispose if bitmap && bitmap.respond_to?(:dispose)
    end
    photos << entry
    register_capture(entry)
    return entry
  end

  def play_shutter_effect
    pbSEPlay(SHUTTER_SE, 90, 120) rescue nil
    pbFlash(SHUTTER_FLASH_COLOR, SHUTTER_FLASH_FRAMES) rescue nil
  end

  def preserve_menu_state
    previous_in_menu = nil
    previous_menu_calling = nil
    if $game_temp
      previous_in_menu = $game_temp.in_menu
      previous_menu_calling = $game_temp.menu_calling if $game_temp.respond_to?(:menu_calling)
    end
    begin
      yield
    ensure
      if $game_temp
        $game_temp.in_menu = previous_in_menu unless previous_in_menu.nil?
        if !previous_menu_calling.nil? && $game_temp.respond_to?(:menu_calling=)
          $game_temp.menu_calling = previous_menu_calling
        end
      end
    end
  end

  def release_field_controls!
    return if !$game_temp
    $game_temp.in_menu = false
    $game_temp.menu_calling = false if $game_temp.respond_to?(:menu_calling=)
    $game_temp.message_window_showing = false if $game_temp.respond_to?(:message_window_showing=)
    $game_map.update if $game_map
    pbUpdateSceneMap if defined?(pbUpdateSceneMap)
    Graphics.frame_reset
    Input.update
  rescue
    nil
  end

  def capture_photo(scene = nil)
    preserve_menu_state do
      ensure_data
      if !camera_owned?
        pbMessage(_INTL("You need to purchase the {1} from a PC first.", CAMERA_ITEM_NAME))
        return false
      end
      return false if !$scene || !defined?(Scene_Map) || !$scene.is_a?(Scene_Map)
      target = select_photo_target
      return false if !target
      scene.pbHideMenu if scene && scene.respond_to?(:pbHideMenu)
      pbUpdateSceneMap
      Graphics.update
      Input.update
      entry = save_capture(target)
      play_shutter_effect
      pbMessage(post_capture_text(entry))
      return true
    rescue => e
      pbMessage(_INTL("The photo could not be saved.\n{1}", e.message))
      return false
    end
  end

  def register_capture(entry)
    record = map_record(entry["map_id"])
    return if entry["subject_type"] == "battle"
    record["location"] = entry["id"] if !record["location"]
    if entry["subject_type"] == "location"
      record["location"] = entry["id"]
    else
      record["landmarks"][entry["subject_key"]] = entry["id"]
    end
  end

  def summary_for_map(map_id)
    record = map_record(map_id)
    total = 1 + landmarks_for_map(map_id).length
    captured = record["location"] ? 1 : 0
    captured += record["landmarks"].keys.length
    return [captured, total]
  end

  def target_status_label(captured)
    return captured ? "[x]" : "[ ]"
  end

  def latest_photo_for_target(map_id, subject_type, subject_key)
    photos.reverse_each do |entry|
      next if entry["map_id"].to_i != map_id.to_i
      next if entry["subject_type"].to_s != subject_type.to_s
      next if entry["subject_key"].to_s != subject_key.to_s
      return entry
    end
    return nil
  end

  def photos_for_map(map_id)
    return photos.select { |entry| entry["map_id"].to_i == map_id.to_i }
  end

  def gallery_entries(filter_map_id = nil)
    source = filter_map_id ? photos_for_map(filter_map_id) : photos
    return source.reverse
  end

  def formatted_time(entry)
    stamp = entry["captured_at"].to_i
    return "Unknown time" if stamp <= 0
    return Time.at(stamp).strftime("%Y-%m-%d %H:%M")
  rescue
    return "Unknown time"
  end

  def open_map_collection(map_id)
    loop do
      record = map_record(map_id)
      commands = []
      helps = []
      commands << _INTL("{1} Scenic Shot", target_status_label(!!record["location"]))
      helps << _INTL("Photograph the overall feel of {1}.", map_name(map_id))
      landmarks = landmarks_for_map(map_id)
      landmarks.each do |spot|
        commands << _INTL("{1} {2}", target_status_label(record["landmarks"].key?(spot[:key].to_s)), spot[:name])
        helps << spot[:description].to_s
      end
      commands << _INTL("View Map Album")
      helps << _INTL("Open the saved album entries for this map.")
      commands << _INTL("Back")
      helps << _INTL("Return to the previous menu.")
      choice = pbShowCommandsWithHelp(nil, commands, helps, -1, 0)
      return if choice < 0 || choice == commands.length - 1
      if choice == commands.length - 2
        open_full_gallery(map_id)
        next
      end
      entries = gallery_entries(map_id)
      if choice == 0
        entry = latest_photo_for_target(map_id, :location, "location")
        entry ? open_photo_viewer(entry, entries) : pbMessage(_INTL("You haven't taken the scenic shot for {1} yet.", map_name(map_id)))
      else
        spot = landmarks[choice - 1]
        entry = latest_photo_for_target(map_id, :landmark, spot[:key])
        entry ? open_photo_viewer(entry, entries) : pbMessage(_INTL("You haven't photographed {1} yet.", spot[:name]))
      end
    end
  end

  def open_location_collection
    preserve_menu_state do
      ensure_data
      command = 0
      loop do
        groups = map_groups
        commands = groups.map do |group|
          captured, total = grouped_progress(group[:map_ids])
          suffix = group[:map_ids].length > 1 ? sprintf(" (%d)", group[:map_ids].length) : ""
          sprintf("[%d/%d] %s%s", captured, total, group[:name], suffix)
        end
        helps = groups.map do |group|
          captured, total = grouped_progress(group[:map_ids])
          if group[:map_ids].length > 1
            _INTL("Open {1} grouped maps. Total progress: {2}/{3}.", group[:map_ids].length, captured, total)
          else
            _INTL("Photo progress for {1}: {2}/{3} targets complete.", group[:name], captured, total)
          end
        end
        commands << _INTL("Back")
        helps << _INTL("Return to the previous menu.")
        choice = pbShowCommandsWithHelp(nil, commands, helps, -1, command)
        return if choice < 0 || choice >= groups.length
        command = choice
        open_map_group_collection(groups[choice])
      end
    end
  end

  def open_full_gallery(filter_map_id = nil)
    preserve_menu_state do
      ensure_data
      available = gallery_entries(filter_map_id)
      if available.empty?
        pbMessage(_INTL("Your {1} is still empty.", CAMERA_ALBUM_NAME))
        return
      end
      viewer = LocationCameraPhotoViewer.new(available, 0)
      viewer.main
    end
  end

  def open_photo_viewer(entry, entries = nil)
    preserve_menu_state do
      entries ||= [entry]
      start_index = entries.index { |candidate| candidate["id"].to_i == entry["id"].to_i } || 0
      viewer = LocationCameraPhotoViewer.new(entries, start_index)
      viewer.main
    end
  end

  def open_quick_menu(scene = nil)
    begin
      if !camera_owned?
        pbMessage(_INTL("You need to buy the {1} from a PC first.", CAMERA_ITEM_NAME))
        return false
      end
      command = pbShowCommandsWithHelp(nil,
        [_INTL("Take Photo"), _INTL("Journey Overview"), _INTL("Journey Collection"), _INTL("Journey Album"), _INTL("Tips"), _INTL("Cancel")],
        [_INTL("Take a scenic shot of the current area or a nearby landmark."),
         _INTL("Review your current area progress, world progress, and nearby camera subjects."),
         _INTL("Review checklist progress for every map and route."),
         _INTL("Browse every saved photo in your album."),
         _INTL("Learn how the camera fits into exploration, landmarks, and battles."),
         _INTL("Return to the field.")],
        -1, 0)
      case command
      when 0 then return capture_photo(scene)
      when 1
        pbMessage(overview_text)
        return true
      when 2
        open_location_collection
        return true
      when 3
        open_full_gallery
        return true
      when 4
        pbMessage(tips_text)
        return true
      end
      return false
    ensure
      release_field_controls!
    end
  end

  def open_bag_menu(scene = nil)
    begin
      if !camera_owned?
        pbMessage(_INTL("You need to buy the {1} from a PC first.", CAMERA_ITEM_NAME))
        return false
      end
      command = pbShowCommandsWithHelp(nil,
        [_INTL("Take Photo"), _INTL("Journey Overview"), _INTL("Journey Collection"), _INTL("Journey Album"), _INTL("Tips"), _INTL("Cancel")],
        [_INTL("Frame the current route or a nearby landmark through the camera lens."),
         _INTL("Review your current area progress, world progress, and nearby camera subjects."),
         _INTL("Review every route and map photo target you have logged."),
         _INTL("Browse every saved photo, including battle scenes."),
         _INTL("Review tips for scenic shots, landmarks, and battle photography."),
         _INTL("Put the camera away.")],
        -1, 0)
      case command
      when 0 then return capture_photo(scene)
      when 1
        pbMessage(overview_text)
        return true
      when 2
        open_location_collection
        return true
      when 3
        open_full_gallery
        return true
      when 4
        pbMessage(tips_text)
        return true
      end
      return false
    ensure
      release_field_controls!
    end
  end

  def can_use_in_battle?(battle, scene, show_messages)
    if !camera_owned?
      scene.pbDisplay(_INTL("You don't have the {1}.", CAMERA_ITEM_NAME)) if show_messages && scene
      return false
    end
    if !battle || !battle.respond_to?(:internalBattle) || !battle.internalBattle
      scene.pbDisplay(_INTL("The camera can't be used here.")) if show_messages && scene
      return false
    end
    return true
  end

  def capture_battle_photo(battle, battler, scene = nil)
    ensure_data
    return false if !can_use_in_battle?(battle, scene, true)
    Graphics.update
    Input.update
    entry = save_capture(battle_target(battle, battler))
    play_shutter_effect
    battle.pbDisplayPaused(_INTL("{1} captured a battlefield photo of {2}!", $Trainer.name, entry["battle_subject"] || entry["subject_name"])) if battle
    return true
  rescue => e
    if battle
      battle.pbDisplayPaused(_INTL("The photo could not be saved: {1}", e.message))
    else
      pbMessage(_INTL("The photo could not be saved: {1}", e.message))
    end
    return false
  end

  def open_pc_menu
    ensure_data
    if !camera_owned?
      if $Trainer.money < CAMERA_PRICE
        pbMessage(_INTL("The {1} costs ${2}. You don't have enough money yet.\n\n{3}", CAMERA_ITEM_NAME, CAMERA_PRICE, purchase_pitch_text))
        return
      end
      return if !pbConfirmMessage(_INTL("Buy the {1} for ${2}?\n\n{3}", CAMERA_ITEM_NAME, CAMERA_PRICE, purchase_pitch_text))
      $Trainer.money -= CAMERA_PRICE
      pbReceiveItem(CAMERA_ITEM_ID) if !$PokemonBag || !$PokemonBag.pbHasItem?(CAMERA_ITEM_ID)
      self.camera_owned = true
      ensure_bag_item
      pbMessage(_INTL("{1}\n\n{2}", purchase_success_text, overview_text))
      return
    end
    command = 0
    loop do
      command = pbShowCommandsWithHelp(nil,
        [_INTL("Journey Overview"), _INTL("Journey Collection"), _INTL("Journey Album"), _INTL("Tips"), _INTL("Log Off")],
        [_INTL("Review your current area progress, world progress, and nearby camera subjects."),
         _INTL("Review map-by-map checklist progress."),
         _INTL("Browse every saved travel photo and battle memory."),
         _INTL("Read how scenic shots, landmarks, and battle photos work."),
         _INTL("Return to the previous menu.")],
        -1, command)
      case command
      when 0 then pbMessage(overview_text)
      when 1 then open_location_collection
      when 2 then open_full_gallery
      when 3
        pbMessage(tips_text)
      else
        break
      end
    end
  end

  def pause_menu_display(commands)
    display = commands.dup
    inserted = []
    return [display, inserted] if !camera_owned?
    return [display, inserted] if display.include?(_INTL(CAMERA_MENU_NAME))
    anchor = display.index(_INTL("Outfit"))
    anchor = display.index(_INTL("Options")) if anchor.nil?
    insert_pos = anchor ? anchor + 1 : display.length
    display.insert(insert_pos, _INTL(CAMERA_MENU_NAME))
    inserted << insert_pos
    return [display, inserted]
  end
end

if defined?(GameData) && defined?(GameData::Item)
  class GameData::Item
    class << self
      alias __location_camera_load load unless method_defined?(:__location_camera_load)

      def load
        __location_camera_load
        LocationCamera.register_camera_item if defined?(LocationCamera)
      end
    end
  end
end

# KIF fix: the camera item only exists while this mod is installed, so it is kept out of
# save files (taken out of the Bag just while the file is written, then put back). It comes
# back from location_camera_owned (plain data) when a save loads, so a save made with the
# mod still loads cleanly without it (no unknown item in the Bag or Ready menu).
module LocationCamera
  module_function

  def strip_from_bag
    return nil if !$PokemonBag
    pockets = $PokemonBag.instance_variable_get(:@pockets)
    return nil if !pockets.is_a?(Array)
    pockets.each_with_index do |pocket, p|
      next if !pocket.is_a?(Array)
      i = pocket.index { |entry| entry.is_a?(Array) && entry[0] == CAMERA_ITEM_ID }
      next if !i
      registered = $PokemonBag.registeredItems.index(CAMERA_ITEM_ID)
      $PokemonBag.registeredItems.delete(CAMERA_ITEM_ID) if registered
      $PokemonGlobal.instance_variable_set(:@location_camera_registered, registered ? true : false) if $PokemonGlobal
      return [p, i, pocket.delete_at(i), registered]
    end
    return nil
  rescue
    return nil
  end

  def restore_to_bag(removed)
    return if !removed || !$PokemonBag
    p, i, entry, registered = removed
    pocket = $PokemonBag.instance_variable_get(:@pockets)[p]
    pocket.insert([i, pocket.length].min, entry) if !pocket.any? { |e| e.is_a?(Array) && e[0] == CAMERA_ITEM_ID }
    list = $PokemonBag.registeredItems
    list.insert([registered, list.length].min, CAMERA_ITEM_ID) if registered && !list.include?(CAMERA_ITEM_ID)
  rescue
    nil
  end

  # after a save loads: the item back in the Bag (and the Ready menu if it was there)
  def restore_after_load
    return if !$PokemonGlobal || !$PokemonGlobal.location_camera_owned
    ensure_data
    if $PokemonGlobal.instance_variable_get(:@location_camera_registered) && $PokemonBag &&
       $PokemonBag.pbHasItem?(CAMERA_ITEM_ID) && !$PokemonBag.pbIsRegistered?(CAMERA_ITEM_ID)
      $PokemonBag.pbRegisterItem(CAMERA_ITEM_ID)
    end
  rescue
    nil
  end
end

module SaveData
  class << self
    alias __location_camera_save_to_file save_to_file unless method_defined?(:__location_camera_save_to_file)

    def save_to_file(file_path)
      removed = LocationCamera.strip_from_bag
      begin
        return __location_camera_save_to_file(file_path)
      ensure
        LocationCamera.restore_to_bag(removed)
      end
    end
  end
end

module Game
  class << self
    alias __location_camera_load load unless method_defined?(:__location_camera_load)

    def load(save_data)
      ret = __location_camera_load(save_data)
      LocationCamera.restore_after_load
      return ret
    end
  end
end

class PokemonGlobalMetadata
  attr_accessor :location_camera_owned
  attr_accessor :location_camera_records
  attr_accessor :location_camera_photos
  attr_accessor :location_camera_next_id

  alias __location_camera_initialize initialize unless method_defined?(:__location_camera_initialize)

  def initialize
    __location_camera_initialize
    @location_camera_owned = false if @location_camera_owned.nil?
    @location_camera_records = {} if !@location_camera_records.is_a?(Hash)
    @location_camera_photos = [] if !@location_camera_photos.is_a?(Array)
    @location_camera_next_id = 1 if !@location_camera_next_id || @location_camera_next_id <= 0
  end
end

class LocationCameraPhotoViewer
  FRAME_COLOR = Color.new(26, 28, 36)
  PANEL_COLOR = Color.new(54, 58, 72)
  PANEL_DARK = Color.new(36, 39, 50)
  BORDER_COLOR = Color.new(150, 156, 178)
  TEXT_COLOR = Color.new(242, 244, 248)
  SHADOW_COLOR = Color.new(32, 34, 42)
  ACCENT_COLOR = Color.new(120, 196, 255)
  VIEW_MARGIN = 12
  HEADER_HEIGHT = 62
  INFO_PANEL_HEIGHT = 96

  def initialize(entries, index = 0)
    @entries = entries
    @index = [[index, 0].max, entries.length - 1].min
    @fullscreen = false
  end

  def cache_dir
    root = File.join("Cache", "LocationCameraViewer")
    Dir.mkdir("Cache") unless Dir.exist?("Cache")   # KIF fix: the parent may not exist yet
    Dir.mkdir(root) unless Dir.exist?(root)
    return root
  rescue
    return "Cache"
  end

  def cached_viewer_path(entry, resolved_path)
    return nil if !resolved_path || !File.file?(resolved_path)
    filename = sprintf("%04d_%s.png", entry["id"].to_i, LocationCamera.sanitize_filename(entry["subject_name"]))
    target = File.join(cache_dir, filename)
    if !File.file?(target) || File.size(target) != File.size(resolved_path)
      File.open(target, "wb") { |file| file.write(File.binread(resolved_path)) }
    end
    return target
  rescue
    return nil
  end

  def load_bitmap(path)
    return nil if !path || path.empty? || !File.file?(path)
    relative = path.tr("\\", "/")
    return Bitmap.new(relative)
  rescue
    begin
      folder = File.dirname(relative || path).tr("\\", "/") + "/"
      filename = File.basename(path, ".*")
      return RPG::Cache.load_bitmap(folder, filename)
    rescue
      return nil
    end
  end

  def current_entry
    return @entries[@index]
  end

  def wrap_index(next_index)
    return 0 if @entries.length <= 1
    return @entries.length - 1 if next_index < 0
    return 0 if next_index >= @entries.length
    return next_index
  end

  def draw_tablet_shell(bitmap)
    bitmap.clear
    if @fullscreen
      bitmap.fill_rect(0, 0, bitmap.width, bitmap.height, Color.new(0, 0, 0))
      return
    end
    bitmap.fill_rect(0, 0, bitmap.width, bitmap.height, FRAME_COLOR)
    bitmap.fill_rect(14, 14, bitmap.width - 28, bitmap.height - 28, PANEL_COLOR)
    bitmap.fill_rect(20, 20, bitmap.width - 40, 34, PANEL_DARK)
    bitmap.fill_rect(20, bitmap.height - INFO_PANEL_HEIGHT, bitmap.width - 40, INFO_PANEL_HEIGHT - 20, PANEL_DARK)
    bitmap.fill_rect(28, HEADER_HEIGHT, bitmap.width - 56, bitmap.height - HEADER_HEIGHT - INFO_PANEL_HEIGHT + 6, Color.new(8, 10, 16))
    bitmap.fill_rect(10, 10, bitmap.width - 20, 4, BORDER_COLOR)
    bitmap.fill_rect(10, bitmap.height - 14, bitmap.width - 20, 4, BORDER_COLOR)
    bitmap.fill_rect(10, 10, 4, bitmap.height - 20, BORDER_COLOR)
    bitmap.fill_rect(bitmap.width - 14, 10, 4, bitmap.height - 20, BORDER_COLOR)
    pbSetSystemFont(bitmap)
  end

  def draw_overlay(bitmap, entry, photo_available)
    bitmap.clear
    return if @fullscreen
    pbSetSystemFont(bitmap)
    title = entry ? _INTL(LocationCamera::CAMERA_ALBUM_NAME) : _INTL(LocationCamera::CAMERA_ITEM_NAME)
    count_text = _INTL("{1}/{2}", @index + 1, @entries.length)
    pbDrawShadowText(bitmap, 32, 22, bitmap.width - 64, 24, title, TEXT_COLOR, SHADOW_COLOR)
    pbDrawShadowText(bitmap, bitmap.width - 96, 22, 64, 24, count_text, ACCENT_COLOR, SHADOW_COLOR, 1)
    left_color = (@entries.length > 1) ? ACCENT_COLOR : Color.new(110, 114, 124)
    right_color = (@entries.length > 1) ? ACCENT_COLOR : Color.new(110, 114, 124)
    pbDrawShadowText(bitmap, 30, Graphics.height / 2 - 24, 48, 32, "<", left_color, SHADOW_COLOR, 2)
    pbDrawShadowText(bitmap, bitmap.width - 78, Graphics.height / 2 - 24, 48, 32, ">", right_color, SHADOW_COLOR, 2)
    if entry
      subject = entry["subject_name"].to_s
      location = entry["map_name"].to_s
      time = LocationCamera.formatted_time(entry)
      caption = photo_available ? entry["description"].to_s : _INTL("The image file is missing or could not be decoded.")
      if photo_available && entry["subject_type"].to_s == "battle"
        battle_summary = entry["battle_scene_summary"].to_s
        caption = battle_summary if !battle_summary.empty?
      end
      pbDrawShadowText(bitmap, 36, Graphics.height - 94, bitmap.width - 72, 24, subject, TEXT_COLOR, SHADOW_COLOR)
      pbSetSmallFont(bitmap)
      pbDrawShadowText(bitmap, 36, Graphics.height - 68, bitmap.width - 72, 18, _INTL("{1}  |  {2}", location, time), ACCENT_COLOR, SHADOW_COLOR)
      pbDrawShadowText(bitmap, 36, Graphics.height - 48, bitmap.width - 72, 16, caption, Color.new(208, 212, 220), SHADOW_COLOR)
    end
    pbSetSmallFont(bitmap)
    controls_text = _INTL("Left/Right: Browse   Use: Full View   Back: Exit")
    pbDrawShadowText(bitmap, 0, Graphics.height - 26, bitmap.width, 16, controls_text, Color.new(196, 200, 208), SHADOW_COLOR, 2)
  end

  def draw_photo_sprite(sprite, bitmap)
    return if !sprite
    if sprite.bitmap && !sprite.bitmap.disposed?
      sprite.bitmap.dispose
    end
    sprite.bitmap = bitmap
    if !bitmap
      sprite.visible = false
      return
    end
    sprite.visible = true
    if @fullscreen
      usable_width = Graphics.width - (VIEW_MARGIN * 2)
      usable_height = Graphics.height - (VIEW_MARGIN * 2)
      photo_top = VIEW_MARGIN
    else
      usable_width = Graphics.width - 96
      usable_height = Graphics.height - HEADER_HEIGHT - INFO_PANEL_HEIGHT + 18
      photo_top = HEADER_HEIGHT + 8
    end
    scale = [usable_width.to_f / bitmap.width, usable_height.to_f / bitmap.height].min
    scale = 1.0 if scale > 1.0
    sprite.zoom_x = scale
    sprite.zoom_y = scale
    sprite.x = ((Graphics.width - bitmap.width * scale) / 2).round
    sprite.y = photo_top + ((usable_height - bitmap.height * scale) / 2).round
  end

  def placeholder_bitmap
    bitmap = Bitmap.new(Graphics.width - 120, Graphics.height - 220)
    bitmap.fill_rect(0, 0, bitmap.width, bitmap.height, Color.new(16, 18, 26))
    pbSetSystemFont(bitmap)
    pbDrawShadowText(bitmap, 0, bitmap.height / 2 - 24, bitmap.width, 24, _INTL("Photo unavailable"), TEXT_COLOR, SHADOW_COLOR, 2)
    pbDrawShadowText(bitmap, 0, bitmap.height / 2 + 4, bitmap.width, 20, _INTL("The saved image could not be loaded."), Color.new(208, 212, 220), SHADOW_COLOR, 2)
    return bitmap
  end

  def build_display_bitmap(entry)
    resolved_path = LocationCamera.resolve_photo_path(entry)
    cached_path = cached_viewer_path(entry, resolved_path)
    bitmap = load_bitmap(cached_path)
    return [bitmap, true] if bitmap
    return [placeholder_bitmap, false]
  end

  def refresh_view(sprites)
    entry = current_entry
    display_bitmap, ok = build_display_bitmap(entry)
    draw_tablet_shell(sprites["bg"].bitmap)
    draw_photo_sprite(sprites["photo"], display_bitmap)
    draw_overlay(sprites["overlay"].bitmap, entry, ok)
  end

  def main
    if !@entries || @entries.empty?
      pbMessage(_INTL("Your {1} is still empty.", LocationCamera::CAMERA_ALBUM_NAME))
      return
    end
    viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    viewport.z = 99999
    sprites = {}
    sprites["bg"] = Sprite.new(viewport)
    sprites["bg"].bitmap = Bitmap.new(Graphics.width, Graphics.height)
    draw_tablet_shell(sprites["bg"].bitmap)

    sprites["photo"] = Sprite.new(viewport)
    sprites["overlay"] = Sprite.new(viewport)
    sprites["overlay"].bitmap = Bitmap.new(Graphics.width, Graphics.height)
    refresh_view(sprites)

    loop do
      Graphics.update
      Input.update
      pbUpdateSpriteHash(sprites)
      if Input.trigger?(Input::LEFT)
        @index = wrap_index(@index - 1)
        refresh_view(sprites)
      elsif Input.trigger?(Input::RIGHT)
        @index = wrap_index(@index + 1)
        refresh_view(sprites)
      elsif Input.trigger?(Input::USE)
        @fullscreen = !@fullscreen
        refresh_view(sprites)
      elsif Input.trigger?(Input::BACK)
        if @fullscreen
          @fullscreen = false
          refresh_view(sprites)
        else
          break
        end
      end
    end
  ensure
    pbDisposeSpriteHash(sprites) if sprites
    viewport.dispose if viewport && !viewport.disposed?
  end
end

class LocationCameraPC
  def shouldShow?
    return true
  end

  def name
    return LocationCamera::CAMERA_PC_NAME
  end

  def access
    pbMessage(_INTL("\se[PC access]Connected to the {1} service.", LocationCamera::CAMERA_ITEM_NAME))
    LocationCamera.open_pc_menu
  end
end

if defined?(PokemonPCList) && (!$location_camera_pc_registered rescue true)
  PokemonPCList.registerPC(LocationCameraPC.new)
  $location_camera_pc_registered = true
end

if defined?(PokemonPauseMenu_Scene)
  class ::PokemonPauseMenu_Scene
    alias __location_camera_pbShowCommands pbShowCommands unless method_defined?(:__location_camera_pbShowCommands)

    def pbShowCommands(commands)
      display, inserted = LocationCamera.pause_menu_display(commands)
      ret_display = __location_camera_pbShowCommands(display)
      return ret_display if ret_display.nil? || ret_display < 0
      if inserted.include?(ret_display) && display[ret_display] == _INTL(LocationCamera::CAMERA_MENU_NAME)
        pbHideMenu
        LocationCamera.open_quick_menu(self)
        return -1
      end
      shift = inserted.count { |index| index < ret_display }
      return ret_display - shift
    end
  end
end

if defined?(ItemHandlers)
  ItemHandlers::UseText.add(LocationCamera::CAMERA_ITEM_ID, proc { |_item|
    next _INTL("Open Camera")
  })

  ItemHandlers::UseFromBag.add(LocationCamera::CAMERA_ITEM_ID, proc { |_item|
    next (LocationCamera.camera_owned?) ? 2 : 0
  })

  ItemHandlers::UseInField.add(LocationCamera::CAMERA_ITEM_ID, proc { |_item|
    next (LocationCamera.open_bag_menu) ? 1 : 0
  })

  ItemHandlers::CanUseInBattle.add(LocationCamera::CAMERA_ITEM_ID, proc { |_item, pokemon, battler, move, firstAction, battle, scene, showMessages|
    next LocationCamera.can_use_in_battle?(battle, scene, showMessages)
  })

  ItemHandlers::UseInBattle.add(LocationCamera::CAMERA_ITEM_ID, proc { |_item, battler, battle|
    LocationCamera.capture_battle_photo(battle, battler, battle.scene)
  })
end

puts "[Overworld Zoom Redux] Journey camera system loaded."
end