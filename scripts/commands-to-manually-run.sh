mkdir -p ~/.local/share/voice-input

python -m venv ~/.local/share/voice-input/venv

~/.local/share/voice-input/venv/bin/pip install faster-whisper

mkdir -p ~/.local/bin

nvim ~/.local/bin/voice-input

# [INSERT the ../src/.local/bin/voice-input code into the above nvim session started]

# Grant the file executable permissions
chmod +x ~/.local/bin/voice-input

---

mkdir -p ~/.local/share/voice-input

python -m venv ~/.local/share/voice-input/venv

~/.local/share/voice-input/venv/bin/pip install faster-whisper

---

# Create the daemon

mkdir -p ~/.config/systemd/user

nvim ~/.config/systemd/user/voice-input.service

# [INSERT the ../src/.config/systemd/user/voice-input.service code into above nvim session]

---

systemctl --user daemon-reload

systemctl --user enable --now voice-input.service

systemctl --user status voice-input.service

## You should see:
#
## voice-input daemon running

---

# After the daemon is running, run:

hyprctl reload

---

~/.local/share/voice-input/venv/bin/python -m pip install -U huggingface_hub

mkdir -p ~/.local/share/voice-input/models

~/.local/share/voice-input/venv/bin/huggingface-cli download \
  Systran/faster-whisper-small \
  --local-dir ~/.local/share/voice-input/models/small

ls -lh ~/.local/share/voice-input/models/small
#You should see model.bin around 484 MB.
