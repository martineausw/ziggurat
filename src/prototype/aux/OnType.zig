const std = @import("std");

const Prototype = @import("../Prototype.zig");

const Self = @This();

const OnTypeError = error{};

pub const Error = OnTypeError;

pub const Params = ?Prototype;

pub fn init(params: Params) Prototype {
    return .{
        .name = @typeName(Self),
        .eval = struct {
            fn eval(actual: anytype) !bool {
                if (params) |prototype| {
                    _ = try prototype.eval(actual);
                }

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                switch (err) {
                    else => std.fmt.comptimePrint("{s}.{s}: {any}", .{ prototype.name, @errorName(err), actual }),
                }
            }
        }.onError,
    };
}
