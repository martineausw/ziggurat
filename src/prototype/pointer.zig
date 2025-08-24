const std = @import("std");
const testing = std.testing;

const Self = @This();

const Prototype = @import("Prototype.zig");
const WithinInterval = @import("aux/WithinInterval.zig");
const HasTypeInfo = @import("aux/HasTypeInfo.zig");
const HasSize = @import("aux/HasTag.zig").Of(std.builtin.Type.Pointer.Size);
const EqualsBool = @import("aux/EqualsBool.zig");
const HasValue = @import("aux/HasValue.zig");
const OnType = @import("aux/OnType.zig");

const PointerError = error{
    AssertsOnTypeChild,
    AssertsInactiveSize,
    AssertsActiveSize,
    AssertsTrueIsConst,
    AssertsFalseIsConst,
    AssertsTrueIsVolatile,
    AssertsFalseIsVolatile,
    AssertsNotNullSentinel,
    AssertsNullSentinel,
};

pub const Error = PointerError || HasTypeInfo.Error;
pub const Params = struct {
    child: OnType.Params = null,
    size: HasSize.Params = .{},
    is_const: EqualsBool.Params = null,
    is_volatile: EqualsBool.Params = null,
    sentinel: HasValue.Params = null,
};

pub fn init(params: Params) Prototype {
    const has_type_info = HasTypeInfo.init(.{
        .pointer = true,
    });
    const child = OnType.init(params.child);
    const size = HasSize.init(params.size);
    const is_const = EqualsBool.init(params.is_const);
    const is_volatile = EqualsBool.init(params.is_volatile);
    const sentinel = HasValue.init(params.sentinel);
    return .{
        .name = @typeName(Self),
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = try has_type_info.eval(actual);

                if (child.eval(@typeInfo(actual).pointer.child)) |result| {
                    if (!result) return false;
                } else |err| return switch (err) {
                    else => Error.AssertsOnTypeChild,
                };

                _ = @call(
                    .always_inline,
                    size.eval,
                    .{@typeInfo(actual).pointer.size},
                ) catch |err|
                    return switch (err) {
                        HasSize.Error.AssertsInactive,
                        => Error.AssertsInactiveSize,
                        HasSize.Error.AssertsActive,
                        => Error.AssertsActiveSize,
                        else => unreachable,
                    };

                _ = is_const.eval(
                    @typeInfo(actual).pointer.is_const,
                ) catch |err|
                    return switch (err) {
                        EqualsBool.Error.AssertsTrue,
                        => Error.AssertsTrueIsConst,
                        EqualsBool.Error.AssertsFalse,
                        => Error.AssertsFalseIsConst,
                        else => unreachable,
                    };

                _ = is_volatile.eval(
                    @typeInfo(actual).pointer.is_volatile,
                ) catch |err|
                    return switch (err) {
                        EqualsBool.Error.AssertsTrue,
                        => Error.AssertsTrueIsVolatile,
                        EqualsBool.Error.AssertsFalse,
                        => Error.AssertsFalseIsVolatile,
                        else => unreachable,
                    };

                _ = sentinel.eval(
                    @typeInfo(actual).pointer.sentinel(),
                ) catch |err|
                    return switch (err) {
                        HasValue.Error.AssertsNotNull => Error.AssertsNotNullSentinel,
                        HasValue.Error.AssertsNull => Error.AssertsNullSentinel,
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
                    => has_type_info.onError.?(err, prototype, actual),

                    Error.AssertsOnTypeChild,
                    => child.onError.?(
                        try child.eval(@typeInfo(actual).pointer.child),
                        prototype,
                        @typeInfo(actual).pointer.child,
                    ),

                    Error.AssertsInactiveSize,
                    Error.AssertsActiveSize,
                    => size.onError.?(
                        try size.eval(@typeInfo(actual).pointer.size),
                        prototype,
                        @typeInfo(actual).pointer.size,
                    ),

                    Error.AssertsTrueIsConst,
                    Error.AssertsFalseIsConst,
                    => is_const.onError.?(
                        try is_const.eval(@typeInfo(actual).pointer.is_const),
                        prototype,
                        @typeInfo(actual).pointer.is_const,
                    ),

                    Error.AssertsTrueIsVolatile,
                    Error.AssertsFalseIsVolatile,
                    => is_volatile.onError.?(
                        try is_volatile.eval(@typeInfo(actual).pointer.is_volatile),
                        prototype,
                        @typeInfo(actual).pointer.is_volatile,
                    ),

                    Error.AssertsNotNullSentinel,
                    => sentinel.onError.?(
                        try sentinel.eval(@typeInfo(actual).pointer.sentinel()),
                        prototype,
                        @typeInfo(actual).pointer.sentinel(),
                    ),
                    else => unreachable,
                }
            }
        }.onError,
    };
}

test "is pointer" {
    try testing.expectEqual(true, init(.{}).eval([]struct {}));
    try testing.expectEqual(true, init(.{}).eval([]const struct {}));
    try testing.expectEqual(true, init(.{}).eval([]volatile struct {}));
    try testing.expectEqual(true, init(.{}).eval([]const volatile struct {}));

    try testing.expectEqual(true, init(.{}).eval([:0]u8));
    try testing.expectEqual(true, init(.{}).eval([:0]const u8));
    try testing.expectEqual(true, init(.{}).eval([:0]volatile u8));
    try testing.expectEqual(true, init(.{}).eval([:0]const volatile u8));

    try testing.expectEqual(true, init(.{}).eval(*union {}));
    try testing.expectEqual(true, init(.{}).eval(*const union {}));
    try testing.expectEqual(true, init(.{}).eval(*volatile union {}));
    try testing.expectEqual(true, init(.{}).eval(*const volatile union {}));

    try testing.expectEqual(true, init(.{}).eval([*]enum {}));
    try testing.expectEqual(true, init(.{}).eval([*]const enum {}));
    try testing.expectEqual(true, init(.{}).eval([*]volatile enum {}));
    try testing.expectEqual(true, init(.{}).eval([*]const volatile enum {}));
}

test "failse is pointer" {
    try testing.expectEqual(false, init(.{ .child = .false }).eval([]const volatile struct {}));
    try testing.expectEqual(Error.AssertsOnTypeChild, init(.{ .child = .@"error" }).eval([:0]const volatile u8));
    try testing.expectEqual(Error.AssertsInactiveSize, init(.{ .size = .{ .slice = false } }).eval([]struct {}));
    try testing.expectEqual(Error.AssertsActiveSize, init(.{ .size = .{ .slice = true } }).eval(*union {}));
    try testing.expectEqual(Error.AssertsFalseIsConst, init(.{ .is_const = false }).eval([]const struct {}));
    try testing.expectEqual(Error.AssertsTrueIsConst, init(.{ .is_const = true }).eval([:0]volatile u8));
    try testing.expectEqual(Error.AssertsFalseIsVolatile, init(.{ .is_volatile = false }).eval([]volatile struct {}));
    try testing.expectEqual(Error.AssertsTrueIsVolatile, init(.{ .is_volatile = true }).eval([:0]const u8));
    try testing.expectEqual(Error.AssertsNullSentinel, init(.{ .sentinel = false }).eval([:0]u8));
    try testing.expectEqual(Error.AssertsNotNullSentinel, init(.{ .sentinel = true }).eval(*const union {}));
}
