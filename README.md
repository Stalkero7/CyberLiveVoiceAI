# CyberLiveVoiceAI: AI-Powered NPC Conversations with Persistent Memory

A real-time AI integration for Cyberpunk 2077 that allows players to speak to Night City residents using their own voice. NPCs remember past conversations and build relationships over time through persistent JSON memory files.

**Current Version:** Brain v2.0.0 | Target Sender v7.2.0 | Voice Display v8.0.0

## System Architecture

The mod consists of **three independent components** that communicate via file-based "Dead Drop" protocol:

### 1. **The Brain** (Rust v2.0.0) - `brain.exe`
**Purpose:** Core AI engine and audio processing pipeline

**What it does:**
- Monitors **Numpad 7** keypress globally (works even when game isn't focused)
- Captures microphone audio while key is held
- Transcribes speech using **OpenAI Whisper API**
- Reads `target.txt` to know who you're talking to
- Loads character memory from JSON files (conversation history)
- Sends context to **GPT-4o**: personality + last 3 conversations + new input
- Receives AI-generated NPC response
- Updates character memory with new conversation entry
- Writes response to `output.txt` for display

**Key Features:**
- Character memory system (each NPC remembers you)
- Tracks total interactions, first met date, last seen
- Auto-trims conversation history to last 10 entries
- Preset personalities for known NPCs (Judy, Jackie, Panam, Johnny)

### 2. **The Target Sender** (Lua) - `cyber_live_sender/init.lua`
**Purpose:** NPC targeting and memory file management

**What it does:**
- Provides UI overlay (press `~` to toggle) for selecting NPCs
- **Manual target entry**: Type any NPC name and set as current target
- Creates JSON memory files for each NPC on first interaction
- Writes current target info to `target.txt`:
  ```
  Panam Palmer|0xPANAM|TRUE
  Timestamp: 2024-02-22 18:45:00
  Memory: memory_Panam_Palmer.json
  ```
- **Dynamic preset buttons**: Every custom NPC you add becomes a clickable button
- Saves presets to `cyberlive_presets.txt` (persists between sessions)
- Loads saved presets automatically on game start

**Current Status:**
- ⚠️ **Auto-targeting currently not working** (scanning NPCs under crosshair)
- ✅ **Manual entry always works** - type any name and set as target

### 3. **The Voice Display** (Lua) - `cyber_live_voice/init.lua`
**Purpose:** Visual dialogue display with Cyberpunk 2077 aesthetic

**What it does:**
- Monitors `output.txt` every 0.3 seconds for new responses
- Parses format: `"NPC Name: Response text"`
- Displays in authentic CP77-styled HUD (bottom-left corner)
- Auto-popup for 7 seconds when AI speaks
- Animated effects: glitch, RGB split, scanlines, corner brackets
- Fades in smoothly, fades out in last second
- No input blocking (displays during gameplay)

**Available versions:**
- **Enhanced (v8.0)**: Balanced performance, glitch effects, CP77 styling
- **Premium (v8.5)**: Maximum immersion, typing animation, holographic waves

## The Communication Flow

```
┌────────────────────────────────────────────────────────────┐
│                   CONVERSATION FLOW                         │
└────────────────────────────────────────────────────────────┘

1. PLAYER OPENS TARGET SENDER OVERLAY (~)
   ↓
2. TYPES "Panam Palmer" IN CUSTOM TARGET ENTRY
   ↓ Checks "Save as Preset Button" ✓
   ↓ Clicks "SET CUSTOM TARGET"
   ↓
3. TARGET SENDER (Lua):
   - Creates memory_Panam_Palmer.json (if doesn't exist)
   - Writes to target.txt:
     "Panam Palmer|0xPANAM|TRUE
      Memory: memory_Panam_Palmer.json"
   - Adds "Panam Palmer" button to preset list
   ↓
4. PLAYER CLOSES OVERLAY, HOLDS NUMPAD 7
   ↓
5. BRAIN (Rust):
   - Detects Numpad 7 held
   - Starts recording microphone
   - Voice Display shows: "UPLINK: [ RECORDING... ]"
   ↓
6. PLAYER SPEAKS: "Hey Panam, how's the Basilisk running?"
   ↓
7. PLAYER RELEASES NUMPAD 7
   ↓
8. BRAIN (Rust):
   - Stops recording, saves voice.wav
   - Reads target.txt → sees "Panam Palmer"
   - Loads memory_Panam_Palmer.json → finds 5 past conversations
   - Sends audio to Whisper API → transcribes to text
   - Voice Display shows: "UPLINK: [ NEURAL LINK ESTABLISHED ]"
   ↓
9. BRAIN sends to GPT-4o with context:
   System: "You are Panam Palmer, fierce Nomad driver.
            Last conversations: [3 recent exchanges]
            This is interaction #6, first met 2024-02-20"
   User: "Hey Panam, how's the Basilisk running?"
   ↓
10. GPT-4o responds with memory:
    "Still purring like a kitten, V. Thanks to you fixing 
     that cooling issue last time!"
   ↓
11. BRAIN (Rust):
    - Updates memory_Panam_Palmer.json:
      * Adds new conversation entry with timestamp
      * Increments total_interactions: 6
      * Updates last_seen: 2024-02-22
    - Writes to output.txt:
      "Panam Palmer: Still purring like a kitten..."
    ↓
12. VOICE DISPLAY (Lua):
    - Detects new text in output.txt
    - Parses "Panam Palmer: [message]"
    - Shows CP77-styled popup (bottom-left)
    - Displays for 7 seconds with animations
    - Auto-hides after timer expires
```

## Character Memory System

Each NPC gets a persistent JSON file (`memory_[name].json`) that stores:

```json
{
  "character_name": "Panam Palmer",
  "character_hash": "0xPANAM",
  "created_at": "2024-02-20 15:30:00",
  "last_interaction": "2024-02-22 18:45:00",
  "conversation_history": [
    {
      "timestamp": "2024-02-20 15:30:00",
      "player_said": "Hey Panam, need help with anything?",
      "npc_replied": "V! Yeah, the Basilisk's acting up again."
    },
    {
      "timestamp": "2024-02-22 18:45:00",
      "player_said": "How's the Basilisk running?",
      "npc_replied": "Like a dream, thanks to you."
    }
  ],
  "character_info": {
    "personality": "Fierce, independent Nomad. Passionate about family.",
    "background": "Aldecaldos Nomad, expert driver",
    "relationship_to_player": "Close friend, helped with Basilisk",
    "notes": "Doesn't trust corpos, loyal to clan"
  },
  "stats": {
    "total_interactions": 6,
    "first_met": "2024-02-20",
    "last_seen": "2024-02-22"
  },
  "custom_data": {}
}
```

**Memory Features:**
- NPCs remember past conversations
- Relationships evolve naturally over time
- Last 3 conversations sent to GPT-4o for context
- Auto-trims to 10 conversations (prevents file bloat)
- Fully editable - customize personalities in JSON
- First met / last seen tracking

## File Structure

```
Cyberpunk 2077/
└── bin/x64/plugins/cyber_engine_tweaks/mods/
    ├── cyber_live_sender/
    │   ├── init.lua                    # Target system & memory management
    │   ├── target.txt                  # Current target info (read by brain)
    │   ├── cyberlive_presets.txt       # Saved preset list
    │   ├── memory_Panam_Palmer.json    # Character memory files
    │   ├── memory_Jackie_Welles.json
    │   └── memory_[YourNPC].json
    │
    └── cyber_live_voice/
        ├── init.lua                    # Visual display overlay
        └── output.txt                  # AI responses (written by brain)

brain.exe (runs separately outside game folder)
├── .env                                # Contains OPENAI_API_KEY
└── voice.wav                           # Temporary recording (overwritten)
```

## Setup Instructions

### 1. Prerequisites
* **Cyberpunk 2077** (v2.13+)
* **Cyber Engine Tweaks (CET)** installed
* **OpenAI API Key** (for Whisper + GPT-4o)

### 2. The Brain (Rust v2.0.0)
1. Navigate to the `/brain` folder
2. Create a `.env` file with your API key:
   ```
   OPENAI_API_KEY=sk-your_actual_key_here
   ```
3. Build with MSVC target:
   ```bash
   cargo build --release --target x86_64-pc-windows-msvc
   ```
4. Run `target/x86_64-pc-windows-msvc/release/cyber_live_brain.exe`
5. Keep it running in the background while playing

### 3. The Lua Mods

**Target Sender:**
1. Copy `cyber_live_sender/` folder to:
   ```
   C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077\
   bin\x64\plugins\cyber_engine_tweaks\mods\cyber_live_sender\
   ```

**Voice Display:**
2. Copy `cyber_live_voice/` folder to:
   ```
   C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077\
   bin\x64\plugins\cyber_engine_tweaks\mods\cyber_live_voice\
   ```

3. Launch game and verify both mods load in CET console (`~`)

## How to Use

### First Time Setup:
1. **Start brain.exe** before launching game
2. **Launch Cyberpunk 2077**
3. **Press `~`** to open CET overlay
4. Verify you see "CyberLive Neural Uplink" window

### Adding Your First NPC:
1. **Open CET overlay** (`~`)
2. Find "Custom Target Entry" section
3. **Type NPC name**: `Panam Palmer`
4. **Optional - Type hash**: `0xPANAM` (or leave blank)
5. **Check** "Save as Preset Button" ✓
6. **Click** "SET CUSTOM TARGET"
7. A new button appears with NPC name!
8. **Close overlay** (`~`)

### Having a Conversation:
1. Make sure brain.exe is running
2. Select your target (button or custom entry)
3. **Hold Numpad 7**
4. **Speak** your message clearly
5. **Release Numpad 7**
6. Wait 3-6 seconds
7. Response appears bottom-left!

### Quick Tips:
- **Preset buttons** = one-click target selection
- **X button** next to preset = delete it
- **F10** = clear current target
- **Custom entry without "Save as Preset"** = one-time target

## Known Characters (Auto-Configured)

The brain recognizes these NPCs with preset personalities:

| Character | Personality |
|-----------|-------------|
| **Judy Alvarez** | Mox BD editor, tech-savvy, sincere, uses Mox slang |
| **Jackie Welles** | Best friend, warm, loyal, uses "choom" and "preem" |
| **Panam Palmer** | Nomad driver, fierce, independent, passionate |
| **Johnny Silverhand** | Rockerboy engram, sarcastic, rebellious, anti-corpo |

Custom NPCs can have personalities defined in their memory JSON files.

## Customization

### Add Custom Personality:
Edit any `memory_[name].json` file:
```json
"character_info": {
  "personality": "Gruff but caring Ripperdoc. Protective of regulars.",
  "background": "Former Trauma Team medic, now runs clinic in Watson",
  "relationship_to_player": "Regular customer, trust being built",
  "notes": "Owes V a favor from that Maelstrom job"
}
```
Brain will use this context in all future conversations!

### UI Customization (Premium Display):
In CET console:
```lua
SetDisplayPosition('bottom-left')  -- or 'top-left', 'center'
SetDisplayDuration(10)             -- seconds to display
ToggleTypingEffect()               -- character-by-character text
ToggleGlitch()                     -- RGB glitch effects
```

### Add Presets via Console:
```lua
AddCustomNPC("Viktor Vektor", "0xVIK")
AddCustomNPC("Misty Olszewski", "0xMISTY")
```

## Console Commands

### Target Sender (cyber_live_sender):
Open CET console (`~`) and type:
```lua
ScanCurrentTarget()           -- Force scan attempt
ClearCurrentTarget()          -- Clear target
GetTargetInfo()              -- Show current target details
AddCustomNPC("Name", "Hash")  -- Add preset via console
RemoveNPC("Name")            -- Remove preset
ListAllPresets()             -- Show all saved presets
SavePresets()                -- Manually save preset list
LoadPresets()                -- Reload from file
```

### Voice Display (cyber_live_voice premium only):
```lua
SetDisplayPosition('center')      -- Change position
ToggleTypingEffect()              -- Toggle typing animation
ToggleGlitch()                    -- Toggle glitch effects
SetDisplayDuration(5)             -- Change display time
```

## Technical Details

### Processing Timeline:
- Audio capture: Real-time (while Numpad 7 held)
- Whisper transcription: ~1-2 seconds
- Memory file load: <5 milliseconds
- GPT-4o response: ~2-4 seconds
- Memory file save: <5 milliseconds
- **Total time:** ~3-6 seconds from release to response

### API Costs (OpenAI):
- **Whisper**: ~$0.006 per minute of audio
- **GPT-4o**: ~$0.005 per conversation (with memory context)
- **Estimate**: ~$0.01 per interaction
- **10 conversations**: ~$0.10

### Performance Impact:
- **brain.exe**: Minimal (separate process)
- **Target Sender Lua**: <1 FPS impact
- **Voice Display Lua**: <1-2 FPS impact (Enhanced), <2 FPS (Premium)
- **Memory files**: ~2-5 KB each

### File Sizes:
- Each memory JSON: ~2-5 KB
- 100 NPCs with 10 conversations each: ~500 KB total
- Negligible storage impact

## Current Limitations

### ⚠️ Known Issues:
1. **Auto-targeting not functional**
   - Scanning NPCs under crosshair currently doesn't work
   - **Workaround**: Use manual Custom Target Entry (always works)
   - Future fix planned

2. **AMM spawned NPCs**
   - May not be detectable even when fixed
   - **Solution**: Use manual entry with AMM spawn name

3. **Administrator permissions**
   - brain.exe may need admin rights
   - Required for writing to Program Files

### ✅ What Works Perfectly:
- Manual target entry and preset buttons
- Voice recording and transcription
- Character memory persistence
- GPT-4o responses with context
- UI display and animations
- Preset management

## Troubleshooting

### No response from NPCs:
- ✓ Check brain.exe console is running
- ✓ Verify `.env` has valid `OPENAI_API_KEY`
- ✓ Check target.txt exists in cyber_live_sender folder
- ✓ Verify output.txt path matches in brain code

### Display not showing:
- ✓ Check output.txt exists in cyber_live_voice folder
- ✓ Open CET console (`~`) to check for Lua errors
- ✓ Verify mod loaded: look for "[CyberLive]" messages
- ✓ Try Enhanced version instead of Premium

### Target not being set:
- ✓ Open CET overlay (`~`) to access UI
- ✓ Type name manually in Custom Target Entry
- ✓ Click "SET CUSTOM TARGET"
- ✓ Check target.txt file was created

### Memory not saving:
- ✓ Check file permissions in cyber_live_sender folder
- ✓ Run brain.exe as Administrator
- ✓ Verify JSON isn't corrupted (use jsonlint.com)
- ✓ Check brain.exe console for error messages

### Voice not recording:
- ✓ Check microphone is default device in Windows
- ✓ Test recording with other software first
- ✓ Verify brain.exe shows "Recording..." in console
- ✓ Check Numpad 7 key isn't bound elsewhere

## Version History

### Brain (Rust):
- **v1.2.9**: Original with basic target reading
- **v2.0.0**: ✨ Memory system, character context, enhanced personalities

### Target Sender (Lua):
- **v7.0.0**: Original basic version
- **v7.1.0**: Added targeting attempt (not working)
- **v7.2.0**: ✨ Dynamic preset buttons, memory file creation

### Voice Display (Lua):
- **v7.2.0**: Original simple yellow text
- **v8.0.0**: ✨ Enhanced CP77 aesthetic with glitch effects
- **v8.5.0**: Premium with typing animation and holographic effects

## Future Enhancements

### Planned Features:
- [ ] Fix auto-targeting system for NPCs
- [ ] Text-to-Speech (OpenAI TTS or local)
- [ ] Voice gender/pitch per character
- [ ] Long-term memory compression
- [ ] Relationship level indicators
- [ ] Quest tracking per character
- [ ] Character portraits in UI
- [ ] Voice waveform visualization
- [ ] Multi-language support
- [ ] Conversation export/import

## Important Notes

### Permissions:
- Brain.exe writes to `cyber_live_sender/` folder
- May require **Administrator** rights on some systems
- If files aren't updating, run brain.exe as admin

### Privacy:
- `.env` file contains your API key (**never commit to git!**)
- Voice recordings are temporary (voice.wav overwritten each use)
- Memory files stored locally only
- Data only sent to OpenAI API (Whisper + GPT-4o)
- No telemetry or tracking

### Legal:
- For personal use only
- Ensure compliance with Cyberpunk 2077 EULA
- Respect OpenAI Terms of Service
- Follow modding community guidelines

## Credits

- **Architecture**: File-based "Dead Drop" protocol
- **Memory System**: Persistent JSON character memory (v2.0)
- **Enhanced UI**: Authentic Cyberpunk 2077 styling
- **Technologies**: 
  - Rust (audio capture, API handling)
  - Lua + CET (game integration)
  - OpenAI (Whisper, GPT-4o)
  - chrono, serde, reqwest, cpal, hound

## Support & Community

- **Issues**: Check troubleshooting section first
- **CET Console**: Press `~` to see mod status and errors
- **brain.exe Console**: Shows detailed processing logs
- **Memory Files**: Fully editable JSON for customization

---

**Built for Night City. Powered by AI. Remembers everything.** 🌃🧠✨

*"In Night City, you can be anyone. Now they'll remember who you are."*
