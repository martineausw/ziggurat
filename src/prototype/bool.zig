const std = @import("std");
const testing = std.testing;

const Self = @This();

const Prototype = @import("Prototype.zig");
const HasTypeInfo = @import("aux/HasTypeInfo.zig");

const BoolError = error{};

pub const Error = BoolError || HasTypeInfo.Error;

const has_type_info = HasTypeInfo.init(.{
    .bool = true,
});

pub const init: Prototype = .{
    .name = @typeName(Self),
    .eval = struct {
        fn eval(actual: anytype) Error!bool {
            _ = try has_type_info.eval(actual);

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
            }
        }
    }.onError,
};

test "is bool" {
    try testing.expectEqual(true, init.eval(bool));
}
