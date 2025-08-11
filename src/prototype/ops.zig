//! Boolean operations for `Prototype.eval` implementations.
const std = @import("std");

/// Asserts boolean AND of two prototype evaluation results.
pub const conjoin = @import("ops/conjoin.zig").conjoin;

/// Asserts boolean OR of two prototype evaluation results.
pub const disjoin = @import("ops/disjoin.zig").disjoin;

/// Asserts boolean NOT of a prototype evaluation result.
pub const negate = @import("ops/negate.zig").negate;

test {
    std.testing.refAllDecls(@This());
}
