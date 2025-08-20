//! Auxiliary prototype *toggle*.
//!
//! Asserts an *actual* boolean value to be either true or false.
const std = @import("std");

const Prototype = @import("../Prototype.zig");
const FiltersTypeInfo = @import("FiltersTypeInfo.zig");

/// Error set for *toggle* prototype.
const EqualsBoolError = error{
    /// *actual* requires bool type info.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsWhitelistTypeInfo,
    /// *actual* is false.
    AssertsTrue,
    /// *actual* is true.
    AssertsFalse,
};

pub const Error = EqualsBoolError;

/// Type value assertion for *toggle* prototype evaluation argument.
///
/// See also: [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
pub const has_type_info = FiltersTypeInfo.init(.{
    .bool = true,
});

/// Assertion parameter for *toggle* prototype.
pub const Params = ?bool;

pub fn init(params: Params) Prototype {
    return .{
        .name = @typeName(@This()),
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = has_type_info.eval(@TypeOf(actual)) catch |err|
                    return switch (err) {
                        FiltersTypeInfo.Error.AssertsWhitelistTypeInfo,
                        => EqualsBoolError.AssertsWhitelistTypeInfo,
                        else => @panic("unhandled error"),
                    };

                if (params) |param| {
                    if (param) {
                        if (!actual) {
                            return EqualsBoolError.AssertsTrue;
                        }
                    } else {
                        if (actual) {
                            return EqualsBoolError.AssertsFalse;
                        }
                    }
                }

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
                    EqualsBoolError.AssertsTypeValue,
                    EqualsBoolError.AssertsWhitelistTypeInfo,
                    => has_type_info.onError.?(err, prototype, actual),

                    else => @compileError(
                        std.fmt.comptimePrint("{s}.{s}: {s}", .{
                            prototype.name,
                            @errorName(err),
                            if (actual) "true" else "false",
                        }),
                    ),
                }
            }
        }.onError,
    };
}

test EqualsBoolError {
    _ = EqualsBoolError.AssertsWhitelistTypeInfo catch void;
    _ = EqualsBoolError.AssertsTrue catch void;
    _ = EqualsBoolError.AssertsFalse catch void;
}

test Params {
    const params: Params = null;

    _ = params;
}

test init {
    const toggle = init(null);

    _ = toggle;
}

test "passes toggle assertions" {
    const is_null = init(null);
    const is_true = init(true);
    const is_false = init(false);

    try std.testing.expectEqual(true, is_null.eval(true));
    try std.testing.expectEqual(true, is_null.eval(false));
    try std.testing.expectEqual(true, is_true.eval(true));
    try std.testing.expectEqual(true, is_false.eval(false));
}

test "fails toggle false assertion" {
    const is_false = init(false);

    try std.testing.expectEqual(
        EqualsBoolError.AssertsFalse,
        is_false.eval(true),
    );
}

test "fails toggle true assertion" {
    const is_true = init(true);

    try std.testing.expectEqual(
        EqualsBoolError.AssertsTrue,
        is_true.eval(false),
    );
}
