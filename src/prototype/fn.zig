const std = @import("std");
const testing = std.testing;

const Self = @This();

const Prototype = @import("Prototype.zig");
const WithinInterval = @import("aux/WithinInterval.zig");
const HasTypeInfo = @import("aux/HasTypeInfo.zig");
const HasTag = @import("aux/HasTag.zig");
const EqualsBool = @import("aux/EqualsBool.zig");
const OnType = @import("aux/OnType.zig");

const FnError = error{
    AssertsInactiveCallingConvention,
    AssertsActiveCallingConvention,
    AssertsTrueIsVarArgs,
    AssertsFalseIsVarArgs,
    AssertsTrueIsGeneric,
    AssertsFalseIsGeneric,
    AssertsOnTypeReturnType,
} || Param.Error;

pub const Error = FnError || HasTypeInfo.Error;

const Param = struct {
    const Self = @This();

    const ParamError = error{
        AssertsTrueParamIsGeneric,
        AssertsFalseParamIsGeneric,
        AssertsTrueParamIsNoAlias,
        AssertsFalseParamIsNoAlias,
        AssertsOnTypeParamType,
    };

    pub const Error = ParamError;
    pub const Params = struct {
        is_generic: EqualsBool.Params = null,
        is_noalias: EqualsBool.Params = null,
        type: OnType.Params = null,
    };

    pub fn init(params: Param.Self.Params) Prototype {
        const is_generic = EqualsBool.init(params.is_generic);
        const is_noalias = EqualsBool.init(params.is_noalias);
        const @"type" = OnType.init(params.type);
        return .{
            .name = @typeName(Param.Self),
            .eval = struct {
                fn eval(actual: anytype) anyerror!bool {
                    _ = is_generic.eval(actual.is_generic) catch |err|
                        return switch (err) {
                            EqualsBool.Error.AssertsTrue,
                            => Param.Error.AssertsTrueParamIsGeneric,
                            EqualsBool.Error.AssertsFalse,
                            => Param.Error.AssertsFalseParamIsGeneric,
                            else => unreachable,
                        };

                    _ = is_noalias.eval(actual.is_noalias) catch |err|
                        return switch (err) {
                            EqualsBool.Error.AssertsTrue,
                            => Param.Error.AssertsTrueParamIsNoAlias,
                            EqualsBool.Error.AssertsFalse,
                            => Param.Error.AssertsFalseParamIsNoAlias,
                            else => unreachable,
                        };

                    if (@"type".eval(actual.type)) |result| {
                        if (!result) return false;
                    } else |err| return switch (err) {
                        else => Param.Error.AssertsOnTypeParamType,
                    };

                    return true;
                }
            }.eval,
            .onError = struct {
                fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                    switch (err) {
                        ParamError.AssertsTrueParamIsNoAlias,
                        ParamError.AssertsFalseParamIsNoAlias,
                        => is_noalias.onError.?(
                            try is_noalias.eval(actual.is_var_args),
                            prototype,
                            actual.is_var_args,
                        ),

                        ParamError.AssertsTrueParamIsGeneric,
                        ParamError.AssertsFalseParamIsGeneric,
                        => is_generic.onError.?(
                            try is_generic.eval(actual.is_generic),
                            prototype,
                            actual.is_generic,
                        ),

                        ParamError.AssertsOnTypeParamType,
                        => @"type".onError.?(
                            try @"type".eval(actual.type),
                            prototype,
                            actual.type,
                        ),
                    }
                }
            }.onError,
        };
    }
};

const FiltersCallingConvention = HasTag.Of(std.builtin.CallingConvention);
pub const Params = struct {
    calling_convention: FiltersCallingConvention.Params = .{},
    is_var_args: EqualsBool.Params = null,
    is_generic: EqualsBool.Params = null,
    return_type: OnType.Params = null,
    params: []const Param.Params = &.{},
};

pub fn init(params: Params) Prototype {
    const has_type_info = HasTypeInfo.init(.{
        .@"fn" = true,
    });
    const calling_convention = FiltersCallingConvention.init(params.calling_convention);
    const is_var_args = EqualsBool.init(params.is_var_args);
    const is_generic = EqualsBool.init(params.is_generic);
    const return_type = OnType.init(params.return_type);

    return .{
        .name = @typeName(Self),
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = try @call(.always_inline, has_type_info.eval, .{actual});

                _ = @call(.always_inline, calling_convention.eval, .{@typeInfo(actual).@"fn".calling_convention}) catch |err|
                    return switch (err) {
                        FiltersCallingConvention.Error.AssertsActive,
                        => Error.AssertsActiveCallingConvention,
                        FiltersCallingConvention.Error.AssertsInactive,
                        => Error.AssertsInactiveCallingConvention,
                        else => unreachable,
                    };

                _ = is_var_args.eval(@typeInfo(actual).@"fn".is_var_args) catch |err|
                    return switch (err) {
                        EqualsBool.Error.AssertsTrue,
                        => Error.AssertsTrueIsVarArgs,
                        EqualsBool.Error.AssertsFalse,
                        => Error.AssertsFalseIsVarArgs,
                        else => unreachable,
                    };

                _ = is_generic.eval(@typeInfo(actual).@"fn".is_generic) catch |err|
                    return switch (err) {
                        EqualsBool.Error.AssertsTrue,
                        => Error.AssertsTrueIsGeneric,
                        EqualsBool.Error.AssertsFalse,
                        => Error.AssertsFalseIsGeneric,
                        else => unreachable,
                    };

                _ = return_type.eval(@typeInfo(actual).@"fn".return_type.?) catch |err|
                    return switch (err) {
                        else => Error.AssertsOnTypeReturnType,
                    };

                inline for (params.params, 0..) |param, i| {
                    const param_validator = Param.init(param);
                    _ = try param_validator.eval(@typeInfo(actual).@"fn".params[i]);
                }

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                switch (err) {
                    FnError.AssertsTypeValue,
                    FnError.AssertsActiveTypeInfo,
                    => has_type_info.onError.?(
                        err,
                        prototype,
                        actual,
                    ),

                    FnError.AssertsActiveCallingConvention,
                    FnError.AssertsInactiveCallingConvention,
                    => calling_convention.onError.?(
                        try calling_convention.eval(@typeInfo(actual).@"fn".calling_convention),
                        prototype,
                        @typeInfo(actual).@"fn".calling_convention,
                    ),

                    FnError.AssertsTrueIsVarArgs,
                    FnError.AssertsFalseIsVarArgs,
                    => is_var_args.onError.?(
                        try is_var_args.eval(@typeInfo(actual).@"fn".is_var_args),
                        prototype,
                        @typeInfo(actual).@"fn".is_var_args,
                    ),

                    FnError.AssertsTrueIsGeneric,
                    FnError.AssertsFalseIsGeneric,
                    => is_generic.onError.?(
                        try is_generic.eval(@typeInfo(actual).@"fn".is_generic),
                        prototype,
                        @typeInfo(actual).@"fn".is_generic,
                    ),

                    FnError.AssertsOnTypeReturnType,
                    => return_type.onError.?(
                        try return_type.eval(@typeInfo(actual).@"fn".return_type),
                        prototype,
                        @typeInfo(actual).@"fn".return_type,
                    ),

                    Error.AssertsTrueParamIsGeneric,
                    Error.AssertsFalseParamIsGeneric,
                    Error.AssertsTrueParamIsNoAlias,
                    Error.AssertsFalseParamIsNoAlias,
                    Error.AssertsOnTypeParamType,
                    => {
                        const target_param = inline for (params.params, 0..) |param, i| blk: {
                            const has_param = Param.init(param);
                            has_param.eval(@typeInfo(actual).@"fn".params[i]) catch
                                break :blk .{ has_param, i };
                        };

                        target_param[0].onError.?(
                            try target_param[0].eval(@typeInfo(actual).@"fn".params[target_param[1]]),
                            prototype,
                            @typeInfo(actual).@"fn".params[target_param[1]],
                        );
                    },
                    else => unreachable,
                }
            }
        }.onError,
    };
}

test "is fn" {
    try testing.expectEqual(true, init(.{}).eval(fn () void));
    try testing.expectEqual(true, init(.{}).eval(fn () callconv(.@"inline") void));
}

test "fails is fn" {
    try testing.expectEqual(
        Error.AssertsActiveCallingConvention,
        init(.{ .calling_convention = .{ .@"inline" = true } }).eval(fn () void),
    );
    try testing.expectEqual(
        Error.AssertsInactiveCallingConvention,
        init(.{ .calling_convention = .{ .@"inline" = false } }).eval(fn () callconv(.@"inline") void),
    );
    try testing.expectEqual(
        Error.AssertsTrueIsGeneric,
        init(.{ .is_generic = true }).eval(fn () void),
    );
    try testing.expectEqual(
        Error.AssertsFalseIsGeneric,
        init(.{ .is_generic = false }).eval(fn (comptime T: type) void),
    );
    try testing.expectEqual(
        Error.AssertsTrueIsVarArgs,
        init(.{ .is_var_args = true }).eval(fn () void),
    );

    try testing.expectEqual(
        Error.AssertsFalseIsVarArgs,
        init(.{ .is_var_args = false }).eval(@Type(.{ .@"fn" = .{
            .calling_convention = .{ .aarch64_aapcs_win = .{} },
            .is_generic = false,
            .is_var_args = true,
            .params = &.{},
            .return_type = void,
        } })),
    );
    try testing.expectEqual(
        Error.AssertsOnTypeReturnType,
        init(.{ .return_type = .@"error" }).eval(fn () void),
    );
    try testing.expectEqual(
        Error.AssertsTrueParamIsGeneric,
        init(.{ .params = &.{.{ .is_generic = true }} }).eval(fn (bool) void),
    );
    try testing.expectEqual(
        Error.AssertsFalseParamIsGeneric,
        init(.{ .params = &.{.{ .is_generic = false }} }).eval(fn (anytype) void),
    );
    try testing.expectEqual(
        Error.AssertsTrueParamIsNoAlias,
        init(.{ .params = &.{.{ .is_noalias = true }} }).eval(fn ([]const u8) void),
    );
    try testing.expectEqual(
        Error.AssertsFalseParamIsNoAlias,
        init(.{ .params = &.{.{ .is_noalias = false }} }).eval(fn (noalias []const u8) void),
    );
    try testing.expectEqual(
        Error.AssertsOnTypeParamType,
        init(.{ .params = &.{.{ .type = .@"error" }} }).eval(fn (bool) void),
    );
}
