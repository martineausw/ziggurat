const std = @import("std");
const Prototype = @import("../Prototype.zig");

const InfoSwitchError = error{};

pub const Error = InfoSwitchError;

pub const Params = @Type(.{ .@"struct" = .{
    .layout = .auto,
    .backing_integer = null,
    .fields = fields: {
        var fields: [std.meta.fields(std.builtin.Type).len]std.builtin.Type.StructField = undefined;

        for (0..std.meta.fields(std.builtin.Type).len) |i| {
            fields[i] = .{
                .name = std.meta.fields(std.builtin.Type)[i].name,
                .type = ?Prototype,
                .default_value_ptr = &@as(?Prototype, null),
                .is_comptime = false,
                .alignment = @alignOf(?Prototype),
            };
        }

        break :fields &fields;
    },
    .decls = &[0]std.builtin.Type.Declaration{},
    .is_tuple = false,
} });

pub fn init(params: Params) Prototype {
    return .{
        .name = "InfoSwitch",
        .eval = struct {
            fn eval(actual: anytype) anyerror!bool {
                if (@field(
                    params,
                    @tagName(@typeInfo(@TypeOf(actual))),
                )) |prototype| {
                    _ = try prototype.eval(@TypeOf(actual));
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
