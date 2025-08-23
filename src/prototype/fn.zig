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

                    _ = try @"type".eval(actual.type) catch |err|
                        return switch (err) {
                            OnType.Error.AssertsOnType,
                            => Param.Error.AssertsOnTypeParamType,
                            else => unreachable,
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
                _ = try has_type_info.eval(actual);

                _ = comptime calling_convention.eval(@typeInfo(actual).@"fn".calling_convention) catch |err|
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
                        OnType.Error.AssertsOnType,
                        => Error.AssertsOnTypeReturnType,
                        else => unreachable,
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
                }
            }
        }.onError,
    };
}

test "is fn" {
    try testing.expectEqual(true, init(.{}).eval(fn () void));
    try testing.expectEqual(true, init(.{}).eval(fn () callconv(.@"inline") void));
}
