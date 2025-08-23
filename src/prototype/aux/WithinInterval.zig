const std = @import("std");
const testing = std.testing;

const Prototype = @import("../Prototype.zig");
const HasTypeInfo = @import("HasTypeInfo.zig");

const Self = @This();

const WithinIntervalError = error{
    AssertsMin,
    AssertsMax,
};

pub const Error = WithinIntervalError || HasTypeInfo.Error;
pub const Params = struct {
    min: ?f128 = null,
    max: ?f128 = null,
    tolerance: ?f128 = null,
};

pub fn init(params: Params) Prototype {
    const has_type_info = HasTypeInfo.init(.{
        .int = true,
        .float = true,
        .comptime_int = true,
        .comptime_float = true,
    });

    return .{
        .name = @typeName(Self),
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = try has_type_info.eval(@TypeOf(actual));

                const tolerance = params.tolerance orelse std.math.floatEps(f128);
                const min = params.min orelse std.math.floatMin(f128);
                const max = params.max orelse std.math.floatMax(f128);

                const value = switch (@typeInfo(@TypeOf(actual))) {
                    .comptime_int, .int => @as(f128, @floatFromInt(actual)),
                    .comptime_float, .float => @as(f128, @floatCast(actual)),
                    else => unreachable,
                };

                if (!std.math.approxEqAbs(f128, min, value, tolerance) and min > value) {
                    return Error.AssertsMin;
                }

                if (!std.math.approxEqAbs(f128, max, value, tolerance) and max < value) {
                    return Error.AssertsMax;
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

                    Error.AssertsMin,
                    Error.AssertsMax,
                    => @compileError(std.fmt.comptimePrint(
                        "{s}.{s}: {d}",
                        .{
                            prototype.name,
                            @errorName(err),
                            actual,
                        },
                    )),
                }
            }
        }.onError,
    };
}

test "within interval" {
    try testing.expectEqual(true, init(.{}).eval(@as(usize, 0)));
    try testing.expectEqual(true, init(.{}).eval(@as(i128, 0)));
    try testing.expectEqual(true, init(.{}).eval(@as(f128, 0)));
    try testing.expectEqual(true, init(.{}).eval(@as(comptime_int, 0)));
    try testing.expectEqual(true, init(.{}).eval(@as(comptime_float, 0)));
}
