//! Auxillary prototype for field member of given type.
const std = @import("std");

const Prototype = @import("../Prototype.zig");
const info = @import("info.zig");

/// Error set for field.
const FieldError = error{
    InvalidArgument,
    RequiresType,
    /// Violates `std.builtin.Type.StructField.name` or
    /// `std.builtin.Type.UnionField.name` assertion.
    AssertsFieldName,
    /// Violates `std.builtin.Type.StructField.type` or
    /// `std.builtin.Type.UnionField.type` assertion.
    BanishesFieldType,
    RequiresFieldType,
};

/// Errors returned by `eval`
pub const Error = FieldError;

/// Validates type info of `actual` to continue.
pub const info_validator = info.init(.{
    .@"struct" = true,
    .@"union" = true,
});

/// Parameters used for prototype evaluation.
///
/// Derived from `std.builtin.Type.StructField` and
/// `std.builtin.Type.UnionField`.
pub const Params = struct {
    /// Evaluates against `std.builtin.Type.StructField.name` or
    /// `std.builtin.Type.UnionField.name`.
    name: [:0]const u8,
    /// Evaluates against `std.builtin.Type.StructField.type` or
    /// `std.builtin.Type.UnionField.type`.
    type: info.Params,
};

pub fn init(params: Params) Prototype {
    return .{
        .name = "Field",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                _ = info_validator.eval(actual) catch |err|
                    return switch (err) {
                        info.Error.InvalidArgument,
                        => FieldError.InvalidArgument,
                        info.Error.RequiresType,
                        => FieldError.RequiresType,
                        else => unreachable,
                    };

                if (!@hasField(actual, params.name)) {
                    return FieldError.AssertsFieldName;
                }

                _ = info.init(params.type).eval(@FieldType(
                    actual,
                    params.name,
                )) catch |err|
                    return switch (err) {
                        info.Error.BanishesType => FieldError.BanishesFieldType,
                        info.Error.RequiresType => FieldError.RequiresFieldType,
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
                    FieldError.InvalidArgument,
                    => info_validator.onError.?(err, prototype, actual),

                    FieldError.AssertsFieldName,
                    => @compileError(std.fmt.comptimePrint(
                        "{s}.{s}: {s}",
                        .{
                            prototype.name,
                            @errorName(err),
                            params.name,
                        },
                    )),

                    FieldError.BanishesFieldType,
                    FieldError.RequiresFieldType,
                    => @compileError(std.fmt.comptimePrint(
                        "{s}.{s}: {s}",
                        .{
                            prototype.name,
                            @errorName(err),
                            @FieldType(actual, params.name),
                        },
                    )),

                    else => unreachable,
                }
            }
        }.onError,
    };
}

test FieldError {
    _ = FieldError.InvalidArgument catch void;
    _ = FieldError.AssertsFieldName catch void;
    _ = FieldError.BanishesFieldType catch void;
}

test Params {
    const T = struct {
        field: f128,
    };

    _ = T;

    const params: Params = .{
        .name = "field",
        .type = .{
            .float = true,
        },
    };

    _ = params;
}

test init {
    const T = struct {
        field: f128,
    };

    _ = T;

    const field: Prototype = init(.{
        .name = "field",
        .type = .{
            .float = true,
        },
    });

    _ = field;
}

test "evaluates struct with given field successfully" {
    const T = struct {
        field: bool,
    };

    const params: Params = .{
        .name = "field",
        .type = .{
            .bool = true,
        },
    };

    const has_field: Prototype = init(params);

    try std.testing.expectEqual(
        true,
        has_field.eval(T),
    );
}

test "evaluates union with given field successfully" {
    const T = union {
        field: bool,
    };

    const params: Params = .{
        .name = "field",
        .type = .{
            .bool = true,
        },
    };

    const has_field: Prototype = init(params);

    try std.testing.expectEqual(
        true,
        has_field.eval(T),
    );
}

test "coerces FieldError.AssertsFieldName" {
    const T = struct {};

    const params: Params = .{
        .name = "field",
        .type = .{
            .bool = true,
        },
    };

    const has_field: Prototype = init(params);

    try std.testing.expectEqual(
        FieldError.AssertsFieldName,
        has_field.eval(T),
    );
}

test "coerces FieldError.RequiresFieldType" {
    const T = struct {
        field: ?bool,
    };

    const params: Params = .{
        .name = "field",
        .type = .{
            .bool = true,
        },
    };

    const has_field: Prototype = init(params);

    try std.testing.expectEqual(
        FieldError.RequiresFieldType,
        comptime has_field.eval(T),
    );
}

test "coerces FieldError.BanishesFieldType" {
    const T = struct {
        field: bool,
    };

    const params: Params = .{
        .name = "field",
        .type = .{
            .bool = false,
        },
    };

    const has_field: Prototype = init(params);

    try std.testing.expectEqual(
        FieldError.BanishesFieldType,
        comptime has_field.eval(T),
    );
}
