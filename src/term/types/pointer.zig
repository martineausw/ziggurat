//! Term to filter for for pointer type values with parameterized size,
//! const and volatile qualifiers, and whether a sentinel value exists.
const std = @import("std");
const testing = std.testing;

const Term = @import("../Term.zig");
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

    pub fn onError(err: anyerror, term: Term, actual: anytype) void {
        switch (err) {
            Error.DisallowedInfo,
            Error.IgnoresValidSizes,
            => @compileError(std.fmt.comptimePrint(
                "{s}.{s}: {s}",
                .{
                    term.name,
                    @errorName(err),
                    @tagName(actual),
                },
            )),
        }
    }
};

/// Parameters for term evaluation.
///
/// Associated with `std.builtin.Type.Pointer`
pub const Params = struct {
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
pub fn Has(params: Params) Term {
    const Info = info.Has(.{
        .pointer = true,
    });

    return .{
        .name = "PointerType",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = try Info.eval(actual);

                const actual_info = switch (@typeInfo(actual)) {
                    .pointer => |pointer_info| pointer_info,
                    else => unreachable,
                };

                _ = try params.size.eval(actual_info.size);

                if (params.is_const) |is_const| {
                    if (actual_info.is_const != is_const)
                        return Error.InvalidConstQualifier;
                }
                if (params.is_volatile) |is_const| {
                    if (actual_info.is_const != is_const)
                        return Error.InvalidVolatileQualifier;
                }
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
            fn onError(err: anyerror, term: Term, actual: anytype) void {
                switch (err) {
                    .InvalidType,
                    .ActiveExclusion,
                    .InactiveInclusions,
                    => Info.onError(err, term, actual),

                    .DisallowedSize,
                    .UnexpectedSize,
                    => params.size.onError(err, term, actual),

                    .InvalidConstQualifier,
                    => std.fmt.comptimePrint(
                        "{s}.{s} expects {s}",
                        .{
                            term.name,
                            @errorName(err),
                            if (params.is_const.?)
                                "const"
                            else
                                "const omitted",
                        },
                    ),
                    .InvalidVolatileQualifier,
                    => std.fmt.comptimePrint(
                        "{s}.{s} expects {s}",
                        .{
                            term.name,
                            @errorName(err),
                            if (params.is_const.?)
                                "volatile"
                            else
                                "volatile omitted",
                        },
                    ),
                    .InvalidSentinel,
                    => std.fmt.comptimePrint("{s}.{s} expects {s}", .{
                        term.name,
                        @errorName(err),
                        if (params.is_const.?)
                            "sentinel value"
                        else
                            "sentinel value omitted",
                    }),
                }
            }
        }.onError,
    };
}

test Has {
    const ConstPointer = Has(.{
        .is_const = true,
    });

    try testing.expectEqual(true, ConstPointer.eval(*const struct {}));
    try testing.expectEqual(true, ConstPointer.eval([]const u8));
    try testing.expectEqual(
        true,
        ConstPointer.eval([*]const @Vector(3, usize)),
    );
    try testing.expectEqual(
        error.InvalidConstQualifier,
        ConstPointer.eval([]i16),
    );
    try testing.expectEqual(
        error.InvalidConstQualifier,
        ConstPointer.eval(*bool),
    );
}

test {
    std.testing.refAllDecls(@This());
}
