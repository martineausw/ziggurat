//! Auxillary prototype for field member of given type.
const std = @import("std");

const Prototype = @import("../Prototype.zig");
const info = @import("info.zig");

/// Error set for field.
const FieldError = error{
    InvalidArgument,
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
                        info.Error.RequiresType,
                        => FieldError.InvalidArgument,
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
            fn onError(err: anyerror, prototype: Prototype, actual: anytype) void {
                switch (err) {
                    FieldError.InvalidArgument,
                    => info_validator.onError(err, prototype, actual),

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
    _ = FieldError.NonexistentField catch void;
    _ = FieldError.MismatchedType catch void;
}

test Error {
    _ = Error.InvalidType catch void;
    _ = Error.DisallowedType catch void;
    _ = Error.UnexpectedType catch void;

    _ = Error.NonexistentField catch void;
    _ = Error.MismatchedType catch void;
}

test info_validator {
    _ = try info_validator.eval(struct {});
    _ = try info_validator.eval(union {});
}

test Params {
    const Foo = struct {
        bar: f128,
    };

    _ = Foo;

    const params: Params = .{
        .name = "bar",
        .type = .{},
    };

    _ = params;
}

test init {
    const Foo = struct {
        bar: f128,
    };

    const params: Params = .{
        .name = "bar",
        .type = .{
            .float = true,
        },
    };

    _ = try init(params).eval(Foo);
}
