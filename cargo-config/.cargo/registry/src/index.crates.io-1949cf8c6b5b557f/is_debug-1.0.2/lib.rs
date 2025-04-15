use std::fmt::Display;

#[derive(Debug, PartialEq)]
pub enum BuildModel {
    Debug,
    Release,
}

pub const fn build_channel() -> BuildModel {
    if cfg!(debug_assertions) {
        return BuildModel::Debug;
    }
    BuildModel::Release
}

impl Display for BuildModel {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Debug => f.write_str("debug"),
            Self::Release => f.write_str("release"),
        }
    }
}

pub const fn is_debug() -> bool {
    matches!(build_channel(), BuildModel::Debug)
}

pub const fn is_release() -> bool {
    matches!(build_channel(), BuildModel::Release)
}
