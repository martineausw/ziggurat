pub const Float = @import("prototypes/float.zig");
pub const Int = @import("prototypes/int.zig");
pub const Pointer = @import("prototypes/pointer.zig");
pub const Array = @import("prototypes/array.zig");
pub const Vector = @import("prototypes/vector.zig");
pub const Optional = @import("prototypes/optional.zig");

const std = @import("std");

test {
    std.testing.refAllDecls(@This());
}
