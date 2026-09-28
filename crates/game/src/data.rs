//! Static game data: AI levels, camera names and animatronic path graphs.

#[allow(unused_imports)]
use fnwf_core::prelude::*;

/// One node of a path graph: `(node_name, reachable_node_names)`.
///
/// Node names identify camera positions ("1A", "1B", "1C", "5", "2A", "2B",
/// "3", "4A", "4B", "V") as well as the special terminal nodes `"LEFT_DOOR"`,
/// `"RIGHT_DOOR"` and `"OFFICE_VENT"`. The first string is the node the
/// animatronic currently occupies; the slice lists the nodes it may pick on a
/// successful movement roll.
pub type PathEntry = (&'static str, &'static [&'static str]);
/// A full path graph: a list of [`PathEntry`] nodes.
pub type PathMap = &'static [PathEntry];

/// AI levels for each of the four animatronics on a given night.
pub fn night_ai_levels(night: i32) -> [i32; 4] {
    const LEVELS: [[i32; 4]; 7] = [
        [3, 2, 0, 0],
        [5, 4, 3, 0],
        [7, 6, 6, 5],
        [10, 9, 10, 8],
        [13, 12, 14, 12],
        [16, 15, 18, 15],
        [20, 20, 20, 20],
    ];
    if (1..=7).contains(&night) {
        LEVELS[(night - 1) as usize]
    } else {
        LEVELS[0]
    }
}

/// Camera id → human readable name.
pub fn camera_names() -> &'static [(&'static str, &'static str)] {
    &[
        ("1A", "Show Stage"),
        ("1B", "Dining Area"),
        ("1C", "Backstage"),
        ("5", "Pirate Cove"),
        ("2A", "West Hall"),
        ("2B", "West Hall Corner"),
        ("3", "Supply Closet"),
        ("4A", "East Hall"),
        ("4B", "East Hall Corner"),
        ("V", "Ventilation"),
    ]
}

/// Human readable name for a camera id, if it exists.
pub fn camera_name(id: &str) -> Option<&'static str> {
    camera_names()
        .iter()
        .find(|(cam, _)| *cam == id)
        .map(|(_, name)| *name)
}

/// Positions reachable from `pos` in `path`.
pub fn next_positions(path: PathMap, pos: &str) -> &'static [&'static str] {
    path.iter()
        .find(|(node, _)| *node == pos)
        .map(|(_, next)| *next)
        .unwrap_or(&[])
}

/// Cedro's route: show stage → dining area → west hall → left door.
pub fn cedro_path() -> PathMap {
    &[
        ("1A", &["1B"]),
        ("1B", &["2A", "3", "1C"]),
        ("1C", &["1B"]),
        ("2A", &["2B", "1B", "3"]),
        ("3", &["2A"]),
        ("2B", &["LEFT_DOOR"]),
        ("LEFT_DOOR", &["1B"]),
    ]
}

/// Eser's route: show stage → dining area → east hall → right door.
pub fn eser_path() -> PathMap {
    &[
        ("1A", &["1B"]),
        ("1B", &["4A"]),
        ("4A", &["4B", "1B"]),
        ("4B", &["RIGHT_DOOR"]),
        ("RIGHT_DOOR", &["1B"]),
    ]
}

/// Alice's vent route: show stage → dining area → vent → office vent.
pub fn alice_path() -> PathMap {
    &[
        ("1A", &["1B"]),
        ("1B", &["4A", "2A"]),
        ("4A", &["V"]),
        ("2A", &["V"]),
        ("V", &["OFFICE_VENT"]),
        ("OFFICE_VENT", &["1B"]),
    ]
}

/// Fully interconnected route used by every animatronic in secret mode, so that
/// any of them can reach both doors and the office vent.
pub fn any_door_path() -> PathMap {
    &[
        ("1A", &["1B"]),
        ("1B", &["2A", "4A", "3", "1C"]),
        ("1C", &["1B"]),
        ("2A", &["2B", "1B", "3", "4A"]),
        ("2B", &["LEFT_DOOR", "RIGHT_DOOR", "2A"]),
        ("3", &["2A", "1B"]),
        ("4A", &["4B", "1B", "2A"]),
        ("4B", &["RIGHT_DOOR", "LEFT_DOOR", "4A"]),
        ("LEFT_DOOR", &["1B"]),
        ("RIGHT_DOOR", &["1B"]),
    ]
}
