const std = @import("std");
const testing = std.testing;

const Prototype = @import("../Prototype.zig");
const HasTypeInfo = @import("HasTypeInfo.zig");

const Self = @This();

const HasDeclError = error{
    AssertsHasDecl,
};

pub const Error = HasDeclError || HasTypeInfo.Error;
pub const Params = struct {
    name: [:0]const u8,
};

pub fn init(params: Params) Prototype {
    const has_type_info = HasTypeInfo.init(.{
        .@"struct" = true,
        .@"enum" = true,
        .@"union" = true,
    });

    return .{
        .name = @typeName(Self),
        .eval = struct {
            fn eval(actual: anytype) HasDeclError!bool {
                _ = try @call(.always_inline, has_type_info.eval, .{actual});

                if (!@hasDecl(actual, params.name)) {
                    return Error.AssertsHasDecl;
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
                    Error.AssertsTypeValue,
                    Error.AssertsActiveTypeInfo,
                    Error.AssertsInactiveTypeInfo,
                    => has_type_info.onError.?(err, prototype, actual),

                    Error.AssertsHasDecl,
                    => @compileError(std.fmt.comptimePrint(
                        "{s}.{s}: {s}",
                        .{
                            prototype.name,
                            @errorName(err),
                            params.name,
                        },
                    )),
                }
            }
        }.onError,
    };
}

test "has decl" {
    const Foo = struct {
        const a: type = void;
        const b: bool = false;
        pub const x: usize = 0;
        pub const y: f128 = 1;
    };

    const Bar = union {
        const a: type = void;
        const b: bool = false;
        pub const x: usize = 0;
        pub const y: f128 = 1;
    };

    const Zig = enum {
        const a: type = void;
        const b: bool = false;
        pub const x: usize = 0;
        pub const y: f128 = 1;
    };

    try testing.expectEqual(true, init(
        .{ .name = "a" },
    ).eval(Foo));

    try testing.expectEqual(true, init(
        .{ .name = "b" },
    ).eval(Foo));

    try testing.expectEqual(true, init(
        .{ .name = "x" },
    ).eval(Foo));

    try testing.expectEqual(true, init(
        .{ .name = "y" },
    ).eval(Foo));

    try testing.expectEqual(true, init(
        .{ .name = "a" },
    ).eval(Bar));

    try testing.expectEqual(true, init(
        .{ .name = "b" },
    ).eval(Bar));

    try testing.expectEqual(true, init(
        .{ .name = "x" },
    ).eval(Bar));

    try testing.expectEqual(true, init(
        .{ .name = "y" },
    ).eval(Bar));

    try testing.expectEqual(true, init(
        .{ .name = "a" },
    ).eval(Zig));

    try testing.expectEqual(true, init(
        .{ .name = "b" },
    ).eval(Zig));

    try testing.expectEqual(true, init(
        .{ .name = "x" },
    ).eval(Zig));

    try testing.expectEqual(true, init(
        .{ .name = "y" },
    ).eval(Zig));
}

test "fails has decl" {
    const Foo = struct {};

    const Bar = union {};

    const Zig = enum {};

    try testing.expectEqual(Error.AssertsHasDecl, init(
        .{ .name = "a" },
    ).eval(Foo));

    try testing.expectEqual(Error.AssertsHasDecl, init(
        .{ .name = "b" },
    ).eval(Foo));

    try testing.expectEqual(Error.AssertsHasDecl, init(
        .{ .name = "x" },
    ).eval(Foo));

    try testing.expectEqual(Error.AssertsHasDecl, init(
        .{ .name = "y" },
    ).eval(Foo));

    try testing.expectEqual(Error.AssertsHasDecl, init(
        .{ .name = "a" },
    ).eval(Bar));

    try testing.expectEqual(Error.AssertsHasDecl, init(
        .{ .name = "b" },
    ).eval(Bar));

    try testing.expectEqual(Error.AssertsHasDecl, init(
        .{ .name = "x" },
    ).eval(Bar));

    try testing.expectEqual(Error.AssertsHasDecl, init(
        .{ .name = "y" },
    ).eval(Bar));

    try testing.expectEqual(Error.AssertsHasDecl, init(
        .{ .name = "a" },
    ).eval(Zig));

    try testing.expectEqual(Error.AssertsHasDecl, init(
        .{ .name = "b" },
    ).eval(Zig));

    try testing.expectEqual(Error.AssertsHasDecl, init(
        .{ .name = "x" },
    ).eval(Zig));

    try testing.expectEqual(Error.AssertsHasDecl, init(
        .{ .name = "y" },
    ).eval(Zig));
}
