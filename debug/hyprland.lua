--[[
---- Hyprland loads this file when it is started without a config, and it prefers
-- it over hyprland.conf. HyDE loads it too, last, as the override layer below.
-- The block keeps the two apart: hyde.lua sets `hyde` on its first line, so it
-- runs only when this file is the entry point and HyDE has not been loaded.
-- Removing it leaves a session with a cursor and nothing else. -- Hyprland loads this file when it is started without a config, and it prefers
-- it over hyprland.conf. HyDE loads it too, last, as the override layer below.
-- The block keeps the two apart: hyde.lua sets `hyde` on its first line, so it
-- runs only when this file is the entry point and HyDE has not been loaded.
-- Removing it leaves a session with a cursor and nothing else.
--]]

if not hyde then
	local share = os.getenv("XDG_DATA_HOME") or (os.getenv("HOME") .. "/.local/share")
	local entry = share .. "/hypr/hyde.lua"
	local handle = io.open(entry, "r")
	if not handle then
		error("HyDE is not installed at " .. entry .. ". Run install.sh -r, or point Hyprland at your own config.")
	end
	handle:close()
	dofile(entry)
end

-- Your Hyprland configuration. HyDE never overwrites this file.

--[[
 It loads after HyDE's own binds, so settings here take precedence. Replacing
 a bind needs more than that: see below. HyDE's defaults live in
 ~/.local/share/hypr/lua/ and are overwritten on every update, so edits there
 do not survive.

 Adding a keybind:

     hl.bind("SUPER + SPACE", hl.dsp.exec_cmd(hyde.sh.gamelauncher()), {
         description = "[Utilities] game launcher",
     })

 Replacing one of HyDE's: bind the same combination again and yours takes
 over, but copy its flags across as well. A bind counts as the same one only
 when its flags match, and `description` is not a flag — miss one and both
 binds stay live on that combination. Copy the whole options table from
 ~/.local/share/hypr/lua/key_binds.lua and change only what you need:

     hl.bind("F9", hl.dsp.exec_cmd(hyde.sh.volumecontrol("-o", "m")), {
         locked = true,
         description = "[Hardware Controls|Audio] un/mute output",
     })

 Press SUPER + / to see what is actually loaded, your own binds included.
 The full reference is [KEYBINDINGS.md in the HyDE repository](https://github.com/HyDE-Project/HyDE/blob/master/KEYBINDINGS.md).
]]

-- -- -- -- -- - -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -  -- -- -- -- -- -- -- -- --
-- !! ## ## ## ##
-- !!  Other Lua files next to this one can be pulled in with require("name").
-- !! ## ## ## ##
-- -- -- -- -- - -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -  -- -- -- -- -- -- -- -- --

require("monitors")
-- add others here
--local MOD = hyde.config.modifiers.main

-- -- -- -- -- - -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -  -- -- -- -- -- -- -- -- --
-- !! CUSOTM CONFIGS BELOW
-- -- -- -- -- - -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -  -- -- -- -- -- -- -- -- --

-- Keybind to activate STT (related files: ~/.local/bin/voice-input  && ~/.config/systemd/user/voice-input.service)

hl.bind(
	"ALT + T",
	hl.dsp.exec_cmd("printf start | socat - UNIX-CONNECT:/tmp/voice-input.sock"),
	{ description = "[Audio] start STT using whisper" }
)

hl.bind("ALT + T", hl.dsp.exec_cmd("printf stop | socat - UNIX-CONNECT:/tmp/voice-input.sock"), { release = true })

-- Open Obsidian

hl.bind("SUPER + O", hl.dsp.exec_cmd("hyde-shell app -- obsidian.desktop"), { description = "[Office] notes manager" })

hl.bind("SUPER + E", hl.dsp.exec_cmd("hyde-shell app -T yazi"), { description = "[Launcher|Apps] file explorer" })

hl.bind("SUPER + ALT + C", hl.dsp.exec_cmd("hyde-shell app -T chroncal"), { description = "[Productivity] calendar" })

---

-- Turn of Capslock (fallback use not yet decideed)

hl.config({
	input = {
		kb_options = "ctrl:nocaps",
	},
})
