#===============================================================================
# Kuray Auto-Capture & Improved Auto-Battle Mod
# Features: 100% Catch Rate (Conditional), Auto-Capture, Multi-Wild Capture
# Version: 1.6
#===============================================================================
class PokeBattle_AI
  alias kuray_pbDefaultChooseEnemyCommand_v2 pbDefaultChooseEnemyCommand
  def pbDefaultChooseEnemyCommand(idxBattler)
    is_autobattler = ($PokemonSystem && $PokemonSystem.autobattler == 1)
    mod_enabled = defined?(XorronModSettings) && XorronModSettings.enabled?("auto_capture_enabled")
    
    owner_index = @battle.pbGetOwnerIndexFromBattlerIndex(idxBattler)
    is_player_side = (owner_index == 0 && !@battle.opposes?(idxBattler))
    # KIF fix: pbFirstBattlerOrder doesn't exist in 6.8.2 (the rescue made this always true);
    # the first actor is the player's first unfainted battler, in the order commands are chosen
    first_idx = nil
    @battle.eachSameSideBattler(0) { |b| first_idx ||= b.index if @battle.pbGetOwnerIndexFromBattlerIndex(b.index) == 0 }
    is_first_actor = (idxBattler == first_idx)

    if is_autobattler && is_player_side && @battle.wildBattle? && mod_enabled && is_first_actor
      targets = []
      @battle.eachOtherSideBattler(idxBattler) do |battler|
        next if battler.fainted?
        pkmn = battler.pokemon
        is_owned = ($Trainer && $Trainer.pokedex) ? $Trainer.pokedex.owned?(pkmn.species) : true
        is_new = !is_owned
        is_shiny = pkmn.shiny?
        catch_shiny_always = defined?(XorronModSettings) && XorronModSettings.enabled?("auto_capture_shinies_always")
        
        priority = 0
        if is_shiny
          if is_new then priority = 3
          elsif catch_shiny_always then priority = 2
          end
        elsif is_new then priority = 1
        end
        targets << { battler: battler, priority: priority, name: pkmn.name, shiny: is_shiny, new: is_new } if priority > 0
      end
      
      targets.sort! { |a, b| b[:priority] <=> a[:priority] }
      
      if targets.length > 0
        best_target = targets[0]
        ball = kuray_find_best_ball
        if ball
          @battle.pbRegisterItem(idxBattler, ball, best_target[:battler].index)
          reason = best_target[:shiny] ? (best_target[:new] ? "SHINY & NEW" : "SHINY DUPLICATE") : "NEW"
          msg = "[AUTO-CAPTURE] Target: #{best_target[:name]} (#{reason})"
          PBDebug.log(msg)
          @battle.pbDisplay(msg) if $DEBUG
          return
        end
      end
    end
    kuray_pbDefaultChooseEnemyCommand_v2(idxBattler)
  end

  alias kuray_pbAIRandom_v2 pbAIRandom
  def pbAIRandom(x)
    return 0 if @kuray_calculating_moves && $PokemonSystem && $PokemonSystem.autobattler == 1
    return kuray_pbAIRandom_v2(x)
  end

  alias kuray_pbChooseMoves_v2 pbChooseMoves
  def pbChooseMoves(idxBattler)
    # KIF fix: only while choosing for the player's own (Auto-Battle) side, not for the foe's AI
    @kuray_calculating_moves = !@battle.opposes?(idxBattler) && @battle.pbGetOwnerIndexFromBattlerIndex(idxBattler) == 0
    begin
      ret = kuray_pbChooseMoves_v2(idxBattler)
    ensure
      @kuray_calculating_moves = false
    end
    return ret
  end

  def kuray_find_best_ball
    return nil if !$PokemonBag
    priority = [:MASTERBALL, :ULTRABALL, :GREATBALL, :POKEBALL]
    priority.each { |ball_id| return ball_id if pbHasItem?(ball_id) }
    GameData::Item.each { |item| return item.id if item.is_poke_ball? && pbHasItem?(item.id) }
    return nil
  end
end

# --- Fix for Item Consumption ---
class PokeBattle_Battle
  alias kuray_pbConsumeItem_v2 pbConsumeItemInBag
  def pbConsumeItemInBag(item, idxBattler)
    # KIF fix: player's side only (owner 0 of the foe's side is the foe), and keep the base
    # "not consumed upon use" check
    if item && $PokemonSystem && $PokemonSystem.autobattler == 1 && !opposes?(idxBattler) &&
       pbGetOwnerIndexFromBattlerIndex(idxBattler) == 0
      use_type = GameData::Item.get(item).battle_use
      return if use_type == 0 || (use_type >= 6 && use_type <= 10)
      return if $PokemonBag && $PokemonBag.pbDeleteItem(item)
    end
    kuray_pbConsumeItem_v2(item, idxBattler)
  end
end

# --- 100% CATCH RATE ---
module PokeBattle_BattleCommon
  alias kuray_original_pbCaptureCalc_v2 pbCaptureCalc
  def pbCaptureCalc(pkmn, battler, catch_rate, ball)
    # Check if 100% Catch Rate is enabled in Xorron Menu
    catch_100_enabled = defined?(XorronModSettings) && XorronModSettings.enabled?("100_catch_rate_enabled")
    
    if catch_100_enabled
      is_owned = ($Trainer && $Trainer.pokedex) ? $Trainer.pokedex.owned?(pkmn.species) : true
      catch_shiny_always = XorronModSettings.enabled?("auto_capture_shinies_always")
      
      # 100% Chance applies when Auto-Capture rules match
      if !is_owned || (pkmn.shiny? && catch_shiny_always)
        @criticalCapture = true # Force instant catch (1 shake instead of 4)
        return 4
      end
    end
    kuray_original_pbCaptureCalc_v2(pkmn, battler, catch_rate, ball)
  end
end

# --- MULTI-WILD CAPTURE (Safe Version) ---
class PokeBattle_Battle
  alias kuray_pbOpposingBattlerCount_v2 pbOpposingBattlerCount
  def pbOpposingBattlerCount(idxBattler=0)
    # If we are checking if we can throw a ball and mod is ON, pretend there is only 1 enemy
    # KIF fix: a flag set around the ball check replaces scanning `caller` on every call, and the
    # Silver boss battle keeps its "too agitated to aim" lock
    if $xorron_ball_check && wildBattle? && !($game_switches && $game_switches[SWITCH_SILVERBOSS_BATTLE]) &&
       defined?(XorronModSettings) && XorronModSettings.enabled?("catch_multiple_wild_enabled")
      return 1
    end
    kuray_pbOpposingBattlerCount_v2(idxBattler)
  end
end

module ItemHandlers
  class << self
    alias kuray_triggerCanUseInBattle_v2 triggerCanUseInBattle unless method_defined?(:kuray_triggerCanUseInBattle_v2)
    def triggerCanUseInBattle(item, *args)
      ball = (GameData::Item.get(item).is_poke_ball? rescue false)
      return kuray_triggerCanUseInBattle_v2(item, *args) unless ball
      old = $xorron_ball_check
      $xorron_ball_check = true
      begin
        return kuray_triggerCanUseInBattle_v2(item, *args)
      ensure
        $xorron_ball_check = old
      end
    end
  end
end

# --- PERSISTENCE ---
class PokeBattle_Battle
  alias kuray_pbStartBattleCore_v2 pbStartBattleCore
  def pbStartBattleCore
    $AutoBattler = true if $PokemonSystem && $PokemonSystem.autobattler == 1
    kuray_pbStartBattleCore_v2
  end
end

# KIF fix: the original ended with `$DEBUG = true`, which turned on Debug mode for the whole game
# (debug menu, Ctrl skips trainer battles, Ctrl catches every Pokemon). Removed.
