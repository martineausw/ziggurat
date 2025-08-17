//! Auxillary prototype *child*.
//! 
//! Asserts an *actual* array, pointer, optional, or vector child type 
//! value to  pass evaluation of given prototype.
//! 
//! See also: 
//! - [`std.builtin.Type.Array`](#std.builtin.Type.Array)
//! - [`std.builtin.Type.Optional`](#std.builtin.Type.Optional)
//! - [`std.builtin.Type.Pointer`](#std.builtin.Type.Pointer)
//! - [`std.builtin.Type.Vector`](#std.builtin.Type.Vector)
const std = @import("std");

const Prototype = @import("../Prototype.zig");
const info = @import("../aux/info.zig");

/// Error set for *child* prototype.
const ChildError = error{
    /// *actual* is not a type value.
    /// 
    /// See also: 
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.type`](#root.prototype.type)
    AssertsTypeValue,
    /// *actual* requires array, pointer, vector, or optional type info.
    /// 
    /// See also: 
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsWhitelistTypeInfo
};

pub const Error = ChildError;

/// Type info assertions for *child* prototype evaluation argument.
/// 
/// See also: 
/// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
/// - [`std.builtin.Type.Array`](#std.builtin.Type.Array)
/// - [`std.builtin.Type.Pointer`](#std.builtin.Type.Pointer)
/// - [`std.builtin.Type.Vector`](#std.builtin.Type.Vector)
/// `std.builtin.Type.Optional`
pub const info_validator = info.init(.{
    .array = true,
    .pointer = true,
    .vector = true,
    .optional = true,
});

/// Assertion parameter for *child*.
/// 
/// Asserts child prototype evaluation.
/// 
/// See also: `ziggurat.Prototype`
pub const Params = Prototype;

pub fn init(params: Params) Prototype {
    return .{
        .name = "Child",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = comptime info_validator.eval(actual) catch |err|
                    return switch (err) {
                        info.Error.AssertsTypeValue,
                        => ChildError.AssertsTypeValue,
                        info.Error.AssertsWhitelistTypeInfo,
                        => ChildError.AssertsWhitelistTypeInfo,
                        else => @panic("unhandled error"),
                    };

                _ = comptime try params.eval(std.meta.Child(actual));

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
                    ChildError.AssertsTypeValue,
                    => info_validator.onError.?(err, prototype, actual),

                    else => @compileError(
                        std.fmt.comptimePrint("{s}.{s}: {s}", .{
                            prototype.name,
                            @errorName(err),
                            @typeName(std.meta.Child(actual)),
                        }),
                    ),
                }
            }
        }.onError,
    };
}

test ChildError {
    _ = ChildError.AssertsTypeValue catch void;
}

test Params {
    const int = @import("../int.zig");
    const params: Params = int.init(.{});

    _ = params;
}

test init {
    const int = @import("../int.zig");
    const child = init(int.init(.{}));

    _ = child;
}

test "passes child assertions" {
    const int = @import("../int.zig");
    const child = init(int.init(
        .{ .bits = .{ .min = 32, .max = 32 } },
    ));

    try std.testing.expectEqual(true, comptime child.eval(*i32));
}
