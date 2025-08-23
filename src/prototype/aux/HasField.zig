const std = @import("std");
const testing = std.testing;

const Prototype = @import("../Prototype.zig");
const HasTypeInfo = @import("HasTypeInfo.zig");
const OnType = @import("OnType.zig");

const Self = @This();

const HasFieldError = error{
    AssertsHasField,
    AssertsOnTypeField,
};

pub const Error = HasFieldError || HasTypeInfo.Error;
pub const Params = struct {
    name: [:0]const u8,
    type: OnType.Params = null,
};

pub fn init(params: Params) Prototype {
    const has_type_info = HasTypeInfo.init(.{
        .@"struct" = true,
        .@"union" = true,
    });
    const on_type = OnType.init(params.type);
    return .{
        .name = @typeName(Self),
        .eval = struct {
            fn eval(actual: anytype) anyerror!bool {
                _ = try has_type_info.eval(actual);

                if (!@hasField(actual, params.name)) {
                    return HasFieldError.AssertsHasField;
                }

                _ = on_type.eval(@FieldType(
                    actual,
                    params.name,
                )) catch |err|
                    return switch (err) {
                        OnType.Error.AssertsOnType,
                        => Error.AssertsOnTypeField,
                        else => unreachable,
                    };

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

                    Error.AssertsOnTypeField,
                    => on_type.onError.?(
                        try on_type.eval(@FieldType(actual, params.name)),
                        prototype,
                        @FieldType(actual, params.name),
                    ),

                    Error.AssertsHasField => @compileError(std.fmt.comptimePrint(
                        "{s}.{s}: {s}",
                        .{ prototype.name, @errorName(err), params.name },
                    )),
                }
            }
        }.onError,
    };
}

test "has field" {
    const Foo = struct {
        a: type,
        b: bool,
        x: usize,
        y: f128,
    };

    const Bar = union {
        a: type,
        b: bool,
        x: usize,
        y: f128,
    };

    try testing.expectEqual(true, try init(
        .{ .name = "a", .type = .is_type },
    ).eval(Foo));

    try testing.expectEqual(true, try init(
        .{ .name = "b", .type = .is_bool },
    ).eval(Foo));

    try testing.expectEqual(true, try init(
        .{ .name = "x", .type = .is_int(.{}) },
    ).eval(Foo));

    try testing.expectEqual(true, try init(
        .{ .name = "y", .type = .is_float(.{}) },
    ).eval(Foo));

    try testing.expectEqual(true, try init(
        .{ .name = "a", .type = .is_type },
    ).eval(Bar));

    try testing.expectEqual(true, try init(
        .{ .name = "b", .type = .is_bool },
    ).eval(Bar));

    try testing.expectEqual(true, try init(
        .{ .name = "x", .type = .is_int(.{}) },
    ).eval(Bar));

    try testing.expectEqual(true, try init(
        .{ .name = "y", .type = .is_float(.{}) },
    ).eval(Bar));
}
