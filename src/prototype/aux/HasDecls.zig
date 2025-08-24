const std = @import("std");
const testing = std.testing;

const Prototype = @import("../Prototype.zig");
const HasDecl = @import("HasDecl.zig");
const HasTypeInfo = @import("HasTypeInfo.zig");

const Self = @This();

pub const Error = HasDecl.Error || HasTypeInfo.Error;
pub const Params = []const HasDecl.Params;

pub fn init(params: Params) Prototype {
    const has_type_info = HasTypeInfo.init(.{
        .@"struct" = true,
        .@"enum" = true,
        .@"union" = true,
    });

    return .{
        .name = @typeName(Self),
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = try @call(.always_inline, has_type_info.eval, .{actual});

                inline for (params) |decl| {
                    if (!@hasDecl(actual, decl.name)) {
                        return Error.AssertsHasDecl;
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
                    Error.AssertsTypeValue,
                    Error.AssertsActiveTypeInfo,
                    Error.AssertsInactiveTypeInfo,
                    => has_type_info.onError.?(err, prototype, actual),

                    Error.AssertsHasDecl,
                    => {
                        const has_decl = HasDecl.init(params[
                            inline for (params.decls, 0..) |decl, i| blk: {
                                if (!@hasDecl(actual, decl.name)) {
                                    break :blk i;
                                }
                            }
                        ]);

                        has_decl.onError.?(
                            try has_decl.eval(actual),
                            prototype,
                            actual,
                        );
                    },
                }
            }
        }.onError,
    };
}

test "has decls" {
    const Foo = struct {
        const a: type = void;
        pub const b: bool = false;
        pub const x: usize = 0;
        pub const y: f128 = 0.0;
    };

    const Bar = union {
        pub const a: type = void;
        pub const b: bool = false;
        pub const x: usize = 0;
        pub const y: f128 = 0.0;
    };

    const Zig = enum {
        pub const a: type = void;
        pub const b: bool = false;
        pub const x: usize = 0;
        pub const y: f128 = 0.0;
    };

    try testing.expectEqual(true, init(&.{
        .{ .name = "a" },
        .{ .name = "b" },
        .{ .name = "x" },
        .{ .name = "y" },
    }).eval(Foo));

    try testing.expectEqual(true, init(&.{
        .{ .name = "a" },
        .{ .name = "b" },
        .{ .name = "x" },
        .{ .name = "y" },
    }).eval(Bar));

    try testing.expectEqual(true, init(&.{
        .{ .name = "a" },
        .{ .name = "b" },
        .{ .name = "x" },
        .{ .name = "y" },
    }).eval(Zig));
}

test "fails has decls" {
    const Foo = struct {};
    const Bar = union {};
    const Zig = enum {};

    try testing.expectEqual(Error.AssertsHasDecl, init(&.{
        .{ .name = "a" },
        .{ .name = "b" },
        .{ .name = "x" },
        .{ .name = "y" },
    }).eval(Foo));

    try testing.expectEqual(Error.AssertsHasDecl, init(&.{
        .{ .name = "a" },
        .{ .name = "b" },
        .{ .name = "x" },
        .{ .name = "y" },
    }).eval(Bar));

    try testing.expectEqual(Error.AssertsHasDecl, init(&.{
        .{ .name = "a" },
        .{ .name = "b" },
        .{ .name = "x" },
        .{ .name = "y" },
    }).eval(Zig));
}

test "fails validation" {
    try testing.expectEqual(Error.AssertsTypeValue, init(&.{}).eval(@as(struct {}, .{})));

    try testing.expectEqual(Error.AssertsActiveTypeInfo, init(&.{}).eval(bool));
    try testing.expectEqual(Error.AssertsActiveTypeInfo, init(&.{}).eval(usize));
    try testing.expectEqual(Error.AssertsActiveTypeInfo, init(&.{}).eval(i128));
    try testing.expectEqual(Error.AssertsActiveTypeInfo, init(&.{}).eval(f128));
}
