const std = @import("std");
const testing = std.testing;

const Self = @This();

const Prototype = @import("Prototype.zig");
const HasTypeInfo = @import("aux/HasTypeInfo.zig");
const OnType = @import("aux/OnType.zig");

const OptionalError = error{
    AssertsOnTypeChild,
};

pub const Error = OptionalError || HasTypeInfo.Error;
pub const Params = struct {
    child: OnType.Params = null,
};

pub fn init(params: Params) Prototype {
    const has_type_info = HasTypeInfo.init(.{
        .optional = true,
    });
    const child = OnType.init(params.child);

    return .{
        .name = @typeName(Self),
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = try has_type_info.eval(actual);
                _ = child.eval(@typeInfo(actual).optional.child) catch |err|
                    return switch (err) {
                        OnType.Error.AssertsOnType,
                        => Error.AssertsOnTypeChild,
                        else => unreachable,
                    };

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                switch (err) {
                    Error.AssertsTypeValue,
                    Error.AssertsActiveTypeInfo,
                    => has_type_info.onError.?(
                        err,
                        prototype,
                        actual,
                    ),

                    Error.AssertsOnTypeChild => child.onError.?(
                        try child.eval(@typeInfo(actual).optional.child),
                        prototype,
                        @typeInfo(actual).optional.child,
                    ),
                }
            }
        }.onError,
    };
}

test "is optional" {
    try testing.expectEqual(true, init(.{}).eval(?void));
    try testing.expectEqual(true, init(.{}).eval(?bool));
    try testing.expectEqual(true, init(.{}).eval(?@TypeOf(undefined)));
    try testing.expectEqual(true, init(.{}).eval(?fn () void));
    try testing.expectEqual(true, init(.{}).eval(?[]const struct {}));
    try testing.expectEqual(true, init(.{}).eval(?*const union {}));
    try testing.expectEqual(true, init(.{}).eval(?[*]enum {}));
    try testing.expectEqual(true, init(.{}).eval(?@Vector(3, f128)));
    try testing.expectEqual(true, init(.{}).eval(?[3]usize));
    try testing.expectEqual(true, init(.{}).eval(?f128));
    try testing.expectEqual(true, init(.{}).eval(?i128));
    try testing.expectEqual(true, init(.{}).eval(?usize));
}
