const std = @import("std");
const testing = std.testing;

const Self = @This();

const Prototype = @import("Prototype.zig");
const WithinInterval = @import("aux/WithinInterval.zig");
const HasTypeInfo = @import("aux/HasTypeInfo.zig");
const HasValue = @import("aux/HasValue.zig");
const OnType = @import("aux/OnType.zig");

const ArrayError = error{
    AssertsOnTypeChild,
    AssertsMinLen,
    AssertsMaxLen,
    AssertsNotNullSentinel,
    AssertsNullSentinel,
};

pub const Error = ArrayError || HasTypeInfo.Error;
pub const Params = struct {
    child: OnType.Params = null,
    len: WithinInterval.Params = .{},
    sentinel: HasValue.Params = null,
};

pub fn init(params: Params) Prototype {
    const has_type_info = HasTypeInfo.init(.{
        .array = true,
    });
    const child = OnType.init(params.child);
    const len = WithinInterval.init(params.len);
    const sentinel = HasValue.init(params.sentinel);

    return .{
        .name = @typeName(Self),
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = try @call(.always_inline, has_type_info.eval, .{actual});

                if (child.eval(@typeInfo(actual).array.child)) |result| {
                    if (!result) return false;
                } else |err| return switch (err) {
                    else => Error.AssertsOnTypeChild,
                };

                _ = len.eval(
                    @typeInfo(actual).array.len,
                ) catch |err|
                    return switch (err) {
                        WithinInterval.Error.AssertsMin,
                        => Error.AssertsMinLen,
                        WithinInterval.Error.AssertsMax,
                        => Error.AssertsMaxLen,
                        else => unreachable,
                    };

                _ = sentinel.eval(
                    @typeInfo(actual).array.sentinel(),
                ) catch |err|
                    return switch (err) {
                        HasValue.Error.AssertsNotNull,
                        => Error.AssertsNotNullSentinel,
                        HasValue.Error.AssertsNull,
                        => Error.AssertsNullSentinel,
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
                    => has_type_info.onError.?(
                        err,
                        prototype,
                        actual,
                    ),

                    Error.AssertsMinLen,
                    Error.AssertsMaxLen,
                    => len.onError.?(
                        try len.eval(@typeInfo(actual).array.len),
                        prototype,
                        @typeInfo(actual).array.len,
                    ),

                    Error.AssertsNullSentinel,
                    Error.AssertsNotNullSentinel,
                    => sentinel.onError.?(
                        try sentinel.eval(@typeInfo(actual).array.sentinel()),
                        prototype,
                        @typeInfo(actual).array.sentinel(),
                    ),

                    Error.AssertsOnTypeChild => child.onError.?(
                        try child.eval(@typeInfo(actual).array.child),
                        prototype,
                        @typeInfo(actual).array.child,
                    ),
                }
            }
        }.onError,
    };
}

test "is array" {
    try testing.expectEqual(true, init(.{}).eval([128]f128));
    try testing.expectEqual(true, init(.{}).eval([100:0]f128));
}

test "fails is array" {
    try testing.expectEqual(
        Error.AssertsOnTypeChild,
        init(.{ .child = .is_int(.{}) }).eval([0]bool),
    );
    try testing.expectEqual(
        Error.AssertsMinLen,
        init(.{ .len = .{ .min = 1 } }).eval([0]usize),
    );
    try testing.expectEqual(
        Error.AssertsMaxLen,
        init(.{ .len = .{ .max = 0 } }).eval([1]usize),
    );
    try testing.expectEqual(
        Error.AssertsNullSentinel,
        init(.{ .sentinel = false }).eval([10:0]u8),
    );
    try testing.expectEqual(
        Error.AssertsNotNullSentinel,
        init(.{ .sentinel = true }).eval([10]u8),
    );
}

test "fails validation" {
    try testing.expectEqual(Error.AssertsTypeValue, init(.{}).eval([_]usize{ 1, 2, 3 }));

    try testing.expectEqual(Error.AssertsActiveTypeInfo, init(.{}).eval([]f128));
    try testing.expectEqual(Error.AssertsActiveTypeInfo, init(.{}).eval([*]f128));
    try testing.expectEqual(Error.AssertsActiveTypeInfo, init(.{}).eval(*const u8));
}
