//! Prototype *pointer*.
//!
//! Asserts *actual* is a pointer type value with parametric child, size,
//! const, volatile, and sentinel assertions.
//!
//! See also: [`std.builtin.Type.Pointer`](#std.builtin.Type.Pointer)
const std = @import("std");
const testing = std.testing;

const Prototype = @import("Prototype.zig");
const WithinInterval = @import("aux/WithinInterval.zig");
const FiltersTypeInfo = @import("aux/FiltersTypeInfo.zig");
const OnTypeInfo = @import("aux/OnTypeInfo.zig");
const FiltersActiveTag = @import("aux/FiltersActiveTag.zig");
const EqualsBool = @import("aux/EqualsBool.zig");
const OnOptional = @import("aux/OnOptional.zig");

/// Error set for `prototype.pointer`.
const PointerError = error{
    /// *actual* is not a type value.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.type`](#root.prototype.type)
    AssertsTypeValue,
    /// *actual* type value requires pointer type info.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsWhitelistTypeInfo,
    /// *actual* pointer child type info has active tag that belongs to blacklist.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsBlacklistChildTypeInfo,
    /// *actual* pointer child type info has active tag that does not belong to whitelist.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsWhitelistChildTypeInfo,
    /// *actual* pointer size has active tag that belongs to blacklist.
    ///
    /// See also: [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsBlacklistSize,
    /// *actual* pointer size has active tag that does not belong to whitelist.
    ///
    /// See also: [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsWhitelistSize,
    /// *actual* pointer is not const.
    ///
    /// See also: [`ziggurat.prototype.aux.toggle`](#root.prototype.aux.toggle)
    AssertsTrueIsConst,
    /// *actual* pointer is const.
    ///
    /// See also: [`ziggurat.prototype.aux.toggle`](#root.prototype.aux.toggle)
    AssertsFalseIsConst,
    /// *actual* pointer is not volatile.
    ///
    /// See also: [`ziggurat.prototype.aux.toggle`](#root.prototype.aux.toggle)
    AssertsTrueIsVolatile,
    /// *actual* pointer is volatile.
    ///
    /// See also: [`ziggurat.prototype.aux.toggle`](#root.prototype.aux.toggle)
    AssertsFalseIsVolatile,
    /// *actual* pointer sentinel is null.
    ///
    /// See also: [`ziggurat.prototype.aux.exists`](#root.prototype.aux.exists)
    AssertsNotNullSentinel,
};

pub const Error = PointerError;

/// Type value assertion for *optional* prototype evaluation argument.
///
/// See also: [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
pub const has_type_info = FiltersTypeInfo.init(.{
    .pointer = true,
});

/// *Size* prototype.
///
/// See also:
/// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
const FiltersSize = FiltersActiveTag.Of(std.builtin.Type.Pointer.Size);

/// Assertion parameters for *pointer* prototype.
///
/// See also: [`std.builtin.Type.Pointer`](#std.builtin.Type.Pointer).
pub const Params = struct {
    /// Asserts pointer child type info.
    ///
    /// See also:
    /// - [`std.builtin.Type.Pointer`](#std.builtin.Type.Pointer)
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    child: OnTypeInfo.Params = .{},
    /// Asserts pointer size.
    ///
    /// See also:
    /// - [`std.builtin.Type.Pointer`](#std.builtin.Type.Pointer)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    size: FiltersSize.Params = .{},
    /// Asserts pointer const qualifier presence.
    ///
    /// See also:
    /// - [`std.builtin.Type.Pointer`](#std.builtin.Type.Pointer)
    /// - [`ziggurat.prototype.aux.toggle`](#root.prototype.aux.toggle)
    is_const: EqualsBool.Params = null,
    /// Asserts pointer volatile qualifier presence.
    ///
    /// See also:
    /// - [`std.builtin.Type.Pointer`](#std.builtin.Type.Pointer)
    /// - [`ziggurat.prototype.aux.toggle`](#root.prototype.aux.toggle)
    is_volatile: EqualsBool.Params = null,
    /// Asserts pointer sentinel existence.
    ///
    /// See also:
    /// - [`std.builtin.Type.Pointer`](#std.builtin.Type.Pointer)
    /// - [`ziggurat.prototype.aux.exists`](#root.prototype.aux.exists)
    sentinel: OnOptional.Params = null,
};

pub fn init(params: Params) Prototype {
    const child = OnTypeInfo.init(params.child);
    const size = FiltersSize.init(params.size);
    const is_const = EqualsBool.init(params.is_const);
    const is_volatile = EqualsBool.init(params.is_volatile);
    const sentinel = OnOptional.init(params.sentinel);
    return .{
        .name = "Pointer",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = has_type_info.eval(actual) catch |err|
                    return switch (err) {
                        FiltersTypeInfo.Error.AssertsTypeValue,
                        => PointerError.AssertsTypeValue,
                        FiltersTypeInfo.Error.AssertsWhitelistTypeInfo,
                        => PointerError.AssertsWhitelistTypeInfo,
                        else => @panic("unhandled error"),
                    };

                _ = try child.eval(@typeInfo(actual).pointer.child);

                _ = comptime size.eval(
                    @typeInfo(actual).pointer.size,
                ) catch |err|
                    return switch (err) {
                        FiltersSize.Error.AssertsBlacklist,
                        => PointerError.AssertsBlacklistSize,
                        FiltersSize.Error.AssertsWhitelist,
                        => PointerError.AssertsWhitelistSize,
                        else => @panic("unhandled error"),
                    };

                _ = is_const.eval(
                    @typeInfo(actual).pointer.is_const,
                ) catch |err|
                    return switch (err) {
                        EqualsBool.Error.AssertsTrue,
                        => PointerError.AssertsTrueIsConst,
                        EqualsBool.Error.AssertsFalse,
                        => PointerError.AssertsFalseIsConst,
                        else => @panic("unhandled error"),
                    };

                _ = is_volatile.eval(
                    @typeInfo(actual).pointer.is_volatile,
                ) catch |err|
                    return switch (err) {
                        EqualsBool.Error.AssertsTrue,
                        => PointerError.AssertsTrueIsVolatile,
                        EqualsBool.Error.AssertsFalse,
                        => PointerError.AssertsFalseIsVolatile,
                        else => @panic("unhandled error"),
                    };

                _ = sentinel.eval(
                    @typeInfo(actual).pointer.sentinel(),
                ) catch |err|
                    return switch (err) {
                        OnOptional.Error.AssertsNotNull => PointerError.AssertsNotNullSentinel,
                        else => err,
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
                    PointerError.AssertsTypeValue,
                    PointerError.AssertsWhitelistTypeInfo,
                    => has_type_info.onError.?(err, prototype, actual),

                    else => child.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).pointer.child,
                    ),

                    PointerError.AssertsBlacklistSize,
                    PointerError.AssertsWhitelistSize,
                    => size.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).pointer.size,
                    ),

                    PointerError.AssertsTrueIsConst,
                    PointerError.AssertsFalseIsConst,
                    => is_const.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).pointer.is_const,
                    ),

                    PointerError.AssertsTrueIsVolatile,
                    PointerError.AssertsFalseIsVolatile,
                    => is_volatile.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).pointer.is_volatile,
                    ),

                    PointerError.AssertsNotNullSentinel,
                    => sentinel.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).pointer.sentinel(),
                    ),
                }
            }
        }.onError,
    };
}

test PointerError {
    _ = PointerError.AssertsTypeValue catch void;
    _ = PointerError.AssertsWhitelistTypeInfo catch void;

    _ = PointerError.AssertsBlacklistSize catch void;
    _ = PointerError.AssertsWhitelistSize catch void;

    _ = PointerError.AssertsTrueIsConst catch void;
    _ = PointerError.AssertsFalseIsConst catch void;

    _ = PointerError.AssertsTrueIsVolatile catch void;
    _ = PointerError.AssertsFalseIsVolatile catch void;

    _ = PointerError.AssertsNotNullSentinel catch void;
}

test Params {
    const params: Params = .{
        .child = .{},
        .size = .{
            .one = null,
            .many = null,
            .slice = null,
            .c = null,
        },
        .is_const = null,
        .is_volatile = null,
        .sentinel = null,
    };

    _ = params;
}

test init {
    const pointer = init(.{
        .child = .{},
        .size = .{},
        .is_const = null,
        .is_volatile = null,
        .sentinel = null,
    });

    _ = pointer;
}

test "passes pointer assertions" {
    const pointer = init(.{
        .child = .{},
        .size = .{
            .one = null,
            .many = null,
            .slice = null,
            .c = null,
        },
        .is_const = null,
        .is_volatile = null,
        .sentinel = null,
    });

    try std.testing.expectEqual(true, pointer.eval(*f128));
    try std.testing.expectEqual(true, pointer.eval(*const f128));
    try std.testing.expectEqual(true, pointer.eval(*const volatile f128));

    try std.testing.expectEqual(true, pointer.eval([]f128));
    try std.testing.expectEqual(true, pointer.eval([]const f128));
    try std.testing.expectEqual(true, pointer.eval([]const volatile f128));

    try std.testing.expectEqual(true, pointer.eval([*]f128));
    try std.testing.expectEqual(true, pointer.eval([*]const f128));
    try std.testing.expectEqual(true, pointer.eval([*]const volatile f128));
}

test "fails pointer size blacklist assertion" {
    const pointer = init(.{
        .child = .{},
        .size = .{
            .one = false,
            .many = null,
            .slice = null,
            .c = null,
        },
        .is_const = null,
        .is_volatile = null,
        .sentinel = null,
    });

    try std.testing.expectEqual(
        PointerError.AssertsBlacklistSize,
        comptime pointer.eval(*f128),
    );
}

test "fails pointer size whitelist assertion" {
    const pointer = init(.{
        .child = .{},
        .size = .{
            .one = null,
            .many = true,
            .slice = true,
            .c = true,
        },
        .is_const = null,
        .is_volatile = null,
        .sentinel = null,
    });
    try std.testing.expectEqual(
        PointerError.AssertsWhitelistSize,
        comptime pointer.eval(*f128),
    );
}

test "fails pointer is const assertion" {
    const pointer = init(.{
        .child = .{},
        .size = .{
            .one = null,
            .many = null,
            .slice = null,
            .c = null,
        },
        .is_const = true,
        .is_volatile = null,
        .sentinel = null,
    });
    try std.testing.expectEqual(
        PointerError.AssertsTrueIsConst,
        pointer.eval(*f128),
    );
}

test "fails pointer is not const assertion" {
    const pointer = init(.{
        .child = .{},
        .size = .{
            .one = null,
            .many = null,
            .slice = null,
            .c = null,
        },
        .is_const = false,
        .is_volatile = null,
        .sentinel = null,
    });
    try std.testing.expectEqual(
        PointerError.AssertsFalseIsConst,
        pointer.eval(*const f128),
    );
}

test "fails pointer is volatile assertion" {
    const pointer = init(.{
        .child = .{},
        .size = .{
            .one = null,
            .many = null,
            .slice = null,
            .c = null,
        },
        .is_const = null,
        .is_volatile = true,
        .sentinel = null,
    });

    try std.testing.expectEqual(
        PointerError.AssertsTrueIsVolatile,
        pointer.eval(*f128),
    );
}

test "fails pointer is not volatile assertion" {
    const pointer = init(.{
        .child = .{},
        .size = .{
            .one = null,
            .many = null,
            .slice = null,
            .c = null,
        },
        .is_const = null,
        .is_volatile = false,
        .sentinel = null,
    });

    try std.testing.expectEqual(
        PointerError.AssertsFalseIsVolatile,
        pointer.eval(*volatile f128),
    );
}

test "fails pointer sentinel is not null assertion" {
    const pointer = init(.{
        .child = .{},
        .size = .{
            .one = null,
            .many = null,
            .slice = null,
            .c = null,
        },
        .is_const = null,
        .is_volatile = null,
        .sentinel = .true,
    });
    try std.testing.expectEqual(
        PointerError.AssertsNotNullSentinel,
        pointer.eval([]f128),
    );
}
