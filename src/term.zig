//! Implementation examples/appendix
const std = @import("std");

pub const Term = @import("term/Term.zig");
pub const params = @import("term/params.zig");
pub const ops = @import("term/ops.zig");
pub const types = @import("term/types.zig");

test {
    std.testing.refAllDecls(@This());
}
