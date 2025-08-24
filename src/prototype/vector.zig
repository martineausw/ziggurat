const std = @import("std");
const testing = std.testing;

const Self = @This();

const Prototype = @import("Prototype.zig");
const WithinInterval = @import("aux/WithinInterval.zig");
const HasTypeInfo = @import("aux/HasTypeInfo.zig");
const OnType = @import("aux/OnType.zig");

const VectorError = error{
    AssertsOnTypeChild,
    AssertsMinLen,
    AssertsMaxLen,
};

pub const Error = VectorError || HasTypeInfo.Error;
pub const Params = struct {
    child: OnType.Params = null,
    len: WithinInterval.Params = .{},
};

pub fn init(params: Params) Prototype {
    const has_type_info = HasTypeInfo.init(.{
        .vector = true,
    });
    const child = OnType.init(params.child);
    const len = WithinInterval.init(params.len);

    return .{
        .name = @typeName(Self),
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = try @call(.always_inline, has_type_info.eval, .{actual});

                if (child.eval(@typeInfo(actual).vector.child)) |result| {
                    if (!result) return false;
                } else |err| return switch (err) {
                    else => Error.AssertsOnTypeChild,
                };

                _ = len.eval(@typeInfo(actual).vector.len) catch |err|
                    return switch (err) {
                        WithinInterval.Error.AssertsMin,
                        => Error.AssertsMinLen,
                        WithinInterval.Error.AssertsMax,
                        => Error.AssertsMaxLen,
                        else => unreachable,
                    };

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(
                err: anyerror,
                prototype: Prototype,
                actual: anytype,
            ) void {
                switch (err) {
                    Error.AssertsTypeValue,
                    Error.AssertsActiveTypeInfo,
                    Error.AssertsInactiveTypeInfo,
                    => has_type_info.onError.?(err, prototype, actual),

                    Error.AssertsMinLen,
                    Error.AssertsMaxLen,
                    => len.onError.?(
                        try len.eval(@typeInfo(actual).vector.len),
                        prototype,
                        @typeInfo(actual).vector.len,
                    ),

                    Error.AssertsOnTypeChild => child.onError.?(
                        try child.eval(@typeInfo(actual).vector.child),
                        prototype,
                        @typeInfo(actual).vector.child,
                    ),
                }
            }
        }.onError,
    };
}

test "is vector" {
    try std.testing.expectEqual(true, init(.{}).eval(@Vector(3, f128)));
    try std.testing.expectEqual(true, init(.{}).eval(@Vector(0, u8)));
    try std.testing.expectEqual(true, init(.{}).eval(@Vector(8, bool)));
}

test "fails is vector" {
    try std.testing.expectEqual(
        false,
        init(
            .{ .child = .false },
        ).eval(@Vector(3, f128)),
    );
    try std.testing.expectEqual(
        Error.AssertsOnTypeChild,
        init(
            .{ .child = .is_bool },
        ).eval(@Vector(3, f128)),
    );
    try std.testing.expectEqual(
        Error.AssertsMinLen,
        init(
            .{ .len = .{ .min = 1 } },
        ).eval(@Vector(0, u8)),
    );
    try std.testing.expectEqual(
        Error.AssertsMaxLen,
        init(
            .{ .len = .{ .max = 0 } },
        ).eval(@Vector(1, bool)),
    );
}
