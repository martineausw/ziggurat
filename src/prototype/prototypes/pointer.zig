//! Prototype to filter for for pointer type values.
const std = @import("std");
const testing = std.testing;

const Prototype = @import("../../Prototype.zig");
const interval = @import("../aux/interval.zig");
const info = @import("../aux/info.zig");

/// Error set for pointer
const PointerError = error{
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
    /// Violates `child` blacklist assertion.
    DisallowedChild,
    /// Violates `child` whitelist assertion.
    UnexpectedChild,
};

/// Error set returned by `eval`
pub const Error = PointerError || interval.Error || info.Error;

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
    const validator_info = info.init(.{
        .pointer = true,
    });

    const validator_child = info.init(params.child);

    const validator_size = params.size;

    return .{
        .name = "Pointer",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = try validator_info.eval(actual);

                const actual_info = switch (@typeInfo(actual)) {
                    .pointer => |pointer_info| pointer_info,
                    else => unreachable,
                };

                _ = validator_child.eval(actual_info.child) catch |err| {
                    return switch (err) {
                        info.Error.DisallowedType => Error.DisallowedChild,
                        info.Error.UnexpectedType => Error.UnexpectedChild,
                        else => unreachable,
                    };
                };

                _ = try validator_size.eval(actual_info.size);

                if (params.is_const) |is_const| {
                    if (actual_info.is_const != is_const)
                        return Error.InvalidConstQualifier;
                }

                if (params.is_volatile) |is_const| {
                    if (actual_info.is_const != is_const)
                        return Error.InvalidVolatileQualifier;
                }

                _ = validator_child.eval(actual_info.child) catch |err| {
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
                    => validator_info.onError(err, prototype, actual),

                    Error.DisallowedChild,
                    Error.UnexpectedChild,
                    => validator_child.onError(err, prototype, actual),

                    Error.DisallowedSize,
                    Error.UnexpectedSize,
                    => validator_size.onError(err, prototype, actual),

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

test {
    std.testing.refAllDecls(@This());
}
