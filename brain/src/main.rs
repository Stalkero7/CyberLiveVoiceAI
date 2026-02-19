use tiny_http::{Server, Response};
use async_openai::{
    types::{
        ChatCompletionRequestSystemMessageArgs, ChatCompletionRequestUserMessageArgs,
        CreateChatCompletionRequestArgs, CreateTranscriptionRequestArgs,
    },
    Client,
};
use std::sync::{Arc, Mutex};
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use lazy_static::lazy_static;
use dotenvy::dotenv;

lazy_static! {
    static ref IS_RECORDING: Arc<Mutex<bool>> = Arc::new(Mutex::new(false));
    static ref AUDIO_DATA: Arc<Mutex<Vec<f32>>> = Arc::new(Mutex::new(Vec::new()));
}

#[tokio::main]
async fn main() {
    dotenv().ok();
    println!("--- CyberLiveAI v0.7.7: Git Stable ---");

    let host = cpal::default_host();
    let device = host.default_input_device().expect("No mic found");
    let config = device.default_input_config().expect("Config fail");
    let sample_rate = config.sample_rate().0;
    
    let dev_c = device.clone();
    let cfg_c = config.clone();
    std::thread::spawn(move || {
        let mut current_stream: Option<cpal::Stream> = None;
        loop {
            let is_rec = *IS_RECORDING.lock().unwrap();
            if is_rec && current_stream.is_none() {
                let data_acc = AUDIO_DATA.clone();
                let stream = dev_c.build_input_stream(
                    &cfg_c.clone().into(),
                    move |data: &[f32], _| { data_acc.lock().unwrap().extend_from_slice(data); },
                    |_| {}, None
                ).unwrap();
                stream.play().unwrap();
                current_stream = Some(stream);
                println!("[HARDWARE] MIC CAPTURE START");
            } else if !is_rec && current_stream.is_some() {
                current_stream = None; 
                println!("[HARDWARE] MIC CAPTURE STOP");
            }
            std::thread::sleep(std::time::Duration::from_millis(10));
        }
    });

    let server = Server::http("127.0.0.1:80").unwrap();
    println!("[SYSTEM] Brain Listening on http://127.0.0.1:80");

    let ai_client = Client::new();

    for request in server.incoming_requests() {
        let url = request.url().to_string();
        println!("[SIGNAL] {} ", url);

        if url.contains("/start") {
            { *IS_RECORDING.lock().unwrap() = true; }
            AUDIO_DATA.lock().unwrap().clear();
            request.respond(Response::from_string("OK")).unwrap();
        } 
        else if url.contains("/stop") {
            { *IS_RECORDING.lock().unwrap() = false; }
            let response_text = process_signal(&ai_client, sample_rate).await;
            request.respond(Response::from_string(response_text)).unwrap();
        } 
        else {
            request.respond(Response::from_string("READY")).unwrap();
        }
    }
}

async fn process_signal(client: &Client<async_openai::config::OpenAIConfig>, sample_rate: u32) -> String {
    let audio_samples = { AUDIO_DATA.lock().unwrap().clone() };
    if audio_samples.len() < 1000 { return "No audio detected.".to_string(); }

    let path = "buffer.wav";
    let spec = hound::WavSpec {
        channels: 1, sample_rate, bits_per_sample: 32,
        sample_format: hound::SampleFormat::Float,
    };
    let mut writer = hound::WavWriter::create(path, spec).unwrap();
    for &sample in audio_samples.iter() { writer.write_sample(sample).unwrap(); }
    writer.finalize().unwrap();

    let whisper_req = CreateTranscriptionRequestArgs::default().file(path).model("whisper-1").build().unwrap();
    if let Ok(tr) = client.audio().transcribe(whisper_req).await {
        let chat_req = CreateChatCompletionRequestArgs::default()
            .max_tokens(60u32).model("gpt-4o-mini")
            .messages([
                ChatCompletionRequestSystemMessageArgs::default()
                    .content("You are an NPC in Night City. Be brief.").build().unwrap().into(),
                ChatCompletionRequestUserMessageArgs::default().content(tr.text).build().unwrap().into(),
            ]).build().unwrap();

        if let Ok(res) = client.chat().create(chat_req).await {
            return res.choices[0].message.content.clone().unwrap_or_default();
        }
    }
    "Net error...".to_string()
}