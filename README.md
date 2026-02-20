# CyberLiveVoiceAI: Working AI Mimic

A real-time AI integration for Cyberpunk 2077 that allows players to speak to Night City residents using their own voice. This version (v1.2.5 / v2.4.2) uses a Stable Intermediary Protocol, bypassing memory-heavy FFI links in favor of a reliable file-based "Dead Drop" system.

## System Architecture

The mod consists of two independent parts that communicate via a physical file:

1. The Brain (Rust v1.2.5): A standalone executable that handles global key-hooks (Numpad 7), audio capture, and the OpenAI API pipeline (Whisper + GPT-4o).
2. The Interface (Lua v2.4.2): A Cyber Engine Tweaks (CET) mod that monitors the output file and renders the dialogue in a "Golden Version" HUD inspired by the Feb 16th build.

## Setup Instructions

### 1. Prerequisites
* Cyberpunk 2077 (v2.13+)
* Cyber Engine Tweaks (CET) installed.
* OpenAI API Key.

### 2. The Brain (Rust)
1. Navigate to the /brain folder.
2. Create a .env file and add your key:
   OPENAI_API_KEY=your_actual_key_here
3. Build the brain using the MSVC target:
   cargo build --release --target x86_64-pc-windows-msvc
4. Run the generated cyber_live_brain.exe.

### 3. The Interface (Lua)
1. Copy the contents of the /interface folder to:
   C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077\bin\x64\plugins\cyber_engine_tweaks\mods\cyber_live_voice\
2. Launch the game and ensure the mod is initialized in the CET console.

## How to Use
1. Ensure the Brain.exe is running in the background.
2. In-game, Hold Numpad 7 to begin recording.
3. The HUD will display [ RECORDING... ].
4. Speak your message and Release Numpad 7.
5. Wait for [ DECRYPTING... ] to finish; the resident's response will appear in yellow.

## Important Notes
* Permissions: Since the mod writes to C:\Program Files (x86), you may need to run the Brain as Administrator.
* Privacy: The .env file and output.txt are included in .gitignore to protect your API keys and local data.