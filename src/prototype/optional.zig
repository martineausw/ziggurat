//! Prototype *optional*.
//!
//! Asserts *actual* is an optional type value with a parametric
//! child assertion.
//!
//! See also: [`std.builtin.Type.Optional`](#std.builtin.Type.Optional)
const std = @import("std");
const testing = std.testing;

const Prototype = @import("Prototype.zig");
const FiltersTypeInfo = @import("aux/FiltersTypeInfo.zig");
const OnTypeInfo = @import("aux/OnTypeInfo.zig");

/// Error set for *optional* prototype.
const OptionalError = error{
    /// *actual* is not a type value.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.type`](#root.prototype.type)
    AssertsTypeValue,
    /// *actual* type value requires optional type info.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsWhitelistTypeInfo,
    /// *actual* optional child type info has active tag that belongs to blacklist.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info_switch)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsBlacklistChildTypeInfo,
    /// *actual* optional child type info has active tag that does not belong to whitelist.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info_switch)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsWhitelistChildTypeInfo,
};

pub const Error = OptionalError;

/// Type value assertion for *optional* prototype evaluation argument.
///
/// See also: [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
pub const has_type_info = FiltersTypeInfo.init(.{
    .optional = true,
});

/// Assertion parameters for *optional* prototype.
///
/// See also: [`std.builtin.Type.Optional`](#std.builtin.Type.Optional)
pub const Params = struct {
    /// Asserts optional child type info.
    ///
    /// See also:
    /// - [`std.builtin.Type.Optional`](#std.builtin.Type.Optional)
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info_switch)
    child: OnTypeInfo.Params = .{},
};

pub fn init(params: Params) Prototype {
    const child = OnTypeInfo.init(params.child);

    return .{
        .name = "Optional",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = has_type_info.eval(actual) catch |err|
                    return switch (err) {
                        FiltersTypeInfo.Error.AssertsTypeValue,
                        => OptionalError.AssertsTypeValue,
                        FiltersTypeInfo.Error.AssertsWhitelistTypeInfo,
                        => OptionalError.AssertsWhitelistTypeInfo,
                        else => unreachable,
                    };

                _ = try child.eval(@typeInfo(actual).optional.child);

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                switch (err) {
                    OptionalError.AssertsTypeValue,
                    OptionalError.AssertsWhitelistTypeInfo,
                    => has_type_info.onError.?(
                        err,
                        prototype,
                        actual,
                    ),

                    else => child.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).optional.child,
                    ),
                }
            }
        }.onError,
    };
}

test OptionalError {
    _ = OptionalError.AssertsTypeValue catch void;
    _ = OptionalError.AssertsWhitelistTypeInfo catch void;
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
            .bool = .true,
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
