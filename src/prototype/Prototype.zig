//! Evaluates values to guide control flow and type reasoning.
const std = @import("std");

const Self = @This();

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
    prototype: Self,
    actual: anytype,
) void = null,

/// Callback triggered by `Sign` when `eval` returns `false`.
onFail: ?*const fn (prototype: Self, actual: anytype) void = null,

const Error = error{UnimplementedError};

pub const @"false": Self = .{
    .name = "false",
    .eval = struct {
        fn eval(_: anytype) !bool {
            return false;
        }
    }.eval,
};

pub const @"true": Self = .{
    .name = "true",
    .eval = struct {
        fn eval(_: anytype) !bool {
            return true;
        }
    }.eval,
};

pub const @"error": Self = .{
    .name = "error",
    .eval = struct {
        fn eval(_: anytype) !bool {
            return error.Error;
        }
    }.eval,
    .onError = struct {
        fn onError(err: anyerror, _: Self, _: anytype) void {
            if (@inComptime()) {
                @compileError(@errorName(err));
            }
            @panic(@errorName(err));
        }
    }.onError,
};

pub const Array = @import("Array.zig");
pub const Bool = @import("Bool.zig");
pub const Float = @import("Float.zig");
pub const Fn = @import("Fn.zig");
pub const Int = @import("Int.zig");
pub const Optional = @import("Optional.zig");
pub const Pointer = @import("Pointer.zig");
pub const Struct = @import("Struct.zig");
pub const Type = @import("Type.zig");
pub const Vector = @import("Vector.zig");

pub const is_array = Array.init;
pub const is_bool = Bool.init;
pub const is_float = Float.init;
pub const is_fn = Fn.init;
pub const is_int = Int.init;
pub const is_optional = Optional.init;
pub const is_pointer = Pointer.init;
pub const is_struct = Struct.init;
pub const is_type = Type.init;
pub const is_vector = Vector.init;

test Array {
    _ = Array.Params{
        .child = .true,
        .len = .{
            .min = null,
            .max = null,
        },
        .sentinel = null,
    };
    _ = Array.Error;
    _ = Array.init(.{});
}

test Bool {
    _ = Bool.init;
    _ = Bool.Error;
}

test Fn {
    _ = Fn.init(.{});
}

test Float {
    _ = Float.Params{
        .bits = .{
            .min = null,
            .max = null,
        },
    };
    _ = Float.Error;
    _ = Float.init(.{});
}

test Int {
    _ = Int.Params{
        .bits = .{
            .min = null,
            .max = null,
        },
        .signedness = .{
            .signed = null,
            .unsigned = null,
        },
    };
    _ = Int.Error;
    _ = Int.has_type_info;
}

test Optional {
    _ = Optional.Params{
        .child = .true,
    };
    _ = Optional.Error;
    _ = Optional.init(.{});
}

test Pointer {
    _ = Pointer.Params{
        .child = .true,
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
    _ = Pointer.init(.{});
    _ = Pointer.Error;
}

test Struct {
    _ = Struct.Error;
    _ = Struct.Params{
        .layout = .{
            .@"extern" = null,
            .@"packed" = null,
            .auto = null,
        },
        .fields = &.{},
        .decls = &.{},
        .is_tuple = null,
    };
    _ = Struct.init(.{});
}

test Type {
    _ = Type.init;
    _ = Type.Error;
}

test Vector {
    _ = Vector.Params{
        .child = .true,
        .len = .{
            .min = null,
            .max = null,
        },
    };

    _ = Vector.Error;
    _ = Vector.init(.{});
}

pub const EqualsBool = @import("aux/EqualsBool.zig");
pub const FiltersActiveTag = @import("aux/FiltersActiveTag.zig");
pub const FiltersTypeInfo = @import("aux/FiltersTypeInfo.zig");
pub const HasDecl = @import("aux/HasDecl.zig");
pub const HasField = @import("aux/HasField.zig");
pub const OnOptional = @import("aux/OnOptional.zig");
pub const OnType = @import("aux/OnType.zig");
pub const OnTypeInfo = @import("aux/OnTypeInfo.zig");
pub const WithinInterval = @import("aux/WithinInterval.zig");

pub const equals_bool = EqualsBool.init;
pub const filters = FiltersActiveTag.Of;
pub const has_type_info = FiltersTypeInfo.init;
pub const has_decl = HasDecl.init;
pub const has_field = HasField.init;
pub const on_optional = OnOptional.init;
pub const on_type = OnType.init;
pub const on_type_info = OnTypeInfo.init;
pub const within_interval = WithinInterval.init;

test EqualsBool {
    _ = EqualsBool.init(null);
}

test FiltersActiveTag {
    const Foo = union(enum) {
        bar: bool,
    };

    _ = FiltersActiveTag.Of(Foo).init(.{});
}

test FiltersTypeInfo {
    const info_params: FiltersTypeInfo.Params = .{
        .type = null,
        .void = null,
        .bool = null,
        .noreturn = null,
        .int = null,
        .float = null,
        .pointer = null,
        .array = null,
        .@"struct" = null,
        .comptime_float = null,
        .comptime_int = null,
        .undefined = null,
        .null = null,
        .optional = null,
        .error_union = null,
        .error_set = null,
        .@"enum" = null,
        .@"union" = null,
        .@"fn" = null,
        .@"opaque" = null,
        .frame = null,
        .@"anyframe" = null,
        .vector = null,
        .enum_literal = null,
    };

    const info_prototype = FiltersTypeInfo.init(info_params);

    _ = info_prototype;
    _ = FiltersTypeInfo.Error;
}

test HasDecl {
    _ = HasDecl.init(.{ .name = "foo" });
}

test HasField {
    _ = HasField.init(.{ .name = "foo", .type = .true });
}

test OnOptional {
    _ = OnOptional.init(true);
}

test OnType {
    _ = OnType.init(.true);
}

test OnTypeInfo {
    _ = OnTypeInfo;
}

test WithinInterval {
    const interval_params: WithinInterval.Params = .{
        .min = null,
        .max = null,
    };

    const interval_prototype = WithinInterval.init(interval_params);

    _ = interval_prototype;
    _ = WithinInterval.Error;
}

pub const all = @import("ops/all.zig").all;
pub const any = @import("ops/any.zig").any;
pub const not = @import("ops/not.zig").not;
pub const seq = @import("ops/seq.zig").seq;

test all {
    _ = all;
}

test any {
    _ = any;
}

test not {
    _ = not;
}

test seq {
    _ = seq;
}
