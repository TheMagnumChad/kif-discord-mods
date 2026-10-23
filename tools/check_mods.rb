# Checks every mod folder in this catalog the way KIF reads it.
#
#   ruby tools/check_mods.rb            every mod
#   ruby tools/check_mods.rb a b        only folders a and b
#
# Fails (exit 1) on anything that would break the mod in the game or make it
# unsafe to merge without a closer look. Warnings don't fail, but are listed
# for the reviewer: they mark code worth reading before merging (programs
# started, files deleted, downloads).
# Written to GITHUB_STEP_SUMMARY when it runs as a GitHub Action.
require "json"

# MODS_ROOT: the catalog to check (the Action runs main's copy of this script
# on the pull request's files, so a pull request can't change the rules)
ROOT = File.expand_path(ENV["MODS_ROOT"] || File.join(__dir__, ".."))
SKIP = %w[.git .github tools modpacks].freeze
ID = /\A[a-z0-9][a-z0-9_\-]*\z/
VERSION = /\A\d+(\.\d+){0,3}([a-z0-9.\-]*)?\z/i
BLOCKED_EXT = %w[.exe .dll .bat .cmd .ps1 .vbs .msi .scr .com .jar .so .dylib .sh .lnk .zip .7z .rar].freeze
MAX_FILE = 25 * 1024 * 1024
MAX_MOD = 100 * 1024 * 1024
LIST_FIELDS = %w[scripts dependencies load_after incompatible replaces credits].freeze
# Code a reviewer should read (not forbidden: some mods have a reason)
RISKY = {
  /\b(system|spawn|exec)\s*[(\s]["'\w]/ => "starts a program",
  /`[^`\n]+`|%x[({\[]/ => "starts a program (backticks)",
  /IO\.popen|Open3/ => "starts a program",
  /Win32API|Fiddle|DL\.dlopen/ => "calls Windows directly",
  /Net::HTTP|TCPSocket|UDPSocket|URI\.open|open-uri/ => "uses the network",
  /File\.(delete|unlink)|FileUtils\.(rm|rm_rf|rm_r|remove)|Dir\.(delete|rmdir|unlink)/ => "deletes files",
  /Marshal\.load/ => "loads Marshal data (only safe for the mod's own files)",
  /\beval\s*\(|instance_eval\s*\(\s*[a-z]|binding\.eval/ => "evaluates text as code",
  /ENV\[/ => "reads environment variables"
}.freeze

def mod_dirs(names)
  all = Dir.children(ROOT).select { |d| File.directory?(File.join(ROOT, d)) && !SKIP.include?(d) && !d.start_with?(".") }.sort
  return all if names.empty?
  return names.select { |n| all.include?(n) }
end

errors = Hash.new { |h, k| h[k] = [] }
warns = Hash.new { |h, k| h[k] = [] }
ids = {}
all_ids = {}

# ids of every mod in the catalog (a pull request's mod must not reuse one)
mod_dirs([]).each do |d|
  j = (JSON.parse(File.read(File.join(ROOT, d, "mod.json"), encoding: "UTF-8")) rescue nil)
  all_ids[d] = j["id"].to_s if j.is_a?(Hash) && j["id"]
end

checked = mod_dirs(ARGV)
checked.each do |dir|
  path = File.join(ROOT, dir)
  err = errors[dir]
  warn = warns[dir]
  jpath = File.join(path, "mod.json")
  unless File.file?(jpath)
    err << "no mod.json in the folder"
    next
  end
  json = begin
    JSON.parse(File.read(jpath, encoding: "UTF-8"))
  rescue JSON::ParserError, ArgumentError => e
    err << "mod.json isn't valid JSON (#{e.message.lines.first.strip})"
    next
  end
  unless json.is_a?(Hash)
    err << "mod.json must be an object { ... }"
    next
  end
  id = json["id"].to_s
  err << "\"id\" is missing or has characters other than a-z, 0-9, _ and - (got #{json['id'].inspect})" unless id =~ ID
  %w[name author description].each { |k| err << "\"#{k}\" is missing" if json[k].to_s.strip.empty? }
  err << "\"version\" should look like 1.0 or 1.2.3 (got #{json['version'].inspect})" unless json["version"].to_s =~ VERSION
  if (other = all_ids.find { |d, i| i == id && d != dir })
    err << "id \"#{id}\" is already used by #{other[0]}"
  end
  err << "id \"#{id}\" appears twice in this check" if ids[id] && ids[id] != dir
  ids[id] = dir
  LIST_FIELDS.each do |k|
    next unless json.key?(k)
    v = json[k]
    ok = v.is_a?(Array) && v.all? { |x| x.is_a?(String) || (x.is_a?(Hash) && x["id"]) }
    err << "\"#{k}\" must be a list of names" unless ok
  end
  if json.key?("requires_kif") && json["requires_kif"].to_s !~ /\A\s*([<>=]=?\s*)?\d+(\.\d+)*(\s*,\s*([<>=]=?\s*)?\d+(\.\d+)*)*\s*\z/
    err << "\"requires_kif\" should look like \">=1.1.0\" or \">=1.1.0, <2.0\""
  end
  if json.key?("catalog") && json["catalog"].to_s !~ %r{\A[\w.\-]+/[\w.\-]+(@[\w.\-/]+)?\z}
    err << "\"catalog\" should look like owner/repo or owner/repo@branch"
  end
  warn << "sets settings for the player (\"locks\": #{json['locks'].keys.join(', ')})" if json["locks"].is_a?(Hash) && !json["locks"].empty?
  warn << "takes over KIF features (\"replaces\": #{Array(json['replaces']).join(', ')})" unless Array(json["replaces"]).empty?

  files = Dir.glob(File.join(path, "**", "*"), File::FNM_DOTMATCH).select { |f| File.file?(f) }
  total = 0
  files.each do |f|
    rel = f.sub(path + "/", "")
    size = File.size(f)
    total += size
    err << "#{rel}: #{File.extname(f)} files aren't allowed (unpack archives; no programs)" if BLOCKED_EXT.include?(File.extname(f).downcase)
    err << "#{rel}: #{(size / 1048576.0).round(1)} MB, over the 25 MB limit per file" if size > MAX_FILE
  end
  err << "#{(total / 1048576.0).round(1)} MB in all, over the 100 MB limit per mod" if total > MAX_MOD

  scripts = Array(json["scripts"]).map(&:to_s)
  scripts.each { |s| err << "script \"#{s}\" listed in mod.json isn't in the folder" unless File.file?(File.join(path, s)) }
  rbs = files.select { |f| f.end_with?(".rb") }
  err << "no .rb scripts" if rbs.empty? && scripts.empty? && !json["assets_only"]
  rbs.each do |f|
    rel = f.sub(path + "/", "")
    src = File.binread(f).force_encoding("UTF-8")
    unless src.valid_encoding?
      err << "#{rel}: not UTF-8 text"
      next
    end
    begin
      RubyVM::InstructionSequence.compile(src, rel)
    rescue SyntaxError => e
      err << "#{rel}: doesn't compile: #{e.message.lines.first(2).join(' ').strip}"
      next
    end
    src.each_line.with_index(1) do |line, n|
      next if line.lstrip.start_with?("#")
      RISKY.each { |re, what| warn << "#{rel}:#{n} #{what}: `#{line.strip[0, 90]}`" if line =~ re }
    end
  end
end

out = []
out << "## Mod check"
out << ""
checked.each do |d|
  e = errors[d]
  w = warns[d]
  out << "### #{e.empty? ? 'OK' : 'FAILED'}: #{d}"
  e.each { |m| out << "- **error:** #{m}" }
  unless w.empty?
    out << "- Worth a look before merging:"
    w.first(40).each { |m| out << "  - #{m}" }
    out << "  - ... and #{w.length - 40} more" if w.length > 40
  end
  out << ""
end
out << "No mod folders to check." if checked.empty?
text = out.join("\n")
puts text
File.open(ENV["GITHUB_STEP_SUMMARY"], "a") { |f| f.puts(text) } if ENV["GITHUB_STEP_SUMMARY"]
exit(checked.any? { |d| !errors[d].empty? } ? 1 : 0)
