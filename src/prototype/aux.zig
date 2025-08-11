//! Auxillary prototypes for convenience.
const std = @import("std");

/// Asserts filter type info tags.
///
pub const info = @import("aux/info.zig");

/// Asserts inclusive interval on number values.
///
/// - `min`, asserts inclusive minimum
/// - `max`, asserts inclusive maximum
pub const interval = @import("aux/interval.zig");

/// Asserts value is `type` type.
pub const @"type" = @import("aux/type.zig").init;

test {
    std.testing.refAllDecls(@This());
}
