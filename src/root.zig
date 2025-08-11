//! 0.14.1 microlibrary to introduce type constraints.
const std = @import("std");

pub const Prototype = @import("Prototype.zig");
pub const sign = @import("sign.zig").sign;

pub const aux = @import("prototype/aux.zig");
pub const prototypes = @import("prototype/prototypes.zig");
pub const ops = @import("prototype/ops.zig");

test {
    std.testing.refAllDecls(@This());
}
