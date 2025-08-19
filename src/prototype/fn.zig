//! Prototype *fn*.
//!
//! Asserts *actual* is a fn type value.
//!
//! See also: [`std.builtin.Type.Fn`](#std.builtin.Type.Fn)
const std = @import("std");
const testing = std.testing;

const Prototype = @import("Prototype.zig");
const interval = @import("aux/interval.zig");
const info = @import("aux/info.zig");
const filter = @import("aux/filter.zig");
const toggle = @import("aux/toggle.zig");
const exists = @import("aux/exists.zig");
const child = @import("aux/child.zig");

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
pub const info_validator = info.init(.{
    .@"fn" = true,
});

/// Assertion parameters for *fn param* prototype.
///
/// See also: [`std.builtin.Type.Fn`](#std.builtin.Type.Fn)
const Param = struct {
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
        is_generic: toggle.Params = null,
        /// Asserts fn parameter has or does not have alias.
        ///
        /// See also:
        /// - [`std.builtin.Type.Fn`](#std.builtin.Type.Fn)
        /// - [`ziggurat.prototype.aux.toggle`](#root.prototype.aux.toggle)
        is_noalias: toggle.Params = null,
        /// Asserts fn exists and applies prototype to a child or does not exist.
        ///
        /// See also:
        /// - [`std.builtin.Type.Fn`](#std.builtin.Type.Fn)
        /// - [`ziggurat.prototype.aux.exists`](#root.prototype.aux.exists)
        /// - [`ziggurat.prototype.aux.child`](#root.prototype.aux.child)
        type: ?info.Params = null,
    };

    pub fn init(params: @This().Params) Prototype {
        const is_generic_validator = toggle.init(params.is_generic);
        const is_noalias_validator = toggle.init(params.is_noalias);
        const type_validator = if (params.type) |_| info.init(params.type.?) else exists.init(false);
        return .{
            .name = "Fn.Param",
            .eval = struct {
                fn eval(actual: anytype) anyerror!bool {
                    _ = is_generic_validator.eval(actual.is_generic) catch |err|
                        return switch (err) {
                            toggle.Error.AssertsTrue,
                            => FnError.AssertsTrueParamIsGeneric,
                            toggle.Error.AssertsFalse,
                            => FnError.AssertsFalseParamIsGeneric,
                            else => @panic("unhandled error"),
                        };

                    _ = is_noalias_validator.eval(actual.is_noalias) catch |err|
                        return switch (err) {
                            toggle.Error.AssertsTrue,
                            => FnError.AssertsTrueParamIsNoAlias,
                            toggle.Error.AssertsFalse,
                            => FnError.AssertsFalseParamIsNoAlias,
                            else => @panic("unhandled error"),
                        };

                    _ = type_validator.eval(if (params.type) |_| actual.type.? else actual.type) catch |err|
                        return switch (err) {
                            info.Error.AssertsBlacklistTypeInfo,
                            => FnError.AssertsBlacklistParamTypeInfo,

                            info.Error.AssertsWhitelistTypeInfo,
                            => FnError.AssertsWhitelistParamTypeInfo,

                            exists.Error.AssertsNull,
                            => FnError.AssertsNullParamType,
                            else => @panic("unhandled error"),
                        };

                    return true;
                }
            }.eval,
            .onError = struct {
                fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                    switch (err) {
                        ParamError.AssertsTrueParamIsNoAlias,
                        ParamError.AssertsFalseParamIsNoAlias,
                        => is_noalias_validator.onError.?(err, prototype, actual.is_var_args),

                        ParamError.AssertsTrueParamIsGeneric,
                        ParamError.AssertsFalseParamIsGeneric,
                        => is_generic_validator.onError.?(err, prototype, actual.is_generic),

                        ParamError.AssertsBlacklistParamTypeInfo,
                        ParamError.AssertsWhitelistParamTypeInfo,
                        ParamError.AssertsNullParamType,
                        => type_validator.onError.?(err, prototype, actual.type),

                        else => @panic("unhandled error"),
                    }
                }
            }.onError,
        };
    }
};

const calling_convention = filter.Filter(std.builtin.CallingConvention);
/// Assertion parameters for *fn* prototype.
///
/// See also: [`std.builtin.Type.Fn`](#std.builtin.Type.Fn)
pub const Params = struct {
    /// Asserts fn calling convention.
    ///
    /// See also:
    /// - [`std.builtin.CallingConvention`](#std.builtin.CallingConvention)
    /// - [`ziggurat.prototype.aux.filter`](#root.prototype.aux.filter)
    calling_convention: calling_convention.Params = .{},
    /// Asserts fn is or is not var args.
    ///
    /// See also:
    /// - [`std.builtin.Type.Fn`](#std.builtin.Type.Fn)
    /// - [`ziggurat.prototype.aux.toggle`](#root.prototype.aux.toggle)
    is_var_args: toggle.Params = null,
    /// Asserts fn is or is not generic.
    ///
    /// See also:
    /// - [`std.builtin.Type.Fn`](#std.builtin.Type.Fn)
    /// - [`ziggurat.prototype.aux.toggle`](#root.prototype.aux.toggle)
    is_generic: toggle.Params = null,
    /// Asserts fn exists and applies prototype to a child or does not exist.
    ///
    /// See also:
    /// - [`std.builtin.Type.Fn`](#std.builtin.Type.Fn)
    /// - [`ziggurat.prototype.aux.exists`](#root.prototype.aux.exists)
    /// - [`ziggurat.prototype.aux.child`](#root.prototype.aux.child)
    return_type: info.Params = .{},

    /// Asserts fn parameters.
    params: []const Param.Params = &.{},
};

pub fn init(params: Params) Prototype {
    const calling_convention_validator = calling_convention.init(params.calling_convention);
    const is_var_args_validator = toggle.init(params.is_var_args);
    const is_generic_validator = toggle.init(params.is_generic);
    const return_type_validator = info.init(params.return_type);

    return .{
        .name = "Fn",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = comptime info_validator.eval(actual) catch |err|
                    return switch (err) {
                        info.Error.AssertsTypeValue,
                        => FnError.AssertsTypeValue,
                        info.Error.AssertsWhitelistTypeInfo,
                        => FnError.AssertsWhitelistTypeInfo,
                        else => @panic("unhandled error"),
                    };

                _ = calling_convention_validator.eval(@typeInfo(actual).@"fn".calling_convention) catch |err|
                    return switch (err) {
                        calling_convention.Error.AssertsWhitelist,
                        => FnError.AssertsWhitelistCallingConvention,
                        calling_convention.Error.AssertsBlacklist,
                        => FnError.AssertsBlacklistCallingConvention,
                        else => @panic("unhandled error"),
                    };

                _ = is_var_args_validator.eval(@typeInfo(actual).@"fn".is_var_args) catch |err|
                    return switch (err) {
                        toggle.Error.AssertsTrue,
                        => FnError.AssertsTrueIsVarArgs,
                        toggle.Error.AssertsFalse,
                        => FnError.AssertsFalseIsVarArgs,
                        else => @panic("unhandled error"),
                    };

                _ = is_generic_validator.eval(@typeInfo(actual).@"fn".is_generic) catch |err|
                    return switch (err) {
                        toggle.Error.AssertsTrue,
                        => FnError.AssertsTrueIsGeneric,
                        toggle.Error.AssertsFalse,
                        => FnError.AssertsFalseIsGeneric,
                        else => @panic("unhandled error"),
                    };

                _ = return_type_validator.eval(@typeInfo(actual).@"fn".return_type.?) catch |err|
                    return switch (err) {
                        info.Error.AssertsBlacklistTypeInfo,
                        => FnError.AssertsBlacklistReturnTypeInfo,
                        info.Error.AssertsWhitelistTypeInfo,
                        => FnError.AssertsWhitelistReturnTypeInfo,
                        else => @panic("unhandled error"),
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
                    FnError.AssertsWhitelistTypeInfo,
                    => info_validator.onError.?(
                        err,
                        prototype,
                        actual,
                    ),

                    FnError.AssertsWhitelistCallingConvention,
                    FnError.AssertsBlacklistCallingConvention,
                    => calling_convention_validator.onError.?(
                        err,
                        prototype,
                        actual,
                    ),

                    FnError.AssertsTrueIsVarArgs,
                    FnError.AssertsFalseIsVarArgs,
                    => is_var_args_validator.onError.?(
                        err,
                        prototype,
                        actual,
                    ),

                    FnError.AssertsTrueIsGeneric,
                    FnError.AssertsFalseIsGeneric,
                    => is_generic_validator.onError.?(
                        err,
                        prototype,
                        actual,
                    ),

                    FnError.AssertsBlacklistReturnTypeInfo,
                    FnError.AssertsWhitelistReturnTypeInfo,
                    => return_type_validator.onError.?(
                        err,
                        prototype,
                        actual,
                    ),

                    else => return_type_validator.onError.?(
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

test "fails fn return type whitelist assertion" {
    const @"fn": Prototype = init(.{
        .calling_convention = .{},
        .is_generic = null,
        .is_var_args = null,
        .params = &.{},
        .return_type = .{
            .int = true,
        },
    });

    try std.testing.expectEqual(
        FnError.AssertsWhitelistReturnTypeInfo,
        comptime @"fn".eval(fn () void),
    );
}

test "fails fn return type blacklist assertion" {
    const @"fn": Prototype = init(.{
        .calling_convention = .{},
        .is_generic = null,
        .is_var_args = null,
        .params = &.{},
        .return_type = .{
            .void = false,
        },
    });

    try std.testing.expectEqual(
        FnError.AssertsBlacklistReturnTypeInfo,
        comptime @"fn".eval(fn () void),
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
        .return_type = .{},
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
        .return_type = .{},
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
        .return_type = .{},
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
        .return_type = .{},
    });

    try std.testing.expectEqual(
        FnError.AssertsFalseParamIsNoAlias,
        comptime @"fn".eval(fn (noalias actual: anytype) void),
    );
}

test "fails fn param type is null assertion" {
    const @"fn": Prototype = init(.{
        .calling_convention = .{},
        .is_generic = null,
        .is_var_args = null,
        .params = &.{.{
            .type = null,
        }},
        .return_type = .{},
    });

    try std.testing.expectEqual(
        FnError.AssertsNullParamType,
        comptime @"fn".eval(fn (i128) void),
    );
}

test "fails fn param type blacklist assertion" {
    const @"fn": Prototype = init(.{
        .calling_convention = .{},
        .is_generic = null,
        .is_var_args = null,
        .params = &.{.{
            .type = .{ .void = false },
        }},
        .return_type = .{},
    });

    try std.testing.expectEqual(
        FnError.AssertsBlacklistParamTypeInfo,
        comptime @"fn".eval(fn (void) void),
    );
}
