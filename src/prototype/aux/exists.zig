//! Evaluates an *optional* value against either *null* or *not null*.
const std = @import("std");

const Prototype = @import("../Prototype.zig");
const info = @import("info.zig");

/// Error set for *exists* prototype.
const ExistsError = error{
    /// *actual* is not type value.
    /// 
    /// See also: 
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.type`](#root.prototype.type)
    ExpectsTypeValue,
    /// *actual* requires `optional` type info.
    ///
    /// See also: [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    RequiresTypeInfo,
    /// *actual* is null.
    AssertsNotNull,
    /// *actual* is not null.
    AssertsNull,
};

pub const Error = ExistsError;

/// Type info assertions for *exists* prototype evaluation argument.
/// 
/// See also: [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
pub const info_validator = info.init(.{
    .optional = true,
});

pub const Params = ?bool;

pub fn init(params: Params) Prototype {
    return .{
        .name = "Toggle",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = info_validator.eval(@TypeOf(actual)) catch |err|
                    return switch (err) {
                        info.Error.ExpectsTypeValue,
                        => ExistsError.ExpectsTypeValue,
                        info.Error.RequiresTypeInfo,
                        => ExistsError.RequiresTypeInfo,
                        else => unreachable,
                    };

                if (params) |param| {
                    if (param) {
                        if (actual) |_| {} else {
                            return ExistsError.AssertsNotNull;
                        }
                    } else {
                        if (actual) |_| {
                            return ExistsError.AssertsNull;
                        }
                    }
                }

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                switch (err) {
                    ExistsError.ExpectsTypeValue,
                    => info_validator.onError.?(err, prototype, actual),

                    else => @compileError(
                        std.fmt.comptimePrint("{s}.{s}: {any}", .{
                            prototype.name,
                            @errorName(err),
                            actual,
                        }),
                    ),
                }
            }
        }.onError,
    };
}

test ExistsError {}

test Params {
    const params: Params = null;

    _ = params;
}

test init {
    const exists: Prototype = init(null);

    _ = exists;
}

test "passes exists assertions" {
    const no_assertion = init(null);
    const asserts_not_null = init(true);
    const asserts_null = init(false);

    try std.testing.expectEqual(
        true,
        no_assertion.eval(@as(?u8, 'a')),
    );

    try std.testing.expectEqual(
        true,
        no_assertion.eval(@as(?u8, null)),
    );

    try std.testing.expectEqual(
        true,
        asserts_not_null.eval(@as(?u8, 'a')),
    );

    try std.testing.expectEqual(
        true,
        asserts_null.eval(@as(?u8, null)),
    );
}

test "fails not null optional assertion" {
    const asserts_not_null = init(true);

    try std.testing.expectEqual(
        ExistsError.AssertsNotNull,
        asserts_not_null.eval(@as(?u8, null)),
    );
}

test "fails null optional assertion" {
    const asserts_null = init(false);

    try std.testing.expectEqual(
        ExistsError.AssertsNull,
        asserts_null.eval(@as(?u8, 'a')),
    );
}
