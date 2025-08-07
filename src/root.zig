//! 0.14.1 microlibrary to introduce type constraints.
const std = @import("std");

pub const impl = @import("impl");
pub const contract = @import("contract");

test {
    std.testing.refAllDecls(@This());
}
