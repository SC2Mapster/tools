#!/usr/bin/lua

-------------------------------------------------------------------------------
-- CONFIG
--

local VERSION = 3
local FOLDER_SC2 = os.getenv("FOLDER_SC2")
local FOLDER_STORM = os.getenv("FOLDER_STORM")
local DRY_RUN = false

local PRUNE_EXCLUDE_SC2 = {
	"novastoryassets.sc2mod"
}
local PRUNE_SC2 = {
	".(sc2mod|sc2campaign)"
}
local INCLUDE_SC2 = {
	"\\.(fx|xml|txt|json|galaxy|SC2Style|SC2Hotkeys|SC2Lib|TriggerLib|SC2Interface|SC2Locale|SC2Components|SC2Layout|SC2Cutscene|SC2Scene)$",
	"\\\\(DocumentInfo|Objects|Regions|Triggers)$"
}
local EXCLUDE_SC2 = {
	"^(?!campaigns|mods)",
	"\\\\editordata\\\\texturereduction",
	"(dede|eses|esmx|frfr|itit|kokr|plpl|ptbr|ruru|zhcn|zhtw)\\.sc2data",
	"(PreloadAssetDB|TextureReductionValues).txt$",
	"nova\\d+.sc2map"
}

local PRUNE_EXCLUDE_STORM = {}
local PRUNE_STORM = {
	".stormmod"
}
local INCLUDE_STORM = {
	"\\.(aitree|fx|xml|txt|json|galaxy|TriggerLib|StormComponents|StormCutscene|StormHotkeys|StormInterface|StormLayout|StormLib|StormLocale|StormStyle)$",
	"\\\\(DocumentInfo|Objects|Regions|Triggers)$"
}
local EXCLUDE_STORM = {
	"\\\\editordata\\\\texturereduction",
	"(dede|eses|esmx|frfr|itit|kokr|plpl|ptbr|ruru|zhcn|zhtw)\\.StormData",
	"(PreloadAssetDB|TextureReductionValues)\\.txt$",
}

-------------------------------------------------------------------------------
-- UTIL
--

local function helpExit(err)
	if err then print("Error: " .. tostring(err)) end
	print(([[
CASC Update Script
version %d - https://github.com/SC2Mapster/tools
by folk, Talv, licensed MIT

  --help      Outputs this text.
  --sc2       Extracts SC2 data.
  --storm     Extracts Heroes of the Storm data.
  --dry       Dry run. Prints commands instead of executing them.

$FOLDER_SC2 and $FOLDER_STORM should point to your local installs of game data.

This tool is made to facilitate extraction of code and XML data from Blizzard
games. For the moment it supports SC2 and Storm, but since it uses stormex,
which in turn uses CascLib, it should be able to handle any game that uses
CASC storage.

Uses sharkdp/fd and Talv/stormex in addition to git and curl.

To see the lists of files extracted from each game, please read the script.]]):format(VERSION))
	os.exit()
end

local _ = function(s) if type(s) ~= "nil" then return tostring(s) end end

local function noop(c)
	return function(...) print("sh$ " .. c .. " " .. table.concat({...}, " ")); return "DRYRUN" end
end

-------------------------------------------------------------------------------
-- ESSENTIAL STARTUP
--

local sh = require("sh")
if type(sh.fork) ~= "string" or sh.fork ~= "folknor" or sh.version < 4 then
	helpExit("Requires folknors fork of luash, with a version higher than 3.")
end

local which = sh.command("which")
for _, req in next, {"curl", "git", "fd", "stormex"} do
	if which(req).__exitcode ~= 0 then helpExit(("`which %s` does not seem to return anything useful."):format(req)) end
end

-------------------------------------------------------------------------------
-- VERSION CHECK
--

local scriptURL = "https://raw.githubusercontent.com/SC2Mapster/tools/master/update"
local scriptSource = _(sh.command("curl")("-s", scriptURL))
if type(scriptSource) == "string" then
	local remote = tonumber(scriptSource:match("local VERSION = (%d+)"))
	if type(remote) == "number" and remote > VERSION then
		local answer
		repeat
			io.write("There is a new version of the release script available, do you want to exit (y/n)? ")
			io.flush()
			answer = io.read()
		until answer == "y" or answer == "n"
		if answer == "y" then return end
	end
end

-------------------------------------------------------------------------------
-- ARGUMENT PARSING + ENV CHECK
--

local _sc2, _storm
for i = 1, select("#", ...) do
	local arg = (select(i, ...)):lower()
	if arg:find("help") then helpExit()
	elseif arg:find("sc2") then _sc2 = true
	elseif arg:find("storm") then _storm = true
	elseif arg:find("dry") then DRY_RUN = true
	end
end
if not _sc2 and not _storm then
	helpExit("You must specify either --sc2 or --storm.")
end
if _storm and ( type(FOLDER_STORM) ~= "string" or #FOLDER_STORM == 0 ) then helpExit("Set $FOLDER_STORM.") end
if _sc2   and ( type(FOLDER_SC2) ~= "string" or #FOLDER_SC2 == 0 )     then helpExit("Set $FOLDER_SC2.") end

-------------------------------------------------------------------------------
-- IMPL
--

local cmd = DRY_RUN and noop or sh.command
local sex = cmd("stormex")
local fd = cmd("fd")
local git = cmd("git")

local function run(src, incl, excl, prune, pruneExcl)
	if src:sub(#src) ~= "/" then src = src .. "/" end
	if src:find("\\") then print("folk you idiot, you put \\ in the path again."); return end
	print("Updating " .. src .. " ...")

	local isgit = git("-C . rev-parse 2>/dev/null")
	if tonumber(isgit.__exitcode) == 0 or DRY_RUN then
		print("Current folder is a git repo, pruning old extracted files ...")
		for _, p in next, prune do
			local pruneArgs = {
				"-i", "'" .. p .. "'", "-t d", "-j 1"
			}
			for _, e in next, pruneExcl do
				table.insert(pruneArgs, "-E '" .. e .. "'")
			end
			table.insert(pruneArgs, "-x rm -r {}")
			fd(table.unpack(pruneArgs))
		end
	end

	local extractArgs = {
		"-v -S '" .. src .. "'",
		"-x",
	}
	for _, e in next, incl do
		table.insert(extractArgs, "-I '" .. e .. "'")
	end
	for _, e in next, excl do
		table.insert(extractArgs, "-E '" .. e .. "'")
	end
	print("Extracting files ...")
	local output = _(sex(table.unpack(extractArgs)))
	print(output)
end

if _sc2 then run(FOLDER_SC2, INCLUDE_SC2, EXCLUDE_SC2, PRUNE_SC2, PRUNE_EXCLUDE_SC2) end
if _storm then run(FOLDER_STORM, INCLUDE_STORM, EXCLUDE_STORM, PRUNE_STORM, PRUNE_EXCLUDE_STORM) end
print("Done.")
