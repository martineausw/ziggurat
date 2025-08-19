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
    AssertsWhitelistCallingConvention,
    AssertsBlacklistCallingConvention,
    AssertsTrueIsVarArgs,
    AssertsFalseIsVarArgs,
    AssertsTrueIsGeneric,
    AssertsFalseIsGeneric,
    AssertsReturnTypeNull,
};

pub const Error = FnError;

/// Type value assertion for *int* prototype evaluation argument.
///
/// See also: [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
pub const info_validator = info.init(.{
    .@"fn" = true,
});

const Param = struct {
    is_generic: toggle.Params,
    is_noalias: toggle.Params,
    type: info.Params,
};

const calling_convention = filter.Filter(std.builtin.CallingConvention);
/// Assertion parameters for *fn* prototype.
///
/// See also: [`std.builtin.Type.Fn`](#std.builtin.Type.Fn)
pub const Params = struct {
    calling_convention: calling_convention.Params = .{},
    is_var_args: toggle.Params = null,
    is_generic: toggle.Params = null,
    return_type: ?child.Params = null,
    params: []const Params = &.{},
};

pub fn init(params: Params) Prototype {
    const calling_convention_validator = calling_convention.init(params.calling_convention);
    const is_var_args_validator = toggle.init(params.is_var_args);
    const is_generic_validator = toggle.init(params.is_generic);
    const return_type_validator = if (params.return_type) |return_type| child.init(return_type) else exists.init(null);

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
                    };

                _ = is_var_args_validator.eval(@typeInfo(actual).@"fn".is_var_args) catch |err|
                    return switch (err) {
                        toggle.Error.AssertsTrue,
                        => FnError.AssertsTrueIsVarArgs,
                        toggle.Error.AssertsFalse,
                        => FnError.AssertsFalseIsVarArgs,
                    };

                _ = is_generic_validator.eval(@typeInfo(actual).@"fn".is_generic) catch |err|
                    return switch (err) {
                        toggle.Error.AssertsTrue,
                        => FnError.AssertsTrueIsGenericArgs,
                        toggle.Error.AssertsFalse,
                        => FnError.AssertsFalseIsGenericArgs,
                    };

                _ = return_type_validator.eval(@typeInfo(actual).@"fn".return_type) catch |err|
                    return switch (err) {
                        exists.Error.AssertsNull,
                        => FnError.AssertsReturnTypeNull,
                        else => err,
                    };
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
    _ = FnError.AssertsReturnTypeNull catch void;
}

test Params {}

test init {
    const @"fn": Prototype = init(.{
        .calling_convention = .{},
        .is_generic = null,
        .is_var_args = null,
        .params = &.{},
        .return_type = null,
    });

    _ = @"fn";
}

test "passes fn assertions" {}

test "fails type value assertion" {}

test "fails int bits interval assertions" {}

test "fails int signedness blacklist assertion" {}

test "fails int signedness whitelist assertion" {}
