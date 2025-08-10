//! Intermediate terms for convenience.
pub const info = @import("aux/info.zig");
pub const interval = @import("aux/interval.zig");
pub const @"type" = @import("aux/type.zig");

const std = @import("std");

test {
    std.testing.refAllDecls(@This());
}
