// Version 2.0.3: Native RED4ext Plugin - SdkEnv Signature Fix
mod audio;

use red4ext_rs::{
    export_plugin_symbols, Plugin, SemVer, wcstr, U16CStr, SdkEnv
};
use libc::c_char;
use std::sync::{Arc, Mutex};
use std::ffi::CString;
use device_query::{DeviceQuery, DeviceState, Keycode};
use lazy_static::lazy_static;

lazy_static! {
    static ref GLOBAL_TEXT: Arc<Mutex<String>> = Arc::new(Mutex::new("Neural Link: STANDBY".to_string()));
    static ref GLOBAL_STATE: Arc<Mutex<String>> = Arc::new(Mutex::new("IDLE".to_string()));
}

// --- RED4EXT PLUGIN DEFINITION ---
pub struct CyberLiveVoice;

impl Plugin for CyberLiveVoice {
    const AUTHOR: &'static U16CStr = wcstr!("Raul Azocar");
    const NAME: &'static U16CStr = wcstr!("cyber_live_voice");
    const VERSION: SemVer = SemVer::new(2, 0, 3);

    // FIXED: The trait now expects fn(&SdkEnv) instead of fn(&self)
    fn on_load(_env: &SdkEnv) {
        println!("[CyberLive] Plugin loading with SdkEnv...");
        
        // Spawning the worker thread
        std::thread::spawn(|| {
            let rt = tokio::runtime::Runtime::new().unwrap();
            rt.block_on(async { brain_worker().await });
        });
        
        println!("[CyberLive] Brain worker thread launched.");
    }

    fn on_unload(_env: &SdkEnv) {
        println!("[CyberLive] Plugin unloading...");
    }
}

export_plugin_symbols!(CyberLiveVoice);

// --- LUA INTERFACE (C-EXPORTS) ---
#[no_mangle]
pub extern "C" fn GetBrainText() -> *mut c_char {
    let s = GLOBAL_TEXT.lock().unwrap();
    CString::new(s.as_str()).unwrap_or_else(|_| CString::new("Error").unwrap()).into_raw()
}

#[no_mangle]
pub extern "C" fn GetBrainState() -> *mut c_char {
    let s = GLOBAL_STATE.lock().unwrap();
    CString::new(s.as_str()).unwrap_or_else(|_| CString::new("IDLE").unwrap()).into_raw()
}

// --- BACKGROUND WORKER ---
async fn brain_worker() {
    dotenvy::dotenv().ok();
    let mut recorder = audio::AudioRecorder::new();
    let device_state = DeviceState::new();
    let ai_client = async_openai::Client::new();

    loop {
        let keys = device_state.get_keys();
        if keys.contains(&Keycode::Numpad7) {
            *GLOBAL_STATE.lock().unwrap() = "RECORDING".to_string();
            recorder.start_recording();
            
            while DeviceState::new().get_keys().contains(&Keycode::Numpad7) {
                std::thread::sleep(std::time::Duration::from_millis(10));
            }
            
            let audio_samples = recorder.stop_recording();
            *GLOBAL_STATE.lock().unwrap() = "THINKING".to_string();

            let response = process_neural_link(&ai_client, audio_samples).await;
            
            *GLOBAL_TEXT.lock().unwrap() = response;
            *GLOBAL_STATE.lock().unwrap() = "IDLE".to_string();
            std::thread::sleep(std::time::Duration::from_millis(500));
        }
        std::thread::sleep(std::time::Duration::from_millis(50));
    }
}

async fn process_neural_link(client: &async_openai::Client<async_openai::config::OpenAIConfig>, samples: Vec<f32>) -> String {
    if samples.len() < 1000 { return "Link error: Audio too short.".to_string(); }

    let spec = hound::WavSpec {
        channels: 1,
        sample_rate: 44100, 
        bits_per_sample: 32,
        sample_format: hound::SampleFormat::Float,
    };
    
    if let Ok(mut writer) = hound::WavWriter::create("request.wav", spec) {
        for &sample in samples.iter() { writer.write_sample(sample).ok(); }
        writer.finalize().ok();
    } else {
        return "Internal Error: Could not write wav.".to_string();
    }

    let tr_args = async_openai::types::CreateTranscriptionRequestArgs::default()
        .file("request.wav")
        .model("whisper-1")
        .build().unwrap();

    if let Ok(res) = client.audio().transcribe(tr_args).await {
        let chat_args = async_openai::types::CreateChatCompletionRequestArgs::default()
            .max_tokens(64u16) 
            .model("gpt-4o-mini")
            .messages([
                async_openai::types::ChatCompletionRequestSystemMessageArgs::default()
                    .content("You are a street-wise character in Night City. Use slang like choomba, preem, delta. Be brief.")
                    .build().unwrap().into(),
                async_openai::types::ChatCompletionRequestUserMessageArgs::default()
                    .content(res.text)
                    .build().unwrap().into(),
            ])
            .build().unwrap();

        if let Ok(chat_res) = client.chat().create(chat_args).await {
            return chat_res.choices[0].message.content.clone().unwrap_or_else(|| "Silence...".to_string());
        }
    }

    "Link Lost: No response from the Net.".to_string()
}