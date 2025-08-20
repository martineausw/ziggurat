const std = @import("std");
const Prototype = @import("../Prototype.zig");

const OnTypeInfoError = error{};

pub const Error = OnTypeInfoError;

pub const Params =
    struct {
        type: ?Prototype = .false,
        void: ?Prototype = .false,
        bool: ?Prototype = .false,
        noreturn: ?Prototype = .false,
        int: ?Prototype = .false,
        float: ?Prototype = .false,
        pointer: ?Prototype = .false,
        array: ?Prototype = .false,
        @"struct": ?Prototype = .false,
        comptime_float: ?Prototype = .false,
        comptime_int: ?Prototype = .false,
        undefined: ?Prototype = .false,
        null: ?Prototype = .false,
        optional: ?Prototype = .false,
        error_union: ?Prototype = .false,
        error_set: ?Prototype = .false,
        @"enum": ?Prototype = .false,
        @"union": ?Prototype = .false,
        @"fn": ?Prototype = .false,
        @"opaque": ?Prototype = .false,
        frame: ?Prototype = .false,
        @"anyframe": ?Prototype = .false,
        vector: ?Prototype = .false,
        enum_literal: ?Prototype = .false,
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
