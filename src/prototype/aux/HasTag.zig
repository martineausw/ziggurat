const std = @import("std");
const testing = std.testing;

const Self = @This();

const Prototype = @import("../Prototype.zig");
const Type = @import("../Type.zig");

const HasTagError = error{
    AssertsInactive,
    AssertsActive,
};

pub const Error = HasTagError || Type.Error;

pub fn Of(comptime T: type) type {
    return struct {
        const OfSelf = @This();
        pub const Error = Self.Error;

        pub const is_type_value = Type.init;

        pub const Params =
            switch (@typeInfo(T)) {
                .@"union", .@"enum" => @Type(.{ .@"struct" = .{
                    .layout = .auto,
                    .backing_integer = null,
                    .fields = fields: {
                        var fields: [std.meta.fields(T).len]std.builtin.Type.StructField = undefined;

                        for (0..std.meta.fields(T).len) |i| {
                            fields[i] = .{
                                .name = std.meta.fields(T)[i].name,
                                .type = ?bool,
                                .default_value_ptr = &@as(?bool, null),
                                .is_comptime = false,
                                .alignment = @alignOf(?bool),
                            };
                        }

                        break :fields &fields;
                    },
                    .decls = &[0]std.builtin.Type.Declaration{},
                    .is_tuple = false,
                } }),
                else => @compileError("type must be a tagged union or enum"),
            };

        pub inline fn init(params: Params) Prototype {
            return .{
                .name = @typeName(Self),
                .eval = struct {
                    fn eval(actual: anytype) !bool {
                        _ = switch (@typeInfo(@TypeOf(actual))) {
                            inline .@"union", .@"enum" => {},
                            else => return OfSelf.Error.AssertsTypeValue,
                        };

                        // Checks active tag against blacklist
                        if (@field(params, @tagName(actual))) |param| {
                            if (!param) return OfSelf.Error.AssertsInactive;
                            return true;
                        }

                        // Checks remaining fields for active whitelist
                        inline for (std.meta.fields(Params)) |field| {
                            if (@field(params, field.name)) |value| {
                                if (value) return OfSelf.Error.AssertsActive;
                            }
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
                            OfSelf.Error.AssertsTypeValue,
                            OfSelf.Error.AssertsActiveTypeInfo,
                            OfSelf.Error.AssertsInactiveTypeInfo,
                            => is_type_value.onError.?(
                                err,
                                prototype,
                                actual,
                            ),

                            OfSelf.Error.AssertsActive,
                            OfSelf.Error.AssertsInactive,
                            => @compileError(std.fmt.comptimePrint(
                                "{s}.{s}: {s}",
                                .{
                                    prototype.name,
                                    @errorName(err),
                                    @typeName(actual),
                                },
                            )),
                            else => unreachable,
                        }
                    }
                }.onError,
            };
        }
    };
}

test "has tag" {
    const Foo = union(enum) {
        a: type,
        b: bool,
        x: usize,
        y: i128,
    };

    try testing.expectEqual(true, Of(Foo).init(.{}).eval(Foo{ .a = void }));
    try testing.expectEqual(true, Of(Foo).init(.{}).eval(Foo{ .b = false }));
    try testing.expectEqual(true, Of(Foo).init(.{}).eval(Foo{ .x = 0 }));
    try testing.expectEqual(true, Of(Foo).init(.{}).eval(Foo{ .y = 0 }));
}

test "fails has tag" {
    const Foo = union(enum) {
        a: type,
        b: bool,
        x: usize,
        y: i128,
    };

    try testing.expectEqual(Error.AssertsInactive, Of(Foo).init(.{
        .a = false,
    }).eval(Foo{ .a = void }));

    try testing.expectEqual(Error.AssertsActive, Of(Foo).init(.{
        .a = true,
    }).eval(Foo{ .b = false }));
}

test "fails validation" {
    const Foo = union(enum) {
        a: type,
        b: bool,
        x: usize,
        y: i128,
    };

    try testing.expectEqual(Error.AssertsTypeValue, Of(Foo).init(.{}).eval(@as(struct {}, .{})));
}
