const std = @import("std");

pub const Prototype = @import("prototype/Prototype.zig");
pub const sign = @import("sign.zig").sign;

test {
    std.testing.refAllDecls(@This());
}
