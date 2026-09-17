# REVISED PLAN: STT-Local-Whisper Hardening
## Date: 2026-09-17

This document supersedes all previous analysis. It reflects the
user's direct feedback and the real installed system state.


═══════════════════════════════════════════════════════════════
  USER DECISIONS (final)
═══════════════════════════════════════════════════════════════

  1. KEEP ALT+T keybind — no change to HyDE config
  2. LOCK bluetooth profile to HFP while recording
  3. NOTIFICATION OVERLAY via dunstify — stateful, dynamic
  4. KEEP language="en" — already handles Hinglish well
  5. ADD log-to-file for crash recovery


═══════════════════════════════════════════════════════════════
  PART 1: BLUETOOTH LOCK MECHANISM
═══════════════════════════════════════════════════════════════

  PROBLEM
  ─────────
  Bluetooth headset (Mod, 8C:0D:D9:58:20:F2) runs on a2dp
  (high quality playback) by default. When a notification or
  any system event triggers audio, the BT profile can
  momentarily switch or drop the input stream, corrupting the
  recording.

  GOAL
  ─────
  On ALT+T press:
    - Switch headset to HFP/HSP profile (headset-head-unit)
    - This keeps the SCO connection stable for input

  On ALT+T release (with grace period for transcription):
    - After transcription completes, switch back to a2dp
      for music quality

  TOOLS
  ─────
  - pactl: pulseaudio compatibility layer (works over PipeWire)
  - bluez5 device id: bluez_card.8C_0D_D9_58_20_F2

  TARGET PROFILES
  ───────────────
  Lock ON (recording):   headset-head-unit
  Lock OFF (idle):       a2dp-sink  (or whatever was active)

  IMPLEMENTATION NOTES
  ────────────────────
  - Cannot use "lock" in the kernel sense — Bluetooth profiles
    are cooperative. We use pactl set-card-profile to force
    the profile and then refuse to change it during recording.
  - On start_recording(): force HFP profile
  - On stop_recording(): schedule A2DP restore after transcription
  - Must track "previous profile" so we restore what the user
    had, not blindly set a2dp
  - This is a soft lock — other processes CAN still change it,
    but we monitor and re-set if needed


═══════════════════════════════════════════════════════════════
  PART 2: NOTIFICATION OVERLAY SYSTEM
═══════════════════════════════════════════════════════════════

  TOOL: dunstify (already installed at /usr/bin/dunstify)

  KEY FEATURES WE'LL USE:
  ───────────────────────
  -r / --replace-id    Update existing notification in-place
  -t / --expire-time   Set duration (0 = never expire)
  -u / --urgency       low, normal, critical
  -a / --app-name      Group under "voice-input"
  -i / --icon          Use microphone icon
  --stack-tag          Tag for replacement grouping

  NOTIFICATION STATES:
  ────────────────────
  ID: persistent notification with replace-id

  STATE 1 — LISTENING (on key press)
    Summary: "Voice Input: Listening..."
    Body:    "Speak now. Release ALT+T when done."
    Icon:    microphone
    Urgency: normal
    Expiry:  0 (never expires while recording)

  STATE 2 — TRANSCRIBING (VAD detected speech, processing)
    Summary: "Voice Input: Transcribing..."
    Body:    "Processing your speech..."
    Urgency: normal

  STATE 3 — FINALIZING (key released, audio ended,
                         transcription running)
    Summary: "Voice Input: Finalizing..."
    Body:    "Almost done..."
    Urgency: normal

  STATE 4 — DONE (transcription complete, text injected)
    Summary: "Voice Input: Done"
    Body:    "<transcribed text preview>"
    Expiry:  3000ms (auto-fade after 3 seconds)
    Urgency: low

  STATE 5 — ERROR
    Summary: "Voice Input: Error"
    Body:    "<error description>"
    Expiry:  5000ms
    Urgency: critical

  FLOW:
  ─────
  ALT+T pressed
    → dunstify -r 999 -t 0 -u normal -a "voice-input"
      -i "microphone-input"
      "Voice Input: Listening..." "Speak now."

  (recording... VAD detects speech)
    → dunstify -r 999 -t 0 -u normal -a "voice-input"
      -i "microphone-input"
      "Voice Input: Transcribing..." "Processing..."

  ALT+T released
    → dunstify -r 999 -t 0 -u normal -a "voice-input"
      -i "microphone-input"
      "Voice Input: Finalizing..." "Almost done..."

  (transcription done)
    → dunstify -r 999 -t 3000 -u low -a "voice-input"
      -i "microphone-input"
      "Voice Input: Done" "Hello world this is a test"

  NOTE: dunstify -r uses replace-id. First call must print-id
  to get the ID, then we reuse it for subsequent updates.


═══════════════════════════════════════════════════════════════
  PART 3: LOGGING & CRASH RECOVERY
═══════════════════════════════════════════════════════════════

  LOG FILE: /tmp/voice-input.log

  CONTENTS:
  ─────────
  - Timestamp of each start/stop event
  - Duration of recording
  - Transcribed text (full)
  - Audio file size
  - Any errors/exceptions

  FORMAT:
  ────────
  [2026-09-17 17:30:01] START recording
  [2026-09-17 17:30:05] STOP recording (4.2s)
  [2026-09-17 17:30:05] TRANSCRIBING...
  [2026-09-17 17:30:07] RESULT: "Hello world this is a test"
  [2026-09-17 17:30:07] INJECTED via wtype

  CRASH RECOVERY:
  ───────────────
  On startup, the daemon checks for a stale /tmp/voice-input.wav
  and /tmp/voice-input.sock. If found, it logs:
    "RECOVERY: Found stale recording from previous crash"
    "RECOVERY: Audio file size: N bytes"
  The audio file is preserved for potential recovery.
  The user can recover the last recording manually.


═══════════════════════════════════════════════════════════════
  PART 4: CRITICAL BREAKPOINT FIXES (from crash analysis)
═══════════════════════════════════════════════════════════════

  B1 — NO SIGNAL HANDLING → FIX
    Add signal.signal(signal.SIGTERM, cleanup_handler)
    Add signal.signal(signal.SIGINT, cleanup_handler)
    On signal: cleanup() then sys.exit(0)

  B2 — NO EXCEPTION HANDLING → FIX
    Wrap stop_recording() in try/except:
      try:
          # entire transcription pipeline
      except Exception as e:
          log_error(e)
          show_notification("error", str(e))
          # daemon CONTINUES running

  B3 — recorder.wait() TIMEOUT → FIX
    recorder.terminate()
    try:
        recorder.wait(timeout=5)
    except subprocess.TimeoutExpired:
        recorder.kill()   # SIGKILL, guaranteed to die
        recorder.wait()

  B4 — NO MAX RECORDING DURATION → FIX
    Add threading.Timer(60, force_stop_recording)
    On stop: cancel timer
    On timer fire: terminate recorder, log warning

  B5 — RACE CONDITION ON DOUBLE START → FIX
    (Already handled by existing check, but add logging)

  B6 — AUDIO FILE VALIDATION → FIX
    Check file size > 0 before transcription
    If 0 bytes: skip, log error, notify user

  B7 — PIPEWIRE HEALTH CHECK → FIX
    On start_recording():
      - Check `pw-record` is available (`which pw-record`)
      - Optionally: run `pw-record --version` for sanity
    If check fails: notify user, abort gracefully

  B8 — GLOBAL STATE → FIX (low priority)
    Add threading.Lock() for recorder and model access


═══════════════════════════════════════════════════════════════
  PART 5: TASK LIST (execution order)
═══════════════════════════════════════════════════════════════

  Phase 1 — Foundation (CRITICAL)
  ─────────────────────────────────

  T1.1  Add signal handlers for SIGTERM/SIGINT
  T1.2  Add try/except around stop_recording()
  T1.3  Add timeout to recorder.wait()
  T1.4  Add logging to /tmp/voice-input.log

  Phase 2 — Bluetooth Lock
  ─────────────────────────

  T2.1  Add get_current_bluetooth_profile() function
  T2.2  Add set_bluetooth_profile(profile) function
  T2.3  Call set HFP in start_recording()
  T2.4  Call restore profile after transcription (post-stop)

  Phase 3 — Notification Overlay
  ───────────────────────────────

  T3.1  Add notify(state, message) function
  T3.2  Call notify("listening") in start_recording()
  T3.3  Call notify("transcribing") when speech detected
  T3.4  Call notify("finalizing") in stop_recording()
  T3.5  Call notify("done") after successful transcription
  T3.6  Call notify("error") on any exception

  Phase 4 — Robustness
  ─────────────────────

  T4.1  Add max recording timer (60s)
  T4.2  Add audio file size validation
  T4.3  Add PipeWire health check
  T4.4  Add crash recovery logging on startup
  T4.5  Add thread safety with Lock()


═══════════════════════════════════════════════════════════════
  PART 6: FILES TO MODIFY
═══════════════════════════════════════════════════════════════

  PRIMARY:
    ~/.local/bin/voice-input         (the daemon — all changes here)

  SECONDARY:
    ~/.config/hypr/hyprland.lua      (keybind stays ALT+T,
                                      no changes needed)

    ~/.config/systemd/user/voice-input.service
                                     (add audio group if needed,
                                      no functional changes)

  NEW FILES (in repo only):
    debug/docs/REVISED_PLAN.md       (this file)
    debug/docs/CHANGELOG.md          (track changes)


═══════════════════════════════════════════════════════════════
  PART 7: TESTING CHECKLIST
═══════════════════════════════════════════════════════════════

  After applying fixes, verify:

  [ ] Basic record/release works
  [ ] Notification appears on press, updates on release,
      fades after done
  [ ] Bluetooth profile switches to HFP on press, back
      to A2DP on release
  [ ] Log file is created and populated
  [ ] Double-press (press-release-press) doesn't crash
  [ ] Very long press (>60s) auto-stops
  [ ] Very short press (<0.5s) handles gracefully
  [ ] Log contains entries for each test
  [ ] Simulated crash (kill -9) recovers cleanly
  [ ] After recovery, stale audio is logged but not lost


═══════════════════════════════════════════════════════════════
  APPENDIX: KEY TECHNICAL DETAILS
═══════════════════════════════════════════════════════════════

  Bluetooth device path:
    bluez_card.8C_0D_D9_58_20_F2

  Headset HFP profile name (PulseAudio compat):
    headset-head-unit

  A2DP profile name:
    a2dp-sink

  dunstify replace-id workflow:
    First call: dunstify -p ... → prints ID
    Subsequent: dunstify -r ID ... → updates in-place

  Socket path: /tmp/voice-input.sock
  Audio path:  /tmp/voice-input.wav
  Log path:    /tmp/voice-input.log
  Model path:  ~/.local/share/voice-input/models/small

  Keybind: ALT + T (HyDE-integrated, DO NOT CHANGE)
