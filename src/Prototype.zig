const std = @import("std");
const testing = std.testing;

pub const Prototype = @import("prototype/Prototype.zig");

pub const array = @import("prototype/array.zig");
pub const @"bool" = @import("prototype/bool.zig");
pub const float = @import("prototype/float.zig");
pub const int = @import("prototype/int.zig");
pub const optional = @import("prototype/optional.zig");
pub const pointer = @import("prototype/pointer.zig");
pub const @"struct" = @import("prototype/struct.zig");
pub const @"type" = @import("prototype/type.zig");
pub const vector = @import("prototype/vector.zig");

pub const aux = @import("prototype/aux.zig");
pub const ops = @import("prototype/ops.zig");

test Prototype {
    _ = Prototype{
        .name = "name",
        .eval = struct {
            fn eval(actual: anytype) anyerror!bool {
                _ = actual;
                return true;
                // return false;
                // return error.Unimplemented;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                _ = err;
                _ = prototype;
                _ = actual;
            }
        }.onError,
        .onFail = struct {
            fn onFail(prototype: Prototype, actual: anytype) void {
                _ = prototype;
                _ = actual;
            }
        }.onFail,
    };
}

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

test aux {
    _ = aux.info;
    _ = aux.interval;
}

test ops {
    _ = ops.conjoin;
    _ = ops.disjoin;
    _ = ops.negate;
}
