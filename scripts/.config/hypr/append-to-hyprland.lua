-- this goes in the ~/.config/hypr/hyprland.lua file

-- starts on press, hold while you speak
hl.bind("SUPER + SPACE", hl.dsp.exec_cmd("printf start | socat - UNIX-CONNECT:/tmp/voice-input.sock"), {
	description = "[Audio] start STT using whisper",
})

-- reslease when done speaking
hl.bind(
	"SUPER + SPACE",
	hl.dsp.exec_cmd("printf stop | socat - UNIX-CONNECT:/tmp/voice-input.sock"),
	{ release = true }
)

-- finally run >> $ hyprctl reload
