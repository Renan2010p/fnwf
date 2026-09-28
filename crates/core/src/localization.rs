//! Embedded pt/en translations.
//!
//! [`get_text`] returns a [`Cow`]: a borrowed `'static` string when the key is
//! known, or an owned copy of the key when it is not (matching the original
//! fallback behaviour). The translation tables are generated from the C++
//! source into `localization_data.rs`.

use alloc::borrow::Cow;
use alloc::collections::BTreeMap;
use alloc::string::String;
use core::sync::atomic::{AtomicU8, Ordering};

use spin::Lazy;

mod localization_data;

use localization_data::{EN, PT};

const LANG_PT: u8 = 0;
const LANG_EN: u8 = 1;

static CURRENT_LANG: AtomicU8 = AtomicU8::new(LANG_PT);

static PT_MAP: Lazy<BTreeMap<&'static str, &'static str>> =
    Lazy::new(|| PT.iter().copied().collect());
static EN_MAP: Lazy<BTreeMap<&'static str, &'static str>> =
    Lazy::new(|| EN.iter().copied().collect());

/// Selects the active language (`"pt"` or `"en"`). Unknown values are ignored.
pub fn set_language(lang: &str) {
    let value = match lang {
        "en" => LANG_EN,
        "pt" => LANG_PT,
        _ => return,
    };
    CURRENT_LANG.store(value, Ordering::Relaxed);
}

/// The active language code (`"pt"` or `"en"`).
pub fn get_language() -> &'static str {
    match CURRENT_LANG.load(Ordering::Relaxed) {
        LANG_EN => "en",
        _ => "pt",
    }
}

/// Looks up `key` in the active language.
pub fn get_text(key: &str) -> Cow<'static, str> {
    let map = if get_language() == "en" {
        &*EN_MAP
    } else {
        &*PT_MAP
    };
    match map.get(key) {
        Some(value) => Cow::Borrowed(*value),
        None => Cow::Owned(key.into()),
    }
}

/// Convenience: like [`get_text`] but always owned, for `format!`-heavy code.
pub fn text(key: &str) -> String {
    get_text(key).into_owned()
}
