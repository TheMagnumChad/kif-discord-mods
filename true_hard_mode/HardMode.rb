#===============================================================================
# HardMode.rb  --  standalone, no settings. Drop into Mods/.
#
# Trainer battles only (wild battles are untouched):
#   0. Trainer Pokemon with a base stat total under a floor are scaled up to
#      exactly that floor (proportionally, so their stat shape is kept). The
#      floor rises with the player's badge count: 300 at 0 badges, 450 at 8,
#      600 at 16.
#   1. Trainer Pokemon get 1.5x stats (HP included), rising with the player's
#      badge count up to 2.0x at 16 badges
#   2. The last Pokemon of each trainer gets another 1.2x on top
#   3. Trainer Pokemon have max IVs
#   4. Every trainer Pokemon gets exactly 6 moves:
#        3 attacks  - 1 is always a priority move (Quick Attack, Extreme Speed..)
#        3 status   - 1 setup, 1 recovery, 1 ailment slot
#      The ailment slot re-targets every turn to the best ailment (or, if none
#      can land, a screen / extra setup move) for the Pokemon it is facing.
#   8. Trainer Pokemon with an empty held-item slot get an item by role:
#      attackers Life Orb, bulky Pokemon Leftovers, a bulky last Pokemon Weakness
#      Policy (Sitrus Berry / Expert Belt if the item isn't in the game).
#   9. Recovery moves have a cooldown on trainer Pokemon: after one is used, no
#      recovery move can be used again for RECOVERY_COOLDOWN turns, so they
#      can't just spam heal.
#   7. A damaged trainer Pokemon heals SWITCH_IN_HEAL of its max HP every time
#      it is switched back in (before entry hazards).
#   6. Contrary on trainer Pokemon only flips stat DROPS into boosts. Stat
#      raises stay raises.
#   5. Once per battle, when a trainer Pokemon drops below 50% HP it gets
#      +1 in its better attacking stat and +1 in its best non-attacking stat
#      (Defense, Sp. Def or Speed).
#
# Everything is hooked with aliases; no existing method is overwritten.
#===============================================================================

module HardMode
  BST_FLOOR_MIN = 300    # BST floor at 0 badges
  BST_FLOOR_MAX = 600    # BST floor at MAX_BADGES badges
  STAT_MULT_MIN = 1.5    # at 0 badges
  STAT_MULT_MAX = 2.0    # at MAX_BADGES badges (the trainer card shows 16 post-game)
  MAX_BADGES    = 16
  LAST_MULT = 1.2
  IV_VALUE  = 31
  SWITCH_IN_HEAL = 0.125   # fraction of max HP healed on switch-in (12.5%)

  # --- Held items (only fills empty slots) ---------------------------------
  # No Assault Vest / Choice items: the status moves and the AI don't mix.
  ITEMS_OFFENSIVE = [:LIFEORB, :EXPERTBELT, :SITRUSBERRY]
  ITEMS_BULKY     = [:LEFTOVERS, :SITRUSBERRY]
  ITEMS_BULKY_ACE = [:WEAKNESSPOLICY, :LEFTOVERS, :SITRUSBERRY]

  # --- Moveset shape ----------------------------------------------------------
  MAX_MOVES = 6
  ATTACKS   = 3   # of which at least 1 is a priority move

  # --- Status moves -----------------------------------------------------------
  SETUP_PHYSICAL = [:SWORDSDANCE, :BULKUP, :DRAGONDANCE, :COIL]
  SETUP_SPECIAL  = [:CALMMIND, :NASTYPLOT, :QUIVERDANCE]
  SETUP_ANY      = [:SHELLSMASH]
  RECOVERY       = [:RECOVER, :ROOST, :SOFTBOILED, :SLACKOFF, :MILKDRINK,
                    :SYNTHESIS, :MOONLIGHT, :MORNINGSUN, :SHOREUP, :HEALORDER]
  SCREENS        = [:REFLECT, :LIGHTSCREEN]   # only used as the ailment-slot fallback

  # Cooldown: one shared timer per trainer Pokemon for all of these moves.
  # Used on turn T, blocked on T+1 .. T+(COOLDOWN-1), usable again on T+COOLDOWN.
  RECOVERY_COOLDOWN = 3
  COOLDOWN_MOVES = RECOVERY + [:REST, :WISH, :JUNGLEHEALING, :LIFEDEW, :LUNARBLESSING]
  DYNAMIC_AILMENTS = [:TOXIC, :WILLOWISP, :THUNDERWAVE]

  # --- Attack fallbacks -------------------------------------------------------
  # Used only when the Pokemon's own moves/learnset cannot fill the slot.
  # These may be moves it could never learn legitimately.
  FALLBACK_ATTACKS = {
    :NORMAL   => :BODYSLAM,    :FIRE     => :FLAMETHROWER,
    :WATER    => :SURF,        :GRASS    => :ENERGYBALL,
    :ELECTRIC => :THUNDERBOLT, :ICE      => :ICEBEAM,
    :FIGHTING => :CLOSECOMBAT, :POISON   => :SLUDGEBOMB,
    :GROUND   => :EARTHQUAKE,  :FLYING   => :AIRSLASH,
    :PSYCHIC  => :PSYCHIC,     :BUG      => :XSCISSOR,
    :ROCK     => :ROCKSLIDE,   :GHOST    => :SHADOWBALL,
    :DRAGON   => :DRAGONPULSE, :DARK     => :DARKPULSE,
    :STEEL    => :FLASHCANNON, :FAIRY    => :MOONBLAST
  }
  FALLBACK_GENERIC = [:BODYSLAM, :HYPERVOICE]

  FALLBACK_PRIORITY = {
    :NORMAL => :EXTREMESPEED, :FIGHTING => :MACHPUNCH, :ICE   => :ICESHARD,
    :WATER  => :AQUAJET,      :GHOST    => :SHADOWSNEAK, :STEEL => :BULLETPUNCH,
    :DARK   => :SUCKERPUNCH,  :ROCK     => :ACCELEROCK
  }
  FALLBACK_PRIORITY_GENERIC = [:EXTREMESPEED, :QUICKATTACK]

  # Moves that are bad to force onto a trainer (never picked, existing ones dropped).
  BAD_ATTACKS = [:EXPLOSION, :SELFDESTRUCT, :MEMENTO, :FINALGAMBIT, :DREAMEATER,
                 :FOCUSPUNCH, :FAKEOUT, :FIRSTIMPRESSION, :FEINT, :HYPERBEAM,
                 :GIGAIMPACT, :BLASTBURN, :FRENZYPLANT, :HYDROCANNON,
                 :ROCKWRECKER, :ROAROFTIME, :PRISMATICLASER, :ETERNABEAM,
                 :SKYATTACK, :LASTRESORT, :SNORE, :SPITUP, :NATURALGIFT,
                 :FLING, :COUNTER, :MIRRORCOAT, :METALBURST, :ENDEAVOR,
                 :BELCH, :SYNCHRONOISE, :UPROAR, :STRUGGLE]

  #=============================================================================
  # Base stat total floor: scale every base stat by floor / BST (proportional),
  # then hand out the rounding remainder so the total is exactly the floor.
  #=============================================================================
  def self.scale_bst(stats, target)
    total = stats.values.sum
    return stats if total <= 0 || total >= target
    exact  = {}
    scaled = {}
    stats.each do |k, v|
      exact[k]  = v * target / total.to_f
      scaled[k] = [exact[k].floor, 1].max
    end
    remainder = target - scaled.values.sum
    order = stats.keys.sort_by { |k| -(exact[k] - exact[k].floor) }
    i = 0
    while remainder > 0
      scaled[order[i % order.length]] += 1
      remainder -= 1
      i += 1
    end
    return scaled
  end

  #=============================================================================
  # Badge scaling (0.0 at 0 badges .. 1.0 at MAX_BADGES badges):
  #   stat multiplier 1.5x -> 2.0x, BST floor 300 -> 600
  #=============================================================================
  def self.badge_progress(battle)
    player = battle.pbPlayer
    badges = player ? player.badge_count : 0
    badges = [[badges, 0].max, MAX_BADGES].min
    return badges / MAX_BADGES.to_f
  end

  def self.stat_mult(battle)
    return STAT_MULT_MIN + (STAT_MULT_MAX - STAT_MULT_MIN) * badge_progress(battle)
  end

  def self.bst_floor(battle)
    return (BST_FLOOR_MIN + (BST_FLOOR_MAX - BST_FLOOR_MIN) * badge_progress(battle)).round
  end

  #=============================================================================
  # Held item by role (empty slots only)
  #=============================================================================
  def self.assign_item(pkmn, is_last)
    return if pkmn.item_id
    offense = [pkmn.attack, pkmn.spatk].max
    bulk    = (pkmn.defense + pkmn.spdef) / 2.0
    list = if offense >= bulk
             ITEMS_OFFENSIVE
           else
             is_last ? ITEMS_BULKY_ACE : ITEMS_BULKY
           end
    pick = list.find { |id| GameData::Item.exists?(id) }
    pkmn.item = pick if pick
  end

  #=============================================================================
  # Recovery cooldown
  #=============================================================================
  def self.on_cooldown?(battle, battler, move)
    return false if !move || !COOLDOWN_MOVES.include?(move.id)
    pkmn = battler.pokemon
    return false if !pkmn || !pkmn.hm_mult
    last = pkmn.instance_variable_get(:@hm_heal_turn)
    return false if last.nil?
    return battle.turnCount - last < RECOVERY_COOLDOWN
  end

  #=============================================================================
  # Battle start: prepare every opposing trainer Pokemon
  #=============================================================================
  def self.apply_to_battle(battle)
    party = battle.pbParty(1)   # opposing side (index 1 always opposes index 0)
    return if !party || party.empty?
    starts = battle.party2starts
    starts = [0] if !starts || starts.empty?
    mult  = stat_mult(battle)
    floor = bst_floor(battle)
    starts.each_with_index do |s, i|
      last_idx = (starts[i + 1] || party.length) - 1
      (s..last_idx).each do |j|
        pkmn = party[j]
        next if !pkmn || pkmn.egg?
        prepare(pkmn, j == last_idx, mult, floor)
      end
    end
  end

  def self.prepare(pkmn, is_last, mult, floor)
    return if pkmn.instance_variable_get(:@hm_done)
    pkmn.instance_variable_set(:@hm_done, true)
    GameData::Stat.each_main { |s| pkmn.iv[s.id] = IV_VALUE }
    rewrite_moves(pkmn)
    assign_item(pkmn, is_last)
    pkmn.hm_bst  = floor
    pkmn.hm_mult = mult * (is_last ? LAST_MULT : 1.0)
    pkmn.calc_stats
  end

  #=============================================================================
  # Move rewriting: 3 attacks (1 priority) + setup + recovery + ailment slot
  #=============================================================================
  def self.move_ok?(id)
    return GameData::Move.exists?(id)
  end

  def self.attack_data(id)
    data = GameData::Move.try_get(id)
    return nil if !data || data.category == 2 || BAD_ATTACKS.include?(id)
    return data
  end

  # Higher is better: matches the Pokemon's better attacking stat, then power
  # (with STAB), then a small bonus for moves it already knew.
  def self.score(data, types, physical, known)
    stab = types.include?(data.type) ? 1.5 : 1.0
    role = ((data.category == 0) == physical) ? 1 : 0
    return [role, data.base_damage * stab, known.include?(data.id) ? 1 : 0]
  end

  def self.rewrite_moves(pkmn)
    old_moves = {}
    pkmn.moves.each { |m| old_moves[m.id] = m }
    known    = pkmn.moves.map { |m| m.id }
    physical = pkmn.attack >= pkmn.spatk
    types    = [pkmn.type1, pkmn.type2].compact.uniq
    level    = pkmn.level_simple

    # Candidate attacks: what it already knows + its learnset up to its level
    ids = known.dup
    if pkmn.respond_to?(:getMoveList)
      (pkmn.getMoveList || []).each { |lv, id| ids.push(id) if lv <= level }
    end
    cands = ids.uniq.map { |id| attack_data(id) }.compact
    ranked = lambda do |list|
      list.sort_by { |d| score(d, types, physical, known) }.reverse.map { |d| d.id }
    end

    attacks = []
    # 1) the priority attack
    prio = ranked.call(cands.select { |d| d.priority > 0 && d.base_damage > 0 }).first
    if !prio
      types.each do |t|
        id = FALLBACK_PRIORITY[t]
        (prio = id; break) if id && move_ok?(id)
      end
    end
    prio ||= FALLBACK_PRIORITY_GENERIC.find { |id| move_ok?(id) }
    attacks.push(prio) if prio

    # 2) the rest from its own moves (40+ power), best first
    strong = cands.select { |d| d.base_damage >= 40 && !attacks.include?(d.id) }
    ranked.call(strong).each do |id|
      break if attacks.length >= ATTACKS
      attacks.push(id)
    end

    # 3) still short: type fallbacks, then generic fallbacks
    if attacks.length < ATTACKS
      types.each do |t|
        id = FALLBACK_ATTACKS[t]
        attacks.push(id) if id && move_ok?(id) && !attacks.include?(id) && attacks.length < ATTACKS
      end
      FALLBACK_GENERIC.each do |id|
        attacks.push(id) if move_ok?(id) && !attacks.include?(id) && attacks.length < ATTACKS
      end
    end

    # Status trio: setup, recovery, ailment slot
    setup_role = (physical ? SETUP_PHYSICAL : SETUP_SPECIAL) + SETUP_ANY
    setup    = known.find { |id| setup_role.include?(id) } ||
               setup_role.find { |id| move_ok?(id) }
    recovery = known.find { |id| RECOVERY.include?(id) } ||
               RECOVERY.find { |id| move_ok?(id) }
    ailment  = known.find { |id| DYNAMIC_AILMENTS.include?(id) } ||
               DYNAMIC_AILMENTS.find { |id| move_ok?(id) }

    final = attacks + [setup, recovery, ailment].compact
    final = final.uniq.first(MAX_MOVES)
    slot  = ailment ? final.index(ailment) : nil

    pkmn.moves = final.map { |id| old_moves[id] || Pokemon::Move.new(id) }
    pkmn.instance_variable_set(:@hm_slot, slot)
  end

  #=============================================================================
  # Below 50% HP: +1 best attack stat, +1 best non-attack stat (once per Pokemon)
  #=============================================================================
  def self.check_enrage(battle, b)
    return if !b || b.fainted? || b.hp * 2 >= b.totalhp
    pkmn = b.pokemon
    return if !pkmn || !pkmn.hm_mult || pkmn.instance_variable_get(:@hm_enraged)
    pkmn.instance_variable_set(:@hm_enraged, true)
    offense = [[:ATTACK, b.attack], [:SPECIAL_ATTACK, b.spatk]]
    others  = [[:DEFENSE, b.defense], [:SPECIAL_DEFENSE, b.spdef], [:SPEED, b.speed]]
    pick = lambda do |list|
      sorted = list.each_with_index.sort_by { |(_st, v), i| [-v, i] }.map { |(st, _v), _i| st }
      sorted.find { |st| b.pbCanRaiseStatStage?(st, b) } || sorted.first
    end
    battle.pbDisplay(_INTL("{1} is fired up!", b.pbThis))
    b.pbRaiseStatStage(pick.call(offense), 1, b)
    b.pbRaiseStatStage(pick.call(others), 1, b)
  end

  #=============================================================================
  # Dynamic ailment slot (runs right before the AI scores its moves)
  #=============================================================================
  def self.retarget_ailment(battle, idx)
    return if battle.wildBattle?
    user = battle.battlers[idx]
    return if !user || user.fainted? || !battle.opposes?(idx)
    pkmn = user.pokemon
    return if !pkmn
    slot = pkmn.instance_variable_get(:@hm_slot)
    return if slot.nil?
    return if user.effects[PBEffects::Transform]
    return if user.effects[PBEffects::ChoiceBand]
    return if user.effects[PBEffects::Encore] > 0
    cur = user.moves[slot]
    return if !cur || !pkmn.moves[slot] || cur.id != pkmn.moves[slot].id

    best = nil
    user.eachOpposing do |t|
      best = best_ailment(user, t)
      break if best
    end
    best ||= fallback_setup(user, pkmn)
    return if !best || best == cur.id
    return if user.moves.any? { |m| m && m.id == best }
    new_move = Pokemon::Move.new(best)   # fresh move = full PP
    pkmn.moves[slot] = new_move
    user.moves[slot] = PokeBattle_Move.from_pokemon_move(battle, new_move)
  end

  def self.abilities_of(battler)
    return [battler.instance_variable_get(:@ability_id),
            battler.instance_variable_get(:@ability2_id)].compact
  end

  def self.best_ailment(user, t)
    return nil if t.status != :NONE
    return nil if t.effects[PBEffects::Substitute] > 0
    return nil if t.pbOwnSide.effects[PBEffects::Safeguard] > 0
    abils = abilities_of(t)
    scores = {}
    if !t.pbHasType?(:POISON) && !t.pbHasType?(:STEEL) &&
       (abils & [:IMMUNITY, :POISONHEAL, :MAGICGUARD, :PASTELVEIL]).empty?
      bulky = (t.defense + t.spdef) >= (t.attack + t.spatk)
      scores[:TOXIC] = bulky ? 2 : 1
    end
    if !t.pbHasType?(:FIRE) &&
       (abils & [:WATERVEIL, :WATERBUBBLE, :MAGICGUARD, :GUTS, :FLAREBOOST]).empty?
      scores[:WILLOWISP] = (t.attack > t.spatk) ? 2 : 1
    end
    if !t.pbHasType?(:GROUND) && !t.pbHasType?(:ELECTRIC) &&
       (abils & [:LIMBER, :VOLTABSORB, :MOTORDRIVE, :LIGHTNINGROD]).empty?
      scores[:THUNDERWAVE] = (t.speed > user.speed) ? 2 : 1
    end
    options = DYNAMIC_AILMENTS.select { |m| scores[m] && move_ok?(m) }
    return nil if options.empty?
    return options.max_by { |m| scores[m] }
  end

  # When no ailment can land, the slot becomes a setup / recovery / screen move
  def self.fallback_setup(user, pkmn)
    physical = pkmn.attack >= pkmn.spatk
    pool = (physical ? SETUP_PHYSICAL : SETUP_SPECIAL) + SETUP_ANY + SCREENS +
           (physical ? SETUP_SPECIAL : SETUP_PHYSICAL)
    return pool.find { |id| move_ok?(id) && !user.moves.any? { |m| m && m.id == id } }
  end
end

#===============================================================================
# Pokemon: stat multiplier (only set on opposing trainer Pokemon in battle)
#===============================================================================
class Pokemon
  attr_accessor :hm_mult

  unless method_defined?(:hm_orig_calc_stats)
    alias hm_orig_calc_stats calc_stats
    def calc_stats(*args)
      diff = (@totalhp || 0) - (@hp || 0)   # damage taken so far
      hm_orig_calc_stats(*args)
      return if !@hm_mult
      @attack  = [(@attack  * @hm_mult).round, 1].max
      @defense = [(@defense * @hm_mult).round, 1].max
      @spatk   = [(@spatk   * @hm_mult).round, 1].max
      @spdef   = [(@spdef   * @hm_mult).round, 1].max
      @speed   = [(@speed   * @hm_mult).round, 1].max
      if @totalhp > 1   # leave Wonder Guard's 1 HP alone
        @totalhp = (@totalhp * @hm_mult).round
        @hp = [[@totalhp - diff, 0].max, @totalhp].min
      end
    end
  end
end

#===============================================================================
# Pokemon: base stats raised to the badge-scaled BST floor (flagged trainer Pokemon only)
#===============================================================================
class Pokemon
  attr_accessor :hm_bst

  unless method_defined?(:hm_orig_baseStats)
    alias hm_orig_baseStats baseStats
    def baseStats(*args)
      stats = hm_orig_baseStats(*args)
      return stats if !@hm_mult || !@hm_bst
      return HardMode.scale_bst(stats, @hm_bst)
    end
  end
end

#===============================================================================
# Battle: prepare the opposing trainer parties right before the battle starts
#===============================================================================
class PokeBattle_Battle
  unless method_defined?(:hm_orig_pbStartBattle)
    alias hm_orig_pbStartBattle pbStartBattle
    def pbStartBattle(*args)
      HardMode.apply_to_battle(self) if trainerBattle?
      return hm_orig_pbStartBattle(*args)
    end
  end
end

#===============================================================================
# AI: re-target the ailment slot before moves are scored
#===============================================================================
class PokeBattle_AI
  unless method_defined?(:hm_orig_pbChooseMoves)
    alias hm_orig_pbChooseMoves pbChooseMoves
    def pbChooseMoves(idxBattler)
      HardMode.retarget_ailment(@battle, idxBattler)
      return hm_orig_pbChooseMoves(idxBattler)
    end
  end
end

#===============================================================================
# Below-50% boost: check after every move (damage, recoil, Life Orb...) and at
# the end of each round (weather, poison, burn...)
#===============================================================================
class PokeBattle_Battler
  unless method_defined?(:hm_orig_pbEffectsAfterMove2)
    alias hm_orig_pbEffectsAfterMove2 pbEffectsAfterMove2
    def pbEffectsAfterMove2(user, targets, move, numHits, switchedBattlers)
      ret = hm_orig_pbEffectsAfterMove2(user, targets, move, numHits, switchedBattlers)
      ([user] + targets).uniq.each do |b|
        next if !b || switchedBattlers.include?(b.index)
        HardMode.check_enrage(@battle, b)
      end
      return ret
    end
  end
end

class PokeBattle_Battle
  unless method_defined?(:hm_orig_pbEndOfRoundPhase)
    alias hm_orig_pbEndOfRoundPhase pbEndOfRoundPhase
    def pbEndOfRoundPhase(*args)
      ret = hm_orig_pbEndOfRoundPhase(*args)
      if @decision == 0
        @battlers.each { |b| HardMode.check_enrage(self, b) }
      end
      return ret
    end
  end
end

#===============================================================================
# Contrary (trainer Pokemon only): drops still become boosts, but boosts are no
# longer flipped into drops. Done by forcing ignoreContrary on every "raise"
# path; the "lower" paths are left alone so Contrary still turns drops into
# boosts.
#===============================================================================
class PokeBattle_Battler
  def hm_contrary_raise_ok?
    return @pokemon && @pokemon.hm_mult && hasActiveAbility?(:CONTRARY)
  end

  unless method_defined?(:hm_orig_pbCanRaiseStatStage?)
    alias hm_orig_pbCanRaiseStatStage? pbCanRaiseStatStage?
    def pbCanRaiseStatStage?(stat, user = nil, move = nil, showFailMsg = false, ignoreContrary = false)
      ignoreContrary = true if hm_contrary_raise_ok?
      return hm_orig_pbCanRaiseStatStage?(stat, user, move, showFailMsg, ignoreContrary)
    end
  end

  unless method_defined?(:hm_orig_pbRaiseStatStageBasic)
    alias hm_orig_pbRaiseStatStageBasic pbRaiseStatStageBasic
    def pbRaiseStatStageBasic(stat, increment, ignoreContrary = false)
      ignoreContrary = true if hm_contrary_raise_ok?
      return hm_orig_pbRaiseStatStageBasic(stat, increment, ignoreContrary)
    end
  end

  unless method_defined?(:hm_orig_pbRaiseStatStage)
    alias hm_orig_pbRaiseStatStage pbRaiseStatStage
    def pbRaiseStatStage(stat, increment, user, showAnim = true, ignoreContrary = false)
      ignoreContrary = true if hm_contrary_raise_ok?
      return hm_orig_pbRaiseStatStage(stat, increment, user, showAnim, ignoreContrary)
    end
  end

  unless method_defined?(:hm_orig_pbRaiseStatStageByCause)
    alias hm_orig_pbRaiseStatStageByCause pbRaiseStatStageByCause
    def pbRaiseStatStageByCause(stat, increment, user, cause, showAnim = true, ignoreContrary = false)
      ignoreContrary = true if hm_contrary_raise_ok?
      return hm_orig_pbRaiseStatStageByCause(stat, increment, user, cause, showAnim, ignoreContrary)
    end
  end
end

#===============================================================================
# Switch-in heal: a damaged trainer Pokemon recovers SWITCH_IN_HEAL of its max
# HP when it enters battle. Runs before entry hazards (pbOnActiveOne) so
# hazard damage can still hurt it afterwards. Healthy Pokemon are unaffected.
#===============================================================================
class PokeBattle_Battler
  unless method_defined?(:hm_orig_pbEffectsOnSwitchIn)
    alias hm_orig_pbEffectsOnSwitchIn pbEffectsOnSwitchIn
    def pbEffectsOnSwitchIn(switchIn = false)
      if switchIn && !fainted? && @pokemon && @pokemon.hm_mult && @hp < @totalhp
        amt = pbRecoverHP((@totalhp * HardMode::SWITCH_IN_HEAL).round)
        @battle.pbDisplay(_INTL("{1} regained some health!", pbThis)) if amt > 0
      end
      return hm_orig_pbEffectsOnSwitchIn(switchIn)
    end
  end
end

#===============================================================================
# Recovery cooldown for trainer Pokemon. The usability check is what DemICE's AI
# (and the engine) consult, so a blocked heal is never even considered.
#===============================================================================
class PokeBattle_Battle
  unless method_defined?(:hm_orig_pbCanChooseMove?)
    alias hm_orig_pbCanChooseMove? pbCanChooseMove?
    def pbCanChooseMove?(idxBattler, idxMove, showMessages, sleepTalk = false)
      ret = hm_orig_pbCanChooseMove?(idxBattler, idxMove, showMessages, sleepTalk)
      return ret if !ret
      battler = @battlers[idxBattler]
      return !HardMode.on_cooldown?(self, battler, battler.moves[idxMove])
    end
  end
end

class PokeBattle_Battler
  unless method_defined?(:hm_orig_pbUseMove)
    alias hm_orig_pbUseMove pbUseMove
    def pbUseMove(choice, specialUsage = false)
      ret = hm_orig_pbUseMove(choice, specialUsage)
      mv = choice[2]
      if mv && @pokemon && @pokemon.hm_mult && HardMode::COOLDOWN_MOVES.include?(mv.id)
        @pokemon.instance_variable_set(:@hm_heal_turn, @battle.turnCount)
      end
      return ret
    end
  end
end

#===============================================================================
# KIF fix: a trainer Pokemon that joins the player (Rocket Mode steal, Snag
# Ball) becomes a normal Pokemon again: no stat multiplier or raised base
# stats, and at most 4 moves, so the player's team and save stay normal.
#===============================================================================
module HardMode
  def self.release(pkmn)
    return if !pkmn || !pkmn.hm_mult
    ratio = pkmn.totalhp > 0 ? pkmn.hp / pkmn.totalhp.to_f : 1.0
    pkmn.hm_mult = nil
    pkmn.hm_bst  = nil
    [:@hm_done, :@hm_slot, :@hm_enraged, :@hm_heal_turn].each do |v|
      pkmn.remove_instance_variable(v) if pkmn.instance_variable_defined?(v)
    end
    pkmn.moves = pkmn.moves.first(Pokemon::MAX_MOVES)
    pkmn.calc_stats
    pkmn.hp = [(pkmn.totalhp * ratio).round, 1].max
  end
end

class PokeBattle_Battle
  unless method_defined?(:hm_orig_pbRecordAndStoreCaughtPokemon)
    alias hm_orig_pbRecordAndStoreCaughtPokemon pbRecordAndStoreCaughtPokemon
    def pbRecordAndStoreCaughtPokemon(*args)
      (@caughtPokemon || []).each { |pkmn| HardMode.release(pkmn) }
      return hm_orig_pbRecordAndStoreCaughtPokemon(*args)
    end
  end
end
