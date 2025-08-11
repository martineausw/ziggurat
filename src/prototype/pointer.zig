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

/// Error set for pointer
const PointerError = error{
    /// Violates `child` blacklist assertion.
    DisallowedChild,
    /// Violates `child` whitelist assertion.
    UnexpectedChild,
    /// Violates `size` blacklist assertion.
    DisallowedSize,
    /// Violates `size` whitelist assertion.
    UnexpectedSize,
    /// Violates `is_const` assertion.
    InvalidConstQualifier,
    /// Violates `is_volatile` assertion.
    InvalidVolatileQualifier,
    /// Violates `sentinel` assertion.
    InvalidSentinel,
};

/// Error set returned by `eval`
pub const Error = PointerError || info.Error;

test Error {
    _ = Error.InvalidType catch void;
    _ = Error.DisallowedType catch void;
    _ = Error.UnexpectedType catch void;

    _ = Error.DisallowedChild catch void;
    _ = Error.UnexpectedChild catch void;
    _ = Error.DisallowedSize catch void;
    _ = Error.UnexpectedSize catch void;
    _ = Error.InvalidConstQualifier catch void;
    _ = Error.InvalidVolatileQualifier catch void;
    _ = Error.InvalidSentinel catch void;
}

pub const info_validator = info.init(.{
    .pointer = true,
});

/// Associated with `std.builtin.Pointer.Array.Size`.
///
/// For any field:
/// - `null`, no assertion
/// - `true`, asserts active tag belongs to subset of `true` members.
/// - `false`, asserts active tag does not belong to subset of `false` members.
const SizeParams = struct {
    one: ?bool = null,
    many: ?bool = null,
    slice: ?bool = null,
    c: ?bool = null,

    pub fn eval(
        self: SizeParams,
        comptime size: std.builtin.Type.Pointer.Size,
    ) Error!bool {
        if (@field(self, @tagName(size))) |param| {
            if (!param) return Error.DisallowedSize;
            return true;
        }

        inline for (std.meta.fields(@TypeOf(self))) |field| {
            if (@field(self, field.name)) |value| {
                if (value) return Error.UnexpectedSize;
            }
        }
        return true;
    }

    pub fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
        switch (err) {
            .DisallowedSize,
            .UnexpectedSize,
            => @compileError(std.fmt.comptimePrint(
                "{s}.{s}: {s}",
                .{
                    prototype.name,
                    @errorName(err),
                    @tagName(actual),
                },
            )),
        }
    }
};

test SizeParams {
    _ = SizeParams{
        .one = null,
        .many = null,
        .slice = null,
        .c = null,
    };
}

/// Parameters for prototype evaluation.
///
/// Associated with `std.builtin.Type.Pointer`
pub const Params = struct {
    /// Evaluates against `.child`
    child: info.Params = .{},

    /// Evaluates against `.size`
    size: SizeParams = .{},

    /// Evaluates against `.is_const`
    ///
    /// - `null`, no assertion.
    /// - `true`, asserts `true`
    /// - `false`, asserts `false`
    is_const: ?bool = null,

    /// Evaluates against `.is_volatile`
    ///
    /// - `null`, no assertion.
    /// - `true`, asserts `true`
    /// - `false`, asserts `false`
    is_volatile: ?bool = null,

    /// Evaluates against `.sentinel()`
    ///
    /// - `null`, no assertion
    /// - `true`, asserts returns not `null`
    /// - `false`, asserts returns `null`
    sentinel: ?bool = null,
};

test Params {
    const params: Params = .{
        .child = .{},
        .is_const = null,
        .is_volatile = null,
        .sentinel = null,
        .size = .{},
    };

    _ = params;
}

/// Expects pointer type value.
///
/// Evaluates:
///
/// Passes pointer type into `TypeWithInfo`, returns associated errors.
///
/// `actual` active tag of `size` belongs to the set of `InfoParams` fields
/// set to true, otherwise returns `PointerTypeError.IgnoresNeeded`.
///
/// `actual` active tag of `Type` does not belong to the set of params
/// fields set to false, otherwise returns error.
///
/// `actual` type info `is_const` is equal to given params, otherwise
/// returns error.
///
/// `actual` type info `is_volatile` is equal to given params, otherwise
/// returns error.
///
/// `actual` type info `sentinel()` is not-null when given params is true
/// or null when given params is false, otherwise returns error.
pub fn init(params: Params) Prototype {
    const child_validator = info.init(params.child);
    const size_validator = params.size;

    return .{
        .name = "Pointer",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = try info_validator.eval(actual);

                const actual_info = switch (@typeInfo(actual)) {
                    .pointer => |pointer_info| pointer_info,
                    else => unreachable,
                };

                _ = child_validator.eval(actual_info.child) catch |err| {
                    return switch (err) {
                        info.Error.DisallowedType => Error.DisallowedChild,
                        info.Error.UnexpectedType => Error.UnexpectedChild,
                        else => unreachable,
                    };
                };

                _ = try size_validator.eval(actual_info.size);

                if (params.is_const) |is_const| {
                    if (actual_info.is_const != is_const)
                        return Error.InvalidConstQualifier;
                }

                if (params.is_volatile) |is_const| {
                    if (actual_info.is_const != is_const)
                        return Error.InvalidVolatileQualifier;
                }

                _ = child_validator.eval(actual_info.child) catch |err| {
                    return switch (err) {
                        info.Error.DisallowedType => Error.DisallowedChild,
                        info.Error.UnexpectedType => Error.UnexpectedChild,
                        else => unreachable,
                    };
                };

                if (params.sentinel) |sentinel| {
                    const actual_sentinel =
                        if (actual_info.sentinel()) |_| {
                            true;
                        } else {
                            false;
                        };

                    if (sentinel != actual_sentinel) |_|
                        return Error.InvalidSentinel;
                }

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                switch (err) {
                    Error.InvalidType,
                    Error.DisallowedType,
                    Error.UnexpectedType,
                    => info_validator.onError(err, prototype, actual),

                    Error.DisallowedChild,
                    Error.UnexpectedChild,
                    => child_validator.onError(err, prototype, actual),

                    Error.DisallowedSize,
                    Error.UnexpectedSize,
                    => size_validator.onError(err, prototype, actual),

                    Error.InvalidConstQualifier,
                    => std.fmt.comptimePrint(
                        "{s}.{s} expects {s}",
                        .{
                            prototype.name,
                            @errorName(err),
                            if (params.is_const.?)
                                "const"
                            else
                                "const omitted",
                        },
                    ),
                    Error.InvalidVolatileQualifier,
                    => std.fmt.comptimePrint(
                        "{s}.{s} expects {s}",
                        .{
                            prototype.name,
                            @errorName(err),
                            if (params.is_const.?)
                                "volatile"
                            else
                                "volatile omitted",
                        },
                    ),
                    Error.InvalidSentinel,
                    => std.fmt.comptimePrint("{s}.{s} expects {s}", .{
                        prototype.name,
                        @errorName(err),
                        if (params.is_const.?)
                            "sentinel value"
                        else
                            "sentinel value omitted",
                    }),
                    else => unreachable,
                }
            }
        }.onError,
    };
}

test init {
    const pointer = init(.{
        .child = .{},
        .size = .{},
        .is_const = null,
        .is_volatile = null,
        .sentinel = null,
    });

    try testing.expectEqual(
        true,
        pointer.eval(*const struct {}),
    );

    try testing.expectEqual(
        true,
        pointer.eval([]const u8),
    );

    try testing.expectEqual(
        true,
        pointer.eval([*]const @Vector(3, usize)),
    );
}
