//! Term to filter for for pointer type values with parameterized size,
//! const and volatile qualifiers, and whether a sentinel value exists.
const std = @import("std");
const testing = std.testing;

const Term = @import("../Term.zig");
const interval = @import("../aux/interval.zig");
const info = @import("../aux/info.zig");

const PointerError = error{
    /// Violated blacklisted size.
    DisallowedSize,
    /// Ignored whitelisted size set.
    UnexpectedSize,
    /// Violated const preference.
    InvalidConstQualifier,
    /// Violated volatile preference.
    InvalidVolatileQualifier,
    /// Violated sentinel preference.
    InvalidSentinel,
};

pub const Error = PointerError || interval.Error || info.Error;

/// - `null`, no preference
/// - `true`, belongs to whitelist, at least one element of whitelist
///   is expected, "pseudo-`union`"
/// - `false`, belongs to blacklist, element should not be used
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

pub const Params = struct {
    size: SizeParams = .{},
    /// - `null`, no preference
    /// - `true`, pointer must be `const` qualified
    /// - `false`, pointer must _not_ be `const` qualified
    is_const: ?bool = null,
    /// - `null`, no preference
    /// - `true`, pointer must be `volatile` qualified
    /// - `false`, pointer must _not_ be `volatile` qualified
    is_volatile: ?bool = null,
    /// - `null`, no preference
    /// - `true`, pointer must have a sentinel element
    /// - `false`, pointer must _not_ have a sentinel element
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
    const ValidInfo = info.Has(.{
        .pointer = true,
    });

    return .{
        .name = "PointerType",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = try ValidInfo.eval(actual);

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
                    => ValidInfo.onError(err, term, actual),

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
