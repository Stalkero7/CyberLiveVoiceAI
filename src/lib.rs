use libc::{c_void, uint32_t};
use std::io::Write;
use std::net::TcpStream;

// RED4ext v1.29.1 expects API version 0
const API_VERSION_0: uint32_t = 0; 
const RUNTIME_INDEPENDENT: uint32_t = 0xFFFFFFFF;

#[repr(C)]
pub struct PluginInfo {
    pub name: *const u8,
    pub author: *const u8,
    pub version: uint32_t,
    pub runtime: uint32_t,
    pub sdk: uint32_t,
}

#[no_mangle]
pub extern "C" fn Supports() -> uint32_t {
    API_VERSION_0
}

#[no_mangle]
pub extern "C" fn Query(info: *mut PluginInfo) {
    unsafe {
        // Using null-terminated C-strings (u8) instead of Wide strings
        // for better compatibility with WopsS core loader
        (*info).name = b"cyber_live_voice\0".as_ptr();
        (*info).author = b"Raul Azocar\0".as_ptr();
        (*info).version = 41; // 0.4.1
        (*info).runtime = RUNTIME_INDEPENDENT;
        (*info).sdk = API_VERSION_0;
    }
}

#[no_mangle]
pub extern "C" fn Main(_handle: *mut c_void, reason: uint32_t, _sdk: *mut c_void) -> bool {
    // reason 0 = kInit
    if reason == 0 {
        // Minimal confirmation
    }
    true
}

// These are the functions your Lua script will call
#[no_mangle]
pub extern "C" fn SetBrainRecording(state: bool) {
    if let Ok(mut stream) = TcpStream::connect("127.0.0.1:8080") {
        let signal = if state { "START_REC" } else { "STOP_REC" };
        let _ = stream.write_all(signal.as_bytes()).ok();
    }
}

#[no_mangle]
pub extern "C" fn GetAiResponse(npc_name_ptr: *const i8) -> *const i8 {
    // Basic TCP fetch logic for the brain
    "AI_RESPONSE_DUMMY\0".as_ptr() as *const i8
}