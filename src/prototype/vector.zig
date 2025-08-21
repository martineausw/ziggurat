//! Prototype *vector*.
//!
//! Asserts *actual* is a vector type value with parametric child and
//! length assertions.
//!
//! See also: [`std.builtin.Type.Vector`](#std.builtin.Type.Vector)
const std = @import("std");
const testing = std.testing;

const Prototype = @import("Prototype.zig");
const WithinInterval = @import("aux/WithinInterval.zig");
const FiltersTypeInfo = @import("aux/FiltersTypeInfo.zig");
const OnType = @import("aux/OnType.zig");

const Self = @This();

/// Error set for *vector* prototype.
const VectorError = error{
    /// *actual* is not a type value.
    ///
    /// See also:
    /// - [`test.prototype.int`](#test.prototype.int)
    AssertsTypeValue,
    /// *actual* type value requires vector type info.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsWhitelistTypeInfo,

    /// *actual* vector length is less than minimum.
    ///
    /// See also: [`ziggurat.prototype.aux.interval`](#root.prototype.aux.interval)
    AssertsMinLen,
    /// *actual* vector length is greater than maximum.
    ///
    /// See also: [`ziggurat.prototype.aux.interval`](#root.prototype.aux.interval)
    AssertsMaxLen,
};

pub const Error = VectorError;

/// Type value assertion for *vector* prototype evaluation argument.
///
/// See also: [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
pub const has_type_info = FiltersTypeInfo.init(.{
    .vector = true,
});

/// Assertion parameters for *vector* prototype.
///
/// - [`std.builtin.Type.Vector`](#std.builtin.Type.Vector)
pub const Params = struct {
    /// Asserts vector child type info.
    ///
    /// See also:
    /// - [`std.builtin.Type.Vector`](#std.builtin.Type.Vector)
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    child: OnType.Params = null,
    /// Asserts vector length interval.
    ///
    /// See also:
    /// - [`std.builtin.Type.Vector`](#std.builtin.Type.Vector)
    /// - [`ziggurat.prototype.aux.interval`](#root.prototype.aux.interval)
    len: WithinInterval.Params = .{},
};

pub fn init(params: Params) Prototype {
    const child = OnType.init(params.child);
    const len = WithinInterval.init(params.len);

    return .{
        .name = @typeName(Self),
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = has_type_info.eval(actual) catch |err|
                    return switch (err) {
                        FiltersTypeInfo.Error.AssertsTypeValue,
                        => VectorError.AssertsTypeValue,
                        FiltersTypeInfo.Error.AssertsWhitelistTypeInfo,
                        => VectorError.AssertsWhitelistTypeInfo,
                        else => @panic("unhandled error"),
                    };

                if (params.child) |prototype| {
                    _ = try prototype.eval(@typeInfo(actual).vector.child);
                }

                _ = len.eval(@typeInfo(actual).vector.len) catch |err|
                    return switch (err) {
                        WithinInterval.Error.AssertsMin,
                        => VectorError.AssertsMinLen,
                        WithinInterval.Error.AssertsMax,
                        => VectorError.AssertsMaxLen,
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
                    VectorError.AssertsTypeValue,
                    VectorError.AssertsWhitelistTypeInfo,
                    => has_type_info.onError.?(err, prototype, actual),

                    VectorError.AssertsMinLen,
                    VectorError.AssertsMaxLen,
                    => len.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).vector.len,
                    ),

                    else => child.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).vector.child,
                    ),
                }
            }
        }.onError,
    };
}

test VectorError {
    _ = VectorError.AssertsTypeValue catch void;
    _ = VectorError.AssertsWhitelistTypeInfo catch void;

    _ = VectorError.AssertsMinLen catch void;
    _ = VectorError.AssertsMaxLen catch void;
}

test Params {
    const params: Params = .{
        .child = .true,
        .len = .{
            .min = null,
            .max = null,
        },
    };
    _ = params;
}

test init {
    const vector = init(.{
        .child = .true,
        .len = .{
            .min = null,
            .max = null,
        },
    });

    _ = vector;
}

test "passes vector assertions" {
    const vector = init(.{
        .child = .true,
        .len = .{
            .min = null,
            .max = null,
        },
    });

    try std.testing.expectEqual(true, vector.eval(@Vector(3, f128)));
}

test "fails vector length interval assertions" {
    const vector = init(.{
        .child = null,
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
