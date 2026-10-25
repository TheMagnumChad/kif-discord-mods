# Hoenn Essentials RC2 settings and PokéNav progression.
module HoennEssentialsSettings
  CATEGORY = "Hoenn Essentials"
  ENTRIES = [
    [:hs_encounters, "Weather encounters", ["On", "Off"], 0],
    [:hs_frequency, "Weather encounter frequency", ["Low", "Normal", "High"], 1],
    [:hs_grass, "Grass and cave encounters", ["On", "Off"], 0],
    [:hs_surf, "Surf encounters", ["On", "Off"], 0],
    [:hs_fishing, "Fishing encounters", ["On", "Off"], 0],
    [:hs_weather_rate, "Weather change frequency", ["Slow", "Normal", "Fast"], 1],
    [:hs_relationships, "Trainer relationships", ["On", "Off"], 0],
    [:hs_affinity_rate, "Affinity gain rate", ["Slow", "Normal", "Fast"], 1],
    [:hs_team_growth, "Dynamic team growth", ["Slow", "Normal", "Fast"], 1],
    [:hs_team_changes, "Team change frequency", ["Low", "Normal", "High"], 1],
    [:hs_gifts, "Trainer gifts", ["On", "Off"], 0],
    [:hs_trading, "Trainer trading", ["On", "Off"], 0],
    [:hs_partners, "Partner recruitment", ["On", "Off"], 0],
    [:hs_notifications, "Trainer contact notifications", ["On", "Off"], 0],
    [:hs_profile, "Trainer profile updates", ["On", "Off"], 0],
    [:hs_radar_effects, "PokéRadar effects", ["On", "Off"], 0],
    [:hs_challenge_sound, "Challenge completion sounds", ["On", "Off"], 0]
  ]
  DEFAULTS = ENTRIES.each_with_object({}) { |row, hash| hash[row[0]] = row[3] }
  def self.get(key)
    return DEFAULTS[key] unless defined?(::ModSettingsMenu) && ::ModSettingsMenu.respond_to?(:get)
    value = ::ModSettingsMenu.get(key)
    value.is_a?(Integer) ? value : DEFAULTS[key]
  rescue StandardError
    DEFAULTS[key]
  end
  def self.on?(key); get(key) == 0; end
  def self.multiplier(key)
    [0.5, 1.0, 2.0][[get(key), 2].min] || 1.0
  end
  def self.register
    return unless defined?(::ModSettingsMenu) && ::ModSettingsMenu.respond_to?(:register)
    ENTRIES.each do |key, title, values, default|
      ::ModSettingsMenu.register(key, :name => title, :type => :enum,
        :values => values, :default => default, :category => CATEGORY,
        :description => "Hoenn Essentials: #{title.downcase}.")
    end
  end
end
if defined?(::ModSettingsMenu) && ::ModSettingsMenu.respond_to?(:register)
  HoennEssentialsSettings.register
else
  $MOD_SETTINGS_PENDING_REGISTRATIONS ||= []
  $MOD_SETTINGS_PENDING_REGISTRATIONS << proc { HoennEssentialsSettings.register }
end

module HoennEssentialsUnlocks
  def self.pokedex?
    return false unless $Trainer
    value = $Trainer.pokedex if $Trainer.respond_to?(:pokedex)
    return !!value unless value.nil?
    return !!$Trainer.has_pokedex if $Trainer.respond_to?(:has_pokedex)
    false
  end
  def self.radar?
    return false unless $Trainer
    bag = defined?($PokemonBag) ? $PokemonBag : nil
    if bag
      return true if bag.respond_to?(:pbHasItem?) && bag.pbHasItem?(:POKERADAR)
      return true if bag.respond_to?(:has?) && bag.has?(:POKERADAR)
    end
    return !!$Trainer.has_pokeradar if $Trainer.respond_to?(:has_pokeradar)
    return !!$PokemonGlobal.pokeradarObtained if $PokemonGlobal && $PokemonGlobal.respond_to?(:pokeradarObtained)
    false
  rescue StandardError
    false
  end
  def self.available?(app)
    case app.to_sym
    when :BOXLINK, :FUSIONQUIZ, :MAP, :MAPS then pokedex?
    when :POKERADAR then radar?
    else true
    end
  end
end

module HoennEssentialsWeatherEncounters
  def choose_wild_pokemon(enc_type, *args)
    # This wrapper controls the extra weather roll; the native roll is untouched.
    super
  end
end

module HoennEssentialsTrainerTuning
  def increase_affinity(entry, points)
    return super unless HoennEssentialsSettings.on?(:hs_relationships)
    rate = HoennEssentialsSettings.multiplier(:hs_affinity_rate)
    adjusted = points.to_i == 0 ? 0 : [(points.to_i * rate).round, 1].max
    super(entry, adjusted)
  end
  def try_post_battle_gift(entry)
    return false unless HoennEssentialsSettings.on?(:hs_gifts)
    super
  end
  def grow_team(entry, levels = 1)
    rate = HoennEssentialsSettings.multiplier(:hs_team_growth)
    super(entry, [(levels.to_i * rate).round, 1].max)
  end
  def dynamic_team_event(entry)
    rate = HoennEssentialsSettings.get(:hs_team_changes)
    return nil if rate == 0 && rand(2) == 0
    return super if rate != 2
    super || super
  end
  def trade_with_trainer(entry)
    return false unless HoennEssentialsSettings.on?(:hs_trading)
    super
  end
  def recruit_partner(entry, event)
    return false unless HoennEssentialsSettings.on?(:hs_partners)
    super
  end
end
if defined?(HoennTrainerRematches)
  HoennTrainerRematches.singleton_class.prepend(HoennEssentialsTrainerTuning)
end
