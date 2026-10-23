#========================================
# Save Delete
# PIF Version: 6.4.5
# KIF Version: 0.20.7
# Script Version: 1.0.1
# Author: Stonewall
# Delete Save Game Functionality with SPECIAL (D/(RS)) Input
#========================================
# KIF fix: this used to replace the whole load screen (PokemonLoad_Scene#pbChoose
# and PokemonLoadScreen#pbStartLoadScreen) with a copy from PIF 6.4.5, which
# dropped everything 6.8.2 and KIF add there. It now wraps the game's own load
# screen and only adds this mod's parts: D on the save panel, and the
# "Save Delete Settings" screen (load menu and KIF Settings > Mods).

module SaveDeleteMod
  FOLDER     = "DELETED SAVES"
  MENU_LABEL = "Save Delete Settings"
  MENU_URL   = "savedelete:settings"   # KIF fix: rides on 6.8.2's load-menu links (see openUrlInBrowser below)

  class << self
    attr_accessor :jump   # [slot] the load menu shows next (slot may be nil: no saves left)
  end

  def self.save_dir; return SaveData::SAVE_DIR.to_s; end
  def self.deleted_folder; return File.join(save_dir, FOLDER); end

  # A save's files in dir: "<base>.rxdata", "<base>.rxdata.bak" and the
  # author's autosave names ("<base> ..." / "<base>.*")
  def self.related(dir, base)
    return [] unless base && Dir.exist?(dir)
    return Dir.children(dir).select do |f|
      File.file?(File.join(dir, f)) && (f.start_with?(base + " ") || f.start_with?(base + "."))
    end.sort
  end

  # KIF fix: moves never write over a file; a name already taken in the
  # target folder gets the next free "<base>~2", "<base>~3"... instead
  def self.free_base(dir, base)
    cand = base
    n = 2
    while !related(dir, cand).empty?
      cand = "#{base}~#{n}"
      n += 1
    end
    return cand
  end

  # Moves a save's files from src to dst, renaming base to new_base; a file
  # whose new name is taken stays where it is. Returns how many moved.
  def self.move_group(src, dst, base, new_base)
    Dir.mkdir(dst) unless Dir.exist?(dst)
    count = 0
    related(src, base).each do |f|
      dest = File.join(dst, new_base + f[base.length..-1])
      next if File.exist?(dest)
      begin
        File.rename(File.join(src, f), dest)
        count += 1
      rescue SystemCallError
      end
    end
    return count
  end

  # D on the save panel. Returns true when the save was moved.
  def self.delete_prompt(slot)
    files = related(save_dir, slot)
    return false if files.empty?
    autosave_count = (files - [slot + ".rxdata", slot + ".rxdata.bak"]).length   # KIF fix: was "files - 2"
    if autosave_count > 0
      delete_msg = _INTL("Delete '{1}' and {2} autosave(s)?", slot, autosave_count)
    else
      delete_msg = _INTL("Delete the save file '{1}'?", slot)
    end
    return false unless pbConfirmMessageSerious(delete_msg)
    pbMessage(_INTL("Total files to be moved: {1}\\nThey will be moved to DELETED SAVES folder.\\wtnp[30]", files.length))
    return false unless pbConfirmMessageSerious(_INTL("Are you absolutely sure?"))
    moved = move_group(save_dir, deleted_folder, slot, free_base(deleted_folder, slot))
    pbMessage(_INTL("Moved {1} files to DELETED SAVES.", moved))
    return true
  end

  # the first save left (the author's choice after a delete), or nil
  def self.first_save
    (SaveData::AUTO_SLOTS + SaveData::MANUAL_SLOTS).each do |slot|
      return slot if File.file?(SaveData.get_full_path(slot))
    end
    return nil
  end

  def self.open_settings
    pbFadeOutIn {
      scene = SaveDeleteSettings_Scene.new
      screen = SaveDeleteSettings_Screen.new(scene)
      screen.pbStartScreen
    }
  end

  # KIF fix: D is read after the game's own pbUpdate, only while the save
  # panel (Continue) is selected and the language icon isn't
  module SceneHook
    def pbChoose(*args)
      loop do
        @save_delete_idx = args[1]
        ret = catch(:save_delete) { super(*args) }
        @save_delete_idx = nil
        return ret unless ret == :save_delete
        slot = args[0][args[1]]   # the Continue entry is the slot's name
        if slot && SaveDeleteMod.delete_prompt(slot)
          SaveDeleteMod.jump = [SaveDeleteMod.first_save]
          return -3   # the game reloads its slots, as after Left (see get_prev_slot below)
        end
      end
    ensure
      @save_delete_idx = nil
    end

    def pbUpdate(*args)
      ret = super
      idx = @save_delete_idx
      if idx && idx >= 0 && !@language_option_selected && @sprites && @sprites["cmdwindow"] &&
         @sprites["cmdwindow"].index == idx && Input.trigger?(Input::SPECIAL)
        @save_delete_idx = nil
        pbPlayDecisionSE
        throw :save_delete, :save_delete
      end
      return ret
    end
  end
end

PokemonLoad_Scene.prepend(SaveDeleteMod::SceneHook)

# KIF fix: after a delete the game's own Left handling (pbCloseScene, reload)
# lands on the slot the author picked, or on no save when none is left
module SaveData
  class << self
    alias save_delete_get_prev_slot get_prev_slot unless method_defined?(:save_delete_get_prev_slot)
    def get_prev_slot(file_list, file)
      if (j = SaveDeleteMod.jump)
        SaveDeleteMod.jump = nil
        return j[0]
      end
      return save_delete_get_prev_slot(file_list, file)
    end
  end
end

# KIF fix: "Save Delete Settings" on the load menu, through 6.8.2's link list
# (the same way KIF adds "Import Old Saves")
if defined?(Settings::MAIN_MENU_LINKS) && Settings::MAIN_MENU_LINKS.is_a?(Hash) && !Settings::MAIN_MENU_LINKS.frozen?
  Settings::MAIN_MENU_LINKS[SaveDeleteMod::MENU_LABEL] = SaveDeleteMod::MENU_URL
end

alias save_delete_openUrlInBrowser openUrlInBrowser unless defined?(save_delete_openUrlInBrowser)
def openUrlInBrowser(url = "")
  return SaveDeleteMod.open_settings if url == SaveDeleteMod::MENU_URL
  return save_delete_openUrlInBrowser(url)
end

#===============================================================================
# Save Delete Settings Menu
#===============================================================================
class SaveDeleteSettings_Scene
  def pbStartScene
    @viewport = Viewport.new(0, 0, Graphics.width, Graphics.height)
    @viewport.z = 99999
    @sprites = {}

    addBackgroundOrColoredPlane(@sprites, "background", "optionsbg",
                                Color.new(64, 64, 64), @viewport)

    @sprites["header"] = Window_UnformattedTextPokemon.newWithSize(
      _INTL("Save Delete Settings"), 0, 0, Graphics.width, 64, @viewport)
    @sprites["header"].baseColor = Color.new(248, 248, 248)
    @sprites["header"].shadowColor = Color.new(0, 0, 0)

    disk_info = get_deleted_saves_disk_info
    info_text = _INTL("Manage deleted save files\n{1} file(s) using {2}",
                      disk_info[:count], disk_info[:size_text])

    @sprites["textbox"] = Window_UnformattedTextPokemon.newWithSize(
      info_text, 0, 64, Graphics.width, 96, @viewport)

    @commands = []
    @commands.push(_INTL("Restore Deleted Saves"))
    @commands.push(_INTL("Clean Up Deleted Saves"))
    @commands.push(_INTL("View Deleted Saves Folder"))
    @commands.push(_INTL("Back"))

    @sprites["cmdwindow"] = Window_CommandPokemon.new(@commands)
    @sprites["cmdwindow"].viewport = @viewport
    @sprites["cmdwindow"].x = 0
    @sprites["cmdwindow"].y = 160
    @sprites["cmdwindow"].width = Graphics.width
    @sprites["cmdwindow"].height = Graphics.height - 160

    pbFadeInAndShow(@sprites)
  end

  def pbEndScene
    pbFadeOutAndHide(@sprites)
    pbDisposeSpriteHash(@sprites)
    @viewport.dispose
  end

  def pbUpdate
    pbUpdateSpriteHash(@sprites)
  end

  def pbRefreshDiskInfo
    disk_info = get_deleted_saves_disk_info
    info_text = _INTL("Manage deleted save files\n{1} file(s) using {2}",
                      disk_info[:count], disk_info[:size_text])
    @sprites["textbox"].text = info_text
  end

  def get_deleted_saves_disk_info
    deleted_folder = SaveDeleteMod.deleted_folder

    count = 0
    total_bytes = 0

    if Dir.exist?(deleted_folder)
      Dir.foreach(deleted_folder) do |filename|
        next if filename == '.' || filename == '..'
        full_path = File.join(deleted_folder, filename)
        if File.file?(full_path)
          count += 1
          total_bytes += File.size(full_path)
        end
      end
    end

    size_text = format_file_size(total_bytes)

    return { count: count, total_bytes: total_bytes, size_text: size_text }
  end

  def format_file_size(bytes)
    return "0 bytes" if bytes == 0
    return "#{bytes} bytes" if bytes < 1024

    kb = bytes / 1024.0
    return "#{kb.round(1)} KB" if kb < 1024

    mb = kb / 1024.0
    return "#{mb.round(2)} MB" if mb < 1024

    gb = mb / 1024.0
    return "#{gb.round(2)} GB"
  end

  def pbGetChoice
    @sprites["cmdwindow"].index = 0
    loop do
      Graphics.update
      Input.update
      pbUpdate
      if Input.trigger?(Input::BACK)
        return -1
      elsif Input.trigger?(Input::USE)
        return @sprites["cmdwindow"].index
      end
    end
  end
end

class SaveDeleteSettings_Screen
  def initialize(scene)
    @scene = scene
  end

  def pbStartScreen
    @scene.pbStartScene
    loop do
      choice = @scene.pbGetChoice
      case choice
      when 0  # Restore Deleted Saves
        pbRestoreDeletedSaves
        @scene.pbRefreshDiskInfo
      when 1  # Clean Up Deleted Saves
        pbCleanUpDeletedSaves
        @scene.pbRefreshDiskInfo
      when 2  # View Deleted Saves Folder
        pbOpenDeletedSavesFolder
      when 3, -1  # Back
        break
      end
    end
    @scene.pbEndScene
  end

  def pbRestoreDeletedSaves
    save_dir = SaveDeleteMod.save_dir
    deleted_folder = SaveDeleteMod.deleted_folder

    if !Dir.exist?(deleted_folder)
      pbMessage(_INTL("No deleted saves folder found."))
      return
    end

    save_files = []
    Dir.foreach(deleted_folder) do |filename|
      next if filename == '.' || filename == '..'
      next unless filename.end_with?(".rxdata")
      next if filename.end_with?(".rxdata.bak")
      save_files.push(filename)
    end

    if save_files.empty?
      pbMessage(_INTL("No deleted save files found to restore."))
      return
    end

    save_files.sort!

    commands = save_files + [_INTL("Cancel")]
    choice = pbMessage(_INTL("Which save file would you like to restore?"), commands, commands.length - 1)

    if choice >= 0 && choice < save_files.length
      selected_file = save_files[choice]
      base_name = selected_file.chomp(".rxdata")

      if pbConfirmMessage(_INTL("Restore '{1}'?", base_name))
        # KIF fix: never write over a save. A save whose slot is in use (or
        # that isn't a slot name) goes into a free slot, after asking.
        target = base_name
        if !(SaveData::AUTO_SLOTS + SaveData::MANUAL_SLOTS).include?(base_name) ||
           !SaveDeleteMod.related(save_dir, base_name).empty?
          free = SaveData::MANUAL_SLOTS.find { |s| SaveDeleteMod.related(save_dir, s).empty? }
          if !free
            pbMessage(_INTL("'{1}' can't go back to its own slot and every save slot is in use. Delete or move a save first.", base_name))
            return
          end
          return unless pbConfirmMessage(_INTL("'{1}' can't go back to its own slot. Restore it as '{2}' instead?", base_name, free))
          target = free
        end
        restored_count = SaveDeleteMod.move_group(deleted_folder, save_dir, base_name, target)
        pbMessage(_INTL("Restored {1} files for '{2}'.", restored_count, target))
      end
    end
  end

  def pbCleanUpDeletedSaves
    deleted_folder = SaveDeleteMod.deleted_folder

    if !Dir.exist?(deleted_folder)
      pbMessage(_INTL("No deleted saves folder found."))
      return
    end

    file_count = 0
    total_bytes = 0
    Dir.foreach(deleted_folder) do |filename|
      next if filename == '.' || filename == '..'
      full_path = File.join(deleted_folder, filename)
      if File.file?(full_path)
        file_count += 1
        total_bytes += File.size(full_path)
      end
    end

    if file_count == 0
      pbMessage(_INTL("The deleted saves folder is already empty."))
      return
    end

    size_text = @scene.format_file_size(total_bytes)

    if pbConfirmMessageSerious(_INTL("Permanently delete all {1} files ({2})?", file_count, size_text))
      pbMessage(_INTL("This will free up {1} of disk space.\nThis cannot be undone!\\wtnp[30]", size_text))
      if pbConfirmMessageSerious(_INTL("Are you absolutely sure?"))
        deleted_count = 0
        Dir.foreach(deleted_folder) do |filename|
          next if filename == '.' || filename == '..'
          full_path = File.join(deleted_folder, filename)
          begin
            if File.file?(full_path)
              File.delete(full_path)
              deleted_count += 1
            end
          rescue SystemCallError
          end
        end
        pbMessage(_INTL("Permanently deleted {1} files.", deleted_count))
      end
    end
  end

  def pbOpenDeletedSavesFolder
    deleted_folder = SaveDeleteMod.deleted_folder

    if !Dir.exist?(deleted_folder)
      pbMessage(_INTL("No deleted saves folder found."))
      Dir.mkdir(deleted_folder)
      pbMessage(_INTL("Created DELETED SAVES folder."))
    end

    # KIF fix: opens only the fixed "<save folder>\DELETED SAVES" path, with no
    # shell (like KIF's own "Open the save folder"); elsewhere the path is shown
    begin
      if System.platform[/Windows/] && !(defined?(KIF.mobile?) && KIF.mobile?)
        system("explorer", File.expand_path(deleted_folder).gsub("/", "\\"))
        pbMessage(_INTL("Opening DELETED SAVES folder..."))
      else
        pbMessage(_INTL("Could not open folder. Path:\n{1}", deleted_folder))
      end
    rescue
      pbMessage(_INTL("Could not open folder. Path:\n{1}", deleted_folder))
    end
  end
end

#===============================================================================
# Register with ModSettingsMenu
#===============================================================================
if defined?(ModSettingsMenu)
  # KIF fix: register_option drops a button's action in KIF; a :button row keeps it
  ModSettingsMenu.register(:save_delete_settings, {
    :name        => "Save Delete Settings",
    :type        => :button,
    :on_press    => proc { SaveDeleteMod.open_settings },
    :description => "Manage deleted save files and clean up old saves",
    :category    => "Quality of Life"
  })
end
