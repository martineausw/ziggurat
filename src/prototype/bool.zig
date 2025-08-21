//! Prototype *bool*.
//!
//! Asserts *actual* is a bool type value.
const std = @import("std");

const Prototype = @import("Prototype.zig");
const FiltersTypeInfo = @import("aux/FiltersTypeInfo.zig");

const Self = @This();

const BoolError = error{
    /// *actual* is not a type value.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.type`](#root.prototype.type)
    AssertsTypeValue,
    /// *actual* type value requires bool type info.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsWhitelistTypeInfo,
};

pub const Error = BoolError;

/// Type value assertion for *bool* prototype evaluation argument.
///
/// See also: [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
pub const has_type_info = FiltersTypeInfo.init(.{
    .bool = true,
});

pub const init: Prototype = .{
    .name = @typeName(Self),
    .eval = struct {
        fn eval(actual: anytype) Error!bool {
            _ = comptime has_type_info.eval(
                actual,
            ) catch |err|
                return switch (err) {
                    FiltersTypeInfo.Error.AssertsTypeValue,
                    => BoolError.AssertsTypeValue,
                    FiltersTypeInfo.Error.AssertsWhitelistTypeInfo,
                    => BoolError.AssertsWhitelistTypeInfo,
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
                BoolError.AssertsTypeValue,
                BoolError.AssertsWhitelistTypeInfo,
                => has_type_info.onError.?(err, prototype, actual),

                else => @panic("unhandled error"),
            }
        }
    }.onError,
};

test BoolError {
    _ = BoolError.AssertsTypeValue catch void;
}

test init {
    const @"bool": Prototype = init;

    _ = @"bool";
}

test "passes bool assertions" {
    const @"bool" = init;

    try std.testing.expectEqual(true, @"bool".eval(bool));
}

test "fails type value assertion" {
    const @"bool" = init;

    try std.testing.expectEqual(BoolError.AssertsTypeValue, comptime @"bool".eval(true));
}
