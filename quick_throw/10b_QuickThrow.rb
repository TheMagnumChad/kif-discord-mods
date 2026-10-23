#========================================
# Quick Throw
# PIF Version: 6.4.5
# KIF Version: 0.20.7
# Script Version: 1.5
# Author: Stonewall
#========================================

# ---------------------------------------------------------------------------
# Extend PokemonSystem to store ball memory
# ---------------------------------------------------------------------------
class PokemonSystem
  attr_accessor :quick_throw_ball_memory
end

# KIF fix: PIF 6.8.2 has no lastUsedPokeBall, so every save of the last ball
# below failed inside its rescue. It holds a plain Symbol, so saves still load
# after the mod is removed.
class PokemonGlobalMetadata
  attr_accessor :lastUsedPokeBall
end

# ---------------------------------------------------------------------------
# Settings Storage & Menu 
# ---------------------------------------------------------------------------
module QuickThrowSettings
  @store = {}
  @pending = []
  @loaded = false

  def self.get(key)
    load_from_persistent_storage
    ensure_defaults
    @store[key]
  end

  def self.set(key, value)
    @store[key] = value
    save_to_persistent_storage
  end

  def self.load_from_persistent_storage
    return if @loaded
    @loaded = true
    if defined?(ModSettingsMenu)
      begin
        saved = ModSettingsMenu.get(:quick_throw_settings)
        if saved.is_a?(Hash)
          @store = saved.dup
        end
      rescue
      end
    end
  end

  def self.save_to_persistent_storage
    if defined?(ModSettingsMenu)
      begin
        ModSettingsMenu.set(:quick_throw_settings, @store)
      rescue
      end
    end
  end

  def self.ensure_defaults
    @store[:quick_throw_mode] = 1 unless @store.key?(:quick_throw_mode) 
    @store[:quick_throw_sprite] = true unless @store.key?(:quick_throw_sprite)
    @store[:ball_info_screen] = true unless @store.key?(:ball_info_screen)
    @store[:ball_rotation] = true unless @store.key?(:ball_rotation)
    @store[:no_balls_message] = true unless @store.key?(:no_balls_message)
    @store[:ball_memory] = true unless @store.key?(:ball_memory)
    @store[:ball_memory_auto_select] = false unless @store.key?(:ball_memory_auto_select)
    @store[:ball_filter_enabled] = false unless @store.key?(:ball_filter_enabled)
    @store[:doubles_target_select] = true unless @store.key?(:doubles_target_select)
  end

  def self.register_button
    ensure_defaults
    if defined?(ModSettingsMenu)
      begin
        unless ModSettingsMenu.registry.any? { |r| r[:key] == :quick_throw_settings_button }
          # KIF fix: register_option drops a button's action in KIF; register a :button row instead
          ModSettingsMenu.register(:quick_throw_settings_button, {
            :name        => "Quick Throw",
            :type        => :button,
            :on_press    => proc { QuickThrowSettings.open_menu },
            :description => "Configure Quick Throw behavior",
            :category    => "Quality of Life"
          })
        end
      rescue
      end
    else
      @pending << proc { register_button }
    end
  end

  def self.try_pending
    return if @pending.empty?
    left = @pending.dup
    @pending.clear
    left.each do |pr|
      begin
        pr.call
      rescue
      end
    end
  end

  def self.settings_definitions
    [
      {
        key: :quick_throw_mode,
        label_proc: proc {
          mode = get(:quick_throw_mode).to_i
          text = case mode
                 when 0 then _INTL("Off")
                 when 1 then _INTL("Button")
                 when 2 then _INTL("Menu")
                 else _INTL("Off")
                 end
          _INTL("Quick Throw Mode: {1}", text)
        },
        type: :cycle,
        values: [0,1,2],
        on_cycle: proc { |dir|
          cur = get(:quick_throw_mode).to_i
          vals = [0,1,2]
          idx = vals.index(cur) || 0
          idx = (idx + dir) % vals.length
          set(:quick_throw_mode, vals[idx])
        },
        on_use: proc {
          self.settings_definitions[0][:on_cycle].call(+1)
        }
      },
      {
        key: :quick_throw_sprite,
        label_proc: proc {
          val = !!get(:quick_throw_sprite)
          text = val ? _INTL("On") : _INTL("Off")
          _INTL("Quick Throw Sprite: {1}", text)
        },
        type: :cycle,
        values: [false,true],
        on_cycle: proc { |dir|
          val = !!get(:quick_throw_sprite)
          vals = [false,true]
          idx = vals.index(val) || 0
          idx = (idx + dir) % vals.length
          set(:quick_throw_sprite, vals[idx])
        },
        on_use: proc {
          set(:quick_throw_sprite, !get(:quick_throw_sprite))
        }
      },
      {
        key: :ball_info_screen,
        label_proc: proc {
          val = !!get(:ball_info_screen)
          text = val ? _INTL("On") : _INTL("Off")
          _INTL("Ball Info Screen: {1}", text)
        },
        type: :cycle,
        values: [false,true],
        on_cycle: proc { |dir|
          val = !!get(:ball_info_screen)
          vals = [false,true]
          idx = vals.index(val) || 0
          idx = (idx + dir) % vals.length
          set(:ball_info_screen, vals[idx])
        },
        on_use: proc { set(:ball_info_screen, !get(:ball_info_screen)) }
      },
      {
        key: :ball_rotation,
        label_proc: proc {
          val = !!get(:ball_rotation)
          text = val ? _INTL("On") : _INTL("Off")
          _INTL("Ball Rotation: {1}", text)
        },
        type: :cycle,
        values: [false,true],
        on_cycle: proc { |dir|
          val = !!get(:ball_rotation)
          vals = [false,true]
          idx = vals.index(val) || 0
          idx = (idx + dir) % vals.length
          set(:ball_rotation, vals[idx])
        },
        on_use: proc { set(:ball_rotation, !get(:ball_rotation)) }
      },
      {
        key: :no_balls_message,
        label_proc: proc {
          val = !!get(:no_balls_message)
          text = val ? _INTL("On") : _INTL("Off")
          _INTL("No Balls Message: {1}", text)
        },
        type: :cycle,
        values: [false,true],
        on_cycle: proc { |dir|
          val = !!get(:no_balls_message)
          vals = [false,true]
          idx = vals.index(val) || 0
          idx = (idx + dir) % vals.length
          set(:no_balls_message, vals[idx])
        },
        on_use: proc { set(:no_balls_message, !get(:no_balls_message)) }
      },
      {
        key: :ball_memory,
        label_proc: proc {
          val = !!get(:ball_memory)
          text = val ? _INTL("On") : _INTL("Off")
          _INTL("Ball Memory: {1}", text)
        },
        type: :cycle,
        values: [false,true],
        on_cycle: proc { |dir|
          val = !!get(:ball_memory)
          vals = [false,true]
          idx = vals.index(val) || 0
          idx = (idx + dir) % vals.length
          set(:ball_memory, vals[idx])
        },
        on_use: proc { set(:ball_memory, !get(:ball_memory)) }
      },
      {
        key: :ball_memory_auto_select,
        label_proc: proc {
          val = !!get(:ball_memory_auto_select)
          text = val ? _INTL("On") : _INTL("Off")
          _INTL("Auto-Select Remembered: {1}", text)
        },
        type: :cycle,
        values: [false,true],
        on_cycle: proc { |dir|
          val = !!get(:ball_memory_auto_select)
          vals = [false,true]
          idx = vals.index(val) || 0
          idx = (idx + dir) % vals.length
          set(:ball_memory_auto_select, vals[idx])
        },
        on_use: proc { set(:ball_memory_auto_select, !get(:ball_memory_auto_select)) }
      },
      {
        key: :ball_filter_enabled,
        label_proc: proc {
          val = !!get(:ball_filter_enabled)
          text = val ? _INTL("On") : _INTL("Off")
          _INTL("Ball Filters: {1}", text)
        },
        type: :cycle,
        values: [false,true],
        on_cycle: proc { |dir|
          val = !!get(:ball_filter_enabled)
          vals = [false,true]
          idx = vals.index(val) || 0
          idx = (idx + dir) % vals.length
          set(:ball_filter_enabled, vals[idx])
        },
        on_use: proc { set(:ball_filter_enabled, !get(:ball_filter_enabled)) }
      },
      {
        key: :doubles_target_select,
        label_proc: proc {
          val = !!get(:doubles_target_select)
          text = val ? _INTL("On") : _INTL("Off")
          _INTL("Doubles Target Select: {1}", text)
        },
        type: :cycle,
        values: [false,true],
        on_cycle: proc { |dir|
          val = !!get(:doubles_target_select)
          vals = [false,true]
          idx = vals.index(val) || 0
          idx = (idx + dir) % vals.length
          set(:doubles_target_select, vals[idx])
        },
        on_use: proc { set(:doubles_target_select, !get(:doubles_target_select)) }
      },
      {
        key: :manage_blacklist,
        label_proc: proc { _INTL("Manage Ball Blacklist") },
        type: :multi,
        on_use: proc { BallFilter.open_blacklist_menu }
      },
      {
        key: :reset_ball_memory,
        label_proc: proc { _INTL("Reset Ball Memory") },
        type: :multi,
        on_use: proc {
          if pbConfirmMessage(_INTL("Reset all ball memory data?"))
            BallMemory.clear_memory
            pbMessage(_INTL("Ball memory has been reset."))
          end
        }
      }
    ]
  end


  def self.open_menu
    ensure_defaults
    defs = settings_definitions
    main_index = 0
    begin
      loop do
        cmds = defs.map { |d| d[:label_proc].call } + [_INTL("Back")]
        win = Window_CommandPokemonEx.new(cmds)
        win.z = 99999
        win.resizeToFit(win.commands)
        screen_w = (Graphics.width rescue 480)
        win.width = screen_w - 15
        pbPositionNearMsgWindow(win, nil, :right) rescue nil
        win.index = main_index
        exit_menu = false
        loop do
          Graphics.update; Input.update; win.update
          if Input.trigger?(Input::BACK)
            pbPlayCancelSE
            exit_menu = true
            while Input.press?(Input::BACK); Graphics.update; Input.update; end
            break
          end
          if Input.trigger?(Input::USE)
            if win.index == defs.length
              pbPlayCancelSE
              exit_menu = true
              break
            else
              entry = defs[win.index]
              begin
                case entry[:type]
                when :cycle
                  entry[:on_use].call
                when :toggle
                  new_val = !get(entry[:key])
                  set(entry[:key], new_val)
                when :numeric
                  set(entry[:key], 0)
                when :multi
                  entry[:on_use].call
                end
              rescue
              end
              pbPlayDecisionSE
              main_index = win.index
              break 
            end
          elsif Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT)
            dir = Input.repeat?(Input::LEFT) ? -1 : +1
            if win.index < defs.length
              entry = defs[win.index]
              begin
                case entry[:type]
                when :cycle
                  entry[:on_cycle].call(dir)
                when :toggle
                  set(entry[:key], !get(entry[:key]))
                when :numeric
                  cur = get(entry[:key]).to_i
                  new_val = [[cur + (dir * (entry[:step] || 1)), entry[:min]].max, entry[:max]].min
                  set(entry[:key], new_val)
                when :multi
                end
              rescue
              end
              pbPlayCursorSE
              main_index = win.index
              break 
            else
              pbPlayCursorSE
            end
          elsif (old_idx = win.index; true)
          end
        end
        win.dispose if win
        break if exit_menu
        main_index = [main_index, defs.length].min
      end
    rescue
    end
  end
end

begin
  QuickThrowSettings.register_button
rescue
end

begin
  if defined?(ModSettingsMenu)
    QuickThrowSettings.try_pending
  end
rescue
end

# ---------------------------------------------------------------------------
# Ball Memory System
# ---------------------------------------------------------------------------
module BallMemory
  @memory = {}  
  @loaded = false
  
  def self.ensure_loaded
    return if @loaded
    @loaded = true
    load_memory
  end
  
  def self.remember_catch(species, ball)
    return unless species && ball
    memory_enabled = (QuickThrowSettings.get(:ball_memory) rescue true)
    return unless memory_enabled
    
    begin
      ensure_loaded
      @memory[species] ||= {}
      @memory[species][ball] ||= 0
      @memory[species][ball] += 1
      
      save_memory
    rescue => e
    end
  end
  
  def self.get_best_remembered_ball(species)
    return nil unless species
    memory_enabled = (QuickThrowSettings.get(:ball_memory) rescue true)
    return nil unless memory_enabled
    
    begin
      ensure_loaded
      species_data = @memory[species]
      return nil unless species_data && species_data.size > 0
      
      # Find ball with most successful catches
      best_ball = species_data.max_by { |ball, count| count }
      return best_ball ? best_ball[0] : nil
    rescue
      return nil
    end
  end
  
  def self.get_success_count(species, ball)
    return 0 unless species && ball
    begin
      ensure_loaded
      return @memory.dig(species, ball) || 0
    rescue
      return 0
    end
  end
  
  def self.load_memory
    begin
      file_path = RTP.getSaveFolder + "\\QuickThrow_BallMemory.dat"
      if File.exist?(file_path)
        File.open(file_path, "rb") do |f|
          @memory = Marshal.load(f)
        end
      else
        @memory = {}
      end
      @loaded = true
    rescue => e
      @memory = {}
      @loaded = true
    end
  end
  
  def self.save_memory
    begin
      file_path = RTP.getSaveFolder + "\\QuickThrow_BallMemory.dat"
      File.open(file_path, "wb") do |f|
        Marshal.dump(@memory, f)
      end
    rescue => e
    end
  end
  
  def self.clear_memory
    @memory.clear
    save_memory
  end
  
  def self.clear_species(species)
    return unless species
    @memory.delete(species)
    save_memory
  end
end

# ---------------------------------------------------------------------------
# Ball Filter System
# ---------------------------------------------------------------------------
module BallFilter
  @blacklist = []  # Array of ball IDs to never use
  
  def self.is_filtered?(ball, catch_chance = nil)
    return false unless ball
    filter_enabled = (QuickThrowSettings.get(:ball_filter_enabled) rescue false)
    return false unless filter_enabled
    
    return @blacklist.include?(ball)
  end
  
  def self.add_to_blacklist(ball)
    return unless ball
    @blacklist << ball unless @blacklist.include?(ball)
    save_blacklist
  end
  
  def self.remove_from_blacklist(ball)
    return unless ball
    @blacklist.delete(ball)
    save_blacklist
  end
  
  def self.is_blacklisted?(ball)
    @blacklist.include?(ball)
  end
  
  def self.clear_blacklist
    @blacklist.clear
    save_blacklist
  end
  
  def self.get_blacklist
    @blacklist.dup
  end
  
  def self.save_blacklist
    begin
      if defined?(ModSettingsMenu)
        ModSettingsMenu.set(:ball_filter_blacklist, @blacklist)
      end
    rescue
    end
  end
  
  def self.load_blacklist
    begin
      if defined?(ModSettingsMenu)
        saved = ModSettingsMenu.get(:ball_filter_blacklist)
        @blacklist = saved if saved.is_a?(Array)
      end
    rescue
    end
  end
  
  def self.open_blacklist_menu
    begin
      # Get all available poke balls
      available_balls = []
      GameData::Item.each do |item|
        if item.is_poke_ball?
          available_balls << item.id
        end
      end
      available_balls.sort!
      
      selected_index = 0
      loop do
        cmds = available_balls.map do |ball|
          name = (GameData::Item.get(ball).name rescue ball.to_s)
          status = is_blacklisted?(ball) ? "[X]" : "[ ]"
          "#{status} #{name}"
        end
        cmds << _INTL("Clear All")
        cmds << _INTL("Back")
        
        win = Window_CommandPokemonEx.new(cmds)
        win.z = 99999
        win.resizeToFit(win.commands)
        screen_w = (Graphics.width rescue 480)
        win.width = [screen_w - 40, 320].max
        win.x = (screen_w - win.width) / 2
        win.y = 40
        win.index = selected_index
        
        choice = -1
        loop do
          Graphics.update
          Input.update
          win.update
          
          if Input.trigger?(Input::BACK)
            pbPlayCancelSE
            choice = -1
            break
          elsif Input.trigger?(Input::USE)
            pbPlayDecisionSE
            choice = win.index
            break
          end
        end
        
        win.dispose
        
        if choice == -1 || choice == cmds.length - 1
          break
        elsif choice == cmds.length - 2
          # Clear all
          if pbConfirmMessage(_INTL("Clear all blacklisted balls?"))
            clear_blacklist
          end
          selected_index = choice
        else
          # Toggle blacklist
          ball = available_balls[choice]
          if is_blacklisted?(ball)
            remove_from_blacklist(ball)
          else
            add_to_blacklist(ball)
          end
          selected_index = choice
        end
      end
    rescue => e
    end
  end
end

# Load ball filter blacklist on startup
begin
  BallFilter.load_blacklist
rescue
end

$lastUsedPokeBall = nil

begin
  if defined?($PokemonGlobal) && $PokemonGlobal && $PokemonGlobal.respond_to?(:lastUsedPokeBall)
    $lastUsedPokeBall = $PokemonGlobal.lastUsedPokeBall if $PokemonGlobal.lastUsedPokeBall
  end
  begin
    if !$lastUsedPokeBall && defined?(ModSettingsMenu)
      saved = ModSettingsMenu.get(:quick_throw_last_ball)
      if saved && (!defined?($PokemonBag) || $PokemonBag.pbHasItem?(saved))
        $lastUsedPokeBall = saved
      end
    end
  rescue
  end
rescue
end

$lastUsedPokeBall = :POKEBALL if !$lastUsedPokeBall
begin
  if defined?($PokemonGlobal) && $PokemonGlobal
    $PokemonGlobal.lastUsedPokeBall ||= $lastUsedPokeBall
  end
  if defined?(ModSettingsMenu)
    ModSettingsMenu.set(:quick_throw_last_ball, $lastUsedPokeBall)
  end
rescue
end

begin
  # KIF fix: 6.8.2 has no onMapSceneStart; onMapSceneChange fires after loading a save and after battles
  if defined?(Events) && Events.respond_to?(:onMapSceneChange)
    Events.onMapSceneChange += proc { |sender, e|
      begin
        if defined?($PokemonGlobal) && $PokemonGlobal && $PokemonGlobal.respond_to?(:lastUsedPokeBall)
          $lastUsedPokeBall = $PokemonGlobal.lastUsedPokeBall if $PokemonGlobal.lastUsedPokeBall
        end
        $lastUsedPokeBall = :POKEBALL if !$lastUsedPokeBall
        begin
          if defined?($PokemonGlobal) && $PokemonGlobal
            $PokemonGlobal.lastUsedPokeBall ||= $lastUsedPokeBall
          end
          if defined?(ModSettingsMenu)
            ModSettingsMenu.set(:quick_throw_last_ball, $lastUsedPokeBall)
          end
        rescue
        end
      rescue
      end
    }
  end
rescue
end

BALL_ICON_MAP = {
  :POKEBALL      => File.join("Graphics","Items","POKEBALL"),
  :GREATBALL     => File.join("Graphics","Items","GREATBALL"),
  :ULTRABALL     => File.join("Graphics","Items","ULTRABALL"),
  :MASTERBALL    => File.join("Graphics","Items","MASTERBALL"),
  :PREMIERBALL   => File.join("Graphics","Items","PREMIERBALL"),
  :DIVEBALL      => File.join("Graphics","Items","DIVEBALL"),
  :TIMERBALL     => File.join("Graphics","Items","TIMERBALL"),
  :QUICKBALL     => File.join("Graphics","Items","QUICKBALL"),
  :DUSKBALL      => File.join("Graphics","Items","DUSKBALL"),
  :HEALBALL      => File.join("Graphics","Items","HEALBALL"),
  :NETBALL       => File.join("Graphics","Items","NETBALL"),
  :NESTBALL      => File.join("Graphics","Items","NESTBALL"),
  :FASTBALL      => File.join("Graphics","Items","FASTBALL"),
  :LEVELBALL     => File.join("Graphics","Items","LEVELBALL"),
  :LOVEBALL      => File.join("Graphics","Items","LOVEBALL"),
  :FRIENDBALL    => File.join("Graphics","Items","FRIENDBALL"),
  :MOONBALL      => File.join("Graphics","Items","MOONBALL"),
  :HEAVYBALL     => File.join("Graphics","Items","HEAVYBALL"),
  :LUREBALL      => File.join("Graphics","Items","LUREBALL"),
  :SPORTBALL     => File.join("Graphics","Items","SPORTBALL"),
  :SAFARIBALL    => File.join("Graphics","Items","SAFARIBALL"),
  :DREAMBALL     => File.join("Graphics","Items","DREAMBALL"),
  :BEASTBALL     => File.join("Graphics","Items","BEASTBALL"),
  :FUSIONBALL    => File.join("Graphics","Items","FUSIONBALL")
}

class PokeBattle_Scene
  unless method_defined?(:quickball_pbInitSprites)
    alias quickball_pbInitSprites pbInitSprites
  end
  
  def pbInitSprites
    quickball_pbInitSprites
    
    @sprites["quickBallIcon"] = BitmapSprite.new(64, 64, @viewport)
    @sprites["quickBallIcon"].z = 250
    @sprites["quickBallIcon"].visible = false
    
    @quickBallBitmaps = {}
    
    @quickBallIndicatorPrepared = false
    
    # Auto-select remembered ball if enabled
    begin
      auto_select = (QuickThrowSettings.get(:ball_memory_auto_select) rescue false)
      memory_enabled = (QuickThrowSettings.get(:ball_memory) rescue true)
      
      if auto_select && memory_enabled && @battle
        battler = @battle.battlers.find { |b| b && @battle.opposes?(b.index) }
        if battler && battler.pokemon
          remembered = BallMemory.get_best_remembered_ball(battler.pokemon.species)
          if remembered && $PokemonBag.pbHasItem?(remembered)
            # Check if ball is blacklisted
            filter_enabled = (QuickThrowSettings.get(:ball_filter_enabled) rescue false)
            is_blacklisted = filter_enabled && BallFilter.is_blacklisted?(remembered)
            
            unless is_blacklisted
              $lastUsedPokeBall = remembered
              if defined?($PokemonGlobal) && $PokemonGlobal
                $PokemonGlobal.lastUsedPokeBall = remembered
              end
              if defined?(ModSettingsMenu)
                ModSettingsMenu.set(:quick_throw_last_ball, remembered)
              end
            end
          end
        end
      end
    rescue
    end
  end
  
  def pbUpdateQuickBallIndicator(show = false, targetIndex = nil)
    return if !@sprites["quickBallIcon"]
    
    sprite_enabled = (QuickThrowSettings.get(:quick_throw_sprite) rescue true)
    if show && sprite_enabled && $lastUsedPokeBall && $PokemonBag.pbHasItem?($lastUsedPokeBall)
      if !@quickBallIndicatorPrepared
        opponentIndex = targetIndex
        if !opponentIndex
          opponentIndex = @battle.battlers.find { |b| b && @battle.opposes?(b.index) }&.index
        end
        return if !opponentIndex
        
        dataBox = @sprites["dataBox_#{opponentIndex}"]
        return if !dataBox
        
           iconX = 20
           iconY = 20
        
          screen_w = (Graphics.width rescue 512)
          @sprites["quickBallIcon"].x = screen_w - 64 - 4
          @sprites["quickBallIcon"].y = -18
        
        bitmap = @sprites["quickBallIcon"].bitmap
        bitmap.clear
        srcbmp = getQuickBallBitmap($lastUsedPokeBall)
        if srcbmp && srcbmp.bitmap
          src = srcbmp.bitmap
          dst_x = iconX
          dst_y = iconY
          max_w = bitmap.width - dst_x
          max_h = bitmap.height - dst_y
          w = [src.width, max_w].min
          h = [src.height, max_h].min
          src_rect = Rect.new(0, 0, w, h)
          bitmap.blt(dst_x, dst_y, src, src_rect)
        end
        
        @quickBallIndicatorPrepared = true
      end
      @sprites["quickBallIcon"].visible = true
    else
      @sprites["quickBallIcon"].visible = false
      @quickBallIndicatorPrepared = false  
    end
  end
  
  unless method_defined?(:quickball_pbEndBattle)
    alias quickball_pbEndBattle pbEndBattle
  end
  
  def pbEndBattle(_result)
    quickball_pbEndBattle(_result)
    begin
      if @quickBallBitmaps
        @quickBallBitmaps.values.each { |bmp| bmp&.dispose }
        @quickBallBitmaps.clear
      end
    rescue
    end
  end

  def getQuickBallBitmap(item_id)
    return nil if !item_id
    begin
      return @quickBallBitmaps[item_id] if @quickBallBitmaps[item_id]
      item = GameData::Item.get(item_id) rescue nil
      path = BALL_ICON_MAP[item&.id] || BALL_ICON_MAP[item_id]
      if !path && item
        sym = item.id.to_s
        candidates = [
          File.join("Graphics","Items", sym),
          File.join("Graphics","Items", sym.downcase),
          File.join("Graphics","Items", sym.upcase)
        ]
        candidates.each do |c|
          begin
            if (pbResolveBitmap(c) rescue nil)
              path = c
              break
            end
          rescue
          end
        end
      end
      path ||= File.join("Graphics", "Misc", "icon_ball_00")
      bmp = AnimatedBitmap.new(path) rescue nil
      @quickBallBitmaps[item_id] = bmp
      return bmp
    rescue
      return nil
    end
  end

  def pbEstimateCatchChance(ball, targetIndex = nil)
    begin
      return nil if !ball || !@battle
      
      if targetIndex
        battler = @battle.battlers[targetIndex]
      else
        battler = @battle.battlers.find { |b| b && @battle.opposes?(b.index) }
      end
      return nil if !battler || !battler.pokemon
      
      pkmn = battler.pokemon
      
      catch_rate = (pkmn.species_data.catch_rate rescue 45).to_f
      
      ultraBeast = [:NIHILEGO, :BUZZWOLE, :PHEROMOSA, :XURKITREE, :CELESTEELA,
                    :KARTANA, :GUZZLORD, :POIPOLE, :NAGANADEL, :STAKATAKA,
                    :BLACEPHALON].include?(pkmn.species)
      
      if !ultraBeast || ball == :BEASTBALL
        case ball
        when :MASTERBALL
          catch_rate = 255.0
        when :ULTRABALL
          catch_rate *= 2.0
        when :GREATBALL
          catch_rate *= 1.5
        when :SAFARIBALL
          catch_rate *= 1.5
        when :SPORTBALL
          catch_rate *= 1.5
        when :NETBALL
          multiplier = 3.5
          catch_rate *= multiplier if battler.pbHasType?(:BUG) || battler.pbHasType?(:WATER)
        when :DIVEBALL
          catch_rate *= 3.5 if @battle.environment == :Underwater
        when :NESTBALL
          if battler.level <= 30
            catch_rate *= [((41 - battler.level) / 10.0), 1].max
          end
        when :REPEATBALL
          multiplier = 3.5
          catch_rate *= multiplier if @battle.pbPlayer.owned?(battler.species)
        when :TIMERBALL
          multiplier = [1 + (0.3 * @battle.turnCount), 4].min
          catch_rate *= multiplier
        when :QUICKBALL
          catch_rate *= 5.0 if @battle.turnCount == 0
        when :DUSKBALL
          multiplier = 3.0
          catch_rate *= multiplier if @battle.time == 2
        when :FASTBALL
          begin
            baseStats = battler.pokemon.baseStats
            if baseStats
              baseSpeed = baseStats[:SPEED]
              catch_rate *= 4 if baseSpeed >= 100
              catch_rate = [catch_rate, 255].min
            end
          rescue
          end
        when :LEVELBALL
          maxlevel = 0
          @battle.eachSameSideBattler do |b|
            maxlevel = b.level if b.level > maxlevel
          end
          if maxlevel >= battler.level * 4
            catch_rate *= 8
          elsif maxlevel >= battler.level * 2
            catch_rate *= 4
          elsif maxlevel > battler.level
            catch_rate *= 2
          end
          catch_rate = [catch_rate, 255].min
        when :LUREBALL
          multiplier = 5
          begin
            if defined?($PokemonTemp) && $PokemonTemp && defined?(GameData::EncounterType)
              catch_rate *= multiplier if GameData::EncounterType.get($PokemonTemp.encounterType).type == :fishing
            end
          rescue
          end
          catch_rate = [catch_rate, 255].min
        when :HEAVYBALL
          if catch_rate > 0
            weight = (battler.pbWeight rescue 0)
            if weight >= 3000
              catch_rate += 30
            elsif weight >= 2000
              catch_rate += 20
            elsif weight < 1000
              catch_rate -= 20
            end
            catch_rate = [catch_rate, 1].max
            catch_rate = [catch_rate, 255].min
          end
        when :LOVEBALL
          @battle.eachSameSideBattler do |b|
            if b.species == battler.species && b.gender != battler.gender && b.gender != 2 && battler.gender != 2
              catch_rate *= 8
              break
            end
          end
          catch_rate = [catch_rate, 255].min
        when :MOONBALL
          begin
            moon_stone = GameData::Item.try_get(:MOONSTONE)
            if moon_stone && battler.pokemon.species_data.family_item_evolutions_use_item?(moon_stone.id)
              catch_rate *= 4
            end
          rescue
          end
          catch_rate = [catch_rate, 255].min
        when :DREAMBALL
          catch_rate *= 4 if battler.status == :SLEEP
        when :BEASTBALL
          if ultraBeast
            catch_rate *= 5.0
          else
            catch_rate /= 10.0
          end
        when :TRADEBALL
          catch_rate *= 0.8
        when :ABILITYBALL
          catch_rate *= 0.6
        when :VIRUSBALL
          catch_rate *= 0.4
        when :SHINYBALL
          catch_rate *= 0.2
        when :PERFECTBALL
          catch_rate *= 0.1
        when :TOXICBALL, :SCORCHBALL, :FROSTBALL, :SPARKBALL
        when :PUREBALL
          catch_rate *= 3.5 if battler.status == :NONE || battler.status == 0
        when :STATUSBALL
          catch_rate *= 2.5 if battler.status != :NONE && battler.status != 0
        when :FUSIONBALL
          begin
            if defined?(Settings) && Settings.const_defined?(:NB_POKEMON)
              species_id_number = (GameData::Species.get(battler.species).id_number rescue 0)
              catch_rate *= 3 if species_id_number > Settings::NB_POKEMON
            end
          rescue
          end
        when :CANDYBALL
          catch_rate *= 0.8
        when :FIRECRACKER
          catch_rate = 0
        end
      else
        catch_rate /= 10.0
      end
      
      hp_max = battler.totalhp.to_f
      hp_cur = battler.hp.to_f
      x = ((3.0 * hp_max - 2.0 * hp_cur) * catch_rate) / (3.0 * hp_max)
      
      if battler.status == :SLEEP || battler.status == :FROZEN
        x *= 2.5
      elsif battler.status != :NONE
        x *= 1.5
      end
      
      x = x.floor
      x = 1 if x < 1
      
      return 1.0 if x >= 255 || BallHandlers.isUnconditional?(ball, @battle, battler)
      
      y = (65536.0 / ((255.0 / x) ** 0.1875)).floor
      
      shake_prob = y / 65536.0
      
      base_catch_chance = shake_prob ** 4
      
      crit_catch_chance = 0.0
      if defined?(Settings) && Settings.const_defined?(:ENABLE_CRITICAL_CAPTURES) && Settings::ENABLE_CRITICAL_CAPTURES
        c = 0
        numOwned = ($Trainer.pokedex.owned_count rescue 0)
        if numOwned > 600
          c = x * 5.0 / 12.0
        elsif numOwned > 450
          c = x * 4.0 / 12.0
        elsif numOwned > 300
          c = x * 3.0 / 12.0
        else
          c = x * 2.0 / 12.0
        end
        
        crit_catch_chance = [c / 256.0, 0].max if c > 0
      end
      
      total_chance = crit_catch_chance + (1.0 - crit_catch_chance) * base_catch_chance
      
      return [[total_chance, 0.0].max, 1.0].min
    rescue
      return nil
    end
  end
  
  def pbSuggestBestBall(targetIndex = nil)
    begin
      return nil if !@battle || !$PokemonBag
      
      if targetIndex
        battler = @battle.battlers[targetIndex]
      else
        battler = @battle.battlers.find { |b| b && @battle.opposes?(b.index) }
      end
      return nil if !battler || !battler.pokemon
      
      pkmn = battler.pokemon
      
      # Check ball memory first
      memory_enabled = (QuickThrowSettings.get(:ball_memory) rescue true)
      if memory_enabled
        remembered_ball = BallMemory.get_best_remembered_ball(pkmn.species)
        if remembered_ball && $PokemonBag.pbHasItem?(remembered_ball)
          success_count = BallMemory.get_success_count(pkmn.species, remembered_ball)
          if success_count >= 3
            return remembered_ball
          end
        end
      end
      
      best_ball = nil
      best_score = -1.0
      
      GameData::Item.each do |item|
        next if !item.is_poke_ball?
        qty = $PokemonBag.pbQuantity(item.id) rescue 0
        next if qty <= 0
        
        # Check if ball is filtered
        catch_chance = pbEstimateCatchChance(item.id, targetIndex) rescue 0.0
        next if !catch_chance
        
        filter_enabled = (QuickThrowSettings.get(:ball_filter_enabled) rescue false)
        if filter_enabled && BallFilter.is_filtered?(item.id, catch_chance)
          next  # Skip filtered balls
        end
        
        score = 0.0
        score = catch_chance
        
        turn = @battle.turnCount rescue 0
        
        # Turn-aware suggestions with stronger bonuses
        if item.id == :QUICKBALL
          if turn == 0
            score += 0.8  
          elsif turn == 1
            score += 0.3  
          else
            score -= 0.2  
          end
        end
        
        if item.id == :TIMERBALL
          if turn >= 10
            score += 0.5  
          elsif turn >= 5
            score += 0.2  
          end
        end
        
        if item.id == :DUSKBALL && @battle.time == 2
          score += 0.3
        end
        
        # Status-based suggestions
        current_status = battler.status rescue :NONE
        
        # Dream Ball gets huge bonus for sleeping targets
        if item.id == :DREAMBALL && current_status == :SLEEP
          score += 0.6  # Strong bonus (4x catch rate)
        end
        
        # Heavy sleep/freeze status - any ball benefits greatly
        if current_status == :SLEEP || current_status == :FROZEN
          score += 0.3  # Bonus for 2.5x status multiplier
        end
        
        # Light status (burn, paralyze, poison) - moderate bonus
        if current_status != :NONE && current_status != :SLEEP && current_status != :FROZEN
          score += 0.15  # Bonus for 1.5x status multiplier
        end
        
        # Pure Ball prefers healthy targets
        if item.id == :PUREBALL
          if current_status == :NONE || current_status == 0
            score += 0.4  # Bonus for no status
          else
            score -= 0.3  # Penalty if target has status
          end
        end
        
        # Status Ball prefers statused targets
        if item.id == :STATUSBALL
          if current_status != :NONE && current_status != 0
            score += 0.4  # Bonus for any status
          else
            score -= 0.3  # Penalty if no status
          end
        end
        
        if item.id == :NETBALL && (battler.pbHasType?(:BUG) || battler.pbHasType?(:WATER))
          score += 0.3
        end
        
        if item.id == :NESTBALL && battler.level <= 20
          score += 0.3
        end
        
        if item.id == :REPEATBALL && @battle.pbPlayer.owned?(battler.species)
          score += 0.3
        end
        
        if item.id == :DIVEBALL && @battle.environment == :Underwater
          score += 0.3
        end
        
        ultraBeast = [:NIHILEGO, :BUZZWOLE, :PHEROMOSA, :XURKITREE, :CELESTEELA,
                      :KARTANA, :GUZZLORD, :POIPOLE, :NAGANADEL, :STAKATAKA,
                      :BLACEPHALON].include?(pkmn.species)
        
        if ultraBeast
          if item.id == :BEASTBALL
            score += 1.0  
          else
            score -= 0.5  
          end
        elsif item.id == :BEASTBALL
          score -= 0.8  
        end
        
        if catch_chance > 0.7
          if [:MASTERBALL, :BEASTBALL, :DREAMBALL].include?(item.id)
            score -= 0.2
          end
        end
        
        if item.id == :MASTERBALL
          if catch_chance < 0.3
            score = 999.0  
          else
            score = 0.0  
          end
        end
        
        if score > best_score
          best_score = score
          best_ball = item.id
        end
      end
      
      return best_ball
    rescue
      return nil
    end
  end
end

class PokeBattle_Battle
  unless method_defined?(:quickball_pbRegisterItem)
    alias quickball_pbRegisterItem pbRegisterItem
  end
  
  def pbRegisterItem(idxBattler, item, idxTarget=nil, idxMove=nil)
    # Recursion guard to prevent infinite loops in multiplayer
    if @_quickthrow_registering
      return quickball_pbRegisterItem(idxBattler, item, idxTarget, idxMove)
    end
    
    begin
      @_quickthrow_registering = true
      
      if item && GameData::Item.get(item).is_poke_ball?
        $lastUsedPokeBall = item
        begin
          if defined?($PokemonGlobal) && $PokemonGlobal
            $PokemonGlobal.lastUsedPokeBall = item
          end
          if defined?(ModSettingsMenu)
            ModSettingsMenu.set(:quick_throw_last_ball, item)
          end
        rescue
        end
        
        # Store ball and target for memory tracking
        @_quickthrow_pending_ball = item
        @_quickthrow_pending_target = idxTarget
      end
      
      return quickball_pbRegisterItem(idxBattler, item, idxTarget, idxMove)
    ensure
      @_quickthrow_registering = false
    end
  end
  
  # Add guard for pbThrowPokeBall to prevent multiplayer alias chain recursion
  unless method_defined?(:quickball_pbThrowPokeBall)
    alias quickball_pbThrowPokeBall pbThrowPokeBall
  end
  
  def pbThrowPokeBall(idxBattler, ball, catch_rate=nil, showPlayer=false)
    # Recursion guard to prevent infinite loops with multiplayer scripts
    if @_quickthrow_throwing
      return quickball_pbThrowPokeBall(idxBattler, ball, catch_rate, showPlayer)
    end
    
    begin
      @_quickthrow_throwing = true
      
      # Track caught Pokemon count before throw for memory
      caught_before = @caughtPokemon ? @caughtPokemon.length : 0
      
      result = quickball_pbThrowPokeBall(idxBattler, ball, catch_rate, showPlayer)
      
      # Check if Pokemon was caught successfully
      caught_after = @caughtPokemon ? @caughtPokemon.length : 0
      if caught_after > caught_before && @caughtPokemon && @caughtPokemon.length > 0
        caught_pkmn = @caughtPokemon.last
        if caught_pkmn && ball
          # Remember this successful catch
          BallMemory.remember_catch(caught_pkmn.species, ball)
        end
      end
      
      return result
    ensure
      @_quickthrow_throwing = false
    end
  end
end

module QuickThrowPatch
  def pbHandleQuickThrowInput
    ball_rotated = false
    if Input.press?(Input::A)
      begin
        rotation_enabled = (QuickThrowSettings.get(:ball_rotation) rescue true)
        
        if rotation_enabled
          balls = []
          GameData::Item.each do |item|
            next if !item.is_poke_ball?
            begin
              if $PokemonBag.pbQuantity(item.id) > 0
                # Check if ball is filtered
                filter_enabled = (QuickThrowSettings.get(:ball_filter_enabled) rescue false)
                if filter_enabled && BallFilter.is_blacklisted?(item.id)
                  next  # Skip blacklisted balls
                end
                balls << item.id
              end
            rescue
            end
          end
          if balls.length > 0
            @quickBallCycleIndex ||= (balls.index($lastUsedPokeBall) || 0)
            dir = 0
            dir = -1 if Input.repeat?(Input::LEFT)
            dir = +1 if Input.repeat?(Input::RIGHT)
            if dir != 0
              @quickBallCycleIndex = (@quickBallCycleIndex + dir) % balls.length
              new_ball = balls[@quickBallCycleIndex]
              if new_ball && new_ball != $lastUsedPokeBall
                $lastUsedPokeBall = new_ball
                begin
                  if defined?($PokemonGlobal) && $PokemonGlobal
                    $PokemonGlobal.lastUsedPokeBall = new_ball
                  end
                  if defined?(ModSettingsMenu)
                    ModSettingsMenu.set(:quick_throw_last_ball, new_ball)
                  end
                rescue
                end
                pbPlayCursorSE rescue nil
                @quickBallIndicatorPrepared = false
                pbUpdateQuickBallIndicator(true)
              end
              ball_rotated = true
            end
          end
        end
      rescue
      end
    else
      @quickBallCycleIndex = nil
    end
    
    if Input.press?(Input::A) && Input.trigger?(Input::UP)
      begin
        info_enabled = (QuickThrowSettings.get(:ball_info_screen) rescue true)
        if info_enabled
          pbPlayDecisionSE rescue nil
          
          # Get all opposing battlers
          opposing_battlers = []
          @battle.battlers.each_with_index do |b, idx|
            if b && @battle.opposes?(b.index) && !b.fainted?
              opposing_battlers << idx
            end
          end
          
          return if opposing_battlers.empty?
          
          # For multi-battles, let user choose target first with a simple menu
          target_idx = nil
          if opposing_battlers.length > 1
            begin
              # Create menu of opponent names
              choices = []
              opposing_battlers.each do |idx|
                battler = @battle.battlers[idx]
                if battler
                  name = battler.pbThis rescue "Target #{idx}"
                  choices << name
                end
              end
              choices << _INTL("Cancel")
              
              # Create command window
              cmdwin = Window_CommandPokemonEx.new(choices)
              cmdwin.z = 99999
              cmdwin.visible = true
              pbBottomRight(cmdwin)
              
              cmd = -1
              loop do
                Graphics.update
                Input.update
                cmdwin.update
                
                if Input.trigger?(Input::USE)
                  cmd = cmdwin.index
                  pbPlayDecisionSE
                  break
                elsif Input.trigger?(Input::BACK)
                  cmd = choices.length - 1  # Cancel
                  pbPlayCancelSE
                  break
                end
              end
              
              cmdwin.dispose
              
              if cmd >= 0 && cmd < opposing_battlers.length
                target_idx = opposing_battlers[cmd]
              else
                return  # Cancelled
              end
            rescue => e
              # Error occurred, default to first opponent
              target_idx = opposing_battlers[0]
            end
          else
            target_idx = opposing_battlers[0]
          end
          
          battler = @battle.battlers[target_idx]
          return if !battler
          
          # Get turn info
          turn = (@battle.turnCount rescue 0)
          turn_txt = _INTL("Turn: {1}", turn + 1)  # Display as 1-based
          
          # Get target name (for multi-battles)
          target_name = ""
          begin
            if opposing_battlers.length > 1
              target_name = battler.pbThis rescue "Target"
              target_name = " (#{target_name})"
            end
          rescue
          end
          
          # Get status info
          status_txt = ""
          begin
            current_status = battler.status rescue :NONE
            status_name = case current_status
            when :SLEEP then "Asleep"
            when :POISON then "Poisoned"
            when :BURN then "Burned"
            when :PARALYSIS then "Paralyzed"
            when :FROZEN then "Frozen"
            else "Healthy"
            end
            status_txt = _INTL("Status: {1}{2}", status_name, target_name)
          rescue
          end
          
          ball_name = $lastUsedPokeBall ? (GameData::Item.get($lastUsedPokeBall).name rescue "Unknown") : "None"
          qty = ($PokemonBag.pbQuantity($lastUsedPokeBall) rescue 0)
          chance = (self.pbEstimateCatchChance($lastUsedPokeBall, target_idx) rescue nil)
          chance_txt = chance ? sprintf("Catch Rate: %d%%", (chance * 100).round) : _INTL("Catch Rate: N/A")
          qty_txt = _INTL("Ball Quantity: {1}", qty)
          
          suggested_ball = self.pbSuggestBestBall(target_idx) rescue nil
          suggested_txt = if suggested_ball
            suggested_name = (GameData::Item.get(suggested_ball).name rescue "Unknown")
            suggested_qty = ($PokemonBag.pbQuantity(suggested_ball) rescue 0)
            suggested_chance = (self.pbEstimateCatchChance(suggested_ball, target_idx) rescue nil)
            if suggested_chance
              _INTL("Suggested Ball: {1} ({2}%, x{3})", suggested_name, (suggested_chance * 100).round, suggested_qty)
            else
              _INTL("Suggested Ball: {1} (x{2})", suggested_name, suggested_qty)
            end
          else
            _INTL("Suggested Ball: None")
          end
          
          # Add ball memory info
          memory_txt = ""
          begin
            memory_enabled = (QuickThrowSettings.get(:ball_memory) rescue true)
            if memory_enabled && battler && battler.pokemon
              remembered = BallMemory.get_best_remembered_ball(battler.pokemon.species)
              if remembered
                count = BallMemory.get_success_count(battler.pokemon.species, remembered)
                mem_name = (GameData::Item.get(remembered).name rescue "Unknown")
                memory_txt = _INTL("Remembered: {1} (x{2})", mem_name, count)
              else
                memory_txt = _INTL("Remembered: None")
              end
            end
          rescue
          end
          
          cmds = [turn_txt]
          cmds << status_txt if status_txt != ""
          cmds += [ball_name, chance_txt, qty_txt, suggested_txt]
          cmds << memory_txt if memory_txt != ""
          
          # Check if ball filter is enabled
          filter_enabled = (QuickThrowSettings.get(:ball_filter_enabled) rescue false)
          
          # Add turn-aware recommendations
          if turn == 0 && $PokemonBag.pbHasItem?(:QUICKBALL)
            is_blacklisted = filter_enabled && BallFilter.is_blacklisted?(:QUICKBALL)
            unless is_blacklisted
              cmds << _INTL("Tip: Quick Ball is 5x effective now!")
            end
          elsif turn >= 9 && $PokemonBag.pbHasItem?(:TIMERBALL)
            is_blacklisted = filter_enabled && BallFilter.is_blacklisted?(:TIMERBALL)
            unless is_blacklisted
              cmds << _INTL("Tip: Timer Ball getting stronger!")
            end
          end
          
          # Add status-aware recommendations
          begin
            current_status = battler.status rescue :NONE
            if (current_status == :SLEEP || current_status == :FROZEN)
              cmds << _INTL("Tip: Target has strong status! (+2.5x catch)")
              if current_status == :SLEEP && $PokemonBag.pbHasItem?(:DREAMBALL)
                is_blacklisted = filter_enabled && BallFilter.is_blacklisted?(:DREAMBALL)
                unless is_blacklisted
                  cmds << _INTL("Tip: Dream Ball is 4x effective!")
                end
              end
            elsif current_status != :NONE && current_status != 0
              cmds << _INTL("Tip: Target is statused! (+1.5x catch)")
            end
          rescue
          end
          
          win = Window_CommandPokemonEx.new(cmds)
          win.z = 99999
          win.resizeToFit(win.commands)
          screen_w = (Graphics.width rescue 480)
          win.width = [screen_w - 40, 320].max  
          pbPositionNearMsgWindow(win, nil, :right) rescue nil
          win.index = -1  
          win.active = false  
          loop do
            Graphics.update
            Input.update
            win.update
            if Input.trigger?(Input::BACK) || Input.trigger?(Input::USE) || Input.trigger?(Input::ACTION)
              pbPlayCancelSE rescue nil
              break
            end
          end
          win.dispose if win
          return true  
        end
      rescue
      end
    end
    
    return ball_rotated  
  end
  
  def pbCommandMenuEx(idxBattler, texts, mode=0)
    quick_throw_mode = (QuickThrowSettings.get(:quick_throw_mode) rescue 1).to_i
    
    if quick_throw_mode == 0
      begin
        pbUpdateQuickBallIndicator(true)
      rescue
      end
      return super
    end
    @quickthrow_cmd = true   # KIF fix: ACTION is shared with KIF's Battle Info (see pbUpdate below)

    if quick_throw_mode == 2
      begin
        pbUpdateQuickBallIndicator(true)
      rescue
      end
      pbShowWindow(PokeBattle_Scene::COMMAND_BOX)
      cw = @sprites["commandWindow"]
      cw.setTexts(texts)
      cw.setIndexAndMode(@lastCmd[idxBattler], mode)
      pbSelectBattler(idxBattler)
      
      ret = -1
      loop do
        oldIndex = cw.index
        pbUpdate(cw)
        
        next if pbHandleQuickThrowInput
        
        if Input.trigger?(Input::AUX2)
          battle_menu_enabled = false
          begin
            if defined?(ModSettingsMenu)
              setting = ModSettingsMenu.get(:battle_command_menu)
              battle_menu_enabled = (setting == 1 || setting == true)
            end
          rescue
          end
          
          if battle_menu_enabled
            pbPlayDecisionSE
            begin
              menu_result = pbOpenBattleCommandMenu(idxBattler) if respond_to?(:pbOpenBattleCommandMenu)
              if menu_result == :quick_throw_used
                pbUpdateQuickBallIndicator(false)
                ret = -11  
                break
              end
              next
            rescue => e
              pbPrintException(e) if $DEBUG
              next
            end
          end
        end
        
        if Input.trigger?(Input::LEFT)
          cw.index -= 1 if (cw.index&1)==1
        elsif Input.trigger?(Input::RIGHT)
          cw.index += 1 if (cw.index&1)==0
        elsif Input.trigger?(Input::UP)
          cw.index -= 2 if (cw.index&2)==2
        elsif Input.trigger?(Input::DOWN)
          cw.index += 2 if (cw.index&2)==0
        end
        pbPlayCursorSE if cw.index!=oldIndex
        if Input.trigger?(Input::USE)
          pbPlayDecisionSE
          pbUpdateQuickBallIndicator(false)
          ret = cw.index
          @lastCmd[idxBattler] = ret
          break
        elsif Input.trigger?(Input::BACK) && mode==1
          pbPlayCancelSE
          pbUpdateQuickBallIndicator(false)
          break
        elsif Input.trigger?(Input::F9) && $DEBUG
          pbPlayDecisionSE
          pbUpdateQuickBallIndicator(false)
          ret = -2
          break
        end
      end
      return ret
    end
    
    pbShowWindow(PokeBattle_Scene::COMMAND_BOX)
    cw = @sprites["commandWindow"]
    cw.setTexts(texts)
    cw.setIndexAndMode(@lastCmd[idxBattler], mode)
    pbSelectBattler(idxBattler)
    
    pbUpdateQuickBallIndicator(true)
    
    ret = -1
    loop do
      oldIndex = cw.index
      pbUpdate(cw)
      
      next if pbHandleQuickThrowInput
      
      if Input.trigger?(Input::AUX2)
        battle_menu_enabled = false
        begin
          if defined?(ModSettingsMenu)
            setting = ModSettingsMenu.get(:battle_command_menu)
            battle_menu_enabled = (setting == 1 || setting == true)
          end
        rescue
        end
        
        if battle_menu_enabled
          pbPlayDecisionSE
          begin
            menu_result = pbOpenBattleCommandMenu(idxBattler) if respond_to?(:pbOpenBattleCommandMenu)
            if menu_result == :quick_throw_used
              pbUpdateQuickBallIndicator(false)
              ret = -10
              break
            end
            next
          rescue => e
            pbPrintException(e) if $DEBUG
            next
          end
        end
      end
      
      if Input.trigger?(Input::SPECIAL)
        if pbCanUseQuickPokeBall?(idxBattler)
          pbPlayDecisionSE
          pbUpdateQuickBallIndicator(false)  
          ret = -10   
          break
        else
          20.times do
            Graphics.update
            Input.update
          end
        end
        next  
      end
      
      if Input.trigger?(Input::LEFT)
        cw.index -= 1 if (cw.index&1)==1 && !Input.press?(Input::A)
      elsif Input.trigger?(Input::RIGHT)
        cw.index += 1 if (cw.index&1)==0 && !Input.press?(Input::A)
      elsif Input.trigger?(Input::UP)
        cw.index -= 2 if (cw.index&2)==2 && !Input.press?(Input::A)
      elsif Input.trigger?(Input::DOWN)
        cw.index += 2 if (cw.index&2)==0 && !Input.press?(Input::A)
      end
      pbPlayCursorSE if cw.index!=oldIndex
      if Input.trigger?(Input::USE)                 
        pbPlayDecisionSE
        pbUpdateQuickBallIndicator(false)  
        ret = cw.index
        @lastCmd[idxBattler] = ret
        break
      elsif Input.trigger?(Input::BACK) && mode==1   
        pbPlayCancelSE
        pbUpdateQuickBallIndicator(false)  
        break
      elsif Input.trigger?(Input::F9) && $DEBUG
        pbPlayDecisionSE
        ret = -2
        break
      end
    end

    return ret
  ensure
    @quickthrow_cmd = false   # KIF fix
    @quickthrow_action_held = false
    @quickthrow_action_combo = false
  end

  # KIF fix: in the command menu KIF opens Battle Info when ACTION is pressed,
  # and Quick Throw uses ACTION held + Left/Right (pick a ball) or + Up (ball
  # info). So both work, Battle Info waits while ACTION is held and opens when
  # it is let go, unless a Quick Throw combo was used during that hold.
  def pbUpdate(*args)
    return super unless @quickthrow_cmd && @kif_bi_command && defined?(KIF::BattleInfo)
    @kif_bi_command = false
    begin
      ret = super
    ensure
      @kif_bi_command = true
    end
    if Input.press?(Input::ACTION)
      @quickthrow_action_held = true
      @quickthrow_action_combo = true if Input.press?(Input::LEFT) || Input.press?(Input::RIGHT) || Input.press?(Input::UP)
    elsif @quickthrow_action_held
      combo = @quickthrow_action_combo
      @quickthrow_action_held = false
      @quickthrow_action_combo = false
      quickthrow_open_battle_info unless combo
    end
    return ret
  end

  def quickthrow_open_battle_info
    return unless KIF::BattleInfo.on? && defined?(KifBattleInfoScreen)
    pbPlayDecisionSE
    @kif_bi_command = false
    begin
      KifBattleInfoScreen.new(@battle).run
    rescue StandardError => e
      KIF.log("Battle Info failed (#{e.class}: #{e.message})") if defined?(KIF.log)
    ensure
      @kif_bi_command = true
    end
    Input.update
  end
end

class PokeBattle_Scene
  prepend QuickThrowPatch
  
  def pbCanUseQuickPokeBall?(idxBattler)
    if !$lastUsedPokeBall
      @battle.pbDisplay(_INTL("You haven't used a Poké Ball yet!"))
      return false
    end
    
    if !$PokemonBag.pbHasItem?($lastUsedPokeBall)
      pbPlayBuzzerSE rescue nil
      if $PokemonBag.pbHasItem?(:POKEBALL)
        show_message = (QuickThrowSettings.get(:no_balls_message) rescue true)
        if show_message
          begin
            itemName = GameData::Item.get($lastUsedPokeBall).name
            message = _INTL("Out of {1}s! Defaulting to Poké Balls.",itemName)
            
            cmds = [message]
            win = Window_CommandPokemonEx.new(cmds)
            win.z = 99999
            win.resizeToFit(win.commands)
            win.width = [win.width, 300].max
            win.x = (Graphics.width - win.width) / 2
            win.y = (Graphics.height - win.height) / 2
            win.index = -1
            win.active = false
            
            60.times do
              Graphics.update
              Input.update
              win.update
            end
            
            win.dispose
          rescue
          end
        end
        
        $lastUsedPokeBall = :POKEBALL
        begin
          if defined?($PokemonGlobal) && $PokemonGlobal
            $PokemonGlobal.lastUsedPokeBall = :POKEBALL
          end
          if defined?(ModSettingsMenu)
            ModSettingsMenu.set(:quick_throw_last_ball, :POKEBALL)
          end
        rescue
        end
        @quickBallIndicatorPrepared = false
        pbUpdateQuickBallIndicator(true)
        return false
      else
        show_message = (QuickThrowSettings.get(:no_balls_message) rescue true)
        if show_message
          begin
            message = _INTL("You don't have any Poké Balls left!")
            
            cmds = [message]
            win = Window_CommandPokemonEx.new(cmds)
            win.z = 99999
            win.resizeToFit(win.commands)
            win.width = [win.width, 300].max
            win.x = (Graphics.width - win.width) / 2
            win.y = (Graphics.height - win.height) / 2
            win.index = -1
            win.active = false
            
            60.times do
              Graphics.update
              Input.update
              win.update
            end
            
            win.dispose
          rescue
            itemName = GameData::Item.get($lastUsedPokeBall).name
            @battle.pbDisplay(_INTL("You don't have any {1}s left!",itemName))
          end
        end
        return false
      end
    end
    
    begin
      if @battle.is_a?(PokeBattle_SafariZone)
        if $lastUsedPokeBall != :SAFARIBALL
          @battle.pbDisplay(_INTL("You can only use Safari Balls here!"))
          return false
        end
      end
    rescue
    end
    
    if @battle.respond_to?(:internalBattle) && !@battle.internalBattle
      @battle.pbDisplay(_INTL("Items can't be used here."))
      return false
    end
    
    return true
  end
end

# KIF fix: EBDX battles (KIF's default look) show the command menu with
# pbCommandMenuEBDX and never call pbCommandMenuEx, so none of the Quick Throw
# keys worked there. The same keys are read here, once per frame of its menu.
if defined?(PokeBattle_SceneEBDX)
  module QuickThrowEBDXPatch
    def pbCommandMenuEBDX(idxBattler, firstAction)
      quick_throw_mode = (QuickThrowSettings.get(:quick_throw_mode) rescue 1).to_i
      return super if quick_throw_mode == 0
      @quickthrow_cmd = true
      @quickthrow_ebdx_idx = idxBattler
      @quickthrow_ebdx_mode = quick_throw_mode
      ret = catch(:quickthrow_ebdx) { super }
      if ret == -10
        @commandWindow.hidePlay if @commandWindow.respond_to?(:hidePlay)
      end
      return ret
    ensure
      @quickthrow_cmd = false
      @quickthrow_action_held = false
      @quickthrow_action_combo = false
    end

    def pbUpdate(*args)
      return super unless @quickthrow_cmd
      bi = @kif_bi_command && defined?(KIF::BattleInfo)
      @kif_bi_command = false if bi
      begin
        ret = super
      ensure
        @kif_bi_command = true if bi
      end
      if Input.press?(Input::ACTION)
        @quickthrow_action_held = true
        @quickthrow_action_combo = true if Input.press?(Input::LEFT) || Input.press?(Input::RIGHT) || Input.press?(Input::UP)
      elsif @quickthrow_action_held
        combo = @quickthrow_action_combo
        @quickthrow_action_held = false
        @quickthrow_action_combo = false
        quickthrow_open_battle_info if bi && !combo
      end
      if @quickthrow_ebdx_mode == 1 && Input.trigger?(Input::SPECIAL)
        if pbCanUseQuickPokeBall?(@quickthrow_ebdx_idx)
          pbPlayDecisionSE
          throw :quickthrow_ebdx, -10
        end
        20.times do
          Graphics.update
          Input.update
        end
        return ret
      end
      if Input.press?(Input::ACTION)
        pbHandleQuickThrowInput
        # while ACTION is held the arrows belong to Quick Throw, not the EBDX cursor
        Input.update if Input.trigger?(Input::LEFT) || Input.trigger?(Input::RIGHT) ||
                        Input.trigger?(Input::UP) || Input.trigger?(Input::DOWN)
      else
        @quickBallCycleIndex = nil
      end
      return ret
    end
  end

  class PokeBattle_SceneEBDX
    prepend QuickThrowEBDXPatch
  end
end

class PokeBattle_Battle
  unless method_defined?(:quickball_pbCommandMenu)
    alias quickball_pbCommandMenu pbCommandMenu
  end
  
  def pbCommandMenu(idxBattler, firstAction)
    ret = quickball_pbCommandMenu(idxBattler, firstAction)
    
    if ret == -10
      if pbQuickPokeBall(idxBattler, firstAction)
        return -10
      else
        return -1  
      end
    elsif ret == -11
      return -10
    end
    
    return ret
  end

  def pbQuickPokeBall(idxBattler, firstAction)
    ball = $lastUsedPokeBall
    
    if !ball || !$PokemonBag.pbHasItem?(ball)
      no_balls_msg = (QuickThrowSettings.get(:no_balls_message) rescue true)
      if no_balls_msg
        if ball
          itemName = GameData::Item.get(ball).name rescue "Poké Ball"
          @scene.pbDisplay(_INTL("You don't have any {1}s left!", itemName))
        else
          @scene.pbDisplay(_INTL("You haven't selected a Poké Ball yet!"))
        end
      end
      return false
    end
    
    battler = @battlers[idxBattler]
    pkmn = battler.pokemon
    
    # Check if this is a doubles/multi battle with multiple opponents
    opposing_battlers = []
    @battlers.each_with_index do |b, idx|
      if b && opposes?(idxBattler, idx) && !b.fainted?
        opposing_battlers << idx
      end
    end
    
    idxTarget = nil
    
    # If multiple opponents, use the game's native target selection
    if opposing_battlers.length > 1
      target_select_enabled = (QuickThrowSettings.get(:doubles_target_select) rescue true)
      if target_select_enabled
        # Use custom target selection that supports info screen
        idxTarget = pbQuickThrowChooseTarget(idxBattler, opposing_battlers)
        return false if idxTarget.nil? || idxTarget < 0  # Player cancelled
      else
        # Default to first opponent
        idxTarget = opposing_battlers[0]
      end
    elsif opposing_battlers.length == 1
      idxTarget = opposing_battlers[0]
    else
      # No valid targets
      @scene.pbDisplay(_INTL("There are no valid targets!"))
      return false
    end
    
    if pbRegisterItem(idxBattler, ball, idxTarget, nil)
      return true
    end
    
    return false
  end
  
  def pbQuickThrowChooseTarget(idxBattler, opposing_battlers)
    # Set the first opponent as default for info screen
    self.selected_target_for_info = opposing_battlers[0]
    
    # Use the game's built-in target selection  
    target_data = GameData::Target.get(:Foe)
    result = @scene.pbChooseTarget(idxBattler, target_data)
    
    # Update to final selection if successful
    if result >= 0
      self.selected_target_for_info = result
    end
    
    # Clear after a short delay
    begin
      self.selected_target_for_info = nil
    rescue
    end
    
    return result
  end
  
  # Allow read/write access to selected target
  attr_accessor :selected_target_for_info
end

class PokeBattle_Battle
  unless method_defined?(:quickball_pbCommandPhaseLoop)
    alias quickball_pbCommandPhaseLoop pbCommandPhaseLoop
  end
  
  def pbCommandPhaseLoop(isPlayer)
    # KIF fix: only the player's own choices need the Quick Throw exit (-10); other choices run the game's own loop
    return quickball_pbCommandPhaseLoop(isPlayer) if !isPlayer || @controlPlayer
    actioned = []
    idxBattler = -1
    loop do
      break if @decision!=0
      idxBattler += 1
      break if idxBattler>=@battlers.length
      next if !@battlers[idxBattler] || pbOwnedByPlayer?(idxBattler)!=isPlayer
      next if @choices[idxBattler][0]!=:None
      next if !pbCanShowCommands?(idxBattler)
      if !@controlPlayer && pbOwnedByPlayer?(idxBattler)
        actioned.push(idxBattler)
        commandsEnd = false
        loop do
          cmd = pbCommandMenu(idxBattler,actioned.length==1)
          
          if cmd == -10
            commandsEnd = true
            break
          end
          
          if cmd>0 && @battlers[idxBattler].effects[PBEffects::SkyDrop]>=0
            pbDisplay(_INTL("Sky Drop won't let {1} go!",@battlers[idxBattler].pbThis(true)))
            next
          end
          case cmd
          when 0    
            break if pbFightMenu(idxBattler)
          when 1    
            if pbItemMenu(idxBattler,actioned.length==1)
              commandsEnd = true if pbItemUsesAllActions?(@choices[idxBattler][1])
              break
            end
          when 2
            # KIF fix: as in 6.8.2, the cursor goes back to Fight after a switch
            if pbPartyMenu(idxBattler)
              @scene.setLastCommandIndex(idxBattler,0)
              break
            end
          when 3    
            if pbRunMenu(idxBattler)
              commandsEnd = true
              break
            end
          when 4    
            break if pbCallMenu(idxBattler)
          when -2   
            pbDebugMenu
            next
          when -1   
            next if actioned.length<=1
            actioned.pop
            idxBattler = actioned.last-1
            pbCancelChoice(idxBattler+1)
            actioned.pop
            break
          end
          pbCancelChoice(idxBattler)
        end
        break if commandsEnd
      else
        @battleAI.pbDefaultChooseEnemyCommand(idxBattler)
      end
      break if commandsEnd
    end
  end
end

if defined?(BattleCommandMenu)
  BattleCommandMenu.register_command(
    _INTL("Quick Throw"),
    proc { |battle, idxBattler, scene|
      if !$lastUsedPokeBall
        battle.pbDisplay(_INTL("You haven't used a Poké Ball yet!"))
        next false
      end
      
      if !$PokemonBag.pbHasItem?($lastUsedPokeBall)
        scene.pbPlayBuzzerSE rescue nil
        
        show_message = (QuickThrowSettings.get(:no_balls_message) rescue true)
        if show_message
          begin
            itemName = GameData::Item.get($lastUsedPokeBall).name
            if $PokemonBag.pbHasItem?(:POKEBALL)
              message = _INTL("Out of {1}s! Defaulting to Poké Balls.",itemName)
            else
              message = _INTL("You don't have any Poké Balls left!")
            end
            
            cmds = [message]
            win = Window_CommandPokemonEx.new(cmds)
            win.z = 99999
            win.resizeToFit(win.commands)
            win.width = [win.width, 300].max
            win.x = (Graphics.width - win.width) / 2
            win.y = (Graphics.height - win.height) / 2
            win.index = -1
            win.active = false
            
            60.times do
              Graphics.update
              Input.update
              win.update
            end
            
            win.dispose
          rescue
          end
        end
        
        if $PokemonBag.pbHasItem?(:POKEBALL)
          $lastUsedPokeBall = :POKEBALL
          begin
            if defined?($PokemonGlobal) && $PokemonGlobal
              $PokemonGlobal.lastUsedPokeBall = :POKEBALL
            end
            if defined?(ModSettingsMenu)
              ModSettingsMenu.set(:quick_throw_last_ball, :POKEBALL)
            end
          rescue
          end
          
          if scene.respond_to?(:pbUpdateQuickBallIndicator)
            scene.instance_variable_set(:@quickBallIndicatorPrepared, false)
            scene.pbUpdateQuickBallIndicator(true)
          end
          
          next false
        else
          next false
        end
      end
      
      begin
        if battle.is_a?(PokeBattle_SafariZone)
          if $lastUsedPokeBall != :SAFARIBALL
            battle.pbDisplay(_INTL("You can only use Safari Balls here!"))
            next false
          end
        end
      rescue
      end
      
      if battle.respond_to?(:internalBattle) && !battle.internalBattle
        battle.pbDisplay(_INTL("Items can't be used here."))
        next false
      end
      
      if battle.respond_to?(:pbQuickPokeBall)
        if battle.pbQuickPokeBall(idxBattler, true)
          next :quick_throw_used
        end
      end
      next false
    },
    _INTL("Throw your last used Poké Ball"),
    proc { |battle, idxBattler|
      quick_throw_mode = (QuickThrowSettings.get(:quick_throw_mode) rescue 1).to_i
      next quick_throw_mode == 2
    },
    1  
  )
end

# ---------------------------------------------------------------------------
# Override Poké Ball restrictions for multi-Pokemon battles
# ---------------------------------------------------------------------------
if defined?(ItemHandlers)
  ItemHandlers::CanUseInBattle.addIf(
    proc { |item| GameData::Item.get(item).is_poke_ball? },
    proc { |item,pokemon,battler,move,firstAction,battle,scene,showMessages|
      # Only override if doubles target select is enabled
      target_select_enabled = (QuickThrowSettings.get(:doubles_target_select) rescue false)
      next nil unless target_select_enabled
      
      # Let the original checks run first
      if battle.pbPlayer.party_full? && $PokemonStorage.full?
        scene.pbDisplay(_INTL("There is no room left in the PC!")) if showMessages
        next false
      end
      
      if !firstAction
        scene.pbDisplay(_INTL("It's impossible to aim without being focused!")) if showMessages
        next false
      end
      
      if battler.semiInvulnerable?
        scene.pbDisplay(_INTL("It's no good! It's impossible to aim at a Pokémon that's not in sight!")) if showMessages
        next false
      end

      begin
        if $game_switches && $game_switches[SWITCH_SILVERBOSS_BATTLE]
          scene.pbDisplay(_INTL("It's no good! It's too agitated to aim!")) if showMessages
          next false
        end
      rescue
      end
      
      # Check for steal ball conditions
      is_steal_ball = false
      begin
        if $PokemonSystem.rocketballsteal && $PokemonSystem.rocketballsteal > 0 && battle.trainerBattle?
          if GameData::Item.get(item).id_number == 623 || $PokemonSystem.rocketballsteal > 1
            is_steal_ball = true
          end
        end
        if $PokemonSystem.nomoneylost && $PokemonSystem.nomoneylost == 1
          is_steal_ball = false
        end
      rescue
      end
      
      # Allow multi-target battles when target select is enabled
      # Override the "can't throw at multiple Pokemon" restriction
      if battle.pbOpposingBattlerCount > 1 && !(GameData::Item.get(item).is_snag_ball? && battle.trainerBattle?) && !is_steal_ball
        # This would normally fail, but we allow it with our target selection
        next true
      end
      
      next nil
    }
  )
end
