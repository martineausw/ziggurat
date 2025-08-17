const std = @import("std");

const Prototype = @import("../Prototype.zig");
const info = @import("../aux/info.zig");

const ChildError = error{
    ExpectsTypeValue,
};

pub const Error = ChildError;

pub const info_validator = info.init(.{
    .array = true,
    .pointer = true,
    .vector = true,
    .optional = true,
});

pub const Params = Prototype;

pub fn init(params: Params) Prototype {
    return .{
        .name = "Child",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = comptime info_validator.eval(actual) catch |err|
                    return switch (err) {
                        info.Error.ExpectsTypeValue,
                        info.Error.RequiresTypeInfo,
                        => ChildError.ExpectsTypeValue,
                        else => unreachable,
                    };

                _ = comptime try params.eval(std.meta.Child(actual));

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
                    ChildError.ExpectsTypeValue,
                    => info_validator.onError.?(err, prototype, actual),

                    else => @compileError(
                        std.fmt.comptimePrint("{s}.{s}: {s}", .{
                            prototype.name,
                            @errorName(err),
                            @typeName(std.meta.Child(actual)),
                        }),
                    ),
                }
            }
        }.onError,
    };
}

test ChildError {
    _ = ChildError.ExpectsTypeValue catch void;
}

test Params {
    const int = @import("../int.zig");
    const params: Params = int.init(.{});

    _ = params;
}

test init {
    const int = @import("../int.zig");
    const child = init(int.init(.{}));

    _ = child;
}

test "passes child assertions" {
    const int = @import("../int.zig");
    const child = init(int.init(
        .{ .bits = .{ .min = 32, .max = 32 } },
    ));

    try std.testing.expectEqual(true, comptime child.eval(*i32));
}
