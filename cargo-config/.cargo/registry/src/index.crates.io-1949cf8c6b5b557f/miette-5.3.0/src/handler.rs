use std::fmt;

use atty::Stream;

use crate::protocol::Diagnostic;
use crate::GraphicalReportHandler;
use crate::GraphicalTheme;
use crate::NarratableReportHandler;
use crate::ReportHandler;
use crate::ThemeCharacters;
use crate::ThemeStyles;

/// Settings to control the color format used for graphical rendering.
#[derive(Copy, Clone, Debug, Eq, PartialEq)]
pub enum RgbColors {
    /// Use RGB colors even if the terminal does not support them
    Always,
    /// Use RGB colors instead of ANSI if the terminal supports RGB
    Preferred,
    /// Always use ANSI, regardless of terminal support for RGB
    Never,
}

impl Default for RgbColors {
    fn default() -> RgbColors {
        RgbColors::Never
    }
}

/**
Create a custom [`MietteHandler`] from options.

## Example

```no_run
miette::set_hook(Box::new(|_| {
    Box::new(miette::MietteHandlerOpts::new()
        .terminal_links(true)
        .unicode(false)
        .context_lines(3)
        .build())
}))
# .unwrap();
```
*/
#[derive(Default, Debug, Clone)]
pub struct MietteHandlerOpts {
    pub(crate) linkify: Option<bool>,
    pub(crate) width: Option<usize>,
    pub(crate) theme: Option<GraphicalTheme>,
    pub(crate) force_graphical: Option<bool>,
    pub(crate) force_narrated: Option<bool>,
    pub(crate) rgb_colors: RgbColors,
    pub(crate) color: Option<bool>,
    pub(crate) unicode: Option<bool>,
    pub(crate) footer: Option<String>,
    pub(crate) context_lines: Option<usize>,
    pub(crate) tab_width: Option<usize>,
    pub(crate) with_cause_chain: Option<bool>,
}

impl MietteHandlerOpts {
    /// Create a new `MietteHandlerOpts`.
    pub fn new() -> Self {
        Default::default()
    }

    /// If true, specify whether the graphical handler will make codes be
    /// clickable links in supported terminals. Defaults to auto-detection
    /// based on known supported terminals.
    pub fn terminal_links(mut self, linkify: bool) -> Self {
        self.linkify = Some(linkify);
        self
    }

    /// Set a graphical theme for the handler when rendering in graphical mode.
    /// Use [`force_graphical()`](`MietteHandlerOpts::force_graphical) to force
    /// graphical mode. This option overrides
    /// [`color()`](`MietteHandlerOpts::color).
    pub fn graphical_theme(mut self, theme: GraphicalTheme) -> Self {
        self.theme = Some(theme);
        self
    }

    /// Sets the width to wrap the report at. Defaults to 80.
    pub fn width(mut self, width: usize) -> Self {
        self.width = Some(width);
        self
    }

    /// Include the cause chain of the top-level error in the report.
    pub fn with_cause_chain(mut self) -> Self {
        self.with_cause_chain = Some(true);
        self
    }

    /// Do not include the cause chain of the top-level error in the report.
    pub fn without_cause_chain(mut self) -> Self {
        self.with_cause_chain = Some(false);
        self
    }

    /// If true, colors will be used during graphical rendering, regardless
    /// of whether or not the terminal supports them.
    ///
    /// If false, colors will never be used.
    ///
    /// If unspecified, colors will be used only if the terminal supports them.
    ///
    /// The actual format depends on the value of
    /// [`MietteHandlerOpts::rgb_colors`].
    pub fn color(mut self, color: bool) -> Self {
        self.color = Some(color);
        self
    }

    /// Controls which color format to use if colors are used in graphical
    /// rendering.
    ///
    /// The default is `Never`.
    ///
    /// This value does not control whether or not colors are being used in the
    /// first place. That is handled by the [`MietteHandlerOpts::color`]
    /// setting. If colors are not being used, the value of `rgb_colors` has
    /// no effect.
    pub fn rgb_colors(mut self, color: RgbColors) -> Self {
        self.rgb_colors = color;
        self
    }

    /// If true, forces unicode display for graphical output. If set to false,
    /// forces ASCII art display.
    pub fn unicode(mut self, unicode: bool) -> Self {
        self.unicode = Some(unicode);
        self
    }

    /// If true, graphical rendering will be used regardless of terminal
    /// detection.
    pub fn force_graphical(mut self, force: bool) -> Self {
        self.force_graphical = Some(force);
        self
    }

    /// If true, forces use of the narrated renderer.
    pub fn force_narrated(mut self, force: bool) -> Self {
        self.force_narrated = Some(force);
        self
    }

    /// Set a footer to be displayed at the bottom of the report.
    pub fn footer(mut self, footer: String) -> Self {
        self.footer = Some(footer);
        self
    }

    /// Sets the number of context lines before and after a span to display.
    pub fn context_lines(mut self, context_lines: usize) -> Self {
        self.context_lines = Some(context_lines);
        self
    }

    /// Set the displayed tab width in spaces.
    pub fn tab_width(mut self, width: usize) -> Self {
        self.tab_width = Some(width);
        self
    }

    /// Builds a [`MietteHandler`] from this builder.
    pub fn build(self) -> MietteHandler {
        let graphical = self.is_graphical();
        let width = self.get_width();
        if !graphical {
            let mut handler = NarratableReportHandler::new();
            if let Some(footer) = self.footer {
                handler = handler.with_footer(footer);
            }
            if let Some(context_lines) = self.context_lines {
                handler = handler.with_context_lines(context_lines);
            }
            if let Some(with_cause_chain) = self.with_cause_chain {
                if with_cause_chain {
                    handler = handler.with_cause_chain();
                } else {
                    handler = handler.without_cause_chain();
                }
            }
            MietteHandler {
                inner: Box::new(handler),
            }
        } else {
            let linkify = self.use_links();
            let characters = match self.unicode {
                Some(true) => ThemeCharacters::unicode(),
                Some(false) => ThemeCharacters::ascii(),
                None if supports_unicode::on(Stream::Stderr) => ThemeCharacters::unicode(),
                None => ThemeCharacters::ascii(),
            };
            let styles = if self.color == Some(false) {
                ThemeStyles::none()
            } else if let Some(color) = supports_color::on(Stream::Stderr) {
                match self.rgb_colors {
                    RgbColors::Always => ThemeStyles::rgb(),
                    RgbColors::Preferred if color.has_16m => ThemeStyles::rgb(),
                    _ => ThemeStyles::ansi(),
                }
            } else if self.color == Some(true) {
                match self.rgb_colors {
                    RgbColors::Always => ThemeStyles::rgb(),
                    _ => ThemeStyles::ansi(),
                }
            } else {
                ThemeStyles::none()
            };
            let theme = self.theme.unwrap_or(GraphicalTheme { characters, styles });
            let mut handler = GraphicalReportHandler::new()
                .with_width(width)
                .with_links(linkify)
                .with_theme(theme);
            if let Some(with_cause_chain) = self.with_cause_chain {
                if with_cause_chain {
                    handler = handler.with_cause_chain();
                } else {
                    handler = handler.without_cause_chain();
                }
            }
            if let Some(footer) = self.footer {
                handler = handler.with_footer(footer);
            }
            if let Some(context_lines) = self.context_lines {
                handler = handler.with_context_lines(context_lines);
            }
            if let Some(w) = self.tab_width {
                handler = handler.tab_width(w);
            }
            MietteHandler {
                inner: Box::new(handler),
            }
        }
    }

    pub(crate) fn is_graphical(&self) -> bool {
        if let Some(force_narrated) = self.force_narrated {
            !force_narrated
        } else if let Some(force_graphical) = self.force_graphical {
            force_graphical
        } else if let Ok(env) = std::env::var("NO_GRAPHICS") {
            env == "0"
        } else {
            true
        }
    }

    // Detects known terminal apps based on env variables and returns true if
    // they support rendering links.
    pub(crate) fn use_links(&self) -> bool {
        if let Some(linkify) = self.linkify {
            linkify
        } else {
            supports_hyperlinks::on(Stream::Stderr)
        }
    }

    pub(crate) fn get_width(&self) -> usize {
        self.width.unwrap_or_else(|| {
            terminal_size::terminal_size()
                .unwrap_or((terminal_size::Width(80), terminal_size::Height(0)))
                .0
                 .0 as usize
        })
    }
}

/**
A [`ReportHandler`] that displays a given [`Report`](crate::Report) in a
quasi-graphical way, using terminal colors, unicode drawing characters, and
other such things.

This is the default reporter bundled with `miette`.

This printer can be customized by using
[`GraphicalReportHandler::new_themed()`] and handing it a [`GraphicalTheme`] of
your own creation (or using one of its own defaults).

See [`set_hook`](crate::set_hook) for more details on customizing your global
printer.
*/
#[allow(missing_debug_implementations)]
pub struct MietteHandler {
    inner: Box<dyn ReportHandler + Send + Sync>,
}

impl MietteHandler {
    /// Creates a new [`MietteHandler`] with default settings.
    pub fn new() -> Self {
        Default::default()
    }
}

impl Default for MietteHandler {
    fn default() -> Self {
        MietteHandlerOpts::new().build()
    }
}

impl ReportHandler for MietteHandler {
    fn debug(&self, diagnostic: &(dyn Diagnostic), f: &mut fmt::Formatter<'_>) -> fmt::Result {
        if f.alternate() {
            return fmt::Debug::fmt(diagnostic, f);
        }

        self.inner.debug(diagnostic, f)
    }
}
