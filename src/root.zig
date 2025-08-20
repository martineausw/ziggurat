//! 0.14.1 microlibrary to introduce type constraints.
const std = @import("std");

pub const Prototype = @import("prototype/Prototype.zig");
pub const sign = @import("sign.zig").sign;

test {
    std.testing.refAllDecls(@This());
}
