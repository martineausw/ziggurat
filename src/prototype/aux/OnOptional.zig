//! Auxiliary prototype *exists*.
//!
//! Asserts an *actual* optional value to either be null or not null.
const std = @import("std");

const Prototype = @import("../Prototype.zig");
const FiltersTypeInfo = @import("FiltersTypeInfo.zig");

/// Error set for *exists* prototype.
const OnOptionalError = error{
    /// *actual* is not a type value.
    ///
    /// See also:
    /// - [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    /// - [`ziggurat.prototype.type`](#root.prototype.type)
    AssertsTypeValue,
    /// *actual* requires `optional` type info.
    ///
    /// See also: [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
    AssertsWhitelistTypeInfo,
    /// *actual* is null.
    AssertsNotNull,
};

pub const Error = OnOptionalError;

/// Type info assertions for *exists* prototype evaluation argument.
///
/// See also: [`ziggurat.prototype.aux.info`](#root.prototype.aux.info)
pub const has_type_info = FiltersTypeInfo.init(.{
    .optional = true,
});

pub const Params = ?Prototype;

pub fn init(params: Params) Prototype {
    return .{
        .name = @typeName(@This()),
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = has_type_info.eval(@TypeOf(actual)) catch |err|
                    return switch (err) {
                        FiltersTypeInfo.Error.AssertsTypeValue,
                        => OnOptionalError.AssertsTypeValue,
                        FiltersTypeInfo.Error.AssertsWhitelistTypeInfo,
                        => OnOptionalError.AssertsWhitelistTypeInfo,
                        else => @panic("unhandled error"),
                    };

                if (params) |param| {
                    if (actual) |value| {
                        return param.eval(value);
                    } else {
                        return OnOptionalError.AssertsNotNull;
                    }
                }
                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                switch (err) {
                    OnOptionalError.AssertsTypeValue,
                    => has_type_info.onError.?(err, prototype, actual),

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

test OnOptionalError {}

test Params {
    const params: Params = null;

    _ = params;
}

test init {
    const exists: Prototype = init(null);

    _ = exists;
}

test "passes exists assertions" {
    const asserts_not_null = init(.true);

    try std.testing.expectEqual(
        true,
        init(null).eval(@as(?u8, null)),
    );

    try std.testing.expectEqual(
        true,
        asserts_not_null.eval(@as(?u8, 'a')),
    );
}

test "fails not null optional assertion" {
    const asserts_not_null = init(.true);

    try std.testing.expectEqual(
        OnOptionalError.AssertsNotNull,
        asserts_not_null.eval(@as(?u8, null)),
    );
}
