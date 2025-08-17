//! Prototype for `type` value with `type` type info.
//!
//! `eval` asserts `type` type value.
const std = @import("std");

const Prototype = @import("Prototype.zig");

/// Error set for type.
const TypeError = error{
    /// Violates `actual` is `type` value assertion.
    ExpectsTypeValue,
};

/// Errors returned by `eval`
pub const Error = TypeError;

/// Expects type value.
///
/// `actual` is type value, otherwise returns error.
pub const init: Prototype = .{
    .name = "Type",

    .eval = struct {
        fn eval(actual: anytype) Error!bool {
            if (@TypeOf(actual) != type) return TypeError.ExpectsTypeValue;
            return true;
        }
    }.eval,
    .onError = struct {
        fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
            switch (err) {
                else => @compileError(std.fmt.comptimePrint(
                    "{s}.{s} expects `type`, actual: {s}",
                    .{
                        prototype.name,
                        @errorName(err),
                        @typeName(@TypeOf(actual)),
                    },
                )),
            }
        }
    }.onError,
};

test TypeError {
    _ = TypeError.ExpectsTypeValue catch void;
}

test init {
    const @"type": Prototype = init;

    _ = @"type";
}

test "passes type value assertions" {
    const @"type": Prototype = init;

    try std.testing.expectEqual(true, @"type".eval(usize));
    try std.testing.expectEqual(true, @"type".eval(u8));
    try std.testing.expectEqual(true, @"type".eval(i128));
    try std.testing.expectEqual(true, @"type".eval(i8));
    try std.testing.expectEqual(true, @"type".eval(f128));
    try std.testing.expectEqual(true, @"type".eval(f16));
    try std.testing.expectEqual(true, @"type".eval(bool));
    try std.testing.expectEqual(true, @"type".eval(?bool));
    try std.testing.expectEqual(true, @"type".eval(comptime_float));
    try std.testing.expectEqual(true, @"type".eval(comptime_int));
    try std.testing.expectEqual(true, @"type".eval(struct {}));
    try std.testing.expectEqual(true, @"type".eval(union {}));
    try std.testing.expectEqual(true, @"type".eval(enum {}));
    try std.testing.expectEqual(true, @"type".eval(error{}));
    try std.testing.expectEqual(true, @"type".eval(fn () void));
    try std.testing.expectEqual(true, @"type".eval([]const u8));
    try std.testing.expectEqual(true, @"type".eval([*]enum {}));
    try std.testing.expectEqual(
        true,
        @"type".eval(*const volatile struct {}),
    );
    try std.testing.expectEqual(true, @"type".eval([3]i128));
    try std.testing.expectEqual(true, @"type".eval(@Vector(3, f128)));
}

test "fails type value assertions" {
    const @"type": Prototype = init;

    try std.testing.expectEqual(
        TypeError.ExpectsTypeValue,
        @"type".eval(@as(usize, 0)),
    );

    try std.testing.expectEqual(
        Error.ExpectsTypeValue,
        @"type".eval(@as(u8, 'a')),
    );

    try std.testing.expectEqual(
        Error.ExpectsTypeValue,
        @"type".eval(@as(i128, 0)),
    );

    try std.testing.expectEqual(
        Error.ExpectsTypeValue,
        @"type".eval(@as(i8, 0)),
    );

    try std.testing.expectEqual(
        Error.ExpectsTypeValue,
        @"type".eval(@as(f128, 0.0)),
    );

    try std.testing.expectEqual(
        Error.ExpectsTypeValue,
        @"type".eval(@as(f16, 0.0)),
    );

    try std.testing.expectEqual(
        Error.ExpectsTypeValue,
        @"type".eval(false),
    );

    try std.testing.expectEqual(
        Error.ExpectsTypeValue,
        @"type".eval(@as(comptime_float, 0.0)),
    );

    try std.testing.expectEqual(
        Error.ExpectsTypeValue,
        @"type".eval(@as(comptime_int, 0)),
    );

    try std.testing.expectEqual(
        Error.ExpectsTypeValue,
        @"type".eval(struct {}{}),
    );

    try std.testing.expectEqual(
        Error.ExpectsTypeValue,
        @"type".eval((union { a: bool }){ .a = false }),
    );

    try std.testing.expectEqual(
        Error.ExpectsTypeValue,
        @"type".eval((enum { a }).a),
    );

    try std.testing.expectEqual(
        Error.ExpectsTypeValue,
        @"type".eval((error{Coerced}).Coerced),
    );

    try std.testing.expectEqual(Error.ExpectsTypeValue, @"type".eval(struct {
        fn foo() void {}
    }.foo));

    try std.testing.expectEqual(
        Error.ExpectsTypeValue,
        @"type".eval(@as([]const u8, "hello")),
    );

    try std.testing.expectEqual(
        Error.ExpectsTypeValue,
        @"type".eval(@as(?bool, null)),
    );

    try std.testing.expectEqual(
        Error.ExpectsTypeValue,
        @"type".eval([3]i128{ 0, 1, 2 }),
    );

    try std.testing.expectEqual(
        Error.ExpectsTypeValue,
        @"type".eval(@Vector(3, f128){ 0.0, 0.0, 0.0 }),
    );
}
