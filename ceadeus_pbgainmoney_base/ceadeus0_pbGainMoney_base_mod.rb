# This mod is just a base mod and will change no functionality
# It just overrides the pbGainMoney function with more or less a copy of itself
# however it will split up the pbGainMoney function into multiple subfunctions
# such that multiple mods can edit different parts of the pbGainMoney function
# without overriding one another
# 
# So this is a prerequisite for having the following mods without them conflicting (or having to use one file for all of them)
#   - mod: gain money on rematches
#   - mod: money gain multiplier
#   - mod: change effectiveness of Amulet coin
#   - mod: change money gain formula
#   - mod: pay day modifier
#
# I prepended the new functions with my Username (Ceadeus) so that they won't overlap
#
# Feel free to use this in your own projects or edit this
#
# 19.04.2025
class PokeBattle_Battle
  # KIF fix: PIF 6.8.2 passes the Hoenn cosmetics money won in this battle
  def pbGainMoney(cosmetics_money = 0)
    ceadeus_pbBeforeGainMoneyHook
    return if ceadeus_pbCheckIsRematch
    return if !ceadeus_pbCheckIfInternalBattle
    return if !ceadeus_pbCheckIfMoneyGain
    return if ceadeus_pbCheckNoMoneyLost

    ceadeus_pbGainMoneyFromTrainer(cosmetics_money)

    ceadeus_pbGainMoneyFromPayday

    ceadeus_pbAfterGainMoneyHook
  end

  def ceadeus_pbBeforeGainMoneyHook
  end

  def ceadeus_pbCheckIsRematch
    return $game_switches[SWITCH_IS_REMATCH] #is rematch
  end

  def ceadeus_pbCheckIfInternalBattle
    return @internalBattle
  end

  def ceadeus_pbCheckIfMoneyGain
    return @moneyGain
  end

  def ceadeus_pbCheckNoMoneyLost
    # KIF fix: KIF's PC self battles set nomoneylost and clear it themselves afterwards
    return $PokemonSystem.respond_to?(:nomoneylost) && $PokemonSystem.nomoneylost.to_i != 0
  end

  def ceadeus_pbGainMoneyFromTrainer(cosmetics_money = 0)
    tMoney = ceadeus_pbCalculateMoneyGainFromTrainerBattle
    tMoney = ceadeus_pbSetMoneyHook(tMoney) # so far unusued
    tMoney = ceadeus_pbSetMoneyHook2(tMoney) # used in another mod for money multiplier
    tMoney = ceadeus_pbSetMoneyHook3(tMoney) # so far unused

    tMoney = ceadeus_pbApplyAmuletCoinEffect(tMoney)
    tMoney = ceadeus_pbApplyHappyHourEffect(tMoney)

    oldMoney = pbPlayer.money
    ceadeus_pbAddMoney(tMoney)
    moneyGained = pbPlayer.money-oldMoney
    if moneyGained>0
      ceadeus_pbDisplayMoneyGained(moneyGained, cosmetics_money)
    end
  end

  def ceadeus_pbCalculateMoneyGainFromTrainerBattle
    # Money rewarded from opposing trainers
    if trainerBattle?
      tMoney = 0
      @opponent.each_with_index do |t,i|
        tMoney += pbMaxLevelInTeam(1, i) * t.base_money
      end
      return tMoney
    end
    return 0
  end

  def ceadeus_pbApplyAmuletCoinEffect(tMoney)
    tMoney *= 2 if @field.effects[PBEffects::AmuletCoin]
    return tMoney
  end

  def ceadeus_pbApplyHappyHourEffect(tMoney)
    tMoney *= 2 if @field.effects[PBEffects::HappyHour]
    return tMoney
  end

  def ceadeus_pbAddMoney(tMoney)
    pbPlayer.money += tMoney
  end

  def ceadeus_pbSetMoneyHook(tMoney)
    return tMoney
  end

  def ceadeus_pbSetMoneyHook2(tMoney)
    return tMoney
  end

  def ceadeus_pbSetMoneyHook3(tMoney)
    return tMoney
  end

  def ceadeus_pbDisplayMoneyGained(moneyGained, cosmetics_money = 0)
    # KIF fix: the same message as PIF 6.8.2 when cosmetics money was won too
    if cosmetics_money > 0
      pbDisplayPaused(_INTL("You got ${1} and some {2} for winning!", moneyGained.to_s_formatted, COSMETIC_CURRENCY_NAME))
      return
    end
    pbDisplayPaused(_INTL("You got ${1} for winning!",moneyGained.to_s_formatted))
  end

  def ceadeus_pbGainMoneyFromPayday
    # Pick up money scattered by Pay Day
    tMoney = 0
    if ceadeus_pbCheckPaydayActive
      tMoney = ceadeus_pbGetPaydayMoney
      tMoney = ceadeus_pbSetMoneyHook(tMoney) # so far unusued
      tMoney = ceadeus_pbSetMoneyHook2(tMoney) # used in another mod for money multiplier
      tMoney = ceadeus_pbSetMoneyHook3(tMoney) # so far unused

      tMoney = ceadeus_pbApplyAmuletCoinEffect(tMoney)
      tMoney = ceadeus_pbApplyHappyHourEffect(tMoney)
      oldMoney = pbPlayer.money
      ceadeus_pbGainPaydayMoney(tMoney)
      moneyGained = pbPlayer.money-oldMoney
      if moneyGained>0
        ceadeus_pbDisplayPaydayMoneyGain(moneyGained)
      end
    end
  end

  def ceadeus_pbCheckPaydayActive
    return @field.effects[PBEffects::PayDay]>0
  end
  
  def ceadeus_pbGetPaydayMoney
    return @field.effects[PBEffects::PayDay]
  end

  def ceadeus_pbGainPaydayMoney(tMoney)
    pbPlayer.money += tMoney
  end

  def ceadeus_pbDisplayPaydayMoneyGain(moneyGained)
    pbDisplayPaused(_INTL("You picked up ${1}!",moneyGained.to_s_formatted))
  end

  def ceadeus_pbAfterGainMoneyHook
  end

end
