//! Prototype for `type` value with `type` type info.
//!
//! `eval` asserts `type` type value.
const std = @import("std");

const Prototype = @import("Prototype.zig");
const TypeError = error{
    /// Violates `actual` is `type` value assertion.
    InvalidType,
};

/// Errors returned by `eval`
pub const Error = TypeError;

test Error {
    _ = Error.InvalidType catch void;
}

/// Expects type value.
///
/// `actual` is type value, otherwise returns error.
pub const init: Prototype = .{
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
        fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
            switch (err) {
                Error.InvalidType => @compileError(std.fmt.comptimePrint(
                    "{s}.{s} expects `type`, actual: {s}",
                    .{
                        prototype.name,
                        @errorName(err),
                        @typeName(@TypeOf(actual)),
                    },
                )),
                else => unreachable,
            }
        }
    }.onError,
};
