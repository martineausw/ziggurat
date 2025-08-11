//! Prototype for `type` value with bool type info.
//!
//! `eval` asserts `bool` type value.
const std = @import("std");

const Prototype = @import("Prototype.zig");
const info = @import("aux/info.zig");

pub const Error = info.Error;

test Error {
    _ = Error.InvalidType catch void;
    _ = Error.DisallowedType catch void;
    _ = Error.UnexpectedType catch void;
}

pub const info_validator = info.init(.{
    .bool = true,
});

pub const init: Prototype = .{
    .name = "Bool",
    .eval = struct {
        fn eval(actual: anytype) Error!bool {
            _ = try info_validator.eval(actual);

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
                else => unreachable,
            }
        }
    }.onError,
};
