const std = @import("std");
const testing = std.testing;

const Self = @This();

const Prototype = @import("../Prototype.zig");
const HasTypeInfo = @import("HasTypeInfo.zig");

const EqualsBoolError = error{
    AssertsTrue,
    AssertsFalse,
};

pub const Error = EqualsBoolError || HasTypeInfo.Error;
pub const Params = ?bool;

pub fn init(params: Params) Prototype {
    const has_type_info = HasTypeInfo.init(.{
        .bool = true,
    });

    return .{
        .name = @typeName(Self),
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = try @call(.always_inline, has_type_info.eval, .{@TypeOf(actual)});

                if (params) |param| {
                    if (param) {
                        if (!actual) {
                            return EqualsBoolError.AssertsTrue;
                        }
                    } else {
                        if (actual) {
                            return EqualsBoolError.AssertsFalse;
                        }
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

                    Error.AssertsTrue,
                    Error.AssertsFalse,
                    => @compileError(
                        std.fmt.comptimePrint("{s}.{s}: {s}", .{
                            prototype.name,
                            @errorName(err),
                            if (actual) "true" else "false",
                        }),
                    ),
                }
            }
        }.onError,
    };
}

test "equals bool" {
    try testing.expectEqual(true, init(null).eval(true));
    try testing.expectEqual(true, init(null).eval(false));

    try testing.expectEqual(true, init(false).eval(false));
    try testing.expectEqual(true, init(true).eval(true));
}

test "fails equals bool" {
    try testing.expectEqual(Error.AssertsFalse, init(false).eval(true));
    try testing.expectEqual(Error.AssertsTrue, init(true).eval(false));
}

test "fails validation" {
    try testing.expectEqual(Error.AssertsActiveTypeInfo, init(null).eval(bool));
}
