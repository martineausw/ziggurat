//! Prototype *array*.
//!
//! Asserts *actual* is an array type value with parametric child,
//! length, and sentinel assertions.
//!
//! See also: [`std.builtin.Type.Array`](#std.builtin.Type.Array)
const std = @import("std");
const testing = std.testing;

const Prototype = @import("Prototype.zig");
const WithinInterval = @import("aux/WithinInterval.zig");
const FiltersTypeInfo = @import("aux/FiltersTypeInfo.zig");
const OnTypeInfo = @import("aux/OnTypeInfo.zig");
const OnOptional = @import("aux/OnOptional.zig");

/// Error set for array.
const ArrayError = error{
    /// *actual* is not a type value.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.type`](#root.prototype.type)
    AssertsTypeValue,
    /// *actual* requires array type info.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsWhitelistTypeInfo,
    /// *actual* array child type info has active tag that belongs to blacklist.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsBlacklistChildTypeInfo,
    /// *actual* array child type info has active tag that does not belong to whitelist.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsWhitelistChildTypeInfo,
    /// *actual* array length is less than minimum.
    ///
    /// See also: [`ziggurat.prototype.aux.interval`](#root.prototype.aux.interval)
    AssertsMinLen,
    /// *actual* array length is greater than maximum.
    ///
    /// See also: [`ziggurat.prototype.aux.interval`](#root.prototype.aux.interval)
    AssertsMaxLen,
    /// *actual* sentinel is null.
    ///
    /// See also: [`ziggurat.prototype.aux.exists`](#root.prototype.aux.exists)
    AssertsNotNullSentinel,
    /// *actual* sentinel is not null.
    ///
    /// See also: [`ziggurat.prototype.aux.exists`](#root.prototype.aux.exists)
    AssertsNullSentinel,
};

/// Error set returned by `eval`.
pub const Error = ArrayError;

/// Type value assertion for *array* prototype evaluation argument.
///
/// See also: [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
pub const has_type_info = FiltersTypeInfo.init(.{
    .array = true,
});

/// Assertion parameters for *array* prototype.
///
/// See also: [`std.builtin.Type.Array`](#std.builtin.Type.Array).
pub const Params = struct {
    /// Asserts array child type info.
    ///
    /// See also:
    /// - [`std.builtin.Type.Array`](#std.builtin.Type.Array)
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    child: OnTypeInfo.Params = .{},

    /// Asserts array length interval.
    ///
    /// See also:
    /// - [`std.builtin.Type.Array`](#std.builtin.Type.Array)
    /// - [`ziggurat.prototype.aux.interval`](#root.prototype.aux.interval)
    len: WithinInterval.Params = .{},

    /// Asserts array sentinel existence.
    ///
    /// See also:
    /// - [`std.builtin.Type.Array`](#std.builtin.Type.Array)
    /// - [`ziggurat.prototype.aux.exists`](#root.prototype.aux.exists)
    sentinel: OnOptional.Params = null,
};

pub fn init(params: Params) Prototype {
    const child = OnTypeInfo.init(params.child);
    const len = WithinInterval.init(params.len);
    const sentinel = OnOptional.init(params.sentinel);

    return .{
        .name = "Array",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = comptime has_type_info.eval(
                    actual,
                ) catch |err|
                    return switch (err) {
                        FiltersTypeInfo.Error.AssertsTypeValue,
                        => ArrayError.AssertsTypeValue,
                        FiltersTypeInfo.Error.AssertsWhitelistTypeInfo,
                        => ArrayError.AssertsWhitelistTypeInfo,
                        else => @panic("unhandled error"),
                    };

                _ = try child.eval(
                    @typeInfo(actual).array.child,
                );

                _ = len.eval(
                    @typeInfo(actual).array.len,
                ) catch |err|
                    return switch (err) {
                        WithinInterval.Error.AssertsMin,
                        => ArrayError.AssertsMinLen,
                        WithinInterval.Error.AssertsMax,
                        => ArrayError.AssertsMaxLen,
                        else => @panic("unhandled error"),
                    };

                _ = sentinel.eval(
                    @typeInfo(actual).array.sentinel(),
                ) catch |err|
                    return switch (err) {
                        OnOptional.Error.AssertsNotNull,
                        => ArrayError.AssertsNotNullSentinel,
                        else => @panic("unhandled error"),
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
                    ArrayError.AssertsTypeValue,
                    ArrayError.AssertsWhitelistTypeInfo,
                    => has_type_info.onError.?(err, prototype, actual),

                    ArrayError.AssertsMinLen,
                    ArrayError.AssertsMaxLen,
                    => len.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).array.len,
                    ),

                    ArrayError.AssertsNullSentinel,
                    => sentinel.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).array.sentinel(),
                    ),

                    else => child.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).array.child,
                    ),
                }
            }
        }.onError,
    };
}

test ArrayError {
    _ = ArrayError.AssertsTypeValue catch void;
    _ = ArrayError.AssertsWhitelistTypeInfo catch void;
    _ = ArrayError.AssertsMinLen catch void;
    _ = ArrayError.AssertsMaxLen catch void;
    _ = ArrayError.AssertsNotNullSentinel catch void;
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
        ArrayError.AssertsTypeValue,
        comptime array.eval([3]usize{ 0, 1, 2 }),
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
            .sentinel = .true,
        },
    );

    try std.testing.expectEqual(
        ArrayError.AssertsNotNullSentinel,
        array.eval([3]u8),
    );
}
