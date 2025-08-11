const std = @import("std");
const testing = std.testing;

/// Error set for type.
const ValueError = error{
    /// Violates `type` assertion.
    InvalidType,
};

/// Error set returned by `eval`
pub const Error = ValueError;

pub const Prototype = @import("prototype/Prototype.zig");

pub const array = @import("prototype/array.zig");
pub const @"bool" = @import("prototype/bool.zig");
pub const float = @import("prototype/float.zig");
pub const int = @import("prototype/int.zig");
pub const optional = @import("prototype/optional.zig");
pub const pointer = @import("prototype/pointer.zig");
pub const @"type" = @import("prototype/type.zig");
pub const vector = @import("prototype/vector.zig");

pub const aux = @import("prototype/aux.zig");
pub const ops = @import("prototype/ops.zig");

test Prototype {
    const @"true": Prototype = .{
        .name = "True",
        .eval = struct {
            fn eval(actual: anytype) anyerror!bool {
                _ = actual;
                return true;
            }
        }.eval,
        .onFail = struct {
            fn onFail(prototype: Prototype, actual: anytype) void {
                _ = prototype;
                _ = actual;
            }
        }.onFail,
        .onError = struct {
            fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                _ = err;
                _ = prototype;
                _ = actual;
            }
        }.onError,
    };

    _ = @"true";
}

test array {
    const array_params: array.Params = .{
        .child = .{},
        .len = .{
            .min = null,
            .max = null,
        },
        .sentinel = null,
    };
    const array_prototype: Prototype = array.init(array_params);

    _ = array_prototype;
    _ = array.Error;
    _ = array.info_validator;
}

test @"bool" {
    const bool_prototype: Prototype = @"bool".init;

    _ = bool_prototype;
    _ = @"bool".Error;
    _ = @"bool".info_validator;
}

test float {
    const float_params: float.Params = .{
        .bits = .{
            .min = null,
            .max = null,
        },
    };
    const float_prototype: Prototype = float.init(float_params);

    _ = float_prototype;
    _ = float.Error;
    _ = float.info_validator;
}

test int {
    const int_params: int.Params = .{
        .bits = .{
            .min = null,
            .max = null,
        },
        .signedness = null,
    };
    const int_prototype: Prototype = int.init(int_params);

    _ = int_prototype;
    _ = int.Error;
    _ = int.info_validator;
}

test optional {
    const optional_params: optional.Params = .{
        .child = .{},
    };
    const optional_prototype: Prototype = optional.init(optional_params);

    _ = optional_prototype;
    _ = optional.Error;

    _ = optional.info_validator;
}

test pointer {
    const pointer_params: pointer.Params = .{
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

    const pointer_prototype: Prototype = pointer.init(pointer_params);

    _ = pointer_prototype;
    _ = pointer.Error;

    _ = pointer.info_validator;
}

test @"type" {
    const type_prototype: Prototype = @"type".init;

    _ = type_prototype;
    _ = @"type".Error;
}

test vector {
    const vector_params: vector.Params = .{
        .child = .{},
        .len = .{
            .min = null,
            .max = null,
        },
    };

    const vector_prototype: Prototype = vector.init(vector_params);

    _ = vector_prototype;
    _ = vector.Error;

    _ = vector.info_validator;
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
