const std = @import("std");
const testing = std.testing;

const Self = @This();

const Prototype = @import("Prototype.zig");
const WithinInterval = @import("aux/WithinInterval.zig");
const HasTypeInfo = @import("aux/HasTypeInfo.zig");
const HasSignedness = @import("aux/HasTag.zig").Of(std.builtin.Signedness);

const IntError = error{
    AssertsMinBits,
    AssertsMaxBits,
    AssertsInactiveSignedness,
    AssertsActiveSignedness,
};

pub const Error = IntError || HasTypeInfo.Error;
pub const Params = struct {
    bits: WithinInterval.Params = .{},
    signedness: HasSignedness.Params = .{},
};

pub fn init(params: Params) Prototype {
    const has_type_info = HasTypeInfo.init(.{
        .int = true,
    });
    const bits = WithinInterval.init(params.bits);
    const signedness = HasSignedness.init(params.signedness);

    return .{
        .name = @typeName(Self),
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = try has_type_info.eval(actual);

                _ = bits.eval(@typeInfo(actual).int.bits) catch |err|
                    return switch (err) {
                        WithinInterval.Error.AssertsMin => Error.AssertsMinBits,
                        WithinInterval.Error.AssertsMax => Error.AssertsMaxBits,
                        else => @panic("unhandled error"),
                    };

                _ = comptime signedness.eval(
                    @typeInfo(actual).int.signedness,
                ) catch |err|
                    return switch (err) {
                        HasSignedness.Error.AssertsInactive => Error.AssertsInactiveSignedness,
                        HasSignedness.Error.AssertsActive => Error.AssertsActiveSignedness,
                        else => @panic("unhandled error"),
                    };

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                switch (err) {
                    Error.AssertsTypeValue,
                    Error.AssertsActiveTypeInfo,
                    => has_type_info.onError.?(
                        err,
                        prototype,
                        actual,
                    ),

                    Error.AssertsMinBits,
                    Error.AssertsMaxBits,
                    => bits.onError.?(
                        try bits.eval(@typeInfo(actual).int.bits),
                        prototype,
                        @typeInfo(actual).int.bits,
                    ),

                    Error.AssertsInactiveSignedness,
                    Error.AssertsActiveSignedness,
                    => signedness.onError.?(
                        try signedness.eval(@typeInfo(actual).int.signedness),
                        prototype,
                        @typeInfo(actual).int.signedness,
                    ),
                }
            }
        }.onError,
    };
}

test "is int" {
    @setEvalBranchQuota(3000);
    inline for (0..128) |bits| {
        try testing.expectEqual(true, init(.{}).eval(std.meta.Int(.signed, bits)));
    }

    inline for (0..128) |bits| {
        try testing.expectEqual(true, init(.{}).eval(std.meta.Int(.unsigned, bits)));
    }

    try testing.expectEqual(true, init(.{}).eval(usize));
}
