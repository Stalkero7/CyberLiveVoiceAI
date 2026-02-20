// Version 2.0.1: Internal Audio Capture (Native DLL Optimized)
// Handles raw mic input and stores it in a thread-safe shared buffer.

use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use std::sync::{Arc, Mutex};

pub struct AudioRecorder {
    /// Shared buffer for raw f32 audio samples
    pub data: Arc<Mutex<Vec<f32>>>,
    /// Handle to the active input stream
    stream: Option<cpal::Stream>,
}

impl AudioRecorder {
    /// Creates a new recorder instance with an empty data buffer
    pub fn new() -> Self {
        Self {
            data: Arc::new(Mutex::new(Vec::new())),
            stream: None,
        }
    }

    /// Starts capturing audio from the default system microphone
    pub fn start_recording(&mut self) {
        let host = cpal::default_host();
        
        // Find default input device (Microphone)
        let device = match host.default_input_device() {
            Some(d) => d,
            None => {
                eprintln!("[NEURAL-AUDIO] No input device found! Ensure mic is plugged in.");
                return;
            }
        };

        // Fetch hardware configuration
        let config = match device.default_input_config() {
            Ok(c) => c,
            Err(e) => {
                eprintln!("[NEURAL-AUDIO] Failed to get mic config: {:?}", e);
                return;
            }
        };

        let data_acc = self.data.clone();
        
        // Reset the buffer for a fresh recording session
        if let Ok(mut buffer) = data_acc.lock() {
            buffer.clear();
            println!("[NEURAL-AUDIO] Buffer cleared, starting capture...");
        }

        // Build the stream logic
        let stream = device.build_input_stream(
            &config.into(),
            move |data: &[f32], _: &cpal::InputCallbackInfo| {
                // Callback: Push incoming samples into the shared buffer
                if let Ok(mut buffer) = data_acc.lock() {
                    buffer.extend_from_slice(data);
                }
            },
            |err| {
                eprintln!("[NEURAL-AUDIO] Stream error: {:?}", err);
            },
            None
        ).expect("Failed to build audio stream");

        // Activate the hardware
        if let Err(e) = stream.play() {
            eprintln!("[NEURAL-AUDIO] Failed to play stream: {:?}", e);
            return;
        }
        
        self.stream = Some(stream);
    }

    /// Stops the capture and returns the collected samples for processing
    pub fn stop_recording(&mut self) -> Vec<f32> {
        // Drop the stream to stop the hardware callback
        self.stream = None; 
        println!("[NEURAL-AUDIO] Capture stopped.");

        match self.data.lock() {
            Ok(buffer) => buffer.clone(),
            Err(e) => {
                eprintln!("[NEURAL-AUDIO] Mutex poisoned: {:?}", e);
                Vec::new()
            }
        }
    }
}