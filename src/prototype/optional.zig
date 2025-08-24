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
                if (child.eval(@typeInfo(actual).optional.child)) |result| {
                    if (!result) return false;
                } else |err| {
                    return switch (err) {
                        else => Error.AssertsOnTypeChild,
                    };
                }

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
                    else => unreachable,
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

test "fails is optional" {
    try testing.expectEqual(false, init(.{ .child = .false }).eval(?void));
    try testing.expectEqual(false, init(.{ .child = .false }).eval(?bool));
    try testing.expectEqual(false, init(.{ .child = .false }).eval(?@TypeOf(undefined)));
    try testing.expectEqual(false, init(.{ .child = .false }).eval(?fn () void));
    try testing.expectEqual(false, init(.{ .child = .false }).eval(?[]const struct {}));
    try testing.expectEqual(false, init(.{ .child = .false }).eval(?*const union {}));
    try testing.expectEqual(false, init(.{ .child = .false }).eval(?[*]enum {}));
    try testing.expectEqual(false, init(.{ .child = .false }).eval(?@Vector(3, f128)));
    try testing.expectEqual(false, init(.{ .child = .false }).eval(?[3]usize));
    try testing.expectEqual(false, init(.{ .child = .false }).eval(?f128));
    try testing.expectEqual(false, init(.{ .child = .false }).eval(?i128));
    try testing.expectEqual(false, init(.{ .child = .false }).eval(?usize));

    try testing.expectEqual(Error.AssertsOnTypeChild, init(.{ .child = .@"error" }).eval(?void));
    try testing.expectEqual(Error.AssertsOnTypeChild, init(.{ .child = .@"error" }).eval(?bool));
    try testing.expectEqual(Error.AssertsOnTypeChild, init(.{ .child = .@"error" }).eval(?@TypeOf(undefined)));
    try testing.expectEqual(Error.AssertsOnTypeChild, init(.{ .child = .@"error" }).eval(?fn () void));
    try testing.expectEqual(Error.AssertsOnTypeChild, init(.{ .child = .@"error" }).eval(?[]const struct {}));
    try testing.expectEqual(Error.AssertsOnTypeChild, init(.{ .child = .@"error" }).eval(?*const union {}));
    try testing.expectEqual(Error.AssertsOnTypeChild, init(.{ .child = .@"error" }).eval(?[*]enum {}));
    try testing.expectEqual(Error.AssertsOnTypeChild, init(.{ .child = .@"error" }).eval(?@Vector(3, f128)));
    try testing.expectEqual(Error.AssertsOnTypeChild, init(.{ .child = .@"error" }).eval(?[3]usize));
    try testing.expectEqual(Error.AssertsOnTypeChild, init(.{ .child = .@"error" }).eval(?f128));
    try testing.expectEqual(Error.AssertsOnTypeChild, init(.{ .child = .@"error" }).eval(?i128));
    try testing.expectEqual(Error.AssertsOnTypeChild, init(.{ .child = .@"error" }).eval(?usize));
}
