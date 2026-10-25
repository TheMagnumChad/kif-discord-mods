def openChallengeApp
  pbFadeOutIn {
    scene = PokemonChallenges_Scene.new
    screen = PokemonChallenges_Screen.new(scene)
    screen.pbStartScreen
    # scene.pbRefresh
  }
end

class Player

  def add_challenge(challenge_id)
    @challenges = {} unless @challenges
    challenge_template = CHALLENGES[challenge_id]
    return unless challenge_template

    reward = pick_challenge_reward(challenge_template.category)
    @challenges[challenge_id] = PlayerChallenge.new(challenge_id, reward)
  end

  def complete_challenge(challenge_id)
    @challenges = {} unless @challenges
    @challenges ||= {}
    if @challenges.has_key?(challenge_id)
      challenge = @challenges[challenge_id]
      return if challenge.completed
      challenge.completed = true
      @challenges[challenge_id] = challenge
      $Trainer.nb_completed_challenges = 0 unless $Trainer.nb_completed_challenges
      $Trainer.nb_completed_challenges += 1
      # Original Hoenn challenge jingle.
      pbSEPlay("challenge_complete") if HoennEssentialsSettings.on?(:hs_challenge_sound)
    end
  end

  def completed_challenge?(challenge_id)
    @challenges ||= {}
    if @challenges.has_key?(challenge_id)
      return @challenges[challenge_id]
    end
    return false
  end

  def select_random_challenge(category)
    candidates = CHALLENGES.select { |_k, v| v.category == category }.keys
    return nil if candidates.empty?
    return candidates.sample
  end

  def refresh_challenges()
    @challenges = {} unless @challenges
    @challenges.each do |challenge_id, challenge|
      unless challenge.completed
        remove_challenge(challenge.id)
      end
    end
    categories = [:encounter, :battle, :catch, :fusion]
    categories.each do |category|
      unclaimed_challenges = listPlayerChallengesOfCategory(category)
      if unclaimed_challenges.empty?
        challenge_id = select_random_challenge(category)
        add_challenge(challenge_id)
      end
    end
  end

  def listPlayerChallengesOfCategory(category)
    challenges_list = []
    @challenges.each do |challenge_id, challenge|
      if challenge.template.category == category
        challenges_list << challenge.id
      end
    end
    return challenges_list
  end

  def remove_challenge(challenge_id)
    @challenges.delete(challenge_id)
  end

  def clear_all_challenges
    @challenges = {} unless @challenges
    for id in @challenges
      remove_challenge(id)
    end
  end

  def pick_challenge_reward(category)
    tier = rand(3) == 0 ? :TIER2 : :TIER1
    items_list = []
    case category
    when :encounter
      items_list = tier == :TIER1 ? CHALLENGE_ENCOUNTER_REWARDS_TIER1 : CHALLENGE_ENCOUNTER_REWARDS_TIER2
    when :battle
      items_list = tier == :TIER1 ? CHALLENGE_BATTLE_REWARDS_TIER1 : CHALLENGE_BATTLE_REWARDS_TIER2
    when :catch
      items_list = tier == :TIER1 ? CHALLENGE_CATCH_REWARDS_TIER1 : CHALLENGE_CATCH_REWARDS_TIER2
    when :fusion
      items_list = tier == :TIER1 ? CHALLENGE_FUSE_REWARDS_TIER1 : CHALLENGE_FUSE_REWARDS_TIER2
    end
    item = items_list.sample
    if tier == :TIER1
      quantity = rand(1..3)
    else
      quantity = 1
    end
    reward = []
    for i in 1..quantity
      reward << item
    end
    return reward
  end

end

class PlayerChallenge
  attr_reader :id
  attr_reader :item_reward
  attr_reader :template
  attr_accessor :completed

  def initialize(id, item_reward = [])
    @id = id
    @item_reward = item_reward
    @template = CHALLENGES[id]
    @completed = false
  end

  def description
    return _INTL(@template.description)
  end

  def category
    return _INTL(@template.category)
  end

  def money_reward
    return _INTL(@template.money_reward)
  end
end

class ChallengeTemplate
  attr_reader :id, :description, :category, :money_reward

  def initialize(id, description, category, money_reward)
    @id = id
    @description = description
    @money_reward = money_reward
    @category = category
  end
end

CHALLENGES = {}

def define_challenge(id, description:, category:, money_reward:)
  CHALLENGES[id] = ChallengeTemplate.new(id, description, category, money_reward)
end


CHALLENGE_ENCOUNTER_REWARDS_TIER1 = [:REPEL, :POTION, :ANTIDOTE]
CHALLENGE_ENCOUNTER_REWARDS_TIER2 = [:SUPERREPEL, :SUPERPOTION, :REVIVE, :DAWNSTONE, :DUSKSTONE]

CHALLENGE_BATTLE_REWARDS_TIER1 = [:XATTACK, :XDEFENSE, :ETHER, :FULLHEAL]
CHALLENGE_BATTLE_REWARDS_TIER2 = [:ELIXIR, :SITRUSBERRY]

CHALLENGE_CATCH_REWARDS_TIER1 = [:POKEBALL, :GREATBALL, :PREMIERBALL, :HEALBALL]
CHALLENGE_CATCH_REWARDS_TIER2 = [:ULTRABALL, :QUICKBALL, :DUSKBALL]

CHALLENGE_FUSE_REWARDS_TIER1 = [:DNASPLICERS, :DNAREVERSER]
CHALLENGE_FUSE_REWARDS_TIER2 = [:FUSIONBALL, :FUSIONREPEL]

########################
#   Encounter challenges
########################

define_challenge :encounter_2_pokemon_at_once,
                 description: _INTL("Get into a battle against 2 wild Pokémon at once"),
                 category: :encounter,
                 money_reward: 200

define_challenge :encounter_3_pokemon_at_once,
                 description: _INTL("Get into a battle against 3 wild Pokémon at once"),
                 category: :encounter,
                 money_reward: 750

define_challenge :encounter_2_different_pokemon_at_once,
                 description: _INTL("Get into a battle against 2 different wild Pokémon at once"),
                 category: :encounter,
                 money_reward: 350

define_challenge :encounter_3_different_pokemon_at_once,
                 description: _INTL("Get into a battle against 3 different wild Pokémon at once"),
                 category: :encounter,
                 money_reward: 750

define_challenge :encounter_2_fused_pokemon_at_once,
                 description: _INTL("Get into a battle against 2 wild fused Pokémon at once"),
                 category: :encounter,
                 money_reward: 1000

define_challenge :encounter_2_same_pokemon_at_once,
                 description: _INTL("Get into a battle against 2 of the same Pokémon at once"),
                 category: :encounter,
                 money_reward: 350

define_challenge :encounter_3_same_pokemon_at_once,
                 description: _INTL("Get into a battle against 3 of the same species of Pokémon at once"),
                 category: :encounter,
                 money_reward: 750


define_challenge :encounter_offguard_any,
                 description: _INTL("Catch a Pokémon off guard"),
                 category: :encounter,
                 money_reward: 200

define_challenge :encounter_offguard_curious,
                 description: _INTL("Catch a curious Pokémon off guard"),
                 category: :encounter,
                 money_reward: 350

define_challenge :encounter_offguard_aggressive,
                 description: _INTL("Catch an aggressive Pokémon off guard"),
                 category: :encounter,
                 money_reward: 500

define_challenge :encounter_offguard_skittish,
                 description: _INTL("Catch a skittish Pokémon off guard"),
                 category: :encounter,
                 money_reward: 500


# define_challenge :wild_pokemon_chase_20_steps,
#                  description: _INTL("Get a wild Pokémon to chase you for 20 steps"),
#                  money_reward: 1000


########################
#   Battle challenges
########################
define_challenge :defeat_1_not_very_effective,
                 description: _INTL("Defeat a  Pokémon in one move using a not-very-effective move"),
                 category: :battle,
                 money_reward: 400
#
# define_challenge :defeat_1_indirect_damage,
#                  description: _INTL("Defeat a wild Pokémon without inflicting any direct damage"),
#                  money_reward: 500
#
define_challenge :battle_enemy_1_hp,
                 description: _INTL("Get an opposing Pokémon to exactly 1 HP"),
                 category: :battle,
                 money_reward: 1000

define_challenge :battle_flinch,
                 description: _INTL("Make your opponent flinch during a battle"),
                 category: :battle,
                 money_reward: 250

define_challenge :rematch_trainer,
                 description: _INTL("Rematch a trainer"),
                 category: :battle,
                 money_reward: 400

# define_challenge :battle_use_healing_item,
#                  description: _INTL("Use a healing item during a battle."),
#                  category: :battle,
#                  money_reward: 200
#
define_challenge :battle_stat_boost,
                 description: _INTL("Use a stat-boosting move or item during a battle"),
                 category: :battle,
                 money_reward: 300

define_challenge :battle_stat_boost_sharp,
                 description: _INTL("Sharply boost your Pokémon's stats in a battle"),
                 category: :battle,
                 money_reward: 500

define_challenge :battle_stat_boost_max,
                 description: _INTL("Max out one of your stats during a battle"),
                 category: :battle,
                 money_reward: 1000

#
# define_challenge :battle_berry,
#                  description: _INTL("Have a Pokémon use a berry during a battle"),
#                  category: :battle,
#                  money_reward: 300

# define_challenge :battle_one_hit_ko,
#                  description: _INTL("Land a One-Hit-KO move"),
#                  category: :fight,
#                  money_reward: 1000
#

########################
#   Catching challenges
########################


define_challenge :catch_first_try,
                 description: _INTL("Catch a Pokémon on the first try"),
                 category: :catch,
                 money_reward: 400

define_challenge :catch_full_health,
                 description: _INTL("Catch a Pokémon at full health"),
                 category: :catch,
                 money_reward: 400

define_challenge :catch_no_damage,
                 description: _INTL("Catch a Pokémon without receiving any damage"),
                 category: :catch,
                 money_reward: 400

define_challenge :catch_premierball,
                 description: _INTL("Catch a Pokémon using a Premier Ball"),
                 category: :catch,
                 money_reward: 150

define_challenge :catch_fused,
                 description: _INTL("Catch a wild fused Pokémon"),
                 category: :catch,
                 money_reward: 300

define_challenge :catch_last_pokeball,
                 description: _INTL("Catch a Pokémon on your very last ball"),
                 category: :catch,
                 money_reward: 1000

define_challenge :catch_weather_encounter,
                 description: _INTL("Catch a Pokémon that appears in special weather conditions"),
                 category: :catch,
                 money_reward: 750


########################
#   Fusing challenges
########################


#
define_challenge :fuse_same_species,
                 description: _INTL("Fuse two Pokémon of the same species together"),
                category: :fusion,
                 money_reward: 500

define_challenge :fuse_same_type,
                 description: _INTL("Fuse two Pokémon that share the same type"),
                category: :fusion,
                 money_reward: 500



define_challenge :fuse_5_pokemon,
                 description: _INTL("Fuse Pokémon 5 times"),
                 category: :fusion,
                 money_reward: 750

define_challenge :fuse_1_pokemon,
                 description: _INTL("Fuse a Pokémon"),
                 category: :fusion,
                 money_reward: 200

define_challenge :fuse_2_pokemon,
                 description: _INTL("Fuse Pokémon 2 times"),
                 category: :fusion,
                 money_reward: 300

define_challenge :unfuse_5_pokemon,
                 description: _INTL("Unfuse Pokémon 5 times"),
                 category: :fusion,
                 money_reward: 750

define_challenge :unfuse_2_pokemon,
                 description: _INTL("Unfuse Pokémon 2 times"),
                 category: :fusion,
                 money_reward: 300

define_challenge :unfuse_1_pokemon,
                 description: _INTL("Unfuse a Pokémon"),
                 category: :fusion,
                 money_reward: 200

define_challenge :fuse_wild_pokemon,
                 description: _INTL("Get two wild Pokémon to fuse before a battle"),
                 category: :fusion,
                 money_reward: 400

# PokéChallenge: Hoenn definitions with a KIF-safe menu.
class Player
  attr_accessor :challenges, :nb_completed_challenges
end

class Pokenav
  attr_accessor :last_opened_challenges
end

module HoennNavChallengeCompat
  def self.ensure_player
    return false unless $Trainer
    $Trainer.challenges ||= {}
    $Trainer.nb_completed_challenges ||= 0
    true
  end

  def self.refresh_if_needed
    return unless ensure_player
    today = pbGetTimeNow
    previous = $Trainer.pokenav.last_opened_challenges
    if previous.nil? || timeDateGreaterThan(today, previous)
      $Trainer.refresh_challenges
    end
    $Trainer.pokenav.last_opened_challenges = today
  end

  def self.show
    return unless ensure_player
    refresh_if_needed
    loop do
      entries = $Trainer.challenges.values
      labels = entries.map do |challenge|
        prefix = challenge.completed ? "[DONE] " : ""
        prefix + challenge.description.to_s
      end
      labels << _INTL("Close")
      selection = pbMessage(_INTL("PokéChallenge - {1} completed", $Trainer.nb_completed_challenges), labels, labels.length)
      break if selection.nil? || selection < 0 || selection >= entries.length
      challenge = entries[selection]
      unless challenge.completed
        pbMessage(_INTL("{1}\nReward: ${2} and items", challenge.description, challenge.money_reward))
        next
      end
      # Claim once; only remove the challenge after both rewards are granted.
      items = challenge.item_reward || []
      unless items.empty?
        item = items[0]
        quantity = items.count(item)
        unless pbReceiveItem(item, quantity)
          pbMessage(_INTL("Make room in your Bag to claim this reward."))
          next
        end
      end
      $Trainer.money += challenge.money_reward.to_i
      $Trainer.remove_challenge(challenge.id)
      pbMessage(_INTL("Challenge reward claimed!"))
    end
  end
end


class HoennPokeNavScreen
  def openChallengeApp
    HoennNavChallengeCompat.show
  end
end

# Use Hoenn's actual challenge scene and button graphics.
class HoennPokeNavScreen
  def openChallengeApp
    return unless HoennNavChallengeCompat.ensure_player
    pbFadeOutIn {
      scene = PokemonChallenges_Scene.new
      PokemonChallenges_Screen.new(scene).pbStartScreen
    }
  end
end
