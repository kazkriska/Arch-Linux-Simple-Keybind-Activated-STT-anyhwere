1. 
```bash 
```
~/.local/share/voice-input/venv/bin/python -c '
from faster_whisper import WhisperModel
WhisperModel(
    "/home/kaz/.local/share/voice-input/models/small",
    device="cpu",
    compute_type="int8"
)
print("LOCAL MODEL OK")
```
```

2.

