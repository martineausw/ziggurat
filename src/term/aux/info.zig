//! Auxillary term for filtering type values based on active info tag.
const std = @import("std");
const testing = std.testing;

const Term = @import("../Term.zig");

const @"type" = @import("type.zig");

/// Error set for info.
const InfoError = error{
    /// Violates type info blacklist.
    DisallowedType,
    /// Ignored type info whitelist.
    UnexpectedType,
};

/// Error set returned by `eval`.
pub const Error = InfoError;

/// Parameters used for term evaluation.
///
/// Associated with `std.builtin.Type`.
///
/// For any field:
/// - `null`, no assertion.
/// - `true`, asserts active tag belongs to subset of `true` members.
/// - `false`, asserts active tag does not belong to subset of `false` members.
pub const Params = struct {
    type: ?bool = null,
    void: ?bool = null,
    bool: ?bool = null,
    noreturn: ?bool = null,
    int: ?bool = null,
    float: ?bool = null,
    pointer: ?bool = null,
    array: ?bool = null,
    @"struct": ?bool = null,
    comptime_float: ?bool = null,
    comptime_int: ?bool = null,
    undefined: ?bool = null,
    null: ?bool = null,
    optional: ?bool = null,
    error_union: ?bool = null,
    error_set: ?bool = null,
    @"enum": ?bool = null,
    @"union": ?bool = null,
    @"fn": ?bool = null,
    @"opaque": ?bool = null,
    frame: ?bool = null,
    @"anyframe": ?bool = null,
    vector: ?bool = null,
    enum_literal: ?bool = null,

    pub fn eval(self: Params, T: type) Error!bool {
        if (@field(self, @tagName(@typeInfo(T)))) |param| {
            if (!param) return Error.DisallowedType;
            return true;
        }

        inline for (std.meta.fields(@TypeOf(self))) |field| {
            if (@field(self, field.name)) |value| {
                if (value) return Error.UnexpectedType;
            }
        }
        return true;
    }

    pub fn onError(err: anyerror, term: Term, actual: anytype) void {
        switch (err) {
            Error.DisallowedType,
            Error.UnexpectedType,
            => @compileError(std.fmt.comptimePrint(
                "{s}.{s}: {s}",
                .{
                    term.name,
                    @errorName(err),
                    @tagName(@typeInfo(actual)),
                },
            )),
        }
    }
};

/// Expects type value.
///
/// `actual` is a type value, otherwise returns error from `IsType`.
///
/// `actual` active tag of `Type` belongs to the set of param fields set to
/// true, otherwise returns error.
///
/// `actual` active tag of `Type` does not belong to the set param fields
/// set to false, otherwise returns error.
pub fn init(params: Params) Term {
    const validator_type = @"type".init;
    const validator_info = params;
    return .{
        .name = "Info",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = validator_type.eval(actual) catch |err| return err;
                _ = validator_info.eval(actual) catch |err| return err;
                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, term: Term, actual: anytype) void {
                switch (err) {
                    Error.InvalidType,
                    => validator_type.onError(err, term, actual),

                    Error.DisallowedType,
                    Error.UnexpectedType,
                    => validator_info.onError(err, term, actual),
                }
            }
        }.onError,
    };
}

test init {
    const number = init(.{
        .int = true,
        .float = true,
        .comptime_int = true,
        .comptime_float = true,
    });

    try testing.expectEqual(
        true,
        number.eval(usize),
    );

    try testing.expectEqual(
        true,
        number.eval(i64),
    );

    try testing.expectEqual(
        true,
        number.eval(f128),
    );

    try testing.expectEqual(
        Error.UnexpectedType,
        number.eval(*comptime_int),
    );

    try testing.expectEqual(
        Error.UnexpectedType,
        number.eval([3]comptime_float),
    );

    const not_number = init(.{
        .int = false,
        .float = false,
        .comptime_int = false,
        .comptime_float = false,
    });

    try testing.expectEqual(
        Error.DisallowedType,
        not_number.eval(usize),
    );
    try testing.expectEqual(
        Error.DisallowedType,
        not_number.eval(i64),
    );
    try testing.expectEqual(
        Error.DisallowedType,
        not_number.eval(f128),
    );

    try testing.expectEqual(true, not_number.eval(*comptime_int));
    try testing.expectEqual(true, not_number.eval([3]comptime_float));

    const parameterized = init(.{
        .optional = true,
        .pointer = true,
        .array = true,
        .vector = true,
    });

    try testing.expectEqual(
        Error.UnexpectedType,
        parameterized.eval(usize),
    );
    try testing.expectEqual(
        Error.UnexpectedType,
        parameterized.eval(i64),
    );
    try testing.expectEqual(
        Error.UnexpectedType,
        parameterized.eval(f128),
    );
    try testing.expectEqual(
        true,
        parameterized.eval(*comptime_int),
    );
    try testing.expectEqual(
        true,
        parameterized.eval([3]comptime_float),
    );
}
