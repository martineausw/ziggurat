//! Prototype *vector*.
//! 
//! Asserts *actual* is an vector type value with parametric child and
//! length assertions.
//! 
//! See also: [`std.builtin.Type.Vector`](#std.builtin.Type.Vector)
const std = @import("std");
const testing = std.testing;

const Prototype = @import("Prototype.zig");
const interval = @import("aux/interval.zig");
const info = @import("aux/info.zig");

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
    /// *actual* vector child type info has active tag that belongs to blacklist.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsBlacklistChildTypeInfo,
    /// *actual* vector child type info has active tag that does not belong to whitelist.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsWhitelistChildTypeInfo,
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
pub const info_validator = info.init(.{
    .vector = true,
});

/// Assertion parameters for *vector* prototype.
///
/// - [`std.builtin.Type.Vector`](#std.builtin.Type.Vector)
pub const Params = struct {
    /// Asserts vector child type info.
    ///
    /// See also:
    /// - [`std.builtin.Type.Struct`](#std.builtin.Type.Struct)
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    child: info.Params = .{},
    /// Asserts vector length interval.
    ///
    /// See also:
    /// - [`std.builtin.Type.Struct`](#std.builtin.Type.Struct)
    /// - [`ziggurat.prototype.aux.interval`](#root.prototype.aux.interval)
    len: interval.Params = .{},
};

pub fn init(params: Params) Prototype {
    const child_validator = info.init(params.child);
    const len_validator = interval.init(params.len);

    return .{
        .name = "Vector",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = info_validator.eval(actual) catch |err|
                    return switch (err) {
                        info.Error.AssertsTypeValue,
                        => VectorError.AssertsTypeValue,
                        info.Error.AssertsWhitelistTypeInfo,
                        => VectorError.AssertsWhitelistTypeInfo,
                        else => @panic("unhandled error"),
                    };

                _ = child_validator.eval(@typeInfo(actual).vector.child) catch |err| {
                    return switch (err) {
                        info.Error.AssertsBlacklistTypeInfo,
                        => VectorError.AssertsBlacklistChildTypeInfo,
                        info.Error.AssertsWhitelistTypeInfo,
                        => VectorError.AssertsWhitelistChildTypeInfo,
                        else => @panic("unhandled error"),
                    };
                };

                _ = len_validator.eval(@typeInfo(actual).vector.len) catch |err|
                    return switch (err) {
                        interval.Error.AssertsMin,
                        => VectorError.AssertsMinLen,
                        interval.Error.AssertsMax,
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
                    => info_validator.onError.?(err, prototype, actual),

                    VectorError.AssertsBlacklistChildType,
                    VectorError.AssertsWhitelistChildType,
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

                    else => @panic("unhandled error"),
                }
            }
        }.onError,
    };
}

test VectorError {
    _ = VectorError.AssertsTypeValue catch void;
    _ = VectorError.AssertsWhitelistTypeInfo catch void;

    _ = VectorError.AssertsBlacklistChildTypeInfo catch void;
    _ = VectorError.AssertsWhitelistChildTypeInfo catch void;

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

test "passes vector assertions" {
    const vector = init(.{
        .child = .{},
        .len = .{
            .min = null,
            .max = null,
        },
    });

    try std.testing.expectEqual(true, vector.eval(@Vector(3, f128)));
}

test "fails vector child type info blacklist assertions" {
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
        VectorError.AssertsBlacklistChildTypeInfo,
        comptime vector.eval(@Vector(3, f128)),
    );
}

test "fails vector child type info whitelist assertions" {
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
        VectorError.AssertsWhitelistChildTypeInfo,
        comptime vector.eval(@Vector(3, f128)),
    );
}

test "fails vector length interval assertions" {
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
