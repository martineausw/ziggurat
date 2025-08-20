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
const FiltersTypeInfo = @import("FiltersTypeInfo.zig");

/// Error set for *at* prototype.
const OnIndexError = error{
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

pub const Error = OnIndexError;

/// Type info assertions for *at* prototype evaluation argument.
/// 
/// See also: 
/// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
/// - [`std.builtin.Type.Array`](#std.builtin.Type.Array)
/// - [`std.builtin.Type.Pointer`](#std.builtin.Type.Pointer)
/// - [`std.builtin.Type.Vector`](#std.builtin.Type.Vector)
/// - [`std.builtin.Type.Optional`](#std.builtin.Type.Optional)
pub const has_type_info = FiltersTypeInfo.init(.{
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
    prototype: Prototype,
    index: usize = 0,
};

pub fn init(params: Params) Prototype {
    return .{
        .name = @typeName(@This()),
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = comptime has_type_info.eval(@TypeOf(actual)) catch |err|
                    return switch (err) {
                        FiltersTypeInfo.Error.AssertsWhitelistTypeInfo,
                        => OnIndexError.AssertsWhitelistTypeInfo,
                        else => @panic("unhandled error"),
                    };
                    

                _ = try params.prototype.eval(actual[params.index]);

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
                    OnIndexError.AssertsWhitelistTypeInfo,
                    => has_type_info.onError.?(err, prototype, actual),

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

test OnIndexError {
}

test Params {
    const params: Params = .{
        .prototype = @import("../int.zig").init(.{}),
        .index= 0, 
    };
    _ = params;
}

test init {
    const at = init(.{
        .prototype= @import("../int.zig").init(.{}),
        .index = 0,
    });

    _ = at;
}

test "passes at assertions" {
    const int_prototype = @import("../int.zig");
    const child_prototype = init(.{
            .prototype = int_prototype.init(.{.bits = .{.min = 32, .max = 32}}),
            .index = 0,
        });

    try std.testing.expectEqual(true, comptime child_prototype.eval(&.{ i32 }));
}
