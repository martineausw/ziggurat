const std = @import("std");
const testing = std.testing;

const Self = @This();

const Prototype = @import("../Prototype.zig");
const HasTypeInfo = @import("HasTypeInfo.zig");

const HasValue = error{
    AssertsNotNull,
    AssertsNull,
};

pub const Error = HasValue || HasTypeInfo.Error;
pub const Params = ?bool;

pub fn init(params: Params) Prototype {
    const has_type_info = HasTypeInfo.init(.{
        .optional = true,
    });
    return .{
        .name = @typeName(Self),
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = try has_type_info.eval(@TypeOf(actual));

                if (params) |param| {
                    if (actual) |_| {
                        if (param) return true;
                        return HasValue.AssertsNull;
                    } else {
                        if (!param) return true;
                        return HasValue.AssertsNotNull;
                    }
                }

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                switch (err) {
                    Error.AssertsTypeValue,
                    Error.AssertsActiveTypeInfo,
                    Error.AssertsInactiveTypeInfo,
                    => has_type_info.onError.?(err, prototype, actual),

                    Error.AssertsNull,
                    Error.AssertsNotNull,
                    => @compileError(
                        std.fmt.comptimePrint("{s}.{s}: {any}", .{
                            prototype.name,
                            @errorName(err),
                            actual,
                        }),
                    ),
                }
            }
        }.onError,
    };
}

test "has value" {
    try testing.expectEqual(true, init(null).eval(@as(?bool, null)));
    try testing.expectEqual(true, init(null).eval(@as(?bool, true)));
    try testing.expectEqual(true, init(null).eval(@as(?bool, false)));
}

test "fails has value" {
    try testing.expectEqual(Error.AssertsNotNull, init(true).eval(@as(?usize, null)));
    try testing.expectEqual(Error.AssertsNull, init(false).eval(@as(?usize, 0)));
}

test "fails validation" {
    try testing.expectEqual(Error.AssertsActiveTypeInfo, init(null).eval(*const u8));
}
