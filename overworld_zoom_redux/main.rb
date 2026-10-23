#==============================================================================
# Overworld Zoom Redux
#
# Standalone replacement for the multiplayer overworld zoom script.
# It keeps the existing mp_overworld_zoom setting, but replaces the
# resize-screen approach with a renderer-scale camera so Scene_Map no longer
# needs to bounce the game resolution when opening menus.
#==============================================================================

if defined?($overworld_zoom_redux_loaded) && $overworld_zoom_redux_loaded
  puts "[Overworld Zoom Redux] Duplicate load skipped."
else
  $overworld_zoom_redux_loaded = true

  module OverworldZoom
    MOD_ID = "overworld_zoom_redux"
    SETTING_KEY = "zoom_percent"
    LEGACY_SETTING_KEY = "zoom_level"
    TILT_KEY = "tilt_enabled"
    WIDESCREEN_KEY = "adaptive_widescreen"
    BASE_SCREEN_WIDTH = Settings::SCREEN_WIDTH
    BASE_SCREEN_HEIGHT = Settings::SCREEN_HEIGHT
    BASE_SCALE = 1.0
    MIN_PERCENT = 0
    MAX_PERCENT = 100
    STEP_PERCENT = 10
    WINDOW_ASPECT_CHECK_FRAMES = 10
    WINDOW_RESIZE_SETTLE_FRAMES = 24
    WINDOW_RESIZE_SIZE_TOLERANCE = 2
    WINDOW_WIDESCREEN_ENTER_THRESHOLD = 1.70
    WINDOW_WIDESCREEN_EXIT_THRESHOLD = 1.50
    WINDOW_WIDESCREEN_MIN_EXTRA_WIDTH = 96
    WIDESCREEN_RATIO = 16.0 / 9.0
    WIDESCREEN_WIDTH = begin
      tile_width = defined?(Game_Map::TILE_WIDTH) ? Game_Map::TILE_WIDTH : 32
      target_width = BASE_SCREEN_HEIGHT * WIDESCREEN_RATIO
      snapped_width = (target_width / tile_width).round * tile_width
      [snapped_width, BASE_SCREEN_WIDTH].max
    end
    STABLE_ZOOM_SCALES = {
      0 => 32.0 / 32.0,
      10 => 29.0 / 32.0,
      20 => 27.0 / 32.0,
      30 => 25.0 / 32.0,
      40 => 23.0 / 32.0,
      50 => 21.0 / 32.0,
      60 => 20.0 / 32.0,
      70 => 19.0 / 32.0,
      80 => 18.0 / 32.0,
      90 => 17.0 / 32.0,
      100 => 16.0 / 32.0
    }.freeze
    PERSPECTIVE_HORIZON_RATIO = 0.05
    PERSPECTIVE_BOTTOM_MARGIN_RATIO = -0.07
    PERSPECTIVE_GROUND_EXPONENT = 1.85
    PERSPECTIVE_FOCUS_RATIO = 0.60
    PERSPECTIVE_X_MIN = 0.78
    OBJECT_X_MIN = 0.94
    TILE_OBJECT_X_BLEND = 0.22
    PRIORITY_TILE_X_MIN = 0.88
    PRIORITY_TILE_X_ANCHOR_ROWS = 4.0
    PRIORITY_TILE_ANCHOR_ROWS = 2.25
    PRIORITY_TILE_VERTICAL_BLEND = 0.35
    OBJECT_DEPTH_MIN = 0.74
    OBJECT_DEPTH_MAX = 1.08
    OBJECT_VERTICAL_BOOST = 1.18
    TILE_X_OVERLAP_PIXELS = 2.2
    PRIORITY_TILE_X_OVERLAP_PIXELS = 2.8
    TILE_Y_OVERLAP_PIXELS = 1.8
    PRIORITY_TILE_Y_OVERLAP_PIXELS = 4.5
    TILE_MARGIN_COLUMNS = 5
    TILE_MARGIN_ROWS = 10
    WEARABLE_TILT_Y_NUDGE = 4

    @applied_index = nil
    @applied_tilt = nil
    @active_scale = BASE_SCALE
    @legacy_checked = false
    @projection_cache = nil
    @window_probe_initialized = false
    @get_foreground_window = nil
    @get_client_rect = nil
    @get_window_rect = nil
    @set_window_pos = nil
    @get_system_metrics = nil
    @saved_window_rect = nil
    @last_ratio_poll_frame = -WINDOW_ASPECT_CHECK_FRAMES
    @last_window_widescreen = nil
    @last_client_size = nil
    @last_client_size_change_frame = -WINDOW_RESIZE_SETTLE_FRAMES

    module_function

    # KIF fix: settings live in KIF's ModSettingsMenu (Options > KIF Settings > Mods),
    # saved for all saves; toggles are stored there as 0/1. Without it they last the session.
    STORE_KEYS = {
      SETTING_KEY    => :overworld_zoom_redux_zoom_percent,
      TILT_KEY       => :overworld_zoom_redux_tilt_enabled,
      WIDESCREEN_KEY => :overworld_zoom_redux_adaptive_widescreen
    }.freeze

    def settings_hash
      return @settings if @settings
      @settings = {}
      if defined?(ModSettingsMenu)
        STORE_KEYS.each do |key, store_key|
          stored = ModSettingsMenu.storage.has_key?(store_key) rescue false
          next if !stored
          value = ModSettingsMenu.get(store_key)
          @settings[key] = (key == SETTING_KEY) ? value.to_i : (value == true || value.to_i != 0)
        end
      end
      return @settings
    end

    # KIF fix: called when a value changes in KIF's settings screen
    def reload_settings!
      @settings = nil
      invalidate_projection_cache
    end

    def settings_file_exists?
      return false if !defined?(ModSettingsMenu)
      return STORE_KEYS.values.any? { |k| ModSettingsMenu.storage.has_key?(k) }
    rescue
      return false
    end

    def save_settings
      return if !defined?(ModSettingsMenu)
      values = settings_hash.dup
      STORE_KEYS.each do |key, store_key|
        next if !values.key?(key)
        value = (key == SETTING_KEY) ? values[key].to_i : (values[key] ? 1 : 0)
        ModSettingsMenu.set(store_key, value)
      end
    rescue
      nil
    end

    def migrate_legacy_setting!
      return if @legacy_checked
      @legacy_checked = true
      settings = settings_hash
      imported = false
      if !settings.key?(SETTING_KEY)
        legacy_value = MIN_PERCENT
        if settings.key?(LEGACY_SETTING_KEY)
          legacy_value = legacy_index_to_percent(settings[LEGACY_SETTING_KEY])
          settings.delete(LEGACY_SETTING_KEY)
          imported = true
        elsif !settings_file_exists? && $PokemonSystem && $PokemonSystem.respond_to?(:mp_overworld_zoom)
          legacy_value = legacy_index_to_percent($PokemonSystem.mp_overworld_zoom)
          imported = true
        end
        settings[SETTING_KEY] = snap_percent(legacy_value)
      end
      settings[TILT_KEY] = false if !settings.key?(TILT_KEY)
      # KIF fix: adaptive widescreen starts Off (it resizes the game screen); turn it on in the settings
      settings[WIDESCREEN_KEY] = false if !settings.key?(WIDESCREEN_KEY)
      # KIF fix: only an imported old zoom value is written; defaults stay unsaved
      save_settings if imported
    end

    def clamp_percent(value)
      percent = value.to_i
      percent = MIN_PERCENT if percent < MIN_PERCENT
      percent = MAX_PERCENT if percent > MAX_PERCENT
      return percent
    end

    def stable_zoom_levels
      return STABLE_ZOOM_SCALES.keys.sort
    end

    def base_screen_dimensions
      return [BASE_SCREEN_WIDTH, BASE_SCREEN_HEIGHT]
    end

    def widescreen_screen_dimensions
      return [WIDESCREEN_WIDTH, BASE_SCREEN_HEIGHT]
    end

    def current_screen_dimensions
      return [Graphics.width, Graphics.height]
    end

    def snap_percent(value)
      safe_percent = clamp_percent(value)
      return stable_zoom_levels.min_by { |level| [(level - safe_percent).abs, level] }
    end

    def stable_tile_size(percent)
      base_tile = defined?(Game_Map::TILE_WIDTH) ? Game_Map::TILE_WIDTH : 32
      return (base_tile * scale_for_percent(percent)).round
    end

    def invalidate_projection_cache
      @projection_cache = nil
    end

    def init_window_probe
      return if @window_probe_initialized
      @window_probe_initialized = true
      @get_foreground_window = Win32API.new('user32', 'GetForegroundWindow', [], 'l')
      @get_client_rect = Win32API.new('user32', 'GetClientRect', ['l', 'p'], 'i')
      @get_window_rect = Win32API.new('user32', 'GetWindowRect', ['l', 'p'], 'i')
      @set_window_pos = Win32API.new('user32', 'SetWindowPos', ['l', 'l', 'i', 'i', 'i', 'i', 'i'], 'i')
      @get_system_metrics = Win32API.new('user32', 'GetSystemMetrics', ['i'], 'i')
      # KIF fix: used to make sure the window is the game's own (see active_window_handle)
      @get_window_thread_process_id = Win32API.new('user32', 'GetWindowThreadProcessId', ['l', 'p'], 'l')
      @get_current_process_id = Win32API.new('kernel32', 'GetCurrentProcessId', [], 'l')
    rescue
      @get_foreground_window = nil
      @get_client_rect = nil
      @get_window_rect = nil
      @set_window_pos = nil
      @get_system_metrics = nil
    end

    def window_probe_available?
      init_window_probe
      return @get_foreground_window && @get_client_rect && @get_window_rect && @set_window_pos &&
             @get_window_thread_process_id && @get_current_process_id
    end

    def active_window_handle
      return nil if !window_probe_available?
      hwnd = @get_foreground_window.call
      return nil if !hwnd || hwnd == 0
      # KIF fix: the foreground window may be another program (alt-tab); only use the game's own
      pid = [0].pack('L')
      @get_window_thread_process_id.call(hwnd, pid)
      return nil if pid.unpack('L')[0] != @get_current_process_id.call
      return hwnd
    rescue
      return nil
    end

    def fullscreen_window?
      return Graphics.fullscreen ? true : false
    rescue
      return false
    end

    def current_fullscreen_size
      return nil if !@get_system_metrics
      width = @get_system_metrics.call(0)
      height = @get_system_metrics.call(1)
      return nil if width <= 0 || height <= 0
      return [width, height]
    rescue
      return nil
    end

    def current_window_client_size
      if fullscreen_window?
        size = current_fullscreen_size
        return size if size
      end
      hwnd = active_window_handle
      return nil if !hwnd
      rect = [0, 0, 0, 0].pack('l4')
      return nil if @get_client_rect.call(hwnd, rect) == 0
      left, top, right, bottom = rect.unpack('l4')
      width = right - left
      height = bottom - top
      return nil if width <= 0 || height <= 0
      return [width, height]
    rescue
      return nil
    end

    def current_window_aspect_ratio
      size = current_window_client_size
      return nil if !size || size[1] <= 0
      return size[0].to_f / size[1].to_f
    end

    def window_size_changed?(size)
      return true if !@last_client_size
      return true if (size[0] - @last_client_size[0]).abs > WINDOW_RESIZE_SIZE_TOLERANCE
      return true if (size[1] - @last_client_size[1]).abs > WINDOW_RESIZE_SIZE_TOLERANCE
      return false
    end

    def note_window_size(size, current_frame = Graphics.frame_count)
      return if !size
      if window_size_changed?(size)
        @last_client_size = size
        @last_client_size_change_frame = current_frame
      end
    end

    def window_resize_settled?(current_frame = Graphics.frame_count)
      return (current_frame - @last_client_size_change_frame) >= WINDOW_RESIZE_SETTLE_FRAMES
    end

    def save_window_rect
      return if fullscreen_window?
      hwnd = active_window_handle
      return if !hwnd
      rect = [0, 0, 0, 0].pack('l4')
      return if @get_window_rect.call(hwnd, rect) == 0
      left, top, right, bottom = rect.unpack('l4')
      @saved_window_rect = [left, top, right - left, bottom - top]
    rescue
      nil
    end

    def restore_window_rect
      return if fullscreen_window?
      hwnd = active_window_handle
      return if !hwnd || !@saved_window_rect
      x, y, width, height = @saved_window_rect
      @set_window_pos.call(hwnd, 0, x, y, width, height, 0x0014)
    rescue
      nil
    end

    def widescreen_window?
      if !widescreen_enabled?
        @last_window_widescreen = false
        return false
      end
      size = current_window_client_size
      return @last_window_widescreen ? true : false if !size || size[1] <= 0
      ratio = size[0].to_f / size[1].to_f
      extra_width = size[0] - ((size[1] * 4.0) / 3.0)
      if @last_window_widescreen.nil?
        @last_window_widescreen = ratio >= WINDOW_WIDESCREEN_ENTER_THRESHOLD && extra_width >= WINDOW_WIDESCREEN_MIN_EXTRA_WIDTH
      elsif @last_window_widescreen
        if ratio <= WINDOW_WIDESCREEN_EXIT_THRESHOLD || extra_width < (WINDOW_WIDESCREEN_MIN_EXTRA_WIDTH / 2.0)
          @last_window_widescreen = false
        end
      else
        if ratio >= WINDOW_WIDESCREEN_ENTER_THRESHOLD && extra_width >= WINDOW_WIDESCREEN_MIN_EXTRA_WIDTH
          @last_window_widescreen = true
        end
      end
      return @last_window_widescreen
    end

    def desired_screen_dimensions
      return widescreen_window? ? widescreen_screen_dimensions : base_screen_dimensions
    end

    def resize_screen_preserving_window(width, height)
      return false if Graphics.width == width && Graphics.height == height
      was_fullscreen = fullscreen_window?
      previous_scale = nil
      previous_scale = Graphics.scale if !was_fullscreen && Graphics.respond_to?(:scale)
      save_window_rect
      Graphics.resize_screen(width, height)
      Graphics.fullscreen = true if was_fullscreen && !fullscreen_window?
      if !was_fullscreen && !previous_scale.nil? && Graphics.respond_to?(:scale=)
        Graphics.scale = previous_scale
        Graphics.center if Graphics.respond_to?(:center)
      end
      restore_window_rect
      invalidate_projection_cache
      Spriteset_Map.update_static_viewport_rects if defined?(Spriteset_Map) && Spriteset_Map.respond_to?(:update_static_viewport_rects)
      return true
    rescue
      return false
    end

    def sync_screen_dimensions!
      dimensions = desired_screen_dimensions
      return resize_screen_preserving_window(dimensions[0], dimensions[1])
    end

    def desired_battle_screen_dimensions
      return widescreen_window? ? widescreen_screen_dimensions : base_screen_dimensions
    end

    def sync_battle_scene_constants!
      return if !defined?(PokeBattle_SceneConstants)
      updates = {
        :PLAYER_BASE_X => 128,
        :PLAYER_BASE_Y => Graphics.height - 80,
        :FOE_BASE_X => Graphics.width - 128,
        :FOE_BASE_Y => (Graphics.height * 3 / 4) - 112,
        :FOCUSUSER_X => 128,
        :FOCUSUSER_Y => 224,
        :FOCUSTARGET_X => Graphics.width - 128,
        :FOCUSTARGET_Y => 96
      }
      updates.each do |name, value|
        # KIF fix: leave the game's constants alone when they already match (always at 512x384)
        next if PokeBattle_SceneConstants.const_defined?(name) && PokeBattle_SceneConstants.const_get(name) == value
        PokeBattle_SceneConstants.send(:remove_const, name) if PokeBattle_SceneConstants.const_defined?(name)
        PokeBattle_SceneConstants.const_set(name, value)
      end
    rescue
      nil
    end

    def prepare_battle_screen!
      resize_screen_preserving_window(*desired_battle_screen_dimensions)
      sync_battle_scene_constants!
    end

    def restore_battle_scene_constants!
      sync_battle_scene_constants!
    end

    def refresh_window_aspect_if_needed
      return false if !$scene || !$scene.is_a?(Scene_Map)
      return false if !widescreen_enabled? && !screen_resized?   # KIF fix: nothing to watch with widescreen Off
      current_frame = Graphics.frame_count
      return false if current_frame - @last_ratio_poll_frame < WINDOW_ASPECT_CHECK_FRAMES
      @last_ratio_poll_frame = current_frame
      size = current_window_client_size
      return false if !size
      note_window_size(size, current_frame)
      return false if !window_resize_settled?(current_frame)
      dimensions = desired_screen_dimensions
      return false if current_screen_dimensions == dimensions
      apply!(force_recreate: true)
      return true
    rescue
      return false
    end

    def legacy_index_to_percent(value)
      case value.to_i
      when 1 then return 40
      when 2 then return 70
      else        return clamp_percent(value)
      end
    end

    def setting_percent
      migrate_legacy_setting!
      raw = settings_hash[SETTING_KEY].to_i
      snapped = snap_percent(raw)
      settings_hash[SETTING_KEY] = snapped if raw != snapped
      return snapped
    rescue
      return MIN_PERCENT
    end

    def set_setting_percent(value, persist = true)
      safe_value = snap_percent(value)
      invalidate_projection_cache if settings_hash[SETTING_KEY] != safe_value
      settings_hash[SETTING_KEY] = safe_value
      save_settings if persist
      return safe_value
    end

    def tilt_enabled?
      migrate_legacy_setting!
      return settings_hash[TILT_KEY] ? true : false
    rescue
      return false
    end

    def tilt_mode_index
      return tilt_enabled? ? 1 : 0
    end

    def set_tilt_mode(index, persist = true)
      enabled = index.to_i > 0
      invalidate_projection_cache if settings_hash[TILT_KEY] != enabled
      settings_hash[TILT_KEY] = enabled
      save_settings if persist
      return enabled ? 1 : 0
    end

    def scale_for_percent(percent)
      safe_percent = snap_percent(percent)
      return STABLE_ZOOM_SCALES[safe_percent] || BASE_SCALE
    end

    def desired_scale
      return scale_for_percent(setting_percent)
    end

    def active?
      return false if !defined?(Scene_Map) || !$scene || !$scene.is_a?(Scene_Map)
      return current_scale < BASE_SCALE || tilt_enabled?
    end

    # KIF fix: with every option Off and the normal screen size the game's own code runs unchanged
    def screen_resized?
      return Graphics.width != BASE_SCREEN_WIDTH || Graphics.height != BASE_SCREEN_HEIGHT
    end

    def any_feature_on?
      return desired_scale < BASE_SCALE || tilt_enabled? || widescreen_enabled? || screen_resized?
    end

    def custom_camera?
      return active? || screen_resized?
    end

    def current_scale
      return BASE_SCALE if !defined?(Scene_Map) || !$scene || !$scene.is_a?(Scene_Map)
      return @active_scale || desired_scale
    end

    def tilt_rendering?
      return active? && tilt_enabled?
    end

    def projection_state(scale = current_scale)
      tilt = tilt_rendering?
      cache_key = [scale.round(6), tilt, Graphics.width, Graphics.height]
      if !@projection_cache || @projection_cache[:key] != cache_key
        raw_width = Graphics.width.to_f / scale
        raw_height = Graphics.height.to_f / scale
        top = tilt ? (Graphics.height * PERSPECTIVE_HORIZON_RATIO).round : 0
        bottom = tilt ? (Graphics.height - (Graphics.height * PERSPECTIVE_BOTTOM_MARGIN_RATIO).round) : Graphics.height
        span = bottom - top
        span = 1 if span <= 0
        @projection_cache = {
          key: cache_key,
          raw_view_width: raw_width,
          raw_view_height: raw_height,
          raw_center_x: raw_width / 2.0,
          screen_center_x: Graphics.width / 2.0,
          top: top,
          bottom: bottom,
          span: span.to_f,
          inv_raw_view_height: raw_height > 0.0 ? 1.0 / raw_height : 0.0
        }
      end
      return @projection_cache
    end

    def scale_pixels(value)
      return (value.to_f * current_scale).round
    end

    def raw_view_width(scale = current_scale)
      return projection_state(scale)[:raw_view_width]
    end

    def raw_view_height(scale = current_scale)
      return projection_state(scale)[:raw_view_height]
    end

    def perspective_horizon_y
      return projection_state[:top]
    end

    def perspective_ground_bottom_y
      return projection_state[:bottom]
    end

    def connection_range_tiles
      return 6 if !active?
      return tilt_rendering? ? 18 : 12
    end

    def connection_range_pixels_x
      return (Graphics.width + connection_range_tiles * Game_Map::TILE_WIDTH) * Game_Map::X_SUBPIXELS
    end

    def connection_range_pixels_y
      return (Graphics.height + connection_range_tiles * Game_Map::TILE_HEIGHT) * Game_Map::Y_SUBPIXELS
    end

    def perspective_focus_screen_y
      return Graphics.height / 2 if !tilt_rendering?
      state = projection_state
      top = state[:top]
      bottom = state[:bottom]
      return top + ((bottom - top) * PERSPECTIVE_FOCUS_RATIO).round
    end

    def clamped_depth(raw_y, scale = current_scale)
      state = projection_state(scale)
      return 0.0 if state[:inv_raw_view_height] <= 0.0
      value = raw_y.to_f * state[:inv_raw_view_height]
      value = 0.0 if value < 0.0
      value = 1.0 if value > 1.0
      return value
    end

    def perspective_ground_depth(raw_y, scale = current_scale)
      return clamped_depth(raw_y, scale) if !tilt_rendering?
      return clamped_depth(raw_y, scale)**PERSPECTIVE_GROUND_EXPONENT
    end

    def transform_ground_y(raw_y, scale = current_scale)
      return (raw_y.to_f * scale).round if !tilt_rendering?
      state = projection_state(scale)
      top = state[:top]
      bottom = state[:bottom]
      depth = perspective_ground_depth(raw_y, scale)
      return top + ((bottom - top) * depth).round
    end

    def inverse_transform_ground_y(screen_y, scale = current_scale)
      return screen_y.to_f / scale if !tilt_rendering?
      state = projection_state(scale)
      top = state[:top].to_f
      span = state[:span]
      ratio = (screen_y.to_f - top) / span
      ratio = 0.0 if ratio < 0.0
      ratio = 1.0 if ratio > 1.0
      raw_ratio = ratio**(1.0 / PERSPECTIVE_GROUND_EXPONENT)
      return raw_ratio * state[:raw_view_height]
    end

    def ground_row_scale(raw_y, scale = current_scale)
      return scale if !tilt_rendering?
      tile_top = raw_y - Game_Map::TILE_HEIGHT
      y0 = transform_ground_y(tile_top, scale)
      y1 = transform_ground_y(raw_y, scale)
      span = (y1 - y0).abs
      span = 1 if span < 1
      return span.to_f / Game_Map::TILE_HEIGHT
    end

    def ground_x_factor(raw_y, scale = current_scale)
      return 1.0 if !tilt_rendering?
      depth = clamped_depth(raw_y, scale)
      return PERSPECTIVE_X_MIN + ((1.0 - PERSPECTIVE_X_MIN) * depth)
    end

    def project_ground_x(raw_x, raw_y, scale = current_scale)
      return (raw_x.to_f * scale).round if !tilt_rendering?
      state = projection_state(scale)
      factor = ground_x_factor(raw_y, scale) * scale
      return (state[:screen_center_x] + ((raw_x - state[:raw_center_x]) * factor)).round
    end

    def object_depth_scale(raw_y, scale = current_scale)
      return scale if !tilt_rendering?
      depth = clamped_depth(raw_y, scale)
      factor = OBJECT_DEPTH_MIN + ((OBJECT_DEPTH_MAX - OBJECT_DEPTH_MIN) * depth)
      return scale * factor
    end

    def object_x_factor(raw_y, scale = current_scale)
      return 1.0 if !tilt_rendering?
      depth = clamped_depth(raw_y, scale)
      return OBJECT_X_MIN + ((1.0 - OBJECT_X_MIN) * depth)
    end

    def project_object_x(raw_x, raw_y, scale = current_scale)
      return (raw_x.to_f * scale).round if !tilt_rendering?
      state = projection_state(scale)
      factor = object_x_factor(raw_y, scale) * scale
      return (state[:screen_center_x] + ((raw_x - state[:raw_center_x]) * factor)).round
    end

    def tile_zoom_x_for_priority(priority, raw_y, scale = current_scale)
      return scale if !tilt_rendering?
      return scale * tile_x_factor_for_priority(priority, tile_x_anchor_raw_y(priority, raw_y), scale)
    end

    def tile_x_anchor_raw_y(priority, raw_y)
      return raw_y if !tilt_rendering? || priority.to_i <= 0
      return raw_y + (Game_Map::TILE_HEIGHT * PRIORITY_TILE_X_ANCHOR_ROWS)
    end

    def tile_anchor_raw_y(priority, raw_y)
      return raw_y if !tilt_rendering? || priority.to_i <= 0
      return raw_y + (Game_Map::TILE_HEIGHT * PRIORITY_TILE_ANCHOR_ROWS)
    end

    def tile_x_factor_for_priority(priority, raw_y, scale = current_scale)
      return 1.0 if !tilt_rendering?
      ground_factor = ground_x_factor(raw_y, scale)
      return ground_factor if priority.to_i <= 0
      ground_factor = PRIORITY_TILE_X_MIN if ground_factor < PRIORITY_TILE_X_MIN
      object_factor = object_x_factor(raw_y, scale)
      depth_weight = 0.2 + (0.8 * clamped_depth(raw_y, scale))
      blend = TILE_OBJECT_X_BLEND * depth_weight * [[priority.to_i, 2].min, 0].max
      blend = 1.0 if blend > 1.0
      return ground_factor + ((object_factor - ground_factor) * blend)
    end

    def project_tile_x(priority, raw_x, raw_y, scale = current_scale)
      return (raw_x.to_f * scale).round if !tilt_rendering?
      anchor_y = tile_x_anchor_raw_y(priority, raw_y)
      state = projection_state(scale)
      factor = tile_x_factor_for_priority(priority, anchor_y, scale) * scale
      return (state[:screen_center_x] + ((raw_x - state[:raw_center_x]) * factor)).round
    end

    def tile_zoom_y_for_priority(priority, raw_y, scale = current_scale)
      return scale if !tilt_rendering?
      return ground_row_scale(raw_y, scale) if priority.to_i <= 0
      ground_scale = ground_row_scale(raw_y, scale)
      object_scale = object_depth_scale(tile_anchor_raw_y(priority, raw_y), scale) * OBJECT_VERTICAL_BOOST
      return ground_scale + ((object_scale - ground_scale) * PRIORITY_TILE_VERTICAL_BLEND)
    end

    def character_raw_ground_y(ch)
      return raw_view_height / 2.0 if !ch || !ch.respond_to?(:real_y)
      return ((ch.real_y.to_f - ch.map.display_y) / Game_Map::Y_SUBPIXELS).round + Game_Map::TILE_HEIGHT
    rescue
      return raw_view_height / 2.0
    end

    def character_zoom_x_for(ch)
      return current_scale if !tilt_rendering?
      raw_y = character_raw_ground_y(ch)
      return current_scale * object_x_factor(raw_y, current_scale)
    end

    def character_zoom_y_for(ch)
      return current_scale if !tilt_rendering?
      return object_depth_scale(character_raw_ground_y(ch), current_scale) * OBJECT_VERTICAL_BOOST
    end

    def tile_zoom_x_with_overlap(priority, raw_y, scale = current_scale)
      zoom = tile_zoom_x_for_priority(priority, raw_y, scale)
      return zoom if !tilt_rendering?
      overlap = TILE_X_OVERLAP_PIXELS.to_f / Game_Map::TILE_WIDTH
      overlap += PRIORITY_TILE_X_OVERLAP_PIXELS.to_f / Game_Map::TILE_WIDTH if priority.to_i > 0
      return zoom + overlap
    end

    def tile_zoom_y_with_overlap(priority, raw_y, scale = current_scale)
      zoom = tile_zoom_y_for_priority(priority, raw_y, scale)
      return zoom if !tilt_rendering?
      overlap = TILE_Y_OVERLAP_PIXELS.to_f / Game_Map::TILE_HEIGHT
      overlap += PRIORITY_TILE_Y_OVERLAP_PIXELS.to_f / Game_Map::TILE_HEIGHT if priority.to_i > 0
      return zoom + overlap
    end

    def wearable_y_nudge(scale_x, scale_y)
      return 0 if !tilt_rendering?
      depth_bonus = [(scale_y - scale_x) * 10.0, 0.0].max.round
      return -(WEARABLE_TILT_Y_NUDGE + depth_bonus)
    end

    def world_screen_center_x
      visible_width = Graphics.width.to_f / current_scale
      return ((visible_width / 2.0) - (Game_Map::TILE_WIDTH / 2.0)) * Game_Map::X_SUBPIXELS
    end

    def world_screen_center_y
      focus_raw_y = inverse_transform_ground_y(perspective_focus_screen_y, current_scale)
      return (focus_raw_y - (Game_Map::TILE_HEIGHT / 2.0)) * Game_Map::Y_SUBPIXELS
    end

    def renderer_scale(renderer = nil)
      if renderer && renderer.respond_to?(:owzoom_scale)
        return renderer.owzoom_scale || BASE_SCALE
      end
      return current_scale
    end

    def renderer_needs_rebuild?(scene = $scene)
      return false if !scene || !scene.is_a?(Scene_Map)
      renderer = scene.map_renderer rescue nil
      return false if !renderer || renderer.disposed?
      return true if @applied_tilt != tilt_enabled?
      return (renderer_scale(renderer) - desired_scale).abs > 0.001
    end

    def apply!(force_recreate: false)
      @active_scale = desired_scale
      screen_changed = sync_screen_dimensions!
      invalidate_projection_cache if !screen_changed
      Spriteset_Map.update_static_viewport_rects if defined?(Spriteset_Map) && Spriteset_Map.respond_to?(:update_static_viewport_rects)
      if $scene && $scene.is_a?(Scene_Map)
        recreate_in_scene if force_recreate || screen_changed || renderer_needs_rebuild?
        $game_player.center($game_player.x, $game_player.y) if $game_player
      end
      @applied_index = setting_percent
      @applied_tilt = tilt_enabled?
      return @active_scale
    end

    def restore!
      @active_scale = BASE_SCALE
      resize_screen_preserving_window(BASE_SCREEN_WIDTH, BASE_SCREEN_HEIGHT)
      restore_battle_scene_constants!
      invalidate_projection_cache
      return BASE_SCALE
    end

    def recreate_in_scene
      scene = $scene
      return if !scene || !scene.is_a?(Scene_Map)
      # KIF fix: before Scene_Map#main has made its spritesets there is nothing to rebuild
      # (making them here too left a second, never disposed set on screen)
      return if !scene.spritesets
      renderer = scene.map_renderer rescue nil
      Graphics.freeze
      scene.send(:disposeSpritesets) if scene.respond_to?(:disposeSpritesets)
      renderer.dispose if renderer && !renderer.disposed?
      scene.instance_variable_set(:@map_renderer, nil)
      scene.send(:createSpritesets) if scene.respond_to?(:createSpritesets)
      $game_player.center($game_player.x, $game_player.y) if $game_player
      Graphics.transition(8)
    end

    def max_percent
      return MAX_PERCENT
    end

    def slider_step
      return STEP_PERCENT
    end

    def label_for_percent(percent = setting_percent)
      safe_percent = clamp_percent(percent)
      return "Off" if safe_percent <= 0
      return "#{safe_percent}% Out"
    end

    def tilt_label
      return tilt_enabled? ? "On" : "Off"
    end

    def tilt_description
      if tilt_enabled?
        return "Experimental horizon perspective is on. It bends the ground toward a faux horizon and scales upright objects by depth for a stronger pseudo-3D look."
      end
      return "Experimental horizon perspective is off. Enable it to try the faux horizon camera effect with depth-scaled overworld objects."
    end

    def widescreen_enabled?
      return settings_hash[WIDESCREEN_KEY] ? true : false
    end

    def widescreen_mode_index
      return widescreen_enabled? ? 1 : 0
    end

    def set_widescreen_mode(value, save = true)
      enabled = (value.to_i == 1)
      changed = settings_hash[WIDESCREEN_KEY] != enabled
      settings_hash[WIDESCREEN_KEY] = enabled
      @last_window_widescreen = false if !enabled
      if changed
        sync_screen_dimensions!
        invalidate_projection_cache
      end
      save_settings if save
      return enabled
    end

    def widescreen_description
      if !widescreen_enabled?
        return "Adaptive widescreen is off. The game will stay on the standard playfield width even in wider windows."
      end
      if widescreen_window?
        return "Adaptive widescreen is on and currently active. Wider windows and fullscreen expand the overworld and battle view left and right without stretching the image."
      end
      return "Adaptive widescreen is on. Widen the window further or use a wider fullscreen shape to expand the overworld and battle view automatically."
    end

    def description_for_percent(percent = setting_percent)
      safe_percent = snap_percent(percent)
      if safe_percent <= 0
        base_text = tilt_enabled? ? "No zoom, but horizon perspective is active for a stronger pseudo-3D overworld view." : "No zoom - normal overworld view."
        return widescreen_window? ? "#{base_text} Widescreen windows also expand the overworld left and right automatically." : base_text
      end
      scale = scale_for_percent(safe_percent)
      tile_pixels = stable_tile_size(safe_percent)
      render_percent = (scale * 100).round
      tilt_note = tilt_enabled? ? " Horizon perspective is also active." : ""
      aspect_note = widescreen_window? ? " Widescreen windows also widen the overworld view automatically." : ""
      return "Zoom out #{safe_percent}% - uses a stable #{tile_pixels}px tile scale at about #{render_percent}% render size for smoother frames and fewer projection seams.#{tilt_note}#{aspect_note}"
    end

    def open_options_menu
      pbFadeOutIn do
        scene = OverworldZoomOptionsScene.new
        screen = PokemonOptionScreen.new(scene)
        screen.pbStartScreen
      end
    end
  end

  class Spriteset_Map
    def self.update_static_viewport_rects
      @@viewport0.rect.set(0, 0, Graphics.width, Graphics.height)
      @@viewport1.rect.set(0, 0, Graphics.width, Graphics.height)
      @@viewport3.rect.set(0, 0, Graphics.width, Graphics.height)
    end

    alias __owzoom_redux_update update unless method_defined?(:__owzoom_redux_update)

    def update
      __owzoom_redux_update
      return if !OverworldZoom.active?   # KIF fix: zoom/perspective Off: the game's own panorama/fog
      scale = OverworldZoom.current_scale
      tmox = (@map.display_x / Game_Map::X_SUBPIXELS).round
      tmoy = (@map.display_y / Game_Map::Y_SUBPIXELS).round
      if @panorama
        @panorama.zoom_x = scale
        @panorama.zoom_y = scale
        @panorama.ox = ((tmox / 2.0) * scale).round
        @panorama.oy = ((tmoy / 2.0) * scale).round
      end
      if @fog
        fog_scale_x = (@map.fog_zoom / 100.0) * scale
        fog_scale_y = (@map.fog_zoom / 100.0) * scale
        @fog.ox = ((tmox + @map.fog_ox) * scale).round
        @fog.oy = ((tmoy + @map.fog_oy) * scale).round
        @fog.zoom_x = fog_scale_x
        @fog.zoom_y = fog_scale_y
      end
      if @fog2
        fog2_scale_x = (@map.fog_zoom / 100.0) * scale
        fog2_scale_y = (@map.fog_zoom / 100.0) * scale
        @fog2.ox = ((tmox + @map.fog2_ox) * scale).round
        @fog2.oy = ((tmoy + @map.fog2_oy) * scale).round
        @fog2.zoom_x = fog2_scale_x
        @fog2.zoom_y = fog2_scale_y
      end
    end
  end

  class TilemapRenderer
    attr_reader :owzoom_scale

    alias __owzoom_redux_initialize initialize unless method_defined?(:__owzoom_redux_initialize)

    def initialize(viewport)
      __owzoom_redux_initialize(viewport)
      @owzoom_scale = OverworldZoom.current_scale
      @owzoom_tilt = OverworldZoom.tilt_rendering?
      # KIF fix: the game's own tile grid (and KIF's frame-rate ring) when zoom/perspective are Off
      return if !owzoom_custom?
      owzoom_rebuild_tile_pool
      @need_refresh = true
    end

    def owzoom_custom?
      return (@owzoom_scale && @owzoom_scale < OverworldZoom::BASE_SCALE) || @owzoom_tilt ? true : false
    end

    def owzoom_target_tile_counts(scale = @owzoom_scale)
      scale = 1.0 if !scale || scale <= 0
      cols = (Graphics.width.to_f / (DISPLAY_TILE_WIDTH * scale)).ceil + 2
      rows = (Graphics.height.to_f / (DISPLAY_TILE_HEIGHT * scale)).ceil + 2
      if @kif_ring   # KIF fix: KIF's frame rate (above 40 fps) needs one more tile round the screen
        cols += 2
        rows += 2
      end
      if @owzoom_tilt
        cols += OverworldZoom::TILE_MARGIN_COLUMNS
        rows += OverworldZoom::TILE_MARGIN_ROWS
      end
      return [cols, rows]
    end

    def owzoom_dispose_tile_pool
      return if !@tiles
      @tiles.each do |col|
        next if !col
        col.each do |coord|
          next if !coord
          coord.each do |tile|
            tile.dispose if tile && !tile.disposed?
          end
          coord.clear
        end
        col.clear
      end
      @tiles.clear
    end

    def owzoom_rebuild_tile_pool
      target_cols, target_rows = owzoom_target_tile_counts
      same_cols = @tiles && @tiles.length == target_cols
      same_rows = same_cols && @tiles[0] && @tiles[0].length == target_rows
      return if same_cols && same_rows
      owzoom_dispose_tile_pool
      @tiles_horizontal_count = target_cols
      @tiles_vertical_count = target_rows
      @tiles = []
      @tiles_horizontal_count.times do |i|
        @tiles[i] = []
        @tiles_vertical_count.times do |j|
          @tiles[i][j] = Array.new(3) { TileSprite.new(@viewport) }
        end
      end
      @tile_offset_x = 0
      @tile_offset_y = 0
      @pixel_offset_x = 0
      @pixel_offset_y = 0
    end

    # KIF fix: wraps the game's/KIF FrameRate's version instead of replacing it
    alias __owzoom_redux_tile_coordinates refresh_tile_coordinates unless method_defined?(:__owzoom_redux_tile_coordinates)
    alias __owzoom_redux_tile_z refresh_tile_z unless method_defined?(:__owzoom_redux_tile_z)

    if method_defined?(:kif_fps_ring)
      alias __owzoom_redux_kif_fps_ring kif_fps_ring unless method_defined?(:__owzoom_redux_kif_fps_ring)

      # KIF fix: KIF's frame rate rebuilds the grid at its own size; make it big enough for the zoom again
      def kif_fps_ring(on)
        __owzoom_redux_kif_fps_ring(on)
        owzoom_rebuild_tile_pool if owzoom_custom?
      end
    end

    def refresh_tile_coordinates(tile, x, y)
      return __owzoom_redux_tile_coordinates(tile, x, y) if !owzoom_custom?
      # KIF fix: KIF's frame-rate ring works the grid out one tile back; draw it one tile on
      if @kif_ring
        x -= 1
        y -= 1
      end
      scale = @owzoom_scale || 1.0
      raw_x = x * DISPLAY_TILE_WIDTH - @pixel_offset_x
      raw_y = y * DISPLAY_TILE_HEIGHT - @pixel_offset_y + DISPLAY_TILE_HEIGHT
      zoom_x = OverworldZoom.tile_zoom_x_with_overlap(tile.priority, raw_y, scale)
      zoom_y = OverworldZoom.tile_zoom_y_with_overlap(tile.priority, raw_y, scale)
      tile.zoom_x = zoom_x
      tile.zoom_y = zoom_y
      tile.x = OverworldZoom.project_tile_x(tile.priority, raw_x, raw_y + DISPLAY_TILE_HEIGHT, scale)
      tile_bottom = OverworldZoom.transform_ground_y(raw_y, scale)
      tile.y = tile_bottom - (DISPLAY_TILE_HEIGHT * zoom_y).round
    end

    def refresh_tile_z(tile, map, y, layer, tile_id)
      return __owzoom_redux_tile_z(tile, map, y, layer, tile_id) if !owzoom_custom?
      y -= 1 if @kif_ring   # KIF fix: same one-tile shift as the coordinates
      if tile.underwater_tile   # KIF fix: 6.8.2's rule (TilemapRenderer.rb:772)
        tile.z = -5
      elsif tile.shows_reflection
        tile.z = -100
      elsif tile.bridge && $PokemonGlobal.bridge > 0
        tile.z = 0
      else
        priority = tile.priority
        raw_y = y * DISPLAY_TILE_HEIGHT - @pixel_offset_y + DISPLAY_TILE_HEIGHT
        base_y = OverworldZoom.transform_ground_y(raw_y, (@owzoom_scale || 1.0))
        tile.z = (priority == 0) ? 0 : (base_y + priority * 32 * (@owzoom_scale || 1.0)).round
      end
    end
  end

  # KIF fix: frames KIF's frame rate draws in between slide the map by the camera's move;
  # on a zoomed map that move is drawn smaller
  if defined?(KIF::FrameRate) && KIF::FrameRate.respond_to?(:camera_move)
    class << KIF::FrameRate
      alias __owzoom_redux_camera_move camera_move unless method_defined?(:__owzoom_redux_camera_move)

      def camera_move(now, last)
        ret = __owzoom_redux_camera_move(now, last)
        return ret if !ret || !OverworldZoom.active?
        scale = OverworldZoom.current_scale
        return [ret[0] * scale, ret[1] * scale]
      end
    end
  end

  class Game_Map
    # KIF fix: wrapped; the game's own versions run while zoom/perspective are Off
    alias __owzoom_redux_display_x_set display_x= unless method_defined?(:__owzoom_redux_display_x_set)
    alias __owzoom_redux_display_y_set display_y= unless method_defined?(:__owzoom_redux_display_y_set)

    def display_x=(value)
      return __owzoom_redux_display_x_set(value) if !OverworldZoom.active?
      return if @display_x == value
      @display_x = value
      if GameData::MapMetadata.exists?(self.map_id) && GameData::MapMetadata.get(self.map_id).snap_edges
        visible_tiles = Graphics.width.to_f / (TILE_WIDTH * OverworldZoom.current_scale)
        max_x = (self.width - visible_tiles) * REAL_RES_X
        max_x = 0 if max_x < 0
        @display_x = [0, [@display_x, max_x].min].max
      end
      $MapFactory.setMapsInRange if $MapFactory
    end

    def display_y=(value)
      return __owzoom_redux_display_y_set(value) if !OverworldZoom.active?
      return if @display_y == value
      @display_y = value
      if GameData::MapMetadata.exists?(self.map_id) && GameData::MapMetadata.get(self.map_id).snap_edges
        visible_tiles = OverworldZoom.raw_view_height(OverworldZoom.current_scale) / TILE_HEIGHT.to_f
        max_y = (self.height - visible_tiles) * REAL_RES_Y
        max_y = 0 if max_y < 0
        @display_y = [0, [@display_y, max_y].min].max
      end
      $MapFactory.setMapsInRange if $MapFactory
    end
  end

  if defined?(MapFactoryHelper)
    module MapFactoryHelper
      class << self
        alias __owzoom_redux_mapInRange_q mapInRange? unless method_defined?(:__owzoom_redux_mapInRange_q)
        alias __owzoom_redux_mapInRangeById_q mapInRangeById? unless method_defined?(:__owzoom_redux_mapInRangeById_q)

        def mapInRange?(map)
          return __owzoom_redux_mapInRange_q(map) if !defined?(OverworldZoom) || !OverworldZoom.active?
          range = OverworldZoom.connection_range_tiles
          dispx = map.display_x
          dispy = map.display_y
          return false if dispx >= (map.width + range) * Game_Map::REAL_RES_X
          return false if dispy >= (map.height + range) * Game_Map::REAL_RES_Y
          return false if dispx <= -OverworldZoom.connection_range_pixels_x
          return false if dispy <= -OverworldZoom.connection_range_pixels_y
          return true
        end

        def mapInRangeById?(id, dispx, dispy)
          return __owzoom_redux_mapInRangeById_q(id, dispx, dispy) if !defined?(OverworldZoom) || !OverworldZoom.active?
          range = OverworldZoom.connection_range_tiles
          dims = MapFactoryHelper.getMapDims(id)
          return false if dispx >= (dims[0] + range) * Game_Map::REAL_RES_X
          return false if dispy >= (dims[1] + range) * Game_Map::REAL_RES_Y
          return false if dispx <= -OverworldZoom.connection_range_pixels_x
          return false if dispy <= -OverworldZoom.connection_range_pixels_y
          return true
        end
      end
    end
  end

  class Game_Character
    # KIF fix: wrapped; the game's own versions run while zoom/perspective are Off
    alias __owzoom_redux_screen_x screen_x unless method_defined?(:__owzoom_redux_screen_x)
    alias __owzoom_redux_screen_y_ground screen_y_ground unless method_defined?(:__owzoom_redux_screen_y_ground)
    alias __owzoom_redux_screen_y screen_y unless method_defined?(:__owzoom_redux_screen_y)
    alias __owzoom_redux_screen_z screen_z unless method_defined?(:__owzoom_redux_screen_z)

    def screen_x
      return __owzoom_redux_screen_x if !OverworldZoom.active?
      raw_x = ((@real_x.to_f - self.map.display_x) / Game_Map::X_SUBPIXELS).round
      raw_y = ((@real_y.to_f - self.map.display_y) / Game_Map::Y_SUBPIXELS).round + Game_Map::TILE_HEIGHT
      raw_x += @width * Game_Map::TILE_WIDTH / 2
      return OverworldZoom.project_object_x(raw_x, raw_y)
    end

    def screen_y_ground
      return __owzoom_redux_screen_y_ground if !OverworldZoom.active?
      raw_y = ((@real_y.to_f - self.map.display_y) / Game_Map::Y_SUBPIXELS).round
      raw_y += Game_Map::TILE_HEIGHT
      return OverworldZoom.transform_ground_y(raw_y)
    end

    def screen_y
      return __owzoom_redux_screen_y if !OverworldZoom.active?
      ret = screen_y_ground
      if jumping?
        if @jump_count > 0
          jump_fraction = ((@jump_count * jump_speed_real / Game_Map::REAL_RES_X) - 0.5).abs
        else
          jump_fraction = ((@jump_distance_left / @jump_distance) - 0.5).abs
        end
        jump_offset = @jump_peak * (4 * jump_fraction**2 - 1)
        ret += OverworldZoom.scale_pixels(jump_offset)
      end
      return ret
    end

    def screen_z(height = 0)
      return __owzoom_redux_screen_z(height) if !OverworldZoom.active?
      return -1 if @under_everything
      return 0 if @under_player   # KIF fix: 6.8.2's rules (007_Game_Character.rb:386-389)
      return 999 if @always_on_top
      return @forced_z if @forced_z
      return 999 if @on_bridge && $PokemonGlobal.bridge <= 0
      z = screen_y_ground
      if @tile_id > 0
        begin
          priority_boost = self.map.priorities[@tile_id] * 32
          return z + (priority_boost * OverworldZoom.character_zoom_y_for(self)).round
        rescue
          return 0
        end
      end
      height_boost = (height > Game_Map::TILE_HEIGHT) ? Game_Map::TILE_HEIGHT - 1 : 0
      return z + (height_boost * OverworldZoom.character_zoom_y_for(self)).round
    end
  end

  class Game_Player
    # KIF fix: wrapped; the game's own versions run at zoom Off and the normal screen size
    alias __owzoom_redux_center center unless method_defined?(:__owzoom_redux_center)
    alias __owzoom_redux_isCentered isCentered unless method_defined?(:__owzoom_redux_isCentered)
    alias __owzoom_redux_update_screen_position update_screen_position unless method_defined?(:__owzoom_redux_update_screen_position)

    def dynamic_screen_center_x
      return OverworldZoom.world_screen_center_x
    end

    def dynamic_screen_center_y
      return OverworldZoom.world_screen_center_y
    end

    def center(x, y)
      return __owzoom_redux_center(x, y) if !OverworldZoom.custom_camera?
      self.map.display_x = x * Game_Map::REAL_RES_X - dynamic_screen_center_x
      self.map.display_y = y * Game_Map::REAL_RES_Y - dynamic_screen_center_y
    end

    def isCentered
      return __owzoom_redux_isCentered if !OverworldZoom.custom_camera?
      x_centered = self.map.display_x == x * Game_Map::REAL_RES_X - dynamic_screen_center_x
      y_centered = self.map.display_y == y * Game_Map::REAL_RES_Y - dynamic_screen_center_y
      return x_centered && y_centered
    end

    def update_screen_position(last_real_x, last_real_y)
      return __owzoom_redux_update_screen_position(last_real_x, last_real_y) if !OverworldZoom.custom_camera?
      return if self.map.scrolling? || !(@moved_last_frame || @moved_this_frame)
      self.map.display_x = @real_x - dynamic_screen_center_x
      self.map.display_y = @real_y - dynamic_screen_center_y
    end
  end

  class Sprite_Character < RPG::Sprite
    alias __owzoom_redux_update update unless method_defined?(:__owzoom_redux_update)

    def update
      __owzoom_redux_update
      return if !OverworldZoom.active?   # KIF fix: leave the game's own zoom/visibility alone when Off
      self.zoom_x = OverworldZoom.character_zoom_x_for(@character)
      self.zoom_y = OverworldZoom.character_zoom_y_for(@character)
      if self.visible
        scaled_width = ((@cw || Game_Map::TILE_WIDTH) * self.zoom_x).round
        scaled_height = ((@ch || Game_Map::TILE_HEIGHT) * self.zoom_y).round
        margin = Game_Map::TILE_WIDTH
        offscreen = false
        offscreen = true if self.x + scaled_width / 2 < -margin
        offscreen = true if self.x - scaled_width / 2 > Graphics.width + margin
        offscreen = true if self.y < -margin
        offscreen = true if self.y - scaled_height > Graphics.height + margin
        self.visible = false if offscreen
      end
    end
  end

  class Sprite_Wearable < RPG::Sprite
    # KIF fix: wrapped; the game's own versions run while zoom/perspective are Off
    alias __owzoom_redux_apply_sprite_offset apply_sprite_offset unless method_defined?(:__owzoom_redux_apply_sprite_offset)
    alias __owzoom_redux_adjust_scrolling adjustPositionForScreenScrolling unless method_defined?(:__owzoom_redux_adjust_scrolling)
    alias __owzoom_redux_set_sprite_position set_sprite_position unless method_defined?(:__owzoom_redux_set_sprite_position)

    def owzoom_scale_x
      return (@player_sprite && @player_sprite.zoom_x) ? @player_sprite.zoom_x : 1.0
    end

    def owzoom_scale_y
      return (@player_sprite && @player_sprite.zoom_y) ? @player_sprite.zoom_y : owzoom_scale_x
    end

    def owzoom_anchor_x
      return @player_sprite.x - (@player_sprite.ox * owzoom_scale_x)
    end

    def owzoom_anchor_y
      return @player_sprite.y - (@player_sprite.oy * owzoom_scale_y)
    end

    def apply_sprite_offset(offsets_array, current_frame)
      return __owzoom_redux_apply_sprite_offset(offsets_array, current_frame) if !OverworldZoom.active?
      return if !offsets_array || !offsets_array[current_frame]
      @sprite.x += (offsets_array[current_frame][0] * owzoom_scale_x).round
      @sprite.y += (offsets_array[current_frame][1] * owzoom_scale_y).round
    end

    def adjustPositionForScreenScrolling
      return __owzoom_redux_adjust_scrolling if !OverworldZoom.active?
      return if !$game_map.scrolling? && !@was_just_scrolling
      if $game_map.scrolling?
        @was_just_scrolling = true
      else
        @was_just_scrolling = false
      end
      offset_x = 0
      offset_y = 0
      case $game_map.scroll_direction
      when DIRECTION_RIGHT then offset_x = (-8 * owzoom_scale_x).round
      when DIRECTION_LEFT  then offset_x = (8 * owzoom_scale_x).round
      when DIRECTION_UP
        offset_y = (8 * owzoom_scale_y).round
        @sprite.z += 50
      when DIRECTION_DOWN then offset_y = (-8 * owzoom_scale_y).round
      end
      @sprite.x += offset_x
      @sprite.y += offset_y
    end

    def set_sprite_position(action, direction, current_frame)
      return __owzoom_redux_set_sprite_position(action, direction, current_frame) if !OverworldZoom.active?
      # KIF fix: same origin as the player sprite, as 6.8.2 does (013_Sprite_Wearable.rb:40-43);
      # the zoom scales around it, so this lands where owzoom_anchor_x/y did
      @sprite.x = @player_sprite.x
      @sprite.y = @player_sprite.y
      @sprite.ox = @player_sprite.ox
      @sprite.oy = @player_sprite.oy
      case action
      when "run"
        apply_sprite_offset(Outfit_Offsets::RUN_OFFSETS_DOWN, current_frame) if direction == DIRECTION_DOWN
        apply_sprite_offset(Outfit_Offsets::RUN_OFFSETS_LEFT, current_frame) if direction == DIRECTION_LEFT
        apply_sprite_offset(Outfit_Offsets::RUN_OFFSETS_RIGHT, current_frame) if direction == DIRECTION_RIGHT
        apply_sprite_offset(Outfit_Offsets::RUN_OFFSETS_UP, current_frame) if direction == DIRECTION_UP
      when "surf"
        apply_sprite_offset(Outfit_Offsets::SURF_OFFSETS_DOWN, current_frame) if direction == DIRECTION_DOWN
        apply_sprite_offset(Outfit_Offsets::SURF_OFFSETS_LEFT, current_frame) if direction == DIRECTION_LEFT
        apply_sprite_offset(Outfit_Offsets::SURF_OFFSETS_RIGHT, current_frame) if direction == DIRECTION_RIGHT
        apply_sprite_offset(Outfit_Offsets::SURF_OFFSETS_UP, current_frame) if direction == DIRECTION_UP
      when "dive"
        apply_sprite_offset(Outfit_Offsets::DIVE_OFFSETS_DOWN, current_frame) if direction == DIRECTION_DOWN
        apply_sprite_offset(Outfit_Offsets::DIVE_OFFSETS_LEFT, current_frame) if direction == DIRECTION_LEFT
        apply_sprite_offset(Outfit_Offsets::DIVE_OFFSETS_RIGHT, current_frame) if direction == DIRECTION_RIGHT
        apply_sprite_offset(Outfit_Offsets::DIVE_OFFSETS_UP, current_frame) if direction == DIRECTION_UP
      when "bike"
        apply_sprite_offset(Outfit_Offsets::BIKE_OFFSETS_DOWN, current_frame) if direction == DIRECTION_DOWN
        apply_sprite_offset(Outfit_Offsets::BIKE_OFFSETS_LEFT, current_frame) if direction == DIRECTION_LEFT
        apply_sprite_offset(Outfit_Offsets::BIKE_OFFSETS_RIGHT, current_frame) if direction == DIRECTION_RIGHT
        apply_sprite_offset(Outfit_Offsets::BIKE_OFFSETS_UP, current_frame) if direction == DIRECTION_UP
      when "fish"
        apply_sprite_offset(Outfit_Offsets::FISH_OFFSETS_DOWN, current_frame) if direction == DIRECTION_DOWN
        apply_sprite_offset(Outfit_Offsets::FISH_OFFSETS_LEFT, current_frame) if direction == DIRECTION_LEFT
        apply_sprite_offset(Outfit_Offsets::FISH_OFFSETS_RIGHT, current_frame) if direction == DIRECTION_RIGHT
        apply_sprite_offset(Outfit_Offsets::FISH_OFFSETS_UP, current_frame) if direction == DIRECTION_UP
      end
      adjustPositionForScreenScrolling
      @sprite.y += OverworldZoom.wearable_y_nudge(owzoom_scale_x, owzoom_scale_y)
      @sprite.y -= (2 * owzoom_scale_y).round if current_frame % 2 == 1
    end

    alias __owzoom_redux_wearable_update update unless method_defined?(:__owzoom_redux_wearable_update)

    def update(action, filename, color)
      __owzoom_redux_wearable_update(action, filename, color)
      return if !@sprite || !@player_sprite
      return if !OverworldZoom.active?   # KIF fix: the game's own behaviour when Off
      @sprite.zoom_x = owzoom_scale_x
      @sprite.zoom_y = owzoom_scale_y
      @sprite.visible = @player_sprite.visible
    end
  end

  class AnimationSprite < RPG::Sprite
    # KIF fix: wrapped; the game's own version runs while zoom/perspective are Off
    alias __owzoom_redux_setCoords setCoords unless method_defined?(:__owzoom_redux_setCoords)

    def setCoords
      return __owzoom_redux_setCoords if !(defined?(OverworldZoom) && OverworldZoom.active?)
      raw_x = ((@tileX * Game_Map::REAL_RES_X - @map.display_x) / Game_Map::X_SUBPIXELS).ceil
      raw_x += Game_Map::TILE_WIDTH / 2
      raw_y = ((@tileY * Game_Map::REAL_RES_Y - @map.display_y) / Game_Map::Y_SUBPIXELS).ceil
      raw_y += Game_Map::TILE_HEIGHT
      if defined?(OverworldZoom) && OverworldZoom.active?
        scale = OverworldZoom.current_scale
        self.x = OverworldZoom.project_ground_x(raw_x, raw_y, scale)
        self.y = OverworldZoom.transform_ground_y(raw_y, scale)
        self.zoom_x = OverworldZoom.ground_x_factor(raw_y, scale) * scale
        self.zoom_y = OverworldZoom.ground_row_scale(raw_y, scale)
      else
        self.x = raw_x
        self.y = raw_y
        self.zoom_x = 1.0
        self.zoom_y = 1.0
      end
    end
  end

  module ScreenPosHelper
    # KIF fix: wrapped (the game defines these as ScreenPosHelper.pbScreenZoomX/Y)
    class << self
      alias __owzoom_redux_pbScreenZoomX pbScreenZoomX unless method_defined?(:__owzoom_redux_pbScreenZoomX)
      alias __owzoom_redux_pbScreenZoomY pbScreenZoomY unless method_defined?(:__owzoom_redux_pbScreenZoomY)

      def pbScreenZoomX(ch)
        return __owzoom_redux_pbScreenZoomX(ch) if !OverworldZoom.active?
        return OverworldZoom.character_zoom_x_for(ch)
      end

      def pbScreenZoomY(ch)
        return __owzoom_redux_pbScreenZoomY(ch) if !OverworldZoom.active?
        return OverworldZoom.character_zoom_y_for(ch)
      end
    end
  end

  if defined?(PokeBattle_SceneConstants)
    module PokeBattle_SceneConstants
      class << self
        # KIF fix: wrapped; the game's own versions run at the normal screen size
        alias __owzoom_redux_pbBattlerPosition pbBattlerPosition unless method_defined?(:__owzoom_redux_pbBattlerPosition)
        alias __owzoom_redux_pbTrainerPosition pbTrainerPosition unless method_defined?(:__owzoom_redux_pbTrainerPosition)

        def pbBattlerPosition(index, sideSize = 1)
          return __owzoom_redux_pbBattlerPosition(index, sideSize) if !OverworldZoom.screen_resized?
          player_base_x = 128
          player_base_y = Graphics.height - 80
          foe_base_x = Graphics.width - 128
          foe_base_y = (Graphics.height * 3 / 4) - 112
          ret = ((index & 1) == 0) ? [player_base_x, player_base_y] : [foe_base_x, foe_base_y]
          case sideSize
          when 2
            ret[0] += [-48, 48, 32, -32][index]
            ret[1] += [0, 0, 16, -16][index]
          when 3
            ret[0] += [-80, 80, 0, 0, 80, -80][index]
            ret[1] += [0, 0, 8, -8, 16, -16][index]
          end
          return ret
        end

        def pbTrainerPosition(side, index = 0, sideSize = 1)
          return __owzoom_redux_pbTrainerPosition(side, index, sideSize) if !OverworldZoom.screen_resized?
          player_base_x = 128
          player_base_y = Graphics.height - 80
          foe_base_x = Graphics.width - 128
          foe_base_y = (Graphics.height * 3 / 4) - 112
          ret = (side == 0) ? [player_base_x, player_base_y - 16] : [foe_base_x, foe_base_y + 6]
          case sideSize
          when 2
            ret[0] += [-48, 48, 32, -32][2 * index + side]
            ret[1] += [0, 0, 0, -16][2 * index + side]
          when 3
            ret[0] += [-80, 80, 0, 0, 80, -80][2 * index + side]
            ret[1] += [0, 0, 0, -8, 0, -16][2 * index + side]
          end
          return ret
        end
      end
    end
  end

  if defined?(PokeBattle_Scene)
    class PokeBattle_Scene
      alias __owzoom_redux_pbStartBattle pbStartBattle unless method_defined?(:__owzoom_redux_pbStartBattle)

      def pbStartBattle(battle)
        OverworldZoom.prepare_battle_screen! if OverworldZoom.any_feature_on?   # KIF fix: nothing to do when Off
        __owzoom_redux_pbStartBattle(battle)
      end
    end
  end

  class Scene_Map
    alias __owzoom_redux_main main unless method_defined?(:__owzoom_redux_main)
    alias __owzoom_redux_update update unless method_defined?(:__owzoom_redux_update)

    # KIF fix: the game's own pause menu (the old code called a method that doesn't exist)
    alias __owzoom_redux_call_menu call_menu unless method_defined?(:__owzoom_redux_call_menu)

    def main
      # KIF fix: only when an option is On (the game's own start otherwise); the spritesets
      # are made by main itself, so nothing is rebuilt here
      OverworldZoom.apply!(force_recreate: true) if OverworldZoom.any_feature_on?
      __owzoom_redux_main
    end

    def update
      OverworldZoom.refresh_window_aspect_if_needed if !($game_temp && $game_temp.in_menu)
      __owzoom_redux_update
    end

    def call_menu
      prev_percent = OverworldZoom.setting_percent
      prev_tilt = OverworldZoom.tilt_enabled?
      prev_wide = OverworldZoom.widescreen_enabled?
      __owzoom_redux_call_menu
      changed = OverworldZoom.setting_percent != prev_percent || OverworldZoom.tilt_enabled? != prev_tilt
      # KIF fix: also when everything was just turned Off, so the normal view comes back
      return if !changed && prev_wide == OverworldZoom.widescreen_enabled? && !OverworldZoom.any_feature_on?
      OverworldZoom.apply!(force_recreate: changed)
      $game_player.center($game_player.x, $game_player.y) if $game_player
    end
  end

  class OverworldZoomOptionsScene < PokemonOption_Scene
    def initUIElements
      @sprites["title"] = Window_UnformattedTextPokemon.newWithSize(
        _INTL("Perspective Options"), 0, 0, Graphics.width, 64, @viewport)
      @sprites["textbox"] = pbCreateMessageWindow
      @sprites["textbox"].text = _INTL("Configure overworld zoom, experimental horizon perspective, and adaptive widescreen expansion.")
      @sprites["textbox"].letterbyletter = false
      pbSetSystemFont(@sprites["textbox"].contents)
    end

    def getDefaultDescription
      return OverworldZoom.description_for_percent(OverworldZoom.setting_percent)
    end

    def updateDescription(index)
      if index == 0
        current_value = @sprites && @sprites["option"] ? @sprites["option"][index].to_i : OverworldZoom.setting_percent
        @sprites["textbox"].text = _INTL(OverworldZoom.description_for_percent(current_value))
      elsif index == 1
        @sprites["textbox"].text = _INTL(OverworldZoom.tilt_description)
      else
        @sprites["textbox"].text = _INTL(OverworldZoom.widescreen_description)
      end
    end

    def pbGetOptions(inloadscreen = false)
      return [
        SliderOption.new(
          _INTL("Zoom Out (%)"),
          OverworldZoom::MIN_PERCENT,
          OverworldZoom.max_percent,
          OverworldZoom.slider_step,
          proc { OverworldZoom.setting_percent },
          proc { |value| OverworldZoom.set_setting_percent(value, false) },
          ""
        ),
        EnumOption.new(
          _INTL("Experimental Horizon Perspective"),
          [_INTL("Off"), _INTL("On")],
          proc { OverworldZoom.tilt_mode_index },
          proc { |value| OverworldZoom.set_tilt_mode(value, false) }
        ),
        EnumOption.new(
          _INTL("Adaptive Widescreen"),
          [_INTL("Off"), _INTL("On")],
          proc { OverworldZoom.widescreen_mode_index },
          proc { |value| OverworldZoom.set_widescreen_mode(value, false) }
        )
      ]
    end

    def pbEndScene
      result = super
      OverworldZoom.save_settings
      return result
    end
  end

  # KIF fix: wraps 6.8.2's pbSceneStandby (002_Overworld_BattleIntroAnim.rb:8), which the old
  # code skipped (its alias pointed at a method that doesn't exist)
  alias __owzoom_redux_pbSceneStandby pbSceneStandby unless defined?(__owzoom_redux_pbSceneStandby)

  def pbSceneStandby(&block)
    __owzoom_redux_pbSceneStandby(&block)
    if $scene && $scene.is_a?(Scene_Map) && OverworldZoom.any_feature_on?
      OverworldZoom.apply!
      $game_player.center($game_player.x, $game_player.y) if $game_player
    end
  end

  # KIF fix: pbCallTitle (999_Main.rb) isn't defined everywhere mods load (the old alias failed
  # to load there); the title scene itself is hooked instead, which every way back to the title uses
  class Scene_Intro
    alias __owzoom_redux_intro_main main unless method_defined?(:__owzoom_redux_intro_main)

    def main
      OverworldZoom.restore! if defined?(OverworldZoom) && OverworldZoom.screen_resized?
      return __owzoom_redux_intro_main
    end
  end

  # KIF fix: 6.8.2's options screens never show the base pbGetOptions, so the button
  # and the settings are listed in Options > KIF Settings > Mods instead
  if defined?(ModSettingsMenu)
    ModSettingsMenu.register(OverworldZoom::STORE_KEYS[OverworldZoom::SETTING_KEY], {
      :name => "Zoom Out (%)", :type => :slider, :min => OverworldZoom::MIN_PERCENT,
      :max => OverworldZoom::MAX_PERCENT, :interval => OverworldZoom::STEP_PERCENT, :default => 0,
      :description => "Zoom the overworld camera out. Off is the normal view.", :category => "Interface",
      :on_change => proc { |_v| OverworldZoom.reload_settings! }
    })
    ModSettingsMenu.register(OverworldZoom::STORE_KEYS[OverworldZoom::TILT_KEY], {
      :name => "Horizon Perspective", :type => :toggle, :default => 0,
      :description => "Experimental faux horizon with depth-scaled overworld objects.", :category => "Interface",
      :on_change => proc { |_v| OverworldZoom.reload_settings! }
    })
    ModSettingsMenu.register(OverworldZoom::STORE_KEYS[OverworldZoom::WIDESCREEN_KEY], {
      :name => "Adaptive Widescreen", :type => :toggle, :default => 0,
      :description => "Wider windows and fullscreen expand the overworld and battle view.", :category => "Interface",
      :on_change => proc { |_v| OverworldZoom.reload_settings! }
    })
    ModSettingsMenu.register(:overworld_zoom_redux_options, {
      :name => "Perspective Options", :type => :button,
      :on_press => proc { OverworldZoom.open_options_menu },
      :description => "Configure overworld zoom, experimental horizon perspective, and adaptive widescreen expansion.",
      :category => "Interface"
    })
  end

  if defined?(MultiplayerOptScene)
    class MultiplayerOptScene
      alias __owzoom_redux_multiplayer_pbGetOptions pbGetOptions unless method_defined?(:__owzoom_redux_multiplayer_pbGetOptions)

      def pbGetOptions(inloadscreen = false)
        options = __owzoom_redux_multiplayer_pbGetOptions(inloadscreen)
        options.reject! { |opt| opt.respond_to?(:name) && opt.name == _INTL("Map Zoom") }
        return options
      end
    end
  end

  OverworldZoom.migrate_legacy_setting!

  puts "[Overworld Zoom Redux] Loaded. Perspective options are now active."
end