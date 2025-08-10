//! Auxillary term for filtering type values based on active info tag.
const std = @import("std");
const testing = std.testing;

const Term = @import("../Term.zig");

const @"type" = @import("type.zig");

/// Error set for info.
const InfoError = error{
    /// Violated blacklisted type info tag.
    DisallowedInfo,
    /// Ignored whitelisted type info tag set.
    UnexpectedInfo,
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
pub const InfoParams = struct {
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

    pub fn eval(self: InfoParams, T: type) Error!bool {
        if (@field(self, @tagName(@typeInfo(T)))) |param| {
            if (!param) return Error.DisallowedInfo;
            return true;
        }

        inline for (std.meta.fields(@TypeOf(self))) |field| {
            if (@field(self, field.name)) |value| {
                if (value) return Error.UnexpectedInfo;
            }
        }
        return true;
    }

    pub fn onError(err: anyerror, term: Term, actual: anytype) void {
        switch (err) {
            Error.DisallowedInfo,
            Error.UnexpectedInfo,
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
pub fn Has(params: InfoParams) Term {
    return .{
        .name = "Info",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = @"type".Is.eval(actual) catch |err| return err;
                _ = params.eval(actual) catch |err| return err;
                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, term: Term, actual: anytype) void {
                switch (err) {
                    Error.InvalidType,
                    => @"type".Type.onError(err, term, actual),

                    Error.DisallowedInfo,
                    Error.UnexpectedInfo,
                    => params.onError(err, term, actual),
                }
            }
        }.onError,
    };
}

test Has {
    const NumberTypes = Has(.{
        .int = true,
        .float = true,
        .comptime_int = true,
        .comptime_float = true,
    });

    try testing.expectEqual(true, NumberTypes.eval(usize));
    try testing.expectEqual(true, NumberTypes.eval(i64));
    try testing.expectEqual(true, NumberTypes.eval(f128));
    try testing.expectEqual(
        error.UnexpectedInfo,
        NumberTypes.eval(*comptime_int),
    );
    try testing.expectEqual(
        error.UnexpectedInfo,
        NumberTypes.eval([3]comptime_float),
    );

    const NotNumberTypes = Has(.{
        .int = false,
        .float = false,
        .comptime_int = false,
        .comptime_float = false,
    });

    try testing.expectEqual(
        error.DisallowedInfo,
        NotNumberTypes.eval(usize),
    );
    try testing.expectEqual(
        error.DisallowedInfo,
        NotNumberTypes.eval(i64),
    );
    try testing.expectEqual(
        error.DisallowedInfo,
        NotNumberTypes.eval(f128),
    );

    try testing.expectEqual(true, NotNumberTypes.eval(*comptime_int));
    try testing.expectEqual(true, NotNumberTypes.eval([3]comptime_float));

    const OnlyParameterizedTypes = Has(.{
        .optional = true,
        .pointer = true,
        .array = true,
        .vector = true,
    });

    try testing.expectEqual(
        error.UnexpectedInfo,
        OnlyParameterizedTypes.eval(usize),
    );
    try testing.expectEqual(
        error.UnexpectedInfo,
        OnlyParameterizedTypes.eval(i64),
    );
    try testing.expectEqual(
        error.UnexpectedInfo,
        OnlyParameterizedTypes.eval(f128),
    );
    try testing.expectEqual(
        true,
        OnlyParameterizedTypes.eval(*comptime_int),
    );
    try testing.expectEqual(
        true,
        OnlyParameterizedTypes.eval([3]comptime_float),
    );
}
