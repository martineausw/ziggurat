pub const float = @import("types/float.zig");
pub const int = @import("types/int.zig");
pub const pointer = @import("types/pointer.zig");

const std = @import("std");

test {
    std.testing.refAllDecls(@This());
}
