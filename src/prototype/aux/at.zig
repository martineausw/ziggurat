//! Auxiliary prototype *at*.
//! 
//! Asserts an *actual* array, pointer, optional, or vector child type 
//! value at a given index to pass evaluation of given prototype.
//! 
//! See also: 
//! - [`std.builtin.Type.Array`](#std.builtin.Type.Array)
//! - [`std.builtin.Type.Optional`](#std.builtin.Type.Optional)
//! - [`std.builtin.Type.Pointer`](#std.builtin.Type.Pointer)
//! - [`std.builtin.Type.Vector`](#std.builtin.Type.Vector)
const std = @import("std");

const Prototype = @import("../Prototype.zig");
const info = @import("../aux/info.zig");
const child = @import("../aux/child.zig");

/// Error set for *at* prototype.
const AtError= error{
    /// *actual* is not a type value.
    /// 
    /// See also: 
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.type`](#root.prototype.type)
    AssertsTypeValue,
    /// *actual* requires array, pointer, vector, or struct type info.
    /// 
    /// See also: 
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsWhitelistTypeInfo
};

pub const Error = AtError;

/// Type info assertions for *at* prototype evaluation argument.
/// 
/// See also: 
/// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
/// - [`std.builtin.Type.Array`](#std.builtin.Type.Array)
/// - [`std.builtin.Type.Pointer`](#std.builtin.Type.Pointer)
/// - [`std.builtin.Type.Vector`](#std.builtin.Type.Vector)
/// - [`std.builtin.Type.Optional`](#std.builtin.Type.Optional)
pub const info_validator = info.init(.{
    .array = true,
    .pointer = true,
    .vector = true,
    .@"struct" = true,
});

/// Assertion parameter for *child*.
/// 
/// Asserts child prototype evaluation.
/// 
/// See also: `ziggurat.Prototype`
pub const Params = struct {
    child: Prototype,
    index: usize = 0,
};

pub fn init(params: Params) Prototype {
    return .{
        .name = "Child",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = comptime info_validator.eval(@TypeOf(actual)) catch |err|
                    return switch (err) {
                        info.Error.AssertsWhitelistTypeInfo,
                        => AtError.AssertsWhitelistTypeInfo,
                        else => @panic("unhandled error"),
                    };
                    

                _ = try params.child.eval(actual[params.index]);

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
                    AtError.AssertsWhitelistTypeInfo,
                    => info_validator.onError.?(err, prototype, actual),

                    else => @compileError(
                        std.fmt.comptimePrint("{s}.{s}: {s}", .{
                            prototype.name,
                            @errorName(err),
                            @typeName(actual),
                        }),
                    ),
                }
            }
        }.onError,
    };
}

test AtError {
}

test Params {
    const params: Params = .{
        .child = @import("../int.zig").init(.{}),
        .at = 0, 
    }

}

test init {
    const at = init(.{
        .child = @import("../int.zig").init(.{}),
        .at = 0,
    });

    _ = at;
}

test "passes at assertions" {
    std.testing.log_level = .debug;
    const int_prototype = @import("../int.zig");
    std.log.debug("{s}", .{@typeName(@TypeOf(.{i32}))});
    const child_prototype = init(.{
            .child = int_prototype.init(.{.bits = .{.min = 32, .max = 32}}),
            .index = 0,
        });

    try std.testing.expectEqual(true, comptime child_prototype.eval(&.{ i32 }));
}
