//! Evaluates a *pointer* type value.
//! 
//! See also: [`std.builtin.Type.Pointer`](#std.builtin.Type.Pointer)
const std = @import("std");
const testing = std.testing;

const Prototype = @import("Prototype.zig");
const interval = @import("aux/interval.zig");
const info = @import("aux/info.zig");
const filter = @import("aux/filter.zig");
const toggle = @import("aux/toggle.zig");
const exists = @import("aux/exists.zig");

/// Error set for `prototype.pointer`.
const PointerError = error{
    /// *actual* is a type value.
    /// 
    /// See also: 
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.type`](#root.prototype.type)
    ExpectsTypeValue,
    /// *actual* type value requires array type info.
    /// 
    /// See also: 
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    RequiresTypeInfo,
    /// *actual* pointer child type info has active tag that belongs to blacklist.
    /// 
    /// See also: 
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    BanishesChildTypeInfo,
    /// *actual* pointer child type info has active tag that does not belong to whitelist.
    /// 
    /// See also: 
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    RequiresChildTypeInfo,
    /// *actual* pointer size has active tag that belongs to blacklist.
    /// 
    /// See also: [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    BanishesSize,
    /// *actual* pointer size has active tag that does not belong to whitelist.
    /// 
    /// See also: [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    RequiresSize,
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
    /// *actual* pointer sentinel is not null.
    /// 
    /// See also: [`ziggurat.prototype.aux.exists`](#root.prototype.aux.exists)
    AssertsNullSentinel,
};

pub const Error = PointerError;

/// Type value assertion for *optional* prototype evaluation argument.
/// 
/// See also: [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
pub const info_validator = info.init(.{
    .pointer = true,
});

/// Assertion parameters for *size* prototype.
const SizeParams = struct {
    one: ?bool = null,
    many: ?bool = null,
    slice: ?bool = null,
    c: ?bool = null,
};

/// *Size* prototype.
/// 
/// See also: 
/// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
const Size = filter.Filter(SizeParams);

/// Parameters for `prototype.pointer` evaluation.
///
/// See also: [`std.builtin.Type.Pointer`](#std.builtin.Type.Pointer).
pub const Params = struct {
    /// Asserts pointer child type info.
    /// 
    /// See also: 
    /// - [`std.builtin.Type.Pointer`](#std.builtin.Type.Pointer)
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)    
    child: info.Params = .{},
    /// Asserts pointer size.
    /// 
    /// See also: 
    /// - [`std.builtin.Type.Pointer`](#std.builtin.Type.Pointer)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)  
    size: SizeParams = .{},
    /// Asserts pointer const qualifier presence.
    /// 
    /// See also: 
    /// - [`std.builtin.Type.Array`](#std.builtin.Type.Array)
    /// - [`ziggurat.prototype.aux.toggle`](#root.prototype.aux.toggle)   
    is_const: ?bool = null,
    /// Asserts pointer volatile qualifier presence.
    /// 
    /// See also: 
    /// - [`std.builtin.Type.Array`](#std.builtin.Type.Array)
    /// - [`ziggurat.prototype.aux.toggle`](#root.prototype.aux.toggle)   
    is_volatile: ?bool = null,
    /// Asserts sentinel existence.
    /// 
    /// See also: 
    /// - [`std.builtin.Type.Array`](#std.builtin.Type.Array)
    /// - [`ziggurat.prototype.aux.exists`](#root.prototype.aux.exists)   
    sentinel: ?bool = null,
};


pub fn init(params: Params) Prototype {
    const child_validator = info.init(params.child);
    const size_validator = Size.init(params.size);
    const is_const_validator = toggle.init(params.is_const);
    const is_volatile_validator = toggle.init(params.is_volatile);
    const sentinel_validator = exists.init(params.sentinel);
    return .{
        .name = "Pointer",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = info_validator.eval(actual) catch |err|
                    return switch (err) {
                        info.Error.ExpectsTypeValue,
                        => PointerError.ExpectsTypeValue,
                        info.Error.RequiresTypeInfo,
                        => PointerError.RequiresTypeInfo,
                        else => unreachable,
                    };

                _ = child_validator.eval(@typeInfo(actual).pointer.child) catch |err|
                    return switch (err) {
                        info.Error.BanishesTypeInfo,
                        => PointerError.BanishesChildTypeInfo,
                        info.Error.RequiresTypeInfo,
                        => PointerError.RequiresChildTypeInfo,
                        else => unreachable,
                    };

                _ = comptime size_validator.eval(
                    @typeInfo(actual).pointer.size,
                ) catch |err|
                    return switch (err) {
                        filter.Error.Banishes,
                        => PointerError.BanishesSize,
                        filter.Error.Requires,
                        => PointerError.RequiresSize,
                        else => unreachable,
                    };

                _ = is_const_validator.eval(
                    @typeInfo(actual).pointer.is_const,
                ) catch |err|
                    return switch (err) {
                        toggle.Error.AssertsTrue,
                        => PointerError.AssertsTrueIsConst,
                        toggle.Error.AssertsFalse,
                        => PointerError.AssertsFalseIsConst,
                        else => unreachable,
                    };

                _ = is_volatile_validator.eval(
                    @typeInfo(actual).pointer.is_volatile,
                ) catch |err|
                    return switch (err) {
                        toggle.Error.AssertsTrue,
                        => PointerError.AssertsTrueIsVolatile,
                        toggle.Error.AssertsFalse,
                        => PointerError.AssertsFalseIsVolatile,
                        else => unreachable,
                    };

                _ = sentinel_validator.eval(
                    @typeInfo(actual).pointer.sentinel(),
                ) catch |err|
                    return switch (err) {
                        exists.Error.AssertsNotNull,
                        => PointerError.AssertsNotNullSentinel,
                        exists.Error.AssertsNull,
                        => PointerError.AssertsNullSentinel,
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
                    PointerError.ExpectsTypeValue,
                    PointerError.RequiresTypeInfo,
                    => info_validator.onError.?(err, prototype, actual),

                    PointerError.BanishesChildTypeInfo,
                    PointerError.RequiresChildTypeInfo,
                    => child_validator.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).pointer.child,
                    ),

                    PointerError.BanishesSize,
                    PointerError.RequiresSize,
                    => size_validator.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).pointer.size,
                    ),

                    PointerError.AssertsTrueIsConst,
                    PointerError.AssertsFalseIsConst,
                    => is_const_validator.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).pointer.is_const,
                    ),

                    PointerError.AssertsTrueIsVolatile,
                    PointerError.AssertsFalseIsVolatile,
                    => is_volatile_validator.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).pointer.is_volatile,
                    ),

                    PointerError.AssertsNotNullSentinel,
                    PointerError.AssertsNullSentinel,
                    => sentinel_validator.onError.?(
                        err,
                        prototype,
                        @typeInfo(actual).pointer.sentinel(),
                    ),
                    else => unreachable,
                }
            }
        }.onError,
    };
}

test PointerError {
    _ = PointerError.ExpectsTypeValue catch void;
    _ = PointerError.RequiresTypeInfo catch void;

    _ = PointerError.BanishesChildTypeInfo catch void;
    _ = PointerError.RequiresChildTypeInfo catch void;

    _ = PointerError.BanishesSize catch void;
    _ = PointerError.RequiresSize catch void;

    _ = PointerError.AssertsTrueIsConst catch void;
    _ = PointerError.AssertsFalseIsConst catch void;

    _ = PointerError.AssertsTrueIsVolatile catch void;
    _ = PointerError.AssertsFalseIsVolatile catch void;

    _ = PointerError.AssertsNotNullSentinel catch void;
    _ = PointerError.AssertsNullSentinel catch void;
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

test "fails pointer child type info blacklist assertion" {
    const pointer = init(.{
        .child = .{
            .float = false,
        },
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

    try std.testing.expectEqual(
        PointerError.BanishesChildTypeInfo,
        comptime pointer.eval(*f128),
    );
}

test "fails pointer child type info whitelist assertion" {
    const pointer = init(.{
        .child = .{
            .int = true,
        },
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
    try std.testing.expectEqual(
        PointerError.RequiresChildTypeInfo,
        comptime pointer.eval(*f128),
    );
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
        PointerError.BanishesSize,
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
        PointerError.RequiresSize,
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

test "fails pointer sentinel is null assertion" {
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
        .sentinel = true,
    });
    try std.testing.expectEqual(
        PointerError.AssertsNotNullSentinel,
        pointer.eval([]f128),
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
        .sentinel = false,
    });
    try std.testing.expectEqual(
        PointerError.AssertsNullSentinel,
        pointer.eval([:0]f128),
    );
}
