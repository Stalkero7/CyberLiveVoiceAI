// Brain v1.2.5: Full Neural Interface
// Purpose: Hardware Numpad 7 -> CPAL Audio -> Whisper -> GPT-4o -> File Dead Drop

use std::fs::File;
use std::io::{Write, BufWriter};
use std::sync::{Arc, Mutex};
use std::env;
use device_query::{DeviceQuery, DeviceState, Keycode};
use dotenv::dotenv;
use reqwest::blocking::{Client, multipart};
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use hound;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    dotenv().ok();
    let api_key = env::var("OPENAI_API_KEY").expect("API Key missing from .env");
    let device_state = DeviceState::new();
    let client = Client::new();

    // TARGET: Must match your init.lua search path
    let output_path = r"C:\Program Files (x86)\Steam\steamapps\common\Cyberpunk 2077\bin\x64\plugins\cyber_engine_tweaks\mods\cyber_live_voice\output.txt";
    let wav_path = "voice.wav";

    println!("--- Brain v1.2.5: Operational ---");
    println!("Dead Drop Path: {}", output_path);

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
            println!("Uplink Active: Recording...");
            write_to_game(output_path, "UPLINK: [ RECORDING... ]");

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

        // TRIGGER: Stop & Process
        if !numpad7_pressed && is_recording {
            is_recording = false;
            drop(stream.take()); // Stop the stream
            println!("Uplink Closed: Processing...");
            write_to_game(output_path, "UPLINK: [ DECRYPTING NEURAL DATA... ]");

            // 1. Save buffer to WAV
            let buffer = recorded_data.lock().unwrap();
            save_wav(wav_path, &buffer, sample_rate)?;

            // 2. Whisper (Speech to Text)
            let whisper_text = transcribe_audio(&client, &api_key, wav_path)?;
            println!("Transcription: {}", whisper_text);

            // 3. GPT-4o (The Persona)
            let ai_response = get_gpt_response(&client, &api_key, &whisper_text)?;

            // 4. Output to Game
            write_to_game(output_path, &ai_response);
            println!("Sent to V: {}", ai_response);
        }
    }
}

fn save_wav(path: &str, samples: &[f32], sample_rate: u32) -> Result<(), Box<dyn std::error::Error>> {
    let spec = hound::WavSpec {
        channels: 1,
        sample_rate,
        bits_per_sample: 32,
        sample_format: hound::SampleFormat::Float,
    };
    let mut writer = hound::WavWriter::create(path, spec)?;
    for &sample in samples {
        writer.write_sample(sample)?;
    }
    writer.finalize()?;
    Ok(())
}

fn transcribe_audio(client: &Client, api_key: &str, file_path: &str) -> Result<String, Box<dyn std::error::Error>> {
    let form = multipart::Form::new()
        .file("file", file_path)?
        .text("model", "whisper-1");

    let res = client.post("https://api.openai.com/v1/audio/transcriptions")
        .header("Authorization", format!("Bearer {}", api_key))
        .multipart(form)
        .send()?
        .json::<serde_json::Value>()?;

    Ok(res["text"].as_str().unwrap_or("...static...").to_string())
}

fn get_gpt_response(client: &Client, api_key: &str, input: &str) -> Result<String, Box<dyn std::error::Error>> {
    let system_prompt = "You are a cynical, tech-savvy resident of Night City. You speak in short, punchy sentences. You are talking to V.";
    
    let body = serde_json::json!({
        "model": "gpt-4o",
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": input}
        ],
        "max_tokens": 100
    });

    let res = client.post("https://api.openai.com/v1/chat/completions")
        .header("Authorization", format!("Bearer {}", api_key))
        .json(&body)
        .send()?
        .json::<serde_json::Value>()?;

    Ok(res["choices"][0]["message"]["content"].as_str().unwrap_or("Neural link severed.").to_string())
}

fn write_to_game(path: &str, text: &str) {
    if let Ok(mut file) = File::create(path) {
        let _ = file.write_all(text.as_bytes());
    }
}