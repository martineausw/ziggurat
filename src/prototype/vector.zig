//! Evaluates a *vector* type value.
//! 
//! See also: [`std.builtin.Type.Vector`](#std.builtin.Type.Vector)
const std = @import("std");
const testing = std.testing;

const Prototype = @import("Prototype.zig");
const interval = @import("aux/interval.zig");
const info = @import("aux/info.zig");

/// Error set for *vector* prototype.
const VectorError = error{
    /// *actual* is a type value.
    /// 
    /// See also: 
    /// - [`test.prototype.int`](#test.prototype.int)
    ExpectsTypeValue,
    /// *actual* requires array type info.
    /// 
    /// See also: 
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    RequiresTypeInfo,
    /// *actual* array child type info has active tag that belongs to blacklist.
    /// 
    /// See also: 
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    BanishesChildTypeInfo,
    /// *actual* array child type info has active tag that does not belong to whitelist.
    /// 
    /// See also: 
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    RequiresChildTypeInfo,
    /// *actual* array length is less than minimum. 
    /// 
    /// See also: [`ziggurat.prototype.aux.interval`](#root.prototype.aux.interval)
    AssertsMinLen,
    /// *actual* array length is greater than maximum. 
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
                        info.Error.ExpectsTypeValue,
                        => VectorError.ExpectsTypeValue,
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
                    VectorError.ExpectsTypeValue,
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
    _ = VectorError.ExpectsTypeValue catch void;
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
        VectorError.BanishesChildTypeInfo,
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
        VectorError.RequiresChildTypeInfo,
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
