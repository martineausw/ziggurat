//! Auxillary term to filter for a type value.
const std = @import("std");
const testing = std.testing;

const Term = @import("../Term.zig");

/// Error set for type.
const TypeError = error{
    /// Violates type value assertion.
    InvalidType,
};

/// Error set returned by `eval`
pub const Error = TypeError;

/// Expects type value.
///
/// `actual` is type value, otherwise returns error.
pub const init: Term = .{
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
                Error.InvalidType => @compileError(std.fmt.comptimePrint(
                    "{s}.{s} expects `type`, actual: {s}",
                    .{
                        term.name,
                        @errorName(err),
                        @typeName(@TypeOf(actual)),
                    },
                )),
                else => unreachable,
            }
        }
    }.onError,
};

test init {
    try testing.expectEqual(true, init.eval(bool));
    try testing.expectEqual(true, init.eval(usize));
    try testing.expectEqual(true, init.eval(i64));
    try testing.expectEqual(true, init.eval(f128));
    try testing.expectEqual(true, init.eval(struct {}));
    try testing.expectEqual(true, init.eval(enum {}));
    try testing.expectEqual(true, init.eval(union {}));

    try testing.expectEqual(Error.InvalidType, init.eval(@as(bool, true)));
    try testing.expectEqual(Error.InvalidType, init.eval(@as(usize, 0)));
    try testing.expectEqual(
        Error.InvalidType,
        init.eval(@as(struct {}, .{})),
    );
}

test {
    std.testing.refAllDecls(@This());
}
