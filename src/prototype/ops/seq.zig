const std = @import("std");

const Self = @This();

const Prototype = @import("../Prototype.zig");
const HasTypeInfo = @import("../aux/HasTypeInfo.zig");

pub const Error = HasTypeInfo.Error;

pub fn seq(prototypes: []const Prototype) Prototype {
    const has_type_info = HasTypeInfo.init(.{
        .array = true,
        .pointer = true,
        .vector = true,
        .@"struct" = true,
    });

    return .{
        .name = @typeName(Self),
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = try has_type_info.eval(@TypeOf(actual));

                inline for (prototypes, 0..) |prototype, i| {
                    _ = try prototype.eval(actual[i]);
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
                    Error.AssertsActiveTypeInfo,
                    => has_type_info.onError.?(err, prototype, actual),

                    else => @compileError(
                        std.fmt.comptimePrint("{s}.{s}: {s}", .{
                            prototype.name,
                            @errorName(err),
                            @typeName(actual),
                        }),
                    ),
                }
            }
        }.onError,
    };
}
