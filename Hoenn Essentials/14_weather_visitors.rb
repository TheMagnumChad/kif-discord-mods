# Rare visitors join normal encounters and both PokéRadar lists.
module HoennWeatherVisitors
  CHANCE = 5
  LOG_PATH = File.join('Mods', 'HoennWeather', 'weather_debug.txt')

  def self.log(message)
    File.open(LOG_PATH, 'a') { |f| f.puts(message) }
  rescue StandardError
    begin
      File.open('weather_debug.txt', 'a') { |f| f.puts(message) }
    rescue StandardError
    end
  end
  # Keep special encounters out of the weather visitor catalog.
  LEGENDARIES = %w[ARTICUNO ZAPDOS MOLTRES MEWTWO MEW RAIKOU ENTEI SUICUNE LUGIA HO_OH CELEBI REGIROCK REGICE REGISTEEL LATIAS LATIOS KYOGRE GROUDON RAYQUAZA JIRACHI DEOXYS UXIE MESPRIT AZELF DIALGA PALKIA HEATRAN REGIGIGAS GIRATINA CRESSELIA PHIONE MANAPHY DARKRAI SHAYMIN ARCEUS VICTINI COBALION TERRAKION VIRIZION TORNADUS THUNDURUS RESHIRAM ZEKROM LANDORUS KYUREM KELDEO MELOETTA GENESECT XERNEAS YVELTAL ZYGARDE DIANCIE HOOPA VOLCANION TYPE_NULL SILVALLY TAPU_KOKO TAPU_LELE TAPU_BULU TAPU_FINI COSMOG COSMOEM SOLGALEO LUNALA NIHILEGO BUZZWOLE PHEROMOSA XURKITREE CELESTEELA KARTANA GUZZLORD NECROZMA MAGEARNA MARSHADOW POIPOLE NAGANADEL STAKATAKA BLACEPHALON ZERAORA MELTAN MELMETAL ZACIAN ZAMAZENTA ETERNATUS KUBFU URSHIFU ZARUDE REGIELEKI REGIDRAGO GLASTRIER SPECTRIER CALYREX ENAMORUS].map(&:to_sym).freeze
  # Pokédex numbers are a second safeguard if species IDs/forms differ.
  # Includes legendary, mythical, Ultra Beast and other event-only lines.
  SPECIAL_DEX_NUMBERS = %w[
    144 145 146 150 151 243 244 245 249 250 251
    377 378 379 380 381 382 383 384 385 386
    480 481 482 483 484 485 486 487 488 489 490 491 492 493
    494 638 639 640 641 642 643 644 645 646 647 648 649
    716 717 718 719 720 721
    772 773 785 786 787 788 789 790 791 792 793 794 795 796
    797 798 799 800 801 802 803 804 805 806 807 808 809
    888 889 890 891 892 893 894 895 896 897 898 905
    1001 1002 1003 1004 1007 1008 1009 1010 1024 1025
  ].map(&:to_i).freeze

  def self.allowed_species?(species)
    return false if species.nil?
    data = GameData::Species.try_get(species)
    return false unless data
    base = data.species
    return false if LEGENDARIES.include?(base) || LEGENDARIES.include?(species)
    return false if SPECIAL_DEX_NUMBERS.include?(data.id_number)
    return false if data.form != 0
    baby = data.get_baby_species
    return false if LEGENDARIES.include?(baby)
    baby_data = GameData::Species.try_get(baby)
    return false if baby_data && SPECIAL_DEX_NUMBERS.include?(baby_data.id_number)
    true
  rescue StandardError
    false
  end

  WEATHER_TYPES = [:Rain, :Storm, :Snow, :Blizzard, :Fog, :Wind, :Sunny, :Ash].freeze
  LAND_TYPES = [:Land, :LandDay, :LandMorning, :LandNight, :Land1, :Land2, :Land3, :TallGrass].freeze
  @catalog = nil

  def self.mode?(encounters)
    mode = encounters.getEncounterMode
    mode == GameData::Encounter || mode == GameData::EncounterModern
  rescue StandardError
    false
  end

  def self.weather_here
    return nil unless defined?(HoennWeatherKIF) && $game_map
    return nil unless HoennWeatherKIF.outdoors?($game_map.map_id)
    weather = $game_weather && $game_weather.current_weather && $game_weather.current_weather[$game_map.map_id]
    weather && weather[0]
  end

  def self.weather_options(species)
    data = GameData::Species.get(species)
    types = [data.type1, data.type2]
    opts = []
    opts += [:Rain, :Storm] if (types & [:WATER, :ELECTRIC, :BUG]).any?
    opts += [:Snow, :Blizzard] if types.include?(:ICE)
    opts += [:Fog] if (types & [:GHOST, :DARK, :PSYCHIC, :POISON]).any?
    opts += [:Wind] if (types & [:FLYING, :NORMAL]).any?
    opts += [:Sunny] if (types & [:GRASS, :FIRE, :GROUND]).any?
    opts += [:Ash] if (types & [:FIRE, :ROCK]).any?
    opts += [:Rain, :Fog, :Wind, :Sunny] if opts.empty?
    opts.uniq
  end

  def self.catalog
    return @catalog if @catalog
    classic = {}
    remix = {}
    [ [GameData::Encounter, classic], [GameData::EncounterModern, remix] ].each do |klass, found|
      klass.each do |record|
        record.types.each_value do |slots|
          slots.each { |slot| found[slot[1]] = true if slot && slot[1] }
        end
      end
    end
    families = {}
    GameData::Species.each do |data|
      next unless data.form == 0 && data.id_number > 0 && data.id_number <= 576
      next unless allowed_species?(data.species)
      baby = data.get_baby_species
      next unless allowed_species?(baby)
      (families[baby] ||= []) << data.species
    end
    missing = families.keys.select do |baby|
      family = families[baby]
      family.none? { |sp| classic[sp] || remix[sp] }
    end
    # Only ordinary obtainable bases; no alternate forms or special fusions.
    missing.select! do |baby|
      data = GameData::Species.try_get(baby)
      data && data.id_number <= 576 && allowed_species?(baby)
    end
    @catalog = { :missing => missing.sort_by { |sp| GameData::Species.get(sp).id_number },
                 :families => families, :classic => classic, :remix => remix }
  rescue StandardError => e
    log("Weather catalog error: #{e.class}: #{e.message}")
    { :missing => [], :families => {}, :classic => {}, :remix => {} }
  end

  # Weather is only half the story. The location should feel right too.
  def self.habitat(name)
    n = name.downcase
    return :volcanic if n.match?(/cinnabar|volcano|chimney|ember|burned tower/)
    return :cold if n.match?(/silver|ice path|seafoam|frozen|snow|peak/)
    return :wetland if n.match?(/lake|marsh|swamp|safari|pond/)
    return :coast if n.match?(/sea|ocean|beach|coast|island|whirl|cianwood|olivine|vermilion/)
    return :forest if n.match?(/forest|woods|grove|ilex|park/)
    return :mountain if n.match?(/mount|mt\.?|cave|rock|tunnel|plateau/)
    return :urban if n.match?(/city|town/)
    number = n[/\broute\s*0*(\d+)\b/, 1].to_i
    return :coast if [19,20,21,40,41].include?(number)
    return :mountain if [10,23,26,27,28,42,44,45,46,47,48].include?(number)
    return :forest if [2,3,4,5,6,8,9,24,25,29,30,31,32,34,35,36,37,38,39,43].include?(number)
    :grassland
  end

  # Broad ecological preferences. Specific species override the type heuristic.
  HABITAT_BY_TYPE = {
    :WATER => [:coast, :wetland, :cold],
    :ICE => [:cold, :coast, :mountain],
    :BUG => [:forest, :wetland, :grassland],
    :GRASS => [:forest, :grassland, :wetland],
    :FIRE => [:volcanic, :mountain, :grassland],
    :ROCK => [:mountain, :volcanic, :cold],
    :GROUND => [:mountain, :grassland, :volcanic],
    :ELECTRIC => [:grassland, :urban, :mountain],
    :GHOST => [:forest, :urban, :mountain],
    :POISON => [:wetland, :forest, :urban],
    :FLYING => [:forest, :grassland, :coast],
    :PSYCHIC => [:urban, :mountain, :forest],
    :DARK => [:forest, :mountain, :grassland],
    :FIGHTING => [:mountain, :grassland, :urban],
    :NORMAL => [:grassland, :forest, :urban],
    :STEEL => [:mountain, :urban, :volcanic],
    :DRAGON => [:mountain, :cold, :coast],
    :FAIRY => [:forest, :grassland, :urban]
  }
  SPECIES_HABITATS = {
    :NINCADA => [:forest, :grassland], :POOCHYENA => [:forest, :grassland],
    :SPHEAL => [:cold, :coast], :NUMEL => [:volcanic, :mountain],
    :SURSKIT => [:wetland, :forest], :BARBOACH => [:wetland, :coast],
    :CLAMPERL => [:coast], :WINGULL => [:coast],
    :TAILLOW => [:grassland, :forest], :SKITTY => [:grassland, :urban],
    :TYNAMO => [:coast, :wetland], :BALTOY => [:mountain, :volcanic]
  }

  def self.habitats_for(species)
    return SPECIES_HABITATS[species] if SPECIES_HABITATS.key?(species)
    data = GameData::Species.get(species)
    ([data.type1, data.type2].compact.flat_map { |t| HABITAT_BY_TYPE[t] || [] }).uniq
  end

  def self.outdoor_locations
    maps = {}
    GameData::Encounter.each do |record|
      next unless record.types.keys.any? { |t| LAND_TYPES.include?(t) }
      id = record.map
      next if maps.key?(id) || !HoennWeatherKIF.outdoors?(id)
      name = HoennWeatherKIF.map_name(id)
      next unless name.match?(/route|forest|woods|grove|park|lake|island|mount|mt\.?|cave|path|sea|coast|safari|city|town/i)
      maps[id] = { :name => name, :habitat => habitat(name) }
    end
    maps
  end

  # Hand-authored route groups. These never shuffle between saves.
  ROUTE_POOLS = {
    1 => { :Rain => [:SURSKIT], :Fog => [:POOCHYENA], :Wind => [:TAILLOW], :Sunny => [:SEEDOT], :Snow => [:SPHEAL] },
    2 => { :Rain => [:SURSKIT, :NINCADA], :Fog => [:CHINGLING], :Wind => [:WOOBAT], :Sunny => [:NINCADA], :Snow => [:SPHEAL] },
    3 => { :Rain => [:SEEDOT], :Fog => [:POOCHYENA], :Wind => [:SWABLU], :Sunny => [:SPOINK], :Snow => [:SPHEAL] },
    4 => { :Rain => [:SURSKIT], :Fog => [:CHINGLING], :Wind => [:HOPPIP], :Sunny => [:SEEDOT], :Snow => [:SPHEAL] },
    5 => { :Rain => [:GULPIN], :Fog => [:POOCHYENA], :Wind => [:DRIFLOON], :Sunny => [:SKITTY], :Snow => [:SPHEAL] },
    6 => { :Rain => [:SURSKIT], :Fog => [:CHINGLING], :Wind => [:WINGULL], :Sunny => [:SKITTY], :Snow => [:SPHEAL] },
    7 => { :Rain => [:SPOINK], :Fog => [:GULPIN], :Wind => [:YANMA], :Sunny => [:SEEDOT] },
    8 => { :Rain => [:NINCADA], :Fog => [:POOCHYENA], :Wind => [:GLIGAR], :Sunny => [:SPOINK] },
    9 => { :Rain => [:SURSKIT], :Fog => [:CHINGLING], :Wind => [:SWABLU], :Sunny => [:SEEDOT] },
    10 => { :Rain => [:BARBOACH], :Fog => [:BALTOY], :Wind => [:SKARMORY], :Sunny => [:SOLROCK], :Snow => [:SPHEAL] },
    11 => { :Rain => [:ELECTRIKE], :Fog => [:GULPIN], :Wind => [:WINGULL], :Sunny => [:SPOINK] },
    12 => { :Rain => [:BARBOACH], :Fog => [:CHINGLING], :Wind => [:TROPIUS], :Sunny => [:SEEDOT] },
    13 => { :Rain => [:SURSKIT], :Fog => [:POOCHYENA], :Wind => [:DRIFLOON], :Sunny => [:SEEDOT] },
    14 => { :Rain => [:NINCADA], :Fog => [:CHINGLING], :Wind => [:YANMA], :Sunny => [:SPOINK] },
    15 => { :Rain => [:GULPIN], :Fog => [:POOCHYENA], :Wind => [:NOIBAT], :Sunny => [:SEEDOT] },
    16 => { :Rain => [:SPOINK], :Fog => [:CHINGLING], :Wind => [:HOPPIP], :Sunny => [:SKITTY] },
    17 => { :Rain => [:ELECTRIKE], :Fog => [:POOCHYENA], :Wind => [:GLIGAR], :Sunny => [:SPOINK] },
    18 => { :Rain => [:GULPIN], :Fog => [:CHINGLING], :Wind => [:WOOBAT], :Sunny => [:SEEDOT] },
    19 => { :Rain => [:WINGULL], :Storm => [:TYNAMO], :Fog => [:CHIMECHO], :Wind => [:WINGULL], :Snow => [:SPHEAL] },
    20 => { :Rain => [:CLAMPERL], :Storm => [:TYNAMO], :Fog => [:CHINGLING], :Wind => [:MANTYKE], :Snow => [:SPHEAL] },
    21 => { :Rain => [:BARBOACH], :Storm => [:ELECTRIKE], :Fog => [:CHIMECHO], :Wind => [:WINGULL], :Snow => [:SPHEAL] },
    22 => { :Rain => [:SPOINK], :Fog => [:POOCHYENA], :Wind => [:TAILLOW], :Sunny => [:SEEDOT] },
    23 => { :Rain => [:BALTOY], :Fog => [:CHIMECHO], :Wind => [:SKARMORY], :Sunny => [:SOLROCK], :Snow => [:SPHEAL] },
    24 => { :Rain => [:SURSKIT], :Fog => [:CHINGLING], :Wind => [:SWABLU], :Sunny => [:SEEDOT] },
    25 => { :Rain => [:NINCADA], :Fog => [:POOCHYENA], :Wind => [:WOOBAT], :Sunny => [:SPOINK] },
    26 => { :Rain => [:BARBOACH], :Fog => [:BALTOY], :Wind => [:SKARMORY], :Snow => [:SPHEAL], :Sunny => [:SOLROCK] },
    27 => { :Rain => [:BARBOACH], :Fog => [:BALTOY], :Wind => [:GLIGAR], :Snow => [:SPHEAL], :Sunny => [:SOLROCK] },
    28 => { :Rain => [:BARBOACH], :Fog => [:BALTOY], :Wind => [:NOIBAT], :Snow => [:SPHEAL], :Sunny => [:SOLROCK] },
    29 => { :Rain => [:SURSKIT, :NINCADA], :Fog => [:CHINGLING, :POOCHYENA], :Wind => [:HOPPIP], :Sunny => [:SEEDOT], :Snow => [:SPHEAL] },
    30 => { :Rain => [:SURSKIT, :NINCADA], :Fog => [:CHINGLING, :POOCHYENA], :Wind => [:SWABLU], :Sunny => [:SEEDOT], :Snow => [:SPHEAL] },
    31 => { :Rain => [:SURSKIT, :NINCADA], :Fog => [:CHINGLING, :POOCHYENA], :Wind => [:YANMA], :Sunny => [:SEEDOT], :Snow => [:SPHEAL] },
    32 => { :Rain => [:SURSKIT, :NINCADA], :Fog => [:CHINGLING, :POOCHYENA], :Wind => [:TAILLOW], :Sunny => [:SEEDOT], :Snow => [:SPHEAL] },
    33 => { :Rain => [:SURSKIT, :NINCADA], :Fog => [:CHINGLING, :POOCHYENA], :Wind => [:DRIFLOON], :Sunny => [:SEEDOT], :Snow => [:SPHEAL] },
    34 => { :Rain => [:SURSKIT, :NINCADA], :Fog => [:CHINGLING, :POOCHYENA], :Wind => [:WOOBAT], :Sunny => [:SEEDOT], :Snow => [:SPHEAL] },
    35 => { :Rain => [:SURSKIT, :NINCADA], :Fog => [:CHINGLING, :POOCHYENA], :Wind => [:HOPPIP], :Sunny => [:SEEDOT], :Snow => [:SPHEAL] },
    36 => { :Rain => [:SURSKIT, :NINCADA], :Fog => [:CHINGLING, :POOCHYENA], :Wind => [:SWABLU], :Sunny => [:SEEDOT], :Snow => [:SPHEAL] },
    37 => { :Rain => [:SURSKIT, :NINCADA], :Fog => [:CHINGLING, :POOCHYENA], :Wind => [:YANMA], :Sunny => [:SEEDOT], :Snow => [:SPHEAL] },
    38 => { :Rain => [:SURSKIT, :NINCADA], :Fog => [:CHINGLING, :POOCHYENA], :Wind => [:GLIGAR], :Sunny => [:SEEDOT], :Snow => [:SPHEAL] },
    39 => { :Rain => [:SURSKIT, :NINCADA], :Fog => [:CHINGLING, :POOCHYENA], :Wind => [:DRIFLOON], :Sunny => [:SEEDOT], :Snow => [:SPHEAL] },
    40 => { :Rain => [:WINGULL, :CLAMPERL], :Wind => [:WINGULL], :Snow => [:SPHEAL], :Storm => [:TYNAMO] },
    41 => { :Rain => [:WINGULL, :CLAMPERL], :Wind => [:MANTYKE], :Snow => [:SPHEAL], :Storm => [:TYNAMO] },
    42 => { :Rain => [:BARBOACH], :Fog => [:BALTOY], :Wind => [:NOIBAT], :Snow => [:SPHEAL], :Sunny => [:SOLROCK] },
    43 => { :Rain => [:SURSKIT, :NINCADA], :Fog => [:CHINGLING, :POOCHYENA], :Wind => [:YANMA], :Sunny => [:SEEDOT], :Snow => [:SPHEAL] },
    44 => { :Rain => [:BARBOACH], :Fog => [:BALTOY], :Wind => [:SKARMORY], :Snow => [:SPHEAL], :Sunny => [:SOLROCK] },
    45 => { :Rain => [:BARBOACH], :Fog => [:BALTOY], :Wind => [:GLIGAR], :Snow => [:SPHEAL], :Sunny => [:SOLROCK] },
    46 => { :Rain => [:BARBOACH], :Fog => [:BALTOY], :Wind => [:SWABLU], :Snow => [:SPHEAL], :Sunny => [:SOLROCK] },
    47 => { :Rain => [:BARBOACH], :Fog => [:BALTOY], :Wind => [:NOIBAT], :Snow => [:SPHEAL], :Sunny => [:SOLROCK] },
    48 => { :Rain => [:BARBOACH], :Fog => [:BALTOY], :Wind => [:SKARMORY], :Snow => [:SPHEAL], :Sunny => [:SOLROCK] }
  }
  # Johto's route geography is stable, too.
  ROUTE_POOLS.each_value(&:freeze)
  ROUTE_POOLS.freeze
  PLACE_POOLS = {
    "viridian forest" => { :Rain => [:SURSKIT, :NINCADA], :Fog => [:CHINGLING], :Wind => [:YANMA], :Sunny => [:SEEDOT], :Snow => [:SPHEAL], :Blizzard => [:SPHEAL] },
    "ilex forest" => { :Rain => [:SURSKIT, :NINCADA], :Fog => [:POOCHYENA], :Wind => [:HOPPIP], :Sunny => [:SEEDOT] },
    "lake of rage" => { :Rain => [:BARBOACH, :SURSKIT], :Storm => [:TYNAMO], :Fog => [:CHINGLING], :Wind => [:WINGULL] },
    "mt. silver" => { :Snow => [:SPHEAL], :Fog => [:CHIMECHO], :Wind => [:SKARMORY], :Sunny => [:SOLROCK], :Rain => [:BALTOY] },
    "secret garden" => { :Rain => [:SURSKIT], :Fog => [:CHINGLING], :Sunny => [:SEEDOT] }
  }.freeze

  def self.fixed_classic_pool(map_id, weather)
    name = HoennWeatherKIF.map_name(map_id).downcase.strip
    route = name[/\broute\s*0*(\d+)\b/, 1]
    # Route 25 has no grass; keep its land pool disabled.
    return [] if route && route.to_i == 25
    pool = route ? ROUTE_POOLS[route.to_i] : PLACE_POOLS[name]
    unless pool
      log("Weather fixed pool missing: map=#{map_id} name=#{name.inspect} weather=#{weather.inspect}")
      return []
    end
    pool[weather] || []
  end

  AQUATIC_TYPES = [:Water, :OldRod, :GoodRod, :SuperRod].freeze
  AQUATIC_WEATHER = {
    :Rain => [:CORPHISH, :BARBOACH, :FEEBAS, :LOTAD],
    :Storm => [:TYNAMO, :CHINCHOU, :CARVANHA],
    :Snow => [:SPHEAL, :MANTYKE],
    :Blizzard => [:SPHEAL, :MANTYKE],
    :Fog => [:SKRELP, :FEEBAS, :CORSOLA],
    :Wind => [:MANTYKE, :WAILMER, :WINGULL],
    :Sunny => [:LUVDISC, :CORSOLA, :CLAMPERL],
    :Ash => [:SKRELP, :CARVANHA]
  }.freeze
  # The method decides which Pokémon are actually reachable.
  AQUATIC_METHODS = {
    :Water => [:SPHEAL, :MANTYKE, :WAILMER, :WINGULL, :CARVANHA, :CORSOLA, :CHINCHOU, :LUVDISC, :SKRELP],
    :OldRod => [:BARBOACH, :CORPHISH, :LOTAD, :FEEBAS, :CARVANHA],
    :GoodRod => [:BARBOACH, :CORPHISH, :FEEBAS, :CHINCHOU, :LUVDISC, :SKRELP, :CLAMPERL],
    :SuperRod => [:CLAMPERL, :WAILMER, :CARVANHA, :CHINCHOU, :SKRELP, :CORSOLA, :FEEBAS]
  }.freeze
  AQUATIC_ZONES = {
    :coast => [:WINGULL, :MANTYKE, :WAILMER, :CLAMPERL, :LUVDISC, :CORSOLA, :SKRELP, :CARVANHA],
    :wetland => [:CORPHISH, :BARBOACH, :FEEBAS, :LOTAD, :TYNAMO, :CHINCHOU],
    :forest => [:CORPHISH, :BARBOACH, :FEEBAS, :LOTAD, :CHINCHOU],
    :grassland => [:CORPHISH, :BARBOACH, :FEEBAS, :LOTAD, :CHINCHOU],
    :mountain => [:BARBOACH, :FEEBAS, :CHINCHOU, :SPHEAL, :SKRELP],
    :cold => [:SPHEAL, :MANTYKE, :CHINCHOU, :WAILMER],
    :urban => [:CORPHISH, :BARBOACH, :CHINCHOU, :LUVDISC],
    :volcanic => [:CARVANHA, :SKRELP, :WAILMER, :CLAMPERL]
  }.freeze
  # Each location has a permanent aquatic identity; never use global RNG here.
  def self.aquatic_pool(map_id, weather, method, mode)
    name = HoennWeatherKIF.map_name(map_id).downcase.strip
    zone = habitat(name)
    return [] unless AQUATIC_WEATHER.key?(weather) && AQUATIC_METHODS.key?(method)
    allowed = AQUATIC_WEATHER[weather] & AQUATIC_METHODS[method] & (AQUATIC_ZONES[zone] || [])
    return [] if allowed.empty?
    route = name[/\broute\s*0*(\d+)\b/, 1]
    location_key = route ? route.to_i : name.bytes.inject(0) { |sum, byte| sum * 31 + byte }
    # Stable, mode-aware ordering. No per-launch encounter generation.
    salt = mode == GameData::Encounter ? 0 : 23
    allowed.sort_by { |sp| (sp.to_s.bytes.inject(0) { |sum, byte| sum * 17 + byte } + location_key * 37 + salt) % 1009 }.take(2)
  end

  def self.visitor_species(mode, map_id, weather, native)
    if mode == GameData::Encounter
      choices = fixed_classic_pool(map_id, weather)
      # No unrelated fallback. An empty slot is better than a nonsense spawn.
    else
      area = habitat(HoennWeatherKIF.map_name(map_id))
      all = catalog[:families].keys.select { |sp| allowed_species?(sp) }
      all.select! { |sp| weather_options(sp).include?(weather) && habitats_for(sp).include?(area) }
      seed = map_id * 37 + weather.to_s.bytes.sum
      choices = all.sort_by { |sp| (GameData::Species.get(sp).id_number * 29 + seed) % 1009 }.take(12)
    end
    filtered = choices.select { |sp| allowed_species?(sp) }
                      .reject { |sp| native.any? { |slot| slot[1] == sp } }.take(2)
    if mode == GameData::Encounter && !choices.empty? && filtered.empty?
      log("Weather fixed pool filtered: map=#{map_id} weather=#{weather} configured=#{choices.inspect}")
    end
    filtered
  end

  # Tables are authored before packaging, never rebuilt on game launch.
  def self.entries(encounters, enc_type)
    return [] unless mode?(encounters)
    weather = weather_here
    return [] unless WEATHER_TYPES.include?(weather)
    table = encounters.instance_variable_get(:@encounter_tables)
    return [] unless table.is_a?(Hash)
    method = LAND_TYPES.include?(enc_type) ? :Land : enc_type
    return [] unless method == :Land || AQUATIC_TYPES.include?(method)
    native = if method == :Land
      LAND_TYPES.map { |t| table[t] }.find { |slots| slots.is_a?(Array) && !slots.empty? }
    else
      table[method]
    end
    return [] unless native.is_a?(Array) && !native.empty?
    mode = encounters.getEncounterMode == GameData::Encounter ? :Classic : :Remix
    version = ($PokemonGlobal && $PokemonGlobal.encounter_version) || 0
    record = HoennWeatherFixedTables::TABLES[[mode, $game_map.map_id, version]] ||
             HoennWeatherFixedTables::TABLES[[mode, $game_map.map_id, 0]]
    return [] unless record
    species = (record[method] || {})[weather] || []
    levels = native.select { |slot| slot.is_a?(Array) && slot.length >= 4 }
    return [] if levels.empty?
    min_level = levels.map { |slot| slot[2] }.min
    max_level = levels.map { |slot| slot[3] }.max
    species.select { |sp| allowed_species?(sp) && !native.any? { |slot| slot[1] == sp } }
           .take(2).map { |sp| [3, sp, min_level, max_level] }
  rescue StandardError => e
    log("Weather visitors error: #{e.class}: #{e.message}")
    []
  end

end

module HoennWeatherVisitorEncounters
  def choose_wild_pokemon(enc_type, *args)
    normal = super
    return normal unless normal && HoennEssentialsSettings.on?(:hs_encounters)
    method = enc_type.to_s.downcase
    setting = if method.include?("fish") || method.include?("rod")
                :hs_fishing
              elsif method.include?("surf") || method.include?("water")
                :hs_surf
              else
                :hs_grass
              end
    return normal unless HoennEssentialsSettings.on?(setting)
    chance = (HoennWeatherVisitors::CHANCE * HoennEssentialsSettings.multiplier(:hs_frequency)).round
    return normal unless rand(100) < chance
    extra = HoennWeatherVisitors.entries(self, enc_type)
    return normal if extra.empty?
    chosen = extra.sample
    [chosen[1], normal[1]]
  end

  # Hoenn's radar reads this list to identify weather-exclusive Pokémon.
  def list_weather_encounters(enc_type)
    native = super
    native = [] unless native.is_a?(Array)
    return native unless HoennEssentialsSettings.on?(:hs_encounters)
    extras = HoennWeatherVisitors.entries(self, enc_type)
    native + extras.reject { |entry| native.any? { |old| old[1] == entry[1] } }
  end
end

PokemonEncounters.prepend(HoennWeatherVisitorEncounters) unless
  PokemonEncounters.ancestors.include?(HoennWeatherVisitorEncounters)
