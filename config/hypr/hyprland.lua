-- Monitor: hypr decides the scale (the shell sets it later, Rules.monitor)
hl.monitor({ output = "", mode = "highres", position = "auto", scale = "auto" })

-- XWayland is scaled by hypr: blurry on HiDPI, but correct size at any scale. Crisp at integer scale — in user.lua:
--   hl.config({ xwayland = { force_zero_scaling = true } }); hl.env("GDK_SCALE", "2")

-- Configs
require("hyprland.env")
require("hyprland.general")
require("hyprland.input")
require("hyprland.misc")
require("hyprland.animations")
require("hyprland.decoration")
require("hyprland.group")
require("hyprland.execs")
require("hyprland.rules")
require("hyprland.gestures")
require("hyprland.keybinds")

-- own binds and tweaks on top of the rice: hypr/user.lua (in .gitignore, repo updates don't touch it)
local user = io.open(os.getenv("HOME") .. "/.config/hypr/user.lua")
if user then user:close(); require("user") end