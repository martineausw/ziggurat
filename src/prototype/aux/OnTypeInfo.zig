const std = @import("std");
const Prototype = @import("../Prototype.zig");

const OnTypeInfoError = error{};

pub const Error = OnTypeInfoError;

pub const Params = struct {
    type: ?Prototype = null,
    void: ?Prototype = null,
    bool: ?Prototype = null,
    noreturn: ?Prototype = null,
    int: ?Prototype = null,
    float: ?Prototype = null,
    pointer: ?Prototype = null,
    array: ?Prototype = null,
    @"struct": ?Prototype = null,
    comptime_float: ?Prototype = null,
    comptime_int: ?Prototype = null,
    undefined: ?Prototype = null,
    null: ?Prototype = null,
    optional: ?Prototype = null,
    error_union: ?Prototype = null,
    error_set: ?Prototype = null,
    @"enum": ?Prototype = null,
    @"union": ?Prototype = null,
    @"fn": ?Prototype = null,
    @"opaque": ?Prototype = null,
    frame: ?Prototype = null,
    @"anyframe": ?Prototype = null,
    vector: ?Prototype = null,
    enum_literal: ?Prototype = null,
};

// pub const Params = @Type(.{ .@"struct" = .{
//     .layout = .auto,
//     .backing_integer = null,
//     .fields = fields: {
//         var fields: [std.meta.fields(std.builtin.Type).len]std.builtin.Type.StructField = undefined;

//         for (0..std.meta.fields(std.builtin.Type).len) |i| {
//             fields[i] = .{
//                 .name = std.meta.fields(std.builtin.Type)[i].name,
//                 .type = ?Prototype,
//                 .default_value_ptr = &@as(?Prototype, null),
//                 .is_comptime = false,
//                 .alignment = @alignOf(?Prototype),
//             };
//         }

//         break :fields &fields;
//     },
//     .decls = &[0]std.builtin.Type.Declaration{},
//     .is_tuple = false,
// } });

pub fn init(params: Params) Prototype {
    return .{
        .name = @typeName(@This()),
        .eval = struct {
            fn eval(actual: anytype) anyerror!bool {
                if (@field(params, @tagName(@typeInfo(actual)))) |prototype| {
                    return prototype.eval(actual);
                }

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(
                err: anyerror,
                prototype: Prototype,
                actual: anytype,
            ) void {
                switch (err) {
                    else => @field(
                        params,
                        @tagName(@typeInfo(@TypeOf(actual))),
                    ).onError.?(err, prototype, actual),
                }
            }
        }.onError,
    };
}
