// Brain v2.0.0: Memory-Enabled Neural Link
// New: Each NPC has persistent JSON memory
// Purpose: Reads from Sender folder -> Writes to Voice folder -> Manages character memory

use std::fs::File;
use std::io::{Read, Write};
use std::sync::{Arc, Mutex};
use std::env;
use device_query::{DeviceQuery, DeviceState, Keycode};
use dotenv::dotenv;
use reqwest::blocking::{Client, multipart};
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use hound;
use serde::{Deserialize, Serialize};
use serde_json;

#[derive(Serialize, Deserialize, Clone)]
struct CharacterInfo {
    personality: String,
    background: String,
    relationship_to_player: String,
    notes: String,
}

#[derive(Serialize, Deserialize, Clone)]
struct Stats {
    total_interactions: u32,
    first_met: String,
    last_seen: String,
}

#[derive(Serialize, Deserialize, Clone)]
struct ConversationEntry {
    timestamp: String,
    player_said: String,
    npc_replied: String,
}

#[derive(Serialize, Deserialize, Clone)]
struct CharacterMemory {
    character_name: String,
    character_hash: String,
    created_at: String,
    last_interaction: String,
    conversation_history: Vec<ConversationEntry>,
    character_info: CharacterInfo,
    stats: Stats,
    custom_data: serde_json::Value,
}

impl CharacterMemory {
    fn new(name: String, hash: String) -> Self {
        let now = chrono::Local::now().format("%Y-%m-%d %H:%M:%S").to_string();
        let today = chrono::Local::now().format("%Y-%m-%d").to_string();
        
        CharacterMemory {
            character_name: name,
            character_hash: hash,
            created_at: now.clone(),
            last_interaction: now,
            conversation_history: Vec::new(),
            character_info: CharacterInfo {
                personality: String::new(),
                background: String::new(),
                relationship_to_player: String::new(),
                notes: String::new(),
            },
            stats: Stats {
                total_interactions: 0,
                first_met: today.clone(),
                last_seen: today,
            },
            custom_data: serde_json::json!({}),
        }
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenv().ok();
    let api_key = env::var("OPENAI_API_KEY").expect("API Key missing from .env");
    let device_state = DeviceState::new();
    let client = Client::new();

    // --- PATH CONFIGURATION ---
    let voice_folder = r"C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077\bin\x64\plugins\cyber_engine_tweaks\mods\cyber_live_voice\";
    let sender_folder = r"C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077\bin\x64\plugins\cyber_engine_tweaks\mods\cyber_live_sender\";

    let output_path = format!("{}output.txt", voice_folder);
    let target_path = format!("{}target.txt", sender_folder);
    let wav_path = "voice.wav";

    println!("--- Brain v2.0.0: Memory-Enabled Neural Link ---");
    println!("Listening to: {}", target_path);
    println!("Responding to: {}", output_path);
    println!("Memory system: ACTIVE");

    // Audio setup
    let host = cpal::default_host();
    let input_device = host.default_input_device().expect("No input device found");
    let config: cpal::StreamConfig = input_device.default_input_config()?.into();
    let sample_rate = config.sample_rate.0;

    let mut is_recording = false;
    let mut stream: Option<cpal::Stream> = None;
    let recorded_data = Arc::new(Mutex::new(Vec::new()));

    loop {
        let keys = device_state.get_keys();
        let numpad7_pressed = keys.contains(&Keycode::Numpad7);

        // TRIGGER: Start Recording
        if numpad7_pressed && !is_recording {
            is_recording = true;
            write_to_game(&output_path, "UPLINK: [ RECORDING... ]");
            println!("\n[INPUT] Numpad 7 Held: Recording...");

            let data_clone = recorded_data.clone();
            data_clone.lock().unwrap().clear();

            stream = Some(input_device.build_input_stream(
                &config,
                move |data: &[f32], _: &cpal::InputCallbackInfo| {
                    let mut buffer = data_clone.lock().unwrap();
                    buffer.extend_from_slice(data);
                },
                |err| println!("Stream Error: {}", err),
                None
            )?);
            stream.as_ref().unwrap().play()?;
        }

        // TRIGGER: Release & Process
        if !numpad7_pressed && is_recording {
            is_recording = false;
            drop(stream.take());
            write_to_game(&output_path, "UPLINK: [ ANALYZING TARGET... ]");

            // 1. READ TARGET FROM SENDER FOLDER
            let mut target_raw = String::new();
            if let Ok(mut t_file) = File::open(&target_path) {
                let _ = t_file.read_to_string(&mut target_raw);
            }
            
            // Parse target.txt format: Name|Hash|Status\nTimestamp: ...\nMemory: filename.json
            let lines: Vec<&str> = target_raw.lines().collect();
            let target_name = if !lines.is_empty() {
                lines[0].split('|').next().unwrap_or("Unknown").trim()
            } else {
                "Unknown"
            };
            
            // Extract memory filename if provided
            let memory_filename = if let Some(memory_line) = lines.iter().find(|line| line.starts_with("Memory:")) {
                if let Some(filename) = memory_line.split(':').nth(1) {
                    filename.trim().to_string()
                } else {
                    // Fallback: generate filename from name
                    let safe_name = target_name.replace(|c: char| !c.is_alphanumeric() && c != ' ' && c != '-', "")
                        .replace(' ', "_");
                    format!("memory_{}.json", safe_name)
                }
            } else {
                // Fallback: generate filename from name
                let safe_name = target_name.replace(|c: char| !c.is_alphanumeric() && c != ' ' && c != '-', "")
                    .replace(' ', "_");
                format!("memory_{}.json", safe_name)
            };
            
            let memory_path = format!("{}{}", sender_folder, memory_filename);
            
            println!("--------------------------------------------------");
            println!("[BRIDGE] Interaction with: '{}'", target_name);
            println!("[MEMORY] Loading from: {}", memory_filename);

            // 2. LOAD OR CREATE CHARACTER MEMORY
            let mut character_memory = load_memory(&memory_path, target_name)?;
            
            // 3. SAVE & TRANSCRIBE
            let buffer = recorded_data.lock().unwrap();
            save_wav(wav_path, &buffer, sample_rate)?;
            println!("[WHISPER] Transcribing...");
            
            let whisper_text = match transcribe_audio(&client, &api_key, wav_path) {
                Ok(text) => text,
                Err(_) => "Signal lost.".to_string(),
            };
            println!("V: {}", whisper_text);

            // 4. GPT-4o WITH MEMORY CONTEXT
            write_to_game(&output_path, "UPLINK: [ NEURAL LINK ESTABLISHED ]");
            let ai_response = get_gpt_response_with_memory(
                &client, 
                &api_key, 
                &whisper_text, 
                &character_memory
            )?;

            // 5. UPDATE MEMORY
            update_memory(&mut character_memory, &whisper_text, &ai_response);
            save_memory(&memory_path, &character_memory)?;

            // 6. OUTPUT TO VOICE MOD FOLDER
            let formatted_response = format!("{}: {}", target_name, ai_response);
            write_to_game(&output_path, &formatted_response);
            println!("[OUTPUT] {}", formatted_response);
            println!("[MEMORY] Saved to: {}", memory_filename);
            println!("[STATS] Total interactions: {}", character_memory.stats.total_interactions);
            println!("--------------------------------------------------");
        }
    }
}

fn load_memory(path: &str, default_name: &str) -> Result<CharacterMemory, Box<dyn std::error::Error>> {
    match File::open(path) {
        Ok(mut file) => {
            let mut contents = String::new();
            file.read_to_string(&mut contents)?;
            let memory: CharacterMemory = serde_json::from_str(&contents)?;
            println!("[MEMORY] Loaded existing memory ({} interactions)", memory.stats.total_interactions);
            Ok(memory)
        }
        Err(_) => {
            println!("[MEMORY] Creating new memory file");
            let memory = CharacterMemory::new(default_name.to_string(), "0x0".to_string());
            save_memory(path, &memory)?;
            Ok(memory)
        }
    }
}

fn save_memory(path: &str, memory: &CharacterMemory) -> Result<(), Box<dyn std::error::Error>> {
    let json = serde_json::to_string_pretty(memory)?;
    let mut file = File::create(path)?;
    file.write_all(json.as_bytes())?;
    Ok(())
}

fn update_memory(memory: &mut CharacterMemory, player_input: &str, npc_response: &str) {
    let now = chrono::Local::now().format("%Y-%m-%d %H:%M:%S").to_string();
    let today = chrono::Local::now().format("%Y-%m-%d").to_string();
    
    // Add conversation entry
    memory.conversation_history.push(ConversationEntry {
        timestamp: now.clone(),
        player_said: player_input.to_string(),
        npc_replied: npc_response.to_string(),
    });
    
    // Keep only last 10 conversations to prevent file bloat
    if memory.conversation_history.len() > 10 {
        memory.conversation_history.remove(0);
    }
    
    // Update stats
    memory.stats.total_interactions += 1;
    memory.stats.last_seen = today;
    memory.last_interaction = now;
}

fn get_gpt_response_with_memory(
    client: &Client, 
    api_key: &str, 
    input: &str, 
    memory: &CharacterMemory
) -> Result<String, Box<dyn std::error::Error>> {
    
    let target_name = &memory.character_name;
    
    // Build system prompt with character info and memory
    let mut system_prompt = String::new();
    
    // Character-specific personalities
    if target_name.contains("Judy") {
        system_prompt.push_str("You are Judy Alvarez from Cyberpunk 2077. You're a Mox, a tech-whiz, and a BD editor. Be sincere and use Mox slang. Keep responses brief (2-3 sentences max).");
    } else if target_name.contains("Jackie") {
        system_prompt.push_str("You are Jackie Welles from Cyberpunk 2077. You're V's best friend - warm, loyal, enthusiastic. Use 'choom' and 'preem'. Keep it brief and friendly.");
    } else if target_name.contains("Panam") {
        system_prompt.push_str("You are Panam Palmer from Cyberpunk 2077. You're a skilled Nomad driver with a fierce, independent spirit. Be direct and passionate. Keep responses brief.");
    } else if target_name.contains("Johnny") || target_name.contains("Silverhand") {
        system_prompt.push_str("You are Johnny Silverhand from Cyberpunk 2077. You're a rebellious rockerboy engram in V's head. Be sarcastic, blunt, and anti-corpo. Keep it brief.");
    } else if target_name == "No Target" || target_name == "Unknown" || target_name == "None" {
        system_prompt.push_str("You are a generic Night City resident. You are busy and slightly annoyed. Be short and to the point.");
    } else {
        system_prompt.push_str(&format!("You are {} from Night City. Respond naturally and stay in character. Keep responses brief (2-3 sentences).", target_name));
    }
    
    // Add custom character info if available
    if !memory.character_info.personality.is_empty() {
        system_prompt.push_str(&format!("\n\nPersonality: {}", memory.character_info.personality));
    }
    if !memory.character_info.relationship_to_player.is_empty() {
        system_prompt.push_str(&format!("\nRelationship to V: {}", memory.character_info.relationship_to_player));
    }
    
    // Add conversation context (last 3 exchanges)
    if !memory.conversation_history.is_empty() {
        system_prompt.push_str("\n\nRecent conversation context:");
        let recent = memory.conversation_history.iter()
            .rev()
            .take(3)
            .rev()
            .collect::<Vec<_>>();
        
        for entry in recent {
            system_prompt.push_str(&format!("\nV: {} | You: {}", entry.player_said, entry.npc_replied));
        }
    }
    
    // Add interaction stats
    system_prompt.push_str(&format!("\n\n(This is interaction #{} with V. First met: {})", 
        memory.stats.total_interactions + 1, 
        memory.stats.first_met
    ));

    let body = serde_json::json!({
        "model": "gpt-4o",
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": input}
        ],
        "max_tokens": 150,
        "temperature": 0.8
    });

    let res = client.post("https://api.openai.com/v1/chat/completions")
        .header("Authorization", format!("Bearer {}", api_key))
        .json(&body)
        .send()?
        .json::<serde_json::Value>()?;

    Ok(res["choices"][0]["message"]["content"].as_str().unwrap_or("...").to_string())
}

fn transcribe_audio(client: &Client, api_key: &str, file_path: &str) -> Result<String, Box<dyn std::error::Error>> {
    let form = multipart::Form::new().file("file", file_path)?.text("model", "whisper-1");
    let res = client.post("https://api.openai.com/v1/audio/transcriptions")
        .header("Authorization", format!("Bearer {}", api_key))
        .multipart(form).send()?.json::<serde_json::Value>()?;
    Ok(res["text"].as_str().unwrap_or("").to_string())
}

fn save_wav(path: &str, samples: &[f32], sample_rate: u32) -> Result<(), Box<dyn std::error::Error>> {
    let spec = hound::WavSpec { channels: 1, sample_rate, bits_per_sample: 32, sample_format: hound::SampleFormat::Float };
    let mut writer = hound::WavWriter::create(path, spec)?;
    for &sample in samples { writer.write_sample(sample)?; }
    writer.finalize()?;
    Ok(())
}

fn write_to_game(path: &str, text: &str) {
    if let Ok(mut file) = File::create(path) { let _ = file.write_all(text.as_bytes()); }
}