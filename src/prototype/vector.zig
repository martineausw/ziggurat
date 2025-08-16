//! Prototype for `type` value with vector type info.
//!
//! `eval` asserts vector type within parameters:
//!
//! - `child`, type info filter assertion.
//! - `len`, type info interval assertion.
const std = @import("std");
const testing = std.testing;

const Prototype = @import("Prototype.zig");
const interval = @import("aux/interval.zig");
const info = @import("aux/info.zig");

/// Error set for vector.
const VectorError = error{
    InvalidArgument,
    RequiresTypeInfo,
    BanishesChildTypeInfo,
    RequiresChildTypeInfo,
    AssertsMinLen,
    AssertsMaxLen,
};

/// Error set returned by `eval`.
pub const Error = VectorError;

/// Validates type info of `actual` to continue.
pub const info_validator = info.init(.{
    .vector = true,
});

/// Parameters for prototype evaluation.
///
/// Associated with `std.builtin.Type.Vector`.
pub const Params = struct {
    /// Evaluates against `.child`
    child: info.Params = .{},

    /// Evaluates against `.len`.
    len: interval.Params = .{},
};

/// Expects vector type value.
///
/// `actual` is a vector type value.
///
/// `actual` type info `len` is within given `params`.
pub fn init(params: Params) Prototype {
    const child_validator = info.init(params.child);
    const len_validator = interval.init(params.len);

    return .{
        .name = "Vector",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = info_validator.eval(actual) catch |err|
                    return switch (err) {
                        info.Error.InvalidArgument,
                        => VectorError.InvalidArgument,
                        info.Error.RequiresTypeInfo,
                        => VectorError.RequiresTypeInfo,
                        else => unreachable,
                    };

                const actual_info = switch (@typeInfo(actual)) {
                    .vector => |vector_info| vector_info,
                    else => unreachable,
                };

                _ = child_validator.eval(actual_info.child) catch |err| {
                    return switch (err) {
                        info.Error.BanishesTypeInfo,
                        => VectorError.BanishesChildTypeInfo,
                        info.Error.RequiresTypeInfo,
                        => VectorError.RequiresChildTypeInfo,
                        else => unreachable,
                    };
                };

                _ = len_validator.eval(actual_info.len) catch |err|
                    return switch (err) {
                        interval.Error.AssertsMin,
                        => VectorError.AssertsMinLen,
                        interval.Error.AssertsMax,
                        => VectorError.AssertsMaxLen,
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
                    VectorError.InvalidArgument,
                    VectorError.RequiresTypeInfo,
                    => info_validator.onError.?(err, prototype, actual),

                    VectorError.BanishesChildType,
                    VectorError.RequiresChildType,
                    => child_validator.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).vector.child,
                    ),

                    VectorError.AssertsMinLen,
                    VectorError.AssertsMaxLen,
                    => len_validator.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).vector.len,
                    ),

                    else => unreachable,
                }
            }
        }.onError,
    };
}

test VectorError {
    _ = VectorError.InvalidArgument catch void;
    _ = VectorError.RequiresTypeInfo catch void;

    _ = VectorError.BanishesChildTypeInfo catch void;
    _ = VectorError.RequiresChildTypeInfo catch void;

    _ = VectorError.AssertsMinLen catch void;
    _ = VectorError.AssertsMaxLen catch void;
}

test Params {
    const params: Params = .{
        .child = .{},
        .len = .{
            .min = null,
            .max = null,
        },
    };
    _ = params;
}

test init {
    const vector = init(.{
        .child = .{},
        .len = .{
            .min = null,
            .max = null,
        },
    });

    _ = vector;
}

test "evaluates vector successfully" {
    const vector = init(.{
        .child = .{},
        .len = .{
            .min = null,
            .max = null,
        },
    });

    try std.testing.expectEqual(true, vector.eval(@Vector(3, f128)));
}

test "coerces VectorError.BanishesChildType" {
    const vector = init(.{
        .child = .{
            .float = false,
        },
        .len = .{
            .min = null,
            .max = null,
        },
    });

    try std.testing.expectEqual(
        VectorError.BanishesChildTypeInfo,
        comptime vector.eval(@Vector(3, f128)),
    );
}

test "coerces VectorError.RequiresChildType" {
    const vector = init(.{
        .child = .{
            .int = true,
        },
        .len = .{
            .min = null,
            .max = null,
        },
    });

    try std.testing.expectEqual(
        VectorError.RequiresChildTypeInfo,
        comptime vector.eval(@Vector(3, f128)),
    );
}

test "coerces VectorError.AssertsMinLen and VectoreError.AssertsMaxLen" {
    const vector = init(.{
        .child = .{},
        .len = .{
            .min = 1,
            .max = 2,
        },
    });

    try std.testing.expectEqual(
        VectorError.AssertsMinLen,
        comptime vector.eval(@Vector(0, f128)),
    );

    try std.testing.expectEqual(
        VectorError.AssertsMaxLen,
        comptime vector.eval(@Vector(3, f128)),
    );
}
