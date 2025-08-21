//! Prototype *fn*.
//!
//! Asserts *actual* is a fn type value.
//!
//! See also: [`std.builtin.Type.Fn`](#std.builtin.Type.Fn)
const std = @import("std");
const testing = std.testing;

const Prototype = @import("Prototype.zig");
const WithinInterval = @import("aux/WithinInterval.zig");
const FiltersTypeInfo = @import("aux/FiltersTypeInfo.zig");
const FiltersActiveTag = @import("aux/FiltersActiveTag.zig");
const EqualsBool = @import("aux/EqualsBool.zig");
const OnType = @import("aux/OnType.zig");

const Self = @This();

/// Error set for *int* prototype.
const FnError = error{
    /// *actual* is not a type value.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.type`](#root.prototype.type)
    AssertsTypeValue,
    /// *actual* type value requires int type info.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsWhitelistTypeInfo,
    /// *actual* fn calling convention has active tag that does not belong to blacklist.
    ///
    /// See also: [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsBlacklistCallingConvention,
    /// *actual* fn calling convention has active tag that belongs to whitelist.
    ///
    /// See also: [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsWhitelistCallingConvention,
    /// *actual* fn is not var args.
    ///
    /// See also: [`ziggurat.prototype.aux.toggle`](#root.prototype.aux.toggle)
    AssertsTrueIsVarArgs,
    /// *actual* fn is var args.
    ///
    /// See also: [`ziggurat.prototype.aux.toggle`](#root.prototype.aux.toggle)
    AssertsFalseIsVarArgs,
    /// *actual* fn is not generic.
    ///
    /// See also: [`ziggurat.prototype.aux.toggle`](#root.prototype.aux.toggle)
    AssertsTrueIsGeneric,
    /// *actual* fn is generic.
    ///
    /// See also: [`ziggurat.prototype.aux.toggle`](#root.prototype.aux.toggle)
    AssertsFalseIsGeneric,
    /// *actual* fn return type has active tag that does not belong to blacklist.
    ///
    /// See also: [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsBlacklistReturnTypeInfo,
    /// *actual* fn return type has active tag that belongs to whitelist.
    ///
    /// See also: [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    AssertsWhitelistReturnTypeInfo,
} || Param.Error;

pub const Error = FnError;

/// Type value assertion for *int* prototype evaluation argument.
///
/// See also: [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
pub const has_type_info = FiltersTypeInfo.init(.{
    .@"fn" = true,
});

/// Assertion parameters for *fn param* prototype.
///
/// See also: [`std.builtin.Type.Fn`](#std.builtin.Type.Fn)
const Param = struct {
    const Self = @This();

    const ParamError = error{
        /// *actual* fn param is not generic.
        ///
        /// See also: [`ziggurat.prototype.aux.toggle`](#root.prototype.aux.toggle)
        AssertsTrueParamIsGeneric,
        /// *actual* fn param is generic.
        ///
        /// See also: [`ziggurat.prototype.aux.toggle`](#root.prototype.aux.toggle)
        AssertsFalseParamIsGeneric,
        /// *actual* fn param is var args.
        ///
        /// See also: [`ziggurat.prototype.aux.toggle`](#root.prototype.aux.toggle)
        AssertsTrueParamIsNoAlias,
        /// *actual* fn param is not var args.
        ///
        /// See also: [`ziggurat.prototype.aux.toggle`](#root.prototype.aux.toggle)
        AssertsFalseParamIsNoAlias,
        /// *actual* fn param type is not null.
        ///
        /// See also: [`ziggurat.prototype.aux.exists`](#root.prototype.aux.exists)
        AssertsNullParamType,
        /// *actual* fn param type has active tag that does not belong to blacklist.
        ///
        /// See also: [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
        AssertsBlacklistParamTypeInfo,
        /// *actual* fn param type has active tag that belongs to whitelist.
        ///
        /// See also: [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
        AssertsWhitelistParamTypeInfo,
    };

    pub const Error = ParamError;

    pub const Params = struct {
        /// Asserts fn parameter is or is not generic.
        ///
        /// See also:
        /// - [`std.builtin.Type.Fn`](#std.builtin.Type.Fn)
        /// - [`ziggurat.prototype.aux.toggle`](#root.prototype.aux.toggle)
        is_generic: EqualsBool.Params = null,
        /// Asserts fn parameter has or does not have alias.
        ///
        /// See also:
        /// - [`std.builtin.Type.Fn`](#std.builtin.Type.Fn)
        /// - [`ziggurat.prototype.aux.toggle`](#root.prototype.aux.toggle)
        is_noalias: EqualsBool.Params = null,
        /// Asserts fn exists and applies prototype to a child or does not exist.
        ///
        /// See also:
        /// - [`std.builtin.Type.Fn`](#std.builtin.Type.Fn)
        /// - [`ziggurat.prototype.aux.exists`](#root.prototype.aux.exists)
        /// - [`ziggurat.prototype.aux.child`](#root.prototype.aux.child)
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
                            => FnError.AssertsTrueParamIsGeneric,
                            EqualsBool.Error.AssertsFalse,
                            => FnError.AssertsFalseParamIsGeneric,
                            else => @panic("unhandled error"),
                        };

                    _ = is_noalias.eval(actual.is_noalias) catch |err|
                        return switch (err) {
                            EqualsBool.Error.AssertsTrue,
                            => FnError.AssertsTrueParamIsNoAlias,
                            EqualsBool.Error.AssertsFalse,
                            => FnError.AssertsFalseParamIsNoAlias,
                            else => @panic("unhandled error"),
                        };

                    _ = if (actual.type) |t| try @"type".eval(t); 

                    return true;
                }
            }.eval,
            .onError = struct {
                fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                    switch (err) {
                        ParamError.AssertsTrueParamIsNoAlias,
                        ParamError.AssertsFalseParamIsNoAlias,
                        => is_noalias.onError.?(err, prototype, actual.is_var_args),

                        ParamError.AssertsTrueParamIsGeneric,
                        ParamError.AssertsFalseParamIsGeneric,
                        => is_generic.onError.?(err, prototype, actual.is_generic),

                        else => @"type".onError.?(err, prototype, actual.type),
                    }
                }
            }.onError,
        };
    }
};

const FiltersCallingConvention = FiltersActiveTag.Of(std.builtin.CallingConvention);
/// Assertion parameters for *fn* prototype.
///
/// See also: [`std.builtin.Type.Fn`](#std.builtin.Type.Fn)
pub const Params = struct {
    /// Asserts fn calling convention.
    ///
    /// See also:
    /// - [`std.builtin.CallingConvention`](#std.builtin.CallingConvention)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    calling_convention: FiltersCallingConvention.Params = .{},
    /// Asserts fn is or is not var args.
    ///
    /// See also:
    /// - [`std.builtin.Type.Fn`](#std.builtin.Type.Fn)
    /// - [`ziggurat.prototype.aux.toggle`](#root.prototype.aux.toggle)
    is_var_args: EqualsBool.Params = null,
    /// Asserts fn is or is not generic.
    ///
    /// See also:
    /// - [`std.builtin.Type.Fn`](#std.builtin.Type.Fn)
    /// - [`ziggurat.prototype.aux.toggle`](#root.prototype.aux.toggle)
    is_generic: EqualsBool.Params = null,
    /// Asserts fn exists and applies prototype to a child or does not exist.
    ///
    /// See also:
    /// - [`std.builtin.Type.Fn`](#std.builtin.Type.Fn)
    /// - [`ziggurat.prototype.aux.exists`](#root.prototype.aux.exists)
    /// - [`ziggurat.prototype.aux.child`](#root.prototype.aux.child)
    return_type: OnType.Params = null,

    /// Asserts fn parameters.
    params: []const Param.Params = &.{},
};

pub fn init(params: Params) Prototype {
    const calling_convention = FiltersCallingConvention.init(params.calling_convention);
    const is_var_args = EqualsBool.init(params.is_var_args);
    const is_generic = EqualsBool.init(params.is_generic);
    const return_type = OnType.init(params.return_type);

    return .{
        .name = @typeName(Self),
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = comptime has_type_info.eval(actual) catch |err|
                    return switch (err) {
                        FiltersTypeInfo.Error.AssertsTypeValue,
                        => FnError.AssertsTypeValue,
                        FiltersTypeInfo.Error.AssertsWhitelistTypeInfo,
                        => FnError.AssertsWhitelistTypeInfo,
                        else => @panic("unhandled error"),
                    };

                _ = calling_convention.eval(@typeInfo(actual).@"fn".calling_convention) catch |err|
                    return switch (err) {
                        FiltersCallingConvention.Error.AssertsWhitelist,
                        => FnError.AssertsWhitelistCallingConvention,
                        FiltersCallingConvention.Error.AssertsBlacklist,
                        => FnError.AssertsBlacklistCallingConvention,
                        else => @panic("unhandled error"),
                    };

                _ = is_var_args.eval(@typeInfo(actual).@"fn".is_var_args) catch |err|
                    return switch (err) {
                        EqualsBool.Error.AssertsTrue,
                        => FnError.AssertsTrueIsVarArgs,
                        EqualsBool.Error.AssertsFalse,
                        => FnError.AssertsFalseIsVarArgs,
                        else => @panic("unhandled error"),
                    };

                _ = is_generic.eval(@typeInfo(actual).@"fn".is_generic) catch |err|
                    return switch (err) {
                        EqualsBool.Error.AssertsTrue,
                        => FnError.AssertsTrueIsGeneric,
                        EqualsBool.Error.AssertsFalse,
                        => FnError.AssertsFalseIsGeneric,
                        else => @panic("unhandled error"),
                    };

                _ = try return_type.eval(@typeInfo(actual).@"fn".return_type.?);

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
                    FnError.AssertsWhitelistTypeInfo,
                    => has_type_info.onError.?(
                        err,
                        prototype,
                        actual,
                    ),

                    FnError.AssertsWhitelistCallingConvention,
                    FnError.AssertsBlacklistCallingConvention,
                    => calling_convention.onError.?(
                        err,
                        prototype,
                        actual,
                    ),

                    FnError.AssertsTrueIsVarArgs,
                    FnError.AssertsFalseIsVarArgs,
                    => is_var_args.onError.?(
                        err,
                        prototype,
                        actual,
                    ),

                    FnError.AssertsTrueIsGeneric,
                    FnError.AssertsFalseIsGeneric,
                    => is_generic.onError.?(
                        err,
                        prototype,
                        actual,
                    ),

                    FnError.AssertsBlacklistReturnTypeInfo,
                    FnError.AssertsWhitelistReturnTypeInfo,
                    => return_type.onError.?(
                        err,
                        prototype,
                        actual,
                    ),

                    else => return_type.onError.?(
                        err,
                        prototype,
                        actual,
                    ),
                }
            }
        }.onError,
    };
}

test FnError {
    _ = FnError.AssertsWhitelistTypeInfo catch void;
    _ = FnError.AssertsWhitelistCallingConvention catch void;
    _ = FnError.AssertsBlacklistCallingConvention catch void;
    _ = FnError.AssertsTrueIsVarArgs catch void;
    _ = FnError.AssertsFalseIsVarArgs catch void;
    _ = FnError.AssertsTrueIsGeneric catch void;
    _ = FnError.AssertsFalseIsGeneric catch void;
    _ = FnError.AssertsBlacklistReturnTypeInfo catch void;
    _ = FnError.AssertsWhitelistReturnTypeInfo catch void;
}

test Params {}

test init {
    const @"fn": Prototype = init(.{
        .calling_convention = .{},
        .is_generic = null,
        .is_var_args = null,
        .params = &.{},
    });

    _ = @"fn";
}

test "passes fn assertions" {
    const @"fn": Prototype = init(.{
        .calling_convention = .{},
        .is_generic = null,
        .is_var_args = null,
        .params = &.{},
    });

    try std.testing.expectEqual(
        true,
        comptime @"fn".eval(fn () void),
    );
}

test "fails type value assertion" {
    const @"fn": Prototype = init(.{
        .calling_convention = .{},
        .is_generic = null,
        .is_var_args = null,
        .params = &.{},
    });

    try std.testing.expectEqual(
        FnError.AssertsTypeValue,
        comptime @"fn".eval(0),
    );
}

test "fails type info assertion" {
    const @"fn": Prototype = init(.{
        .calling_convention = .{},
        .is_generic = null,
        .is_var_args = null,
        .params = &.{},
    });

    try std.testing.expectEqual(
        FnError.AssertsWhitelistTypeInfo,
        comptime @"fn".eval(*const fn () void),
    );
}

test "fails fn calling convention whitelist assertion" {
    const @"fn": Prototype = init(.{
        .calling_convention = .{
            .@"inline" = true,
        },
        .is_generic = null,
        .is_var_args = null,
        .params = &.{},
    });

    try std.testing.expectEqual(
        FnError.AssertsWhitelistCallingConvention,
        comptime @"fn".eval(fn () void),
    );
}

test "fails fn calling convention blacklist assertion" {
    const @"fn": Prototype = init(.{
        .calling_convention = .{
            .@"inline" = false,
        },
        .is_generic = null,
        .is_var_args = null,
        .params = &.{},
    });

    try std.testing.expectEqual(
        FnError.AssertsBlacklistCallingConvention,
        comptime @"fn".eval(fn () callconv(.@"inline") void),
    );
}

test "fails fn is var args is true assertion" {
    const @"fn": Prototype = init(.{
        .calling_convention = .{},
        .is_generic = null,
        .is_var_args = true,
        .params = &.{},
    });

    try std.testing.expectEqual(
        FnError.AssertsTrueIsVarArgs,
        comptime @"fn".eval(fn () void),
    );
}

test "fails fn is var args is false assertion" {
    const @"fn": Prototype = init(.{
        .calling_convention = .{},
        .is_generic = null,
        .is_var_args = false,
        .params = &.{},
    });

    try std.testing.expectEqual(
        FnError.AssertsFalseIsVarArgs,
        comptime @"fn".eval(@Type(.{ .@"fn" = .{
            .calling_convention = .{ .aarch64_aapcs = .{} },
            .is_generic = false,
            .is_var_args = true,
            .params = &.{},
            .return_type = void,
        } })),
    );
}

test "fails fn is generic is true assertion" {
    const @"fn": Prototype = init(.{
        .calling_convention = .{},
        .is_generic = true,
        .is_var_args = null,
        .params = &.{},
    });

    try std.testing.expectEqual(
        FnError.AssertsTrueIsGeneric,
        comptime @"fn".eval(fn () void),
    );
}

test "fails fn is generic is false assertion" {
    const @"fn": Prototype = init(.{
        .calling_convention = .{},
        .is_generic = false,
        .is_var_args = null,
        .params = &.{},
    });

    try std.testing.expectEqual(
        FnError.AssertsFalseIsGeneric,
        comptime @"fn".eval(fn (comptime T: type) void),
    );
}

test "fails fn param is generic is true assertion" {
    const @"fn": Prototype = init(.{
        .calling_convention = .{},
        .is_generic = null,
        .is_var_args = null,
        .params = &.{.{
            .is_generic = true,
        }},
        .return_type = .true,
    });

    try std.testing.expectEqual(
        FnError.AssertsTrueParamIsGeneric,
        comptime @"fn".eval(fn (void) void),
    );
}

test "fails fn param is generic is false assertion" {
    const @"fn": Prototype = init(.{
        .calling_convention = .{},
        .is_generic = null,
        .is_var_args = null,
        .params = &.{.{
            .is_generic = false,
        }},
        .return_type = .true,
    });

    try std.testing.expectEqual(
        FnError.AssertsFalseParamIsGeneric,
        comptime @"fn".eval(fn (anytype) void),
    );
}

test "fails fn param is no alias is true assertion" {
    const @"fn": Prototype = init(.{
        .calling_convention = .{},
        .is_generic = null,
        .is_var_args = null,
        .params = &.{.{
            .is_noalias = true,
        }},
        .return_type = .true,
    });

    try std.testing.expectEqual(
        FnError.AssertsTrueParamIsNoAlias,
        comptime @"fn".eval(fn (anytype) void),
    );
}

test "fails fn param is no alias false assertion" {
    const @"fn": Prototype = init(.{
        .calling_convention = .{},
        .is_generic = null,
        .is_var_args = null,
        .params = &.{.{
            .is_noalias = false,
        }},
        .return_type = .true,
    });

    try std.testing.expectEqual(
        FnError.AssertsFalseParamIsNoAlias,
        comptime @"fn".eval(fn (noalias actual: anytype) void),
    );
}
