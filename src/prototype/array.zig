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
    InvalidArgument,
    /// Violates `std.builtin.Type.array.child` blacklist assertion.
    BanishesChildType,
    RequiresChildType,
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
    len: interval.Params(comptime_int) = .{},

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
    const len_validator = interval.init(comptime_int, params.len);
    const sentinel_validator = exists.init(params.sentinel);

    return .{
        .name = "Array",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = info_validator.eval(actual) catch |err|
                    return switch (err) {
                        info.Error.InvalidArgument,
                        info.Error.RequiresType,
                        => ArrayError.InvalidArgument,
                        else => unreachable,
                    };

                const actual_info = switch (@typeInfo(actual)) {
                    .array => |array_info| array_info,
                    else => unreachable,
                };

                _ = child_validator.eval(actual_info.child) catch |err|
                    return switch (err) {
                        info.Error.BanishesType,
                        => ArrayError.BanishesChildType,
                        info.Error.RequiresType,
                        => ArrayError.RequiresChildType,
                        else => unreachable,
                    };

                _ = len_validator.eval(actual_info.len) catch |err|
                    return switch (err) {
                        interval.Error.AssertsMin,
                        => ArrayError.AssertsMinLen,
                        interval.Error.AssertsMax,
                        => ArrayError.AssertsMaxLen,
                        else => unreachable,
                    };

                _ = sentinel_validator.eval(
                    actual_info.sentinel(),
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
                    ArrayError.InvalidArgument,
                    => info_validator.onError(err, prototype, actual),

                    ArrayError.BanishesChildType,
                    ArrayError.RequiresChildType,
                    => info_validator.onError(
                        err,
                        prototype,
                        @typeInfo(actual).array.child,
                    ),

                    ArrayError.AssertsMinLen,
                    ArrayError.AssertsMaxLen,
                    => len_validator.onError(
                        err,
                        prototype,
                        @typeInfo(actual).array.len,
                    ),

                    ArrayError.AssertsNotNullSentinel,
                    ArrayError.AssertsNullSentinel,
                    => sentinel_validator.onError(
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
    _ = ArrayError.InvalidArgument catch void;
    _ = ArrayError.BanishesChildType catch void;
    _ = ArrayError.RequiresChildType catch void;
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
