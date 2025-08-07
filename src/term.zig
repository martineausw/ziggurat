//! Implementation examples/appendix
const std = @import("std");

const Term = @import("term/Term.zig");
const params = @import("term/params.zig");
const ops = @import("term/ops.zig");
const types = @import("term/types.zig");

test {
    std.testing.refAllDecls(@This());
}
