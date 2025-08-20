//! Evaluates values to guide control flow and type reasoning.
const std = @import("std");

/// Name to be used for messages.
name: [:0]const u8,

/// Evaluates `actual`, returns an error or `false` on failure.
eval: *const fn (actual: anytype) anyerror!bool = struct {
    fn eval(actual: anytype) anyerror!bool {
        _ = actual;
        return Error.UnimplementedError;
    }
}.eval,

/// Callback triggered by `Sign` when `eval` returns an error.
onError: ?*const fn (
    err: anyerror,
    prototype: @This(),
    actual: anytype,
) void = null,

/// Callback triggered by `Sign` when `eval` returns `false`.
onFail: ?*const fn (prototype: @This(), actual: anytype) void = null,

const Error = error{UnimplementedError};

pub const @"false": @This() = .{
    .name = "false",
    .eval = struct {
        fn eval(_: anytype) !bool {
            return false;
        }
    }.eval,
};

pub const @"true": @This() = .{
    .name = "true",
    .eval = struct {
        fn eval(_: anytype) !bool {
            return true;
        }
    }.eval,
};

pub const @"error": @This() = .{ .name = "error", .eval = struct {
    fn eval(_: anytype) !bool {
        return error.Error;
    }
}.eval, .onError = struct {
    fn onError(err: anyerror, _: @This(), _: anytype) void {
        if (@inComptime()) {
            @compileError(@errorName(err));
        }
        @panic(@errorName(err));
    }
} };

pub const array = @import("array.zig");
pub const @"bool" = @import("bool.zig");
pub const float = @import("float.zig");
pub const @"fn" = @import("fn.zig");
pub const int = @import("int.zig");
pub const optional = @import("optional.zig");
pub const pointer = @import("pointer.zig");
pub const @"struct" = @import("struct.zig");
pub const @"type" = @import("type.zig");
pub const vector = @import("vector.zig");

test array {
    _ = array.Params{
        .child = .{},
        .len = .{
            .min = null,
            .max = null,
        },
        .sentinel = null,
    };
    _ = array.Error;
    _ = array.init(.{});
}

test @"bool" {
    _ = @"bool".init;
    _ = @"bool".Error;
}

test @"fn" {
    _ = @"fn".init(.{});
}

test float {
    _ = float.Params{
        .bits = .{
            .min = null,
            .max = null,
        },
    };
    _ = float.Error;
    _ = float.init(.{});
}

test int {
    _ = int.Params{
        .bits = .{
            .min = null,
            .max = null,
        },
        .signedness = .{
            .signed = null,
            .unsigned = null,
        },
    };
    _ = int.Error;
    _ = int.info_validator;
}

test optional {
    _ = optional.Params{
        .child = .{},
    };
    _ = optional.Error;
    _ = optional.init(.{});
}

test pointer {
    _ = pointer.Params{
        .child = .{},
        .is_const = null,
        .is_volatile = null,
        .sentinel = null,
        .size = .{
            .one = null,
            .many = null,
            .slice = null,
            .c = null,
        },
    };
    _ = pointer.init(.{});
    _ = pointer.Error;
}

test @"struct" {
    _ = @"struct".Error;
    _ = @"struct".Params{
        .layout = .{
            .@"extern" = null,
            .@"packed" = null,
            .auto = null,
        },
        .fields = &.{},
        .decls = &.{},
        .is_tuple = null,
    };
    _ = @"struct".init(.{});
}

test @"type" {
    _ = @"type".init;
    _ = @"type".Error;
}

test vector {
    _ = vector.Params{
        .child = .{},
        .len = .{
            .min = null,
            .max = null,
        },
    };

    _ = vector.Error;
    _ = vector.init(.{});
}
