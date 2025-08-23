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
                _ = try has_type_info.eval(actual);

                inline for (params) |decl| {
                    const has_decl = HasDecl.init(decl);
                    _ = try has_decl.eval(actual);
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
                                const has_decl = HasDecl.init(decl);
                                has_decl.eval(actual) catch
                                    break :blk i;
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
        pub const a: type = void;
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
