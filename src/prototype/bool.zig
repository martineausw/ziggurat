//! Prototype *bool*.
//! 
//! Asserts *actual* is an bool type value.
const std = @import("std");

const Prototype = @import("Prototype.zig");
const info = @import("aux/info.zig");

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
pub const info_validator = info.init(.{
    .bool = true,
});

pub const init: Prototype = .{
    .name = "Bool",
    .eval = struct {
        fn eval(actual: anytype) Error!bool {
            _ = comptime info_validator.eval(
                actual,
            ) catch |err|
                return switch (err) {
                    info.Error.AssertsTypeValue,
                    => BoolError.AssertsTypeValue,
                    info.Error.AssertsWhitelistTypeInfo,
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
                => info_validator.onError.?(err, prototype, actual),

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
