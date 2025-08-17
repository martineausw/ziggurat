//! Prototype *optional*.
//! 
//! Asserts *actual* is an optional type value with a possible 
//! child assertion.
//! 
//! See also: `std.builtin.Type.Optional`
const std = @import("std");
const testing = std.testing;

const Prototype = @import("Prototype.zig");
const info = @import("aux/info.zig");

/// Error set for optional.
const OptionalError = error{
    /// *actual* is a type value.
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
};

pub const Error = OptionalError;

/// Type value assertion for *optional* prototype evaluation argument.
///
/// See also: [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
pub const info_validator = info.init(.{
    .optional = true,
});

/// Assertion parameters for *optional* prototype.
///
/// See also: `std.builtin.Type.Optional`
pub const Params = struct {
    /// Asserts optional child type info.
    ///
    /// See also:
    /// `std.builtin.Type.Optional`
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// `ziggurat.prototype.aux.info.Params`
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    child: info.Params = .{},
};

pub fn init(params: Params) Prototype {
    const child_validator = info.init(params.child);

    return .{
        .name = "Optional",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = info_validator.eval(actual) catch |err|
                    return switch (err) {
                        info.Error.AssertsTypeValue,
                        => OptionalError.AssertsTypeValue,
                        info.Error.AssertsWhitelistTypeInfo,
                        => OptionalError.AssertsWhitelistTypeInfo,
                        else => unreachable,
                    };

                _ = child_validator.eval(@typeInfo(actual).optional.child) catch |err|
                    return switch (err) {
                        info.Error.AssertsBlacklistTypeInfo,
                        => OptionalError.AssertsBlacklistChildTypeInfo,
                        info.Error.AssertsWhitelistTypeInfo,
                        => OptionalError.AssertsWhitelistChildTypeInfo,
                        else => unreachable,
                    };

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                switch (err) {
                    OptionalError.AssertsTypeValue,
                    OptionalError.AssertsWhitelistTypeInfo,
                    => info_validator.onError.?(
                        err,
                        prototype,
                        actual,
                    ),

                    OptionalError.AssertsBlacklistChildTypeInfo,
                    OptionalError.AssertsWhitelistChildTypeInfo,
                    => child_validator.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).optional.child,
                    ),

                    else => unreachable,
                }
            }
        }.onError,
    };
}

test OptionalError {
    _ = OptionalError.AssertsTypeValue catch void;
    _ = OptionalError.AssertsWhitelistTypeInfo catch void;
    _ = OptionalError.AssertsBlacklistChildTypeInfo catch void;
    _ = OptionalError.AssertsWhitelistChildTypeInfo catch void;
}

test Params {
    const params: Params = .{
        .child = .{},
    };

    _ = params;
}

test init {
    const optional = init(.{
        .child = .{
            .bool = true,
        },
    });

    _ = optional;
}

test "passes optional assertions" {
    const optional = init(.{
        .child = .{},
    });

    try std.testing.expectEqual(true, optional.eval(?bool));
}

test "fails optional child type info blacklist assertions" {
    const optional = init(.{
        .child = .{
            .bool = false,
        },
    });

    try std.testing.expectEqual(OptionalError.AssertsBlacklistChildTypeInfo, optional.eval(?bool));
}

test "fails optional child type info whitelist assertions" {
    const optional = init(.{
        .child = .{
            .int = true,
        },
    });

    try std.testing.expectEqual(OptionalError.AssertsWhitelistChildTypeInfo, optional.eval(?bool));
}
