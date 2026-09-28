//! The game-state contract and a small state machine.

use alloc::boxed::Box;
use alloc::string::{String, ToString};
use alloc::vec::Vec;

use fnwf_engine::{Engine, Event};

/// High-level outcome of a state (kept for parity with the C++ `StateResult`).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StateResult {
    /// No transition; keep running the current state.
    None,
    /// The night was survived: advance towards the 6 AM / paycheck flow.
    Win,
    /// The player was caught: play the jumpscare and game over.
    Jumpscare,
    /// Return to the main menu.
    Menu,
    /// Go back to the previous screen in the current flow.
    Back,
    /// Start a new game from the first night.
    Start,
    /// Resume from a saved snapshot.
    Continue,
    /// Jump to the Night 6 flow (unlocked bonus night).
    Night6,
    /// Jump to the Night 7 / custom night flow.
    Night7,
    /// Open the Extras/cheats menu.
    Extras,
    /// Open the achievements ("Conquistas") screen.
    Conquistas,
    /// Quit the application.
    Quit,
    /// Open the options screen.
    Options,
    /// Advance to the next screen in the current flow.
    Next,
}

/// Type identifier for a state, replacing `dynamic_cast`.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum StateType {
    /// Unclassified state.
    None,
    /// The epilepsy / flashing-lights warning screen.
    Warning,
    /// The main menu.
    Menu,
    /// The options/settings screen.
    Options,
    /// A playable night.
    Gameplay,
    /// A loading screen between states.
    Loading,
    /// The intro story sequence.
    Story,
    /// The transition card shown between nights.
    NightTransition,
    /// The 6 AM completion screen.
    SixAM,
    /// The paycheck screen after surviving a night.
    Paycheck,
    /// The newspaper screen shown between nights.
    Newspaper,
    /// The game-over screen shown after a jumpscare.
    GameOver,
    /// The custom night AI-configuration screen.
    CustomNight,
    /// The Extras/cheats menu.
    Extras,
    /// The achievements ("Conquistas") screen.
    Conquistas,
    /// The arcade mini-game.
    Arcade,
}

/// A screen/state of the game.
///
/// The engine is passed in on every call instead of being stored, which keeps
/// states free of borrow-coupled references and makes each one independently
/// testable.
///
/// The contract is event-driven: the app forwards input via [`handle_event`],
/// advances the state with [`update`] and renders it with [`draw`]. Transitions
/// are not performed by the state itself; instead the app polls [`result`] (and
/// [`is_done`]) and consults its transition table. Typed accessors below let
/// that table pull small pieces of data out of a state without downcasting.
///
/// [`handle_event`]: GameState::handle_event
/// [`update`]: GameState::update
/// [`draw`]: GameState::draw
/// [`result`]: GameState::result
/// [`is_done`]: GameState::is_done
pub trait GameState {
    /// Handles one input event forwarded from the engine.
    fn handle_event(&mut self, eng: &mut dyn Engine, ev: &Event);

    /// Advances the state by `dt` seconds; `dt` is the frame delta.
    fn update(&mut self, eng: &mut dyn Engine, dt: f32);

    /// Draws the state for the current frame.
    fn draw(&mut self, eng: &mut dyn Engine);

    /// Whether this state has finished and the app should transition away.
    fn is_done(&self) -> bool;

    /// Free-form result string used to drive transitions (`"win"`, `"menu"`, …).
    ///
    /// The app's transition table matches on this value once [`is_done`] is set.
    ///
    /// [`is_done`]: GameState::is_done
    fn result(&self) -> &str {
        ""
    }

    /// Broad category of this state, replacing the original `dynamic_cast`.
    fn state_type(&self) -> StateType {
        StateType::None
    }

    // Optional typed accessors used by the app's transition table. This keeps
    // the main loop free of `Any`/downcasts.
    /// Night number to show on the 6 AM screen, if applicable.
    fn six_am_night(&self) -> Option<i32> {
        None
    }
    /// Whether the game over was a win, if applicable.
    fn game_over_win(&self) -> Option<bool> {
        None
    }
    /// Night number for the game-over screen, if applicable.
    fn game_over_night(&self) -> Option<i32> {
        None
    }
    /// Custom-night AI levels to carry into gameplay, if applicable.
    fn custom_ai_levels(&self) -> Option<Vec<i32>> {
        None
    }
    /// Extras-cheat toggles `(infinite_power, fast_nights)`, if applicable.
    fn extras_cheats(&self) -> Option<(bool, bool)> {
        None
    }
}

/// Owns the currently active [`GameState`] and its name.
#[derive(Default)]
pub struct StateMachine {
    current: Option<Box<dyn GameState>>,
    current_name: String,
}

impl StateMachine {
    /// Creates an empty machine with no active state.
    pub fn new() -> Self {
        Self::default()
    }

    /// Replaces the active state, dropping the previous one, and records `name`
    /// for diagnostics and transition lookups.
    pub fn switch_state(&mut self, name: &str, state: Box<dyn GameState>) {
        self.current_name = name.to_string();
        self.current = Some(state);
    }

    /// Forwards an update to the active state, if any.
    pub fn update(&mut self, eng: &mut dyn Engine, dt: f32) {
        if let Some(state) = self.current.as_mut() {
            state.update(eng, dt);
        }
    }

    /// Forwards a draw call to the active state, if any.
    pub fn draw(&mut self, eng: &mut dyn Engine) {
        if let Some(state) = self.current.as_mut() {
            state.draw(eng);
        }
    }

    /// Forwards an input event to the active state, if any.
    pub fn handle_event(&mut self, eng: &mut dyn Engine, ev: &Event) {
        if let Some(state) = self.current.as_mut() {
            state.handle_event(eng, ev);
        }
    }

    /// Name of the active state as recorded by [`StateMachine::switch_state`].
    pub fn current_name(&self) -> &str {
        &self.current_name
    }

    /// Updates just the recorded name without replacing the state, used when a
    /// transition keeps the same object but changes its logical identity.
    pub fn set_current_name(&mut self, name: &str) {
        self.current_name = name.to_string();
    }

    /// Borrows the active state, or `None` while no state is installed.
    pub fn current(&self) -> Option<&dyn GameState> {
        self.current.as_deref()
    }

    /// Mutably borrows the active state, or `None` while none is installed.
    pub fn current_mut(&mut self) -> Option<&mut (dyn GameState + 'static)> {
        self.current.as_mut().map(|boxed| boxed.as_mut())
    }
}
