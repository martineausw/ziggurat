const std = @import("std");
const testing = std.testing;

const Self = @This();

const Prototype = @import("Prototype.zig");
const HasTypeInfo = @import("aux/HasTypeInfo.zig");
const HasLayout = @import("aux/HasTag.zig").Of(std.builtin.Type.ContainerLayout);
const HasFields = @import("aux/HasFields.zig");
const HasDecls = @import("aux/HasDecls.zig");
const EqualsBool = @import("aux/EqualsBool.zig");

const StructError = error{
    AssertsInactiveLayout,
    AssertsActiveLayout,
    AssertsTrueIsTuple,
    AssertsFalseIsTuple,
};

pub const Error = StructError || HasTypeInfo.Error || HasFields.Error || HasDecls.Error;
pub const Params = struct {
    layout: HasLayout.Params = .{},
    fields: HasFields.Params = &.{},
    decls: HasDecls.Params = &.{},
    is_tuple: ?bool = null,
};

pub fn init(params: Params) Prototype {
    const has_type_info = HasTypeInfo.init(.{
        .@"struct" = true,
    });
    const layout = HasLayout.init(params.layout);
    const has_fields = HasFields.init(params.fields);
    const has_decls = HasDecls.init(params.decls);
    const is_tuple = EqualsBool.init(params.is_tuple);
    return .{
        .name = @typeName(Self),
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = try @call(.always_inline, has_type_info.eval, .{actual});

                _ = @call(
                    .always_inline,
                    layout.eval,
                    .{@typeInfo(actual).@"struct".layout},
                ) catch |err|
                    return switch (err) {
                        HasLayout.Error.AssertsInactive,
                        => StructError.AssertsInactiveLayout,
                        HasLayout.Error.AssertsActive,
                        => StructError.AssertsActiveLayout,
                        else => unreachable,
                    };

                _ = try has_fields.eval(actual);
                _ = try has_decls.eval(actual);

                _ = is_tuple.eval(@typeInfo(actual).@"struct".is_tuple) catch |err|
                    return switch (err) {
                        EqualsBool.Error.AssertsTrue,
                        => Error.AssertsTrueIsTuple,
                        EqualsBool.Error.AssertsFalse,
                        => Error.AssertsFalseIsTuple,
                        else => unreachable,
                    };

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

                    Error.AssertsInactiveLayout,
                    Error.AssertsActiveLayout,
                    => layout.onError.?(
                        try layout.eval(@typeInfo(actual).@"struct".layout),
                        prototype,
                        @typeInfo(actual).@"struct".layout,
                    ),

                    Error.AssertsHasField,
                    Error.AssertsOnTypeField,
                    => has_fields.onError.?(
                        try has_fields.eval(actual),
                        prototype,
                        actual,
                    ),

                    Error.AssertsHasDecl,
                    => has_decls.onError.?(
                        try has_decls.eval(actual),
                        prototype,
                        actual,
                    ),

                    Error.AssertsTrueIsTuple,
                    Error.AssertsFalseIsTuple,
                    => is_tuple.onError.?(
                        try is_tuple.eval(@typeInfo(actual).@"struct".is_tuple),
                        prototype,
                        @typeInfo(actual).@"struct".is_tuple,
                    ),
                    else => unreachable,
                }
            }
        }.onError,
    };
}

test "is struct" {
    try testing.expectEqual(true, init(.{}).eval(struct {}));
    try testing.expectEqual(true, init(.{}).eval(extern struct {}));
    try testing.expectEqual(true, init(.{}).eval(packed struct {}));
}

test "fails is struct" {
    try testing.expectEqual(
        Error.AssertsActiveLayout,
        init(.{ .layout = .{ .@"packed" = true } }).eval(struct {}),
    );
    try testing.expectEqual(
        Error.AssertsInactiveLayout,
        init(.{ .layout = .{ .@"extern" = false } }).eval(extern struct {}),
    );
    try testing.expectEqual(
        Error.AssertsHasField,
        init(.{ .fields = &.{
            .{ .name = "a" },
        } }).eval(struct {}),
    );
    try testing.expectEqual(
        Error.AssertsHasDecl,
        init(.{ .decls = &.{
            .{ .name = "a" },
        } }).eval(struct {}),
    );
    try testing.expectEqual(
        Error.AssertsOnTypeField,
        init(.{ .fields = &.{
            .{ .name = "a", .type = .is_bool },
        } }).eval(
            struct { a: i128 },
        ),
    );
    try testing.expectEqual(
        Error.AssertsTrueIsTuple,
        init(.{ .is_tuple = true }).eval(struct {}),
    );
    try testing.expectEqual(
        Error.AssertsFalseIsTuple,
        init(.{ .is_tuple = false }).eval(struct { bool, bool }),
    );
}
