//! Evaluates values to guide control flow and type reasoning.
const std = @import("std");

const Self = @This();

name: [:0]const u8,

eval: *const fn (actual: anytype) anyerror!bool = struct {
    fn eval(actual: anytype) anyerror!bool {
        _ = actual;
        return Error.UnimplementedError;
    }
}.eval,

onError: ?*const fn (
    err: anyerror,
    prototype: Self,
    actual: anytype,
) void = null,

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

pub const EqualsBool = @import("aux/EqualsBool.zig");
pub const HasTag = @import("aux/HasTag.zig");
pub const HasTypeInfo = @import("aux/HasTypeInfo.zig");
pub const HasDecl = @import("aux/HasDecl.zig");
pub const HasField = @import("aux/HasField.zig");
pub const HasValue = @import("aux/HasValue.zig");
pub const OnType = @import("aux/OnType.zig");
pub const WithinInterval = @import("aux/WithinInterval.zig");

pub const equals_bool = EqualsBool.init;
pub const has_tag = HasTag.Of;
pub const has_type_info = HasTypeInfo.init;
pub const has_decl = HasDecl.init;
pub const has_field = HasField.init;
pub const has_value = HasValue.init;
pub const on_type = OnType.init;
pub const within_interval = WithinInterval.init;

pub const all = @import("ops/all.zig").all;
pub const any = @import("ops/any.zig").any;
pub const not = @import("ops/not.zig").not;
pub const seq = @import("ops/seq.zig").seq;

test {
    std.testing.refAllDecls(@This());
}
