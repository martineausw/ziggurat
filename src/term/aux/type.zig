//! Auxillary term to filter for a type value.
const std = @import("std");
const testing = std.testing;

const Term = @import("../Term.zig");

const TypeError = error{
    /// Value is not type.
    InvalidType,
};

pub const Error = TypeError;

/// Expects type value.
///
/// `actual` is type value, otherwise returns error.
pub const Is: Term = .{
    .name = "Type",

    .eval = struct {
        fn eval(actual: anytype) Error!bool {
            return switch (@typeInfo(@TypeOf(actual))) {
                .type => true,
                else => Error.InvalidType,
            };
        }
    }.eval,
    .onError = struct {
        fn onError(err: anyerror, term: Term, actual: anytype) void {
            switch (err) {
                .InvalidType => @compileError(std.fmt.comptimePrint(
                    "{s}.{s} expects `type`, actual: {s}",
                    .{
                        term.name,
                        @errorName(err),
                        @typeName(@TypeOf(actual)),
                    },
                )),
            }
        }
    }.onError,
};

test Is {
    try testing.expectEqual(true, Is.eval(bool));
    try testing.expectEqual(true, Is.eval(usize));
    try testing.expectEqual(true, Is.eval(i64));
    try testing.expectEqual(true, Is.eval(f128));
    try testing.expectEqual(true, Is.eval(struct {}));
    try testing.expectEqual(true, Is.eval(enum {}));
    try testing.expectEqual(true, Is.eval(union {}));

    try testing.expectEqual(error.InvalidType, Is.eval(@as(bool, true)));
    try testing.expectEqual(error.InvalidType, Is.eval(@as(usize, 0)));
    try testing.expectEqual(
        error.InvalidType,
        Is.eval(@as(struct {}, .{})),
    );
}

test {
    std.testing.refAllDecls(@This());
}
