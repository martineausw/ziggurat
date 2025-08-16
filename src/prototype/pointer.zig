//! Prototype for `type` value with pointer type info.
//!
//! `eval` asserts pointer type within parameters:
//!
//! - `child`, type info filter assertion.
//! - `is_const`, type info value assertion.
//! - `is_volatile`, type info value assertion.
//! - `sentinel`, type info value assertion.
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
    InvalidArgument,
    /// Violates `std.builtin.Type.pointer.child` blacklist assertion.
    BanishesChildType,
    RequiresChildType,
    /// Violates `std.builtin.Type.pointer.size` blacklist assertion.
    BanishesSize,
    RequiresSize,
    /// Violates `std.builtin.Type.pointer.is_const` assertion.
    AssertsTrueIsConst,
    AssertsFalseIsConst,
    /// Violates `std.builtin.Type.pointer.is_volatile` assertion.
    AssertsTrueIsVolatile,
    AssertsFalseIsVolatile,
    /// Violates `std.builtin.Type.pointer.sentinel()` assertion.
    AssertsNotNullSentinel,
    AssertsNullSentinel,
};

/// Error set returned by `eval`.
pub const Error = PointerError;

/// Validates `actual` type info to `std.builtin.Type.pointer`.
pub const info_validator = info.init(.{
    .pointer = true,
});

/// Parameters for `prototype.pointer.size` evaluation.
///
/// Derived from `std.builtin.Pointer.Size`.
const SizeParams = struct {
    one: ?bool = null,
    many: ?bool = null,
    slice: ?bool = null,
    c: ?bool = null,
};

const Size = filter.Filter(SizeParams);

/// Parameters for `prototype.pointer` evaluation.
///
/// Derived from `std.builtin.Type.Pointer`.
pub const Params = struct {
    /// Evaluates against `std.builtin.Type.pointer.child`.
    child: info.Params = .{},
    /// Evaluates against `std.builtin.Type.pointer.size`.
    size: SizeParams = .{},
    /// Evaluates against `std.builtin.Type.pointer.is_const`.
    is_const: ?bool = null,
    /// Evaluates against `std.builtin.Type.pointer.is_volatile`.
    is_volatile: ?bool = null,
    /// Evaluates against `std.builtin.Type.pointer.sentinel()`.
    sentinel: ?bool = null,
};

/// Expects pointer type value.
///
/// `actual` assertions:
///
/// type info is `std.builtin.Type.pointer`.
///
/// `std.builtin.Type.pointer.size` is within `aux.filter` assertions with
/// given `params.filter`.
///
/// `std.builtin.Type.pointer.child` is within `aux.info` assertions with
/// given `params.child`.
///
/// `std.builtin.Type.pointer.is_const` is within `aux.toggle` assertions
/// with given `params.is_const`.
///
/// `std.builtin.Type.pointer.is_volatile` is within `aux.toggle`
/// assertions with given `params.is_volatile`.
///
/// `std.builtin.Type.pointer.sentinel()` is within `aux.exists`
/// assertions with given `params.sentinel`.
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
                        info.Error.InvalidArgument,
                        info.Error.RequiresType,
                        => PointerError.InvalidArgument,
                        else => unreachable,
                    };

                _ = child_validator.eval(@typeInfo(actual).pointer.child) catch |err|
                    return switch (err) {
                        info.Error.BanishesType,
                        => PointerError.BanishesChildType,
                        info.Error.RequiresType,
                        => PointerError.RequiresChildType,
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
                    PointerError.InvalidArgument,
                    => info_validator.onError.?(err, prototype, actual),

                    PointerError.BanishesChildType,
                    PointerError.RequiresChildType,
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
    _ = PointerError.InvalidArgument catch void;

    _ = PointerError.BanishesChildType catch void;
    _ = PointerError.RequiresChildType catch void;

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

test "evaluates pointer successfully" {
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

test "coerces PointerError.BanishesChildType" {
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
        PointerError.BanishesChildType,
        comptime pointer.eval(*f128),
    );
}

test "coerces PointerError.RequiresChildType" {
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
        PointerError.RequiresChildType,
        comptime pointer.eval(*f128),
    );
}

test "coerces PointerError.BanishesSize" {
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

test "coerces PointerError.RequiresSize" {
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

test "coerces PointerError.AssertsTrueIsConst" {
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

test "coerces PointerError.AssertsFalseIsConst" {
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

test "coerces PointerError.AssertsTrueIsVolatile" {
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

test "coerces PointerError.AssertsFalseIsVolatile" {
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

test "coerces PointerError.AssertsNotNullSentinel" {
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

test "coerces PointerError.AssertsNullSentinel" {
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
