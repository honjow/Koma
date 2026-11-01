#![no_std]
#[panic_handler]
fn panic(_: &core::panic::PanicInfo) -> ! { loop {} }
#[no_mangle]
pub extern "C" fn koma_image_processor_abi() -> i32 { 1 }
#[no_mangle]
pub extern "C" fn koma_image_process() -> i32 { loop { core::hint::spin_loop(); } }
