//! Native binary entry point.
//!
//! All game logic lives in the library; on the web the JavaScript side calls
//! `fnwf_app::web::start` instead (see `src/lib.rs`).

#[cfg(not(target_arch = "wasm32"))]
fn main() {
    fnwf_app::run_native();
}

/// The browser entry point lives in the library (`wasm_bindgen(start)`), so the
/// wasm binary itself needs no `main`.
#[cfg(target_arch = "wasm32")]
fn main() {}
