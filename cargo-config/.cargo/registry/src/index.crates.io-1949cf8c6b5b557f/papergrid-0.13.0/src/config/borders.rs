/// Borders represents a Table frame with horizontal and vertical split lines.
#[derive(Debug, Default, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub struct Borders<T> {
    /// A top horizontal on the frame.
    pub top: Option<T>,
    /// A top left on the frame.
    pub top_left: Option<T>,
    /// A top right on the frame.
    pub top_right: Option<T>,
    /// A top horizontal intersection on the frame.
    pub top_intersection: Option<T>,

    /// A bottom horizontal on the frame.
    pub bottom: Option<T>,
    /// A bottom left on the frame.
    pub bottom_left: Option<T>,
    /// A bottom right on the frame.
    pub bottom_right: Option<T>,
    /// A bottom horizontal intersection on the frame.
    pub bottom_intersection: Option<T>,

    /// A horizontal split.
    pub horizontal: Option<T>,
    /// A vertical split.
    pub vertical: Option<T>,
    /// A top left character on the frame.
    pub intersection: Option<T>,

    /// A vertical split on the left frame line.
    pub left: Option<T>,
    /// A horizontal split on the left frame line.
    pub left_intersection: Option<T>,

    /// A vertical split on the right frame line.
    pub right: Option<T>,
    /// A horizontal split on the right frame line.
    pub right_intersection: Option<T>,
}

impl<T> Borders<T> {
    /// Returns empty borders.
    pub const fn empty() -> Self {
        Self {
            top: None,
            top_left: None,
            top_right: None,
            top_intersection: None,
            bottom: None,
            bottom_left: None,
            bottom_right: None,
            bottom_intersection: None,
            horizontal: None,
            left: None,
            right: None,
            vertical: None,
            left_intersection: None,
            right_intersection: None,
            intersection: None,
        }
    }

    /// Returns Borders filled in with a supplied value.
    pub const fn filled(val: T) -> Self
    where
        T: Copy,
    {
        Self {
            top: Some(val),
            top_left: Some(val),
            top_right: Some(val),
            top_intersection: Some(val),
            bottom: Some(val),
            bottom_left: Some(val),
            bottom_right: Some(val),
            bottom_intersection: Some(val),
            horizontal: Some(val),
            left: Some(val),
            right: Some(val),
            vertical: Some(val),
            left_intersection: Some(val),
            right_intersection: Some(val),
            intersection: Some(val),
        }
    }

    /// A verification whether any border was set.
    pub const fn is_empty(&self) -> bool {
        self.top.is_none()
            && self.top_left.is_none()
            && self.top_right.is_none()
            && self.top_intersection.is_none()
            && self.bottom.is_none()
            && self.bottom_left.is_none()
            && self.bottom_right.is_none()
            && self.bottom_intersection.is_none()
            && self.horizontal.is_none()
            && self.left.is_none()
            && self.right.is_none()
            && self.vertical.is_none()
            && self.left_intersection.is_none()
            && self.right_intersection.is_none()
            && self.intersection.is_none()
    }

    /// Verifies if borders has left line set on the frame.
    pub const fn has_left(&self) -> bool {
        self.left.is_some()
            || self.left_intersection.is_some()
            || self.top_left.is_some()
            || self.bottom_left.is_some()
    }

    /// Verifies if borders has right line set on the frame.
    pub const fn has_right(&self) -> bool {
        self.right.is_some()
            || self.right_intersection.is_some()
            || self.top_right.is_some()
            || self.bottom_right.is_some()
    }

    /// Verifies if borders has top line set on the frame.
    pub const fn has_top(&self) -> bool {
        self.top.is_some()
            || self.top_intersection.is_some()
            || self.top_left.is_some()
            || self.top_right.is_some()
    }

    /// Verifies if borders has bottom line set on the frame.
    pub const fn has_bottom(&self) -> bool {
        self.bottom.is_some()
            || self.bottom_intersection.is_some()
            || self.bottom_left.is_some()
            || self.bottom_right.is_some()
    }

    /// Verifies if borders has horizontal lines set.
    pub const fn has_horizontal(&self) -> bool {
        self.horizontal.is_some()
            || self.left_intersection.is_some()
            || self.right_intersection.is_some()
            || self.intersection.is_some()
    }

    /// Verifies if borders has vertical lines set.
    pub const fn has_vertical(&self) -> bool {
        self.intersection.is_some()
            || self.vertical.is_some()
            || self.top_intersection.is_some()
            || self.bottom_intersection.is_some()
    }

    /// Converts borders type into another one.
    pub fn convert_into<T1>(self) -> Borders<T1>
    where
        T1: From<T>,
    {
        Borders {
            left: self.left.map(Into::into),
            right: self.right.map(Into::into),
            top: self.top.map(Into::into),
            bottom: self.bottom.map(Into::into),
            bottom_intersection: self.bottom_intersection.map(Into::into),
            bottom_left: self.bottom_left.map(Into::into),
            bottom_right: self.bottom_right.map(Into::into),
            horizontal: self.horizontal.map(Into::into),
            intersection: self.intersection.map(Into::into),
            left_intersection: self.left_intersection.map(Into::into),
            right_intersection: self.right_intersection.map(Into::into),
            top_intersection: self.top_intersection.map(Into::into),
            top_left: self.top_left.map(Into::into),
            top_right: self.top_right.map(Into::into),
            vertical: self.vertical.map(Into::into),
        }
    }

    /// Converts borders with a given function.
    pub fn map<F, T1>(self, f: F) -> Borders<T1>
    where
        F: Fn(T) -> T1,
    {
        Borders {
            left: self.left.map(&f),
            right: self.right.map(&f),
            top: self.top.map(&f),
            bottom: self.bottom.map(&f),
            bottom_intersection: self.bottom_intersection.map(&f),
            bottom_left: self.bottom_left.map(&f),
            bottom_right: self.bottom_right.map(&f),
            horizontal: self.horizontal.map(&f),
            intersection: self.intersection.map(&f),
            left_intersection: self.left_intersection.map(&f),
            right_intersection: self.right_intersection.map(&f),
            top_intersection: self.top_intersection.map(&f),
            top_left: self.top_left.map(&f),
            top_right: self.top_right.map(&f),
            vertical: self.vertical.map(&f),
        }
    }
}
