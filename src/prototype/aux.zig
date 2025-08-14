//! Auxillary prototypes for convenience.
const std = @import("std");

pub const child = @import("aux/child.zig");
pub const decl = @import("aux/decl.zig");
pub const exists = @import("aux/exists.zig");
pub const field = @import("aux/field.zig");
pub const filter = @import("aux/filter.zig");
pub const info = @import("aux/info.zig");
pub const interval = @import("aux/interval.zig");
pub const toggle = @import("aux/interval.zig");

test child {
    _ = child;
}

test filter {
    const Foo = struct {
        bar: ?bool = null,
    };
    _ = filter.Filter(Foo).init(.{});
}

test info {
    const info_params: info.Params = .{
        .type = null,
        .void = null,
        .bool = null,
        .noreturn = null,
        .int = null,
        .float = null,
        .pointer = null,
        .array = null,
        .@"struct" = null,
        .comptime_float = null,
        .comptime_int = null,
        .undefined = null,
        .null = null,
        .optional = null,
        .error_union = null,
        .error_set = null,
        .@"enum" = null,
        .@"union" = null,
        .@"fn" = null,
        .@"opaque" = null,
        .frame = null,
        .@"anyframe" = null,
        .vector = null,
        .enum_literal = null,
    };

    const info_prototype = info.init(info_params);

    _ = info_prototype;
    _ = info.Error;
}

test interval {
    const interval_params: interval.Params(comptime_int) = .{
        .min = null,
        .max = null,
    };

    const interval_prototype = interval.init(comptime_int, interval_params);

    _ = interval_prototype;
    _ = interval.Error;
}
