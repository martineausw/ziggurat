//! Prototype for `type` value with array type info.
//!
//! `eval` asserts array type within parameters:
//!
//! - `child`, type info filter assertion.
//! - `len`, type info interval assertion.
//! - `sentinel`, type info value assertion.
const std = @import("std");
const testing = std.testing;

const Prototype = @import("Prototype.zig");
const interval = @import("aux/interval.zig");
const info = @import("aux/info.zig");
const exists = @import("aux/exists.zig");

/// Error set for array.
const ArrayError = error{
    ExpectsTypeValue,
    RequiresTypeInfo,
    /// Violates `std.builtin.Type.array.child` blacklist assertion.
    BanishesChildTypeInfo,
    RequiresChildTypeInfo,
    /// Violates `std.builtin.Type.array.len` assertion.
    AssertsMinLen,
    AssertsMaxLen,
    /// Violates `std.builtin.Type.array.sentinel` assertion.
    AssertsNotNullSentinel,
    AssertsNullSentinel,
};

/// Error set returned by `eval`.
pub const Error = ArrayError;

/// Validates `actual` to `std.builtin.Type.array`.
pub const info_validator = info.init(.{
    .array = true,
});

/// Parameters for prototype evaluation.
///
/// Derived from `std.builtin.Type.Array`.
pub const Params = struct {
    /// Evaluates against `std.builtin.Type.array.child`.
    child: info.Params = .{},

    /// Evaluates against `std.builtin.Type.array.len`
    len: interval.Params = .{},

    /// Evaluates against `std.builtin.Type.array.sentinel()`.
    sentinel: exists.Params = null,
};

/// Expects array type value.
///
/// `actual` assertions:
///
/// type info is `std.builtin.Type.array`.
///
/// `std.builtin.Type.pointer.child` is within given `params.child`
/// assertions.
///
/// `std.builtin.Type.pointer.len` is within given `params.len`
/// assertions.
///
/// `actual` type info `sentinel()` is not-null when given params is true
/// or null when given params is false, otherwise returns error.
pub fn init(params: Params) Prototype {
    const child_validator = info.init(params.child);
    const len_validator = interval.init(params.len);
    const sentinel_validator = exists.init(params.sentinel);

    return .{
        .name = "Array",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = comptime info_validator.eval(
                    actual,
                ) catch |err|
                    return switch (err) {
                        info.Error.ExpectsTypeValue,
                        => ArrayError.ExpectsTypeValue,
                        info.Error.RequiresTypeInfo,
                        => ArrayError.RequiresTypeInfo,
                        else => unreachable,
                    };

                _ = comptime child_validator.eval(
                    @typeInfo(actual).array.child,
                ) catch |err|
                    return switch (err) {
                        info.Error.BanishesTypeInfo,
                        => ArrayError.BanishesChildTypeInfo,
                        info.Error.RequiresTypeInfo,
                        => ArrayError.RequiresChildTypeInfo,
                        else => unreachable,
                    };

                _ = len_validator.eval(
                    @typeInfo(actual).array.len,
                ) catch |err|
                    return switch (err) {
                        interval.Error.AssertsMin,
                        => ArrayError.AssertsMinLen,
                        interval.Error.AssertsMax,
                        => ArrayError.AssertsMaxLen,
                        else => unreachable,
                    };

                _ = sentinel_validator.eval(
                    @typeInfo(actual).array.sentinel(),
                ) catch |err|
                    return switch (err) {
                        exists.Error.AssertsNotNull,
                        => ArrayError.AssertsNotNullSentinel,
                        exists.Error.AssertsNull,
                        => ArrayError.AssertsNullSentinel,
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
                    ArrayError.ExpectsTypeValue,
                    ArrayError.RequiresTypeInfo,
                    => info_validator.onError.?(err, prototype, actual),

                    ArrayError.BanishesChildTypeInfo,
                    ArrayError.RequiresChildTypeInfo,
                    => info_validator.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).array.child,
                    ),

                    ArrayError.AssertsMinLen,
                    ArrayError.AssertsMaxLen,
                    => len_validator.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).array.len,
                    ),

                    ArrayError.AssertsNotNullSentinel,
                    ArrayError.AssertsNullSentinel,
                    => sentinel_validator.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).array.sentinel(),
                    ),

                    else => unreachable,
                }
            }
        }.onError,
    };
}

test ArrayError {
    _ = ArrayError.ExpectsTypeValue catch void;
    _ = ArrayError.RequiresTypeInfo catch void;
    _ = ArrayError.BanishesChildTypeInfo catch void;
    _ = ArrayError.RequiresChildTypeInfo catch void;
    _ = ArrayError.AssertsMinLen catch void;
    _ = ArrayError.AssertsMaxLen catch void;
    _ = ArrayError.AssertsNotNullSentinel catch void;
    _ = ArrayError.AssertsNullSentinel catch void;
}

test Params {
    const params: Params = .{
        .child = .{},
        .len = .{
            .min = null,
            .max = null,
        },
        .sentinel = null,
    };

    _ = params;
}

test init {
    const array = init(.{
        .child = .{},
        .len = .{
            .min = null,
            .max = null,
        },
        .sentinel = null,
    });

    _ = array;
}

test "passes array assertions" {
    const array = init(
        .{
            .child = .{},
            .len = .{
                .min = null,
                .max = null,
            },
            .sentinel = null,
        },
    );

    try std.testing.expectEqual(
        true,
        array.eval([5]u8),
    );
}

test "fails type value assertion" {
    const array = init(
        .{
            .child = .{},
            .len = .{
                .min = null,
                .max = null,
            },
            .sentinel = null,
        },
    );

    try std.testing.expectEqual(
        ArrayError.ExpectsTypeValue,
        comptime array.eval([3]usize{ 0, 1, 2 }),
    );
}

test "fails array child type info whitelist assertions" {
    const array = init(
        .{
            .child = .{
                .int = true,
            },
            .len = .{
                .min = null,
                .max = null,
            },
            .sentinel = null,
        },
    );

    try std.testing.expectEqual(
        ArrayError.RequiresChildTypeInfo,
        comptime array.eval([3]f128),
    );
}

test "fails array child type info blacklist assertions" {
    const array = init(
        .{
            .child = .{
                .int = false,
            },
            .len = .{
                .min = null,
                .max = null,
            },
            .sentinel = null,
        },
    );

    try std.testing.expectEqual(
        ArrayError.BanishesChildTypeInfo,
        comptime array.eval([3]usize),
    );
}

test "fails array length interval assertions" {
    const array = init(
        .{
            .child = .{},
            .len = .{
                .min = 1,
                .max = 2,
            },
            .sentinel = null,
        },
    );

    try std.testing.expectEqual(
        ArrayError.AssertsMinLen,
        array.eval([0]usize),
    );

    try std.testing.expectEqual(
        ArrayError.AssertsMaxLen,
        array.eval([3]usize),
    );
}

test "fails array sentinel is not null assertion" {
    const array = init(
        .{
            .child = .{},
            .len = .{
                .min = null,
                .max = null,
            },
            .sentinel = true,
        },
    );

    try std.testing.expectEqual(
        ArrayError.AssertsNotNullSentinel,
        array.eval([3]u8),
    );
}

test "fails array sentinel is null assertion" {
    const array = init(
        .{
            .child = .{},
            .len = .{
                .min = null,
                .max = null,
            },
            .sentinel = false,
        },
    );

    try std.testing.expectEqual(
        ArrayError.AssertsNullSentinel,
        array.eval([3:0]u8),
    );
}
