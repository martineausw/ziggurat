//! Includes "proof-of-concept" implementation  that are
//! representative of primitive types (e.g. `bool`, `float`, ...)
//! and aggregate types (e.g. `struct`, `union`, ...)
const std = @import("std");

const Params = @import("params");
const Term = @import("contract").Term;
const Sign = @import("contract").Sign;

pub fn Implements(comptime expect: type) Term {
    return .{
        .eval = struct {
            fn eval(actual: anytype) bool {
                const actual_info = @typeInfo(@TypeOf(actual)).@"struct";

                inline for (actual_info.fields) |field| {
                    if (!@hasField(expect, field.name)) {
                        continue;
                    }

                    const expect_fn_info = switch (@typeInfo(@field(expect, field.name).type)) {
                        .pointer => |info| switch (@typeInfo(info.child)) {
                            .@"fn" => |func| func,
                            else => continue,
                        },
                        else => continue,
                    };

                    const actual_fn_info = switch (@typeInfo(field.type)) {
                        .pointer => |info| switch (@typeInfo(info.child)) {
                            .@"fn" => |func| func,
                            else => continue,
                        },
                        else => continue,
                    };

                    if (expect_fn_info.calling_convention != actual_fn_info.calling_convention) return false;
                    if (expect_fn_info.is_generic != actual_fn_info.is_generic) return false;
                    if (expect_fn_info.is_var_args != actual_fn_info.is_var_args) return false;
                    if (expect_fn_info.return_type != actual_fn_info.return_type) return false;

                    // pointer type - check for deep equality
                    inline for (0..expect_fn_info.params.len) |i| {
                        const expect_param = expect_fn_info.params[i];
                        const actual_param = actual_fn_info.params[i];

                        if (expect_param.is_generic != actual_param.is_generic) return false;
                        if (expect_param.is_noalias != actual_param.is_noalias) return false;
                        if (expect_param.type != actual_param.type) return false;
                    }
                }
            }
        }.eval,
    };
}

test Implements {
    try std.testing.expect(false);
}

/// Special case implementation for boolean types.
///
/// Checks `actual` against `?bool` value, if specified (not null):
///
/// Always evaluates to true if set to null, otherwise, `actual`
/// is expected to be equal to `bool`.
pub fn Bool(expect: Params.Bool) Term {
    return struct {
        fn eval(actual: anytype) bool {
            switch (@typeInfo(@TypeOf(actual))) {
                .bool => {},
                else => unreachable,
            }
            const e = (expect orelse return true);
            return e == actual;
        }

        fn impl() Term {
            return .{ .eval = eval };
        }
    }.impl();
}

test Bool {
    _ = Bool(@as(?bool, null));
    _ = Bool(@as(?bool, false));
    _ = Bool(@as(?bool, true));
}

/// Special case implementation for integer types.
///
/// Checks `actual` against `parametrics.Int` fields, if specified (not null):
/// ```
/// - min: ?comptime_int = null // inclusive minimum integer value
/// - max: ?comptime_int = null // inclusive maximum integer value
/// - div: ?comptime_int = null // integer divisor value
/// ```
///
/// Always evaluates to true if no parameters are specified.
///
/// When defined, checks if `actual` is evenly divisible by `div`.
pub fn Int(params: Params.Int) Term {
    return struct {
        fn eval(actual: anytype) bool {
            switch (@typeInfo(@TypeOf(actual))) {
                .int, .comptime_int => {},
                else => unreachable,
            }

            if (params.type) |t| if (t != @TypeOf(actual)) return false;

            const min = (params.min orelse actual) <= actual;
            const max = actual <= (params.max orelse actual);
            const div = actual % (params.div orelse actual) == 0;
            return min and max and div;
        }

        fn impl() Term {
            return .{ .eval = eval };
        }
    }.impl();
}

test Int {
    _ = Int(.{
        .min = @as(?comptime_int, null),
        .max = @as(?comptime_int, null),
        .div = @as(?comptime_int, null),
    });
}

/// Special case implementation for floating point types.
///
/// Checks `actual` against `parametrics.Float` fields, if specified (not null):
/// ```
/// - min: ?comptime_float = null // inclusive minimum float value
/// - max: ?comptime_float = null // inclusive maximum float value
/// - err: comptime_float = 0.001 // error tolerance float value
/// ```
///
/// Always evaluates to true if `min` nor `max` are specified.
///
/// `err` is used in `std.math.approxEqAbs(...)` when determining equality on interval endpoints
pub fn Float(params: Params.Float) Term {
    return struct {
        fn eval(actual: anytype) bool {
            switch (@typeInfo(@TypeOf(actual))) {
                .float, .comptime_float => {},
                else => unreachable,
            }

            if (params.type) |t| if (t != @TypeOf(actual)) return false;

            const min = (params.min orelse actual) < actual or std.math.approxEqAbs(
                comptime_float,
                params.min orelse actual,
                actual,
                params.err,
            );

            const max = actual < (params.min orelse actual) or std.math.approxEqAbs(
                comptime_float,
                params.max orelse actual,
                actual,
                params.err,
            );
            return min and max;
        }

        fn impl() Term {
            return .{ .eval = eval };
        }
    }.impl();
}

test Float {
    _ = Float(.{
        .min = @as(?comptime_float, null),
        .max = @as(?comptime_float, null),
        .err = @as(comptime_float, 0.001),
    });
}

/// Special case implementation for `enum` types
///
/// Iterates through original fields to generate a struct with fields
/// of the same name via `parametrics.Filter(...)`.
///
/// Every field is represented as `?bool` to indicate if `enum` values
/// are explicitly allowed or disallowed.
///
/// If `Filter` is given an enum argument where all fields are set to `null`,
/// evaluation result is true.
///
/// If `Filter` is given an enum argument where at least one field is set to `true`,
/// then the enum argument must belong to the set of true values otherwise evaluation
/// result is false.
///
/// If `Filter` is given an enum argument where the field has been set `false`,
/// evaluation result is false.
///
/// ```
/// -   enum { a, b, c, d } => Fields(enum { a, b, c, d })(parametrics.Enum){
///         .a: ?bool = null,
///         .b: ?bool = null,
///         .c: ?bool = null,
///         .d: ?bool = null,
///     }
/// ```
///
pub fn Filter(comptime T: type) fn (Params.Filter(T)) Term {
    return struct {
        pub fn define(params: Params.Filter(T)) Term {
            return struct {
                fn eval(actual: anytype) bool {

                    // Check if used field has explicit setting in params
                    if (@field(params, @tagName(actual))) |field| {
                        // Current enum value has explicit setting
                        return field;
                    }

                    // Iterate remaining fields of params
                    inline for (std.meta.fields(@TypeOf(params))) |field| {
                        // Check if current param field has explicit setting
                        if (@field(params, field.name)) |f| {
                            // Return false if param field is set to true and unused.
                            if (f) return false;
                        }
                    }

                    // Assume no violations
                    return true;
                }

                fn impl() Term {
                    return .{ .eval = eval };
                }
            }.impl();
        }
    }.define;
}

test Filter {
    _ = Filter(enum { a, b, c, d, e })(.{
        .a = @as(?bool, null),
        .b = @as(?bool, null),
        .c = @as(?bool, null),
        .d = @as(?bool, null),
        .e = @as(?bool, null),
    });
}

const SupportedInfo = enum {
    Int,
    Float,
    Pointer,
    Array,
    Vector,
};

/// Special case implementation to parameterize an arguments `std.builtin.Type` definition,
/// as given by `@typeInfo(T: type)`, into `Fields(std.builtin.Type.*)(...)`
///
/// Examples:
/// ```
/// -   Info(.Int) => Fields(std.builtin.Type.Int)(...){
///         .bits: parametrics.Int = .{
///             .min: ?comptime_int = null,
///             .max: ?comptime_int = null,
///             .div: ?comptime_int = null,
///         },
///         .signedness: parametrics.Enum = .{
///             .signed: ?bool = null,
///             .unsigned: ?bool = null,
///         },
///     }
/// -   Info(.Float) => Fields(std.builtin.Type.Float)(...){
///         .bits: parametrics.Int = .{...},
///     }
/// ```
///
/// Functionally identical to `Fields` in evaluation.
///
/// Ensures `std.builtin.Type.*` of argument is used if it exists and is
/// supported.
///
/// See `parametrics` and `std.builtin.Type` for additional context.
pub fn Info(comptime T: SupportedInfo) fn (switch (T) {
    .Int => Params.Fields(std.builtin.Type.Int),
    .Float => Params.Fields(std.builtin.Type.Float),
    .Array => Params.Fields(std.builtin.Type.Array),
    .Pointer => Params.Fields(std.builtin.Type.Pointer),
    .Vector => Params.Fields(std.builtin.Type.Vector),
}) Term {
    const PInfo = switch (T) {
        .Int => Params.Fields(std.builtin.Type.Int),
        .Float => Params.Fields(std.builtin.Type.Float),
        .Array => Params.Fields(std.builtin.Type.Array),
        .Pointer => Params.Fields(std.builtin.Type.Pointer),
        .Vector => Params.Fields(std.builtin.Type.Vector),
    };

    const TInfo = switch (T) {
        .Int => std.builtin.Type.Int,
        .Float => std.builtin.Type.Float,
        .Array => std.builtin.Type.Array,
        .Pointer => std.builtin.Type.Pointer,
        .Vector => std.builtin.Type.Vector,
    };

    return struct {
        fn define(params: PInfo) Term {
            return struct {
                fn eval(actual: anytype) bool {
                    // Pass type info of actual value
                    return Fields(TInfo)(params).eval(switch (@typeInfo(@TypeOf(actual))) {
                        inline else => |info| info,
                    });
                }

                fn impl() Term {
                    return .{ .eval = eval };
                }
            }.impl();
        }
    }.define;
}

test Info {

    // ./zig/0.14.1/lib/zig/std/builtin.zig
    //
    // pub const Type = union (enum) {
    // ...
    //
    // pub const Int = struct {
    //     signedness: Signedness, // enum type
    //     bits: u16,
    // };
    //
    // ...
    // }

    const IntInfo = std.builtin.Type.Int;

    const IntInfoParams: Params.Fields(IntInfo) = .{
        .signedness = @as(Params.Filter(std.builtin.Signedness), .{
            .signed = null,
            .unsigned = null,
        }),
        .bits = @as(Params.Int, .{
            .min = null,
            .max = null,
            .div = null,
        }),
    };

    _ = Info(.Int)(IntInfoParams);
}

/// Special case implementation of aggregate types (e.g. `struct`, `union`)
///
/// Iterates through fields to generate a struct that shares
/// field names of the type it is based on via `parametrics.Filter(...)`.
///
/// A field's type is converted to its "parametric" representation.
/// ```
/// -   bool => Bool(parametrics.Bool)
/// -   u64 => Int(parametrics.Int)
/// -   struct { x: usize } => Fields(struct { x: usize })(parametrics.Fields){
///         .x: parametrics.Int = .{
///             .min: ?comptime_int = null,
///             .max: ?comptime_int = null,
///             .div: ?comptime_int = null,
///         }
///     }
/// ```
///
/// All fields must evaluate to true for final evaluation result to be true
pub fn Fields(comptime T: type) fn (Params.Fields(T)) Term {
    return struct {
        fn define(params: Params.Fields(T)) Term {
            return struct {
                fn eval(actual: anytype) bool {
                    var valid = true;

                    inline for (std.meta.fields(T)) |field| {
                        // Check if param has current field
                        if (!@hasField(@TypeOf(params), field.name)) continue;
                        const param_field = @field(params, field.name);

                        // Check if actual value can contain fields
                        switch (@typeInfo(@TypeOf(actual))) {
                            .@"struct", .@"union" => {},
                            else => continue,
                        }

                        const actual_field = @field(actual, field.name);

                        valid = valid and switch (@typeInfo(field.type)) {
                            .int, .comptime_int => Int(param_field).eval(actual_field),
                            .float, .comptime_float => Float(param_field).eval(actual_field),
                            .@"enum" => Filter(field.type)(param_field).eval(actual_field),
                            .@"struct" => Fields(field.type)(param_field).eval(actual_field),
                            .@"union" => Fields(field.type)(param_field).eval(actual_field),
                            .pointer => Fields(field.type)(param_field).eval(actual_field),
                            .optional => Fields(field.type)(param_field).eval(actual_field),
                            .vector => Fields(field.type)(param_field).eval(actual_field),
                            .array => Fields(field.type)(param_field).eval(actual_field),
                            else => unreachable,
                        };
                    }
                    return valid;
                }

                fn impl() Term {
                    return .{ .eval = eval };
                }
            }.impl();
        }
    }.define;
}

test Fields {
    const Foo = struct {
        bar: bool,
        zig: comptime_int,
        zag: f128,
        fizz: struct {
            buzz: usize,
            fizzbuzz: *const usize,
        },
    };

    const FooParams: Params.Fields(Foo) = .{
        .bar = @as(?bool, null),
        .zig = @as(Params.Int, .{
            .min = @as(?comptime_int, null),
            .max = @as(?comptime_int, null),
            .div = @as(?comptime_int, null),
        }),
        .zag = @as(Params.Float, .{
            .min = @as(?comptime_float, null),
            .max = @as(?comptime_float, null),
            .err = @as(comptime_float, 0.001),
        }),
        .fizz = @as(Params.Fields(struct { buzz: usize, fizzbuzz: *const usize }), .{
            .buzz = @as(Params.Int, .{
                .min = @as(?comptime_int, null),
                .max = @as(?comptime_int, null),
                .div = @as(?comptime_int, null),
            }),
            .fizzbuzz = @as(Params.Int, .{}),
        }),
    };

    _ = (FooParams);
}

test "some ints" {
    const Default: Term = Int(.{
        .min = @as(?comptime_int, null),
        .max = @as(?comptime_int, null),
        .div = @as(?comptime_int, null),
    });

    try std.testing.expect(true == Default.eval(0));
    try std.testing.expect(true == Default.eval(1));

    const EvenInt: Term = Int(.{
        .div = @as(?comptime_int, 2),
    });

    try std.testing.expect(true == EvenInt.eval(0));
    try std.testing.expect(false == EvenInt.eval(1));

    const ZeroOrOne = Int(.{
        .min = @as(?comptime_int, 0),
        .max = @as(?comptime_int, 1),
    });

    try std.testing.expect(true == ZeroOrOne.eval(0));
    try std.testing.expect(true == ZeroOrOne.eval(1));

    const OnlyZero = Int(.{
        .min = 0,
        .max = 0,
    });

    try std.testing.expect(true == OnlyZero.eval(0));
    try std.testing.expect(false == OnlyZero.eval(1));
}

test "some floats" {
    const DefaultFloat: Term = Float(.{
        .min = @as(?comptime_float, null),
        .max = @as(?comptime_float, null),
        .err = @as(comptime_float, 0.001),
    });

    try std.testing.expect(true == DefaultFloat.eval(-0.5));
    try std.testing.expect(true == DefaultFloat.eval(0.5));

    const ApproxZero: Term = Float(.{
        .min = @as(?comptime_float, 0),
        .max = @as(?comptime_float, 0),
    });

    try std.testing.expect(true == ApproxZero.eval(0.0));
    try std.testing.expect(true == ApproxZero.eval(-0.001));
    try std.testing.expect(true == ApproxZero.eval(0.001));

    const ExactlyZero: Term = Float(.{
        .min = @as(?comptime_float, 0),
        .max = @as(?comptime_float, 0),
        .err = @as(comptime_float, 0),
    });

    try std.testing.expect(true == ExactlyZero.eval(0.0));
    try std.testing.expect(false == ExactlyZero.eval(-0.001));
    try std.testing.expect(false == ExactlyZero.eval(0.001));
}

test "some bools" {
    const DefaultBool = Bool(@as(?bool, null));
    try std.testing.expect(true == DefaultBool.eval(false));
    try std.testing.expect(true == DefaultBool.eval(true));

    const OnlyTrue = Bool(@as(?bool, true));
    try std.testing.expect(false == OnlyTrue.eval(false));
    try std.testing.expect(true == OnlyTrue.eval(true));

    const OnlyFalse = Bool(@as(?bool, false));
    try std.testing.expect(true == OnlyFalse.eval(false));
    try std.testing.expect(false == OnlyFalse.eval(true));
}

test "some fields" {
    const DefaultFields = Fields(struct {})(void{});

    try std.testing.expect(true == DefaultFields.eval(void));

    const OneField = Fields(struct { x: u8 })(.{});

    try std.testing.expect(true == OneField.eval(.{ .x = 1 }));
    try std.testing.expect(true == OneField.eval(.{ .x = 1 }));

    const NestedFields = Fields(struct {
        x: struct {
            y: struct {
                z: u8 = 0,
            },
        },
    })(.{
        .x = .{
            .y = .{
                .z = .{
                    .min = 0,
                    .max = 0,
                },
            },
        },
    });
    try std.testing.expect(true == NestedFields.eval(.{ .x = .{ .y = .{ .z = 0 } } }));
    try std.testing.expect(false == NestedFields.eval(.{ .x = .{ .y = .{ .z = 1 } } }));
}

test "some filters" {
    const DefaultFilter = Filter(enum { x })(.{});

    try std.testing.expect(true == DefaultFilter.eval((enum { x }).x));

    const OneFilter = Filter(enum { a })(.{ .a = @as(?bool, null) });

    try std.testing.expect(true == OneFilter.eval(enum { a }.a));

    const OneFilterExplicitUse = Filter(enum { a })(.{ .a = @as(?bool, true) });

    try std.testing.expect(true == OneFilterExplicitUse.eval(enum { a }.a));

    const OneFilterExplicitNoUse = Filter(enum { a })(.{ .a = @as(?bool, false) });

    try std.testing.expect(false == OneFilterExplicitNoUse.eval(enum { a }.a));
}

test "some signs" {
    const AnyInteger = Int(.{});
    const SignedAnyInteger = Sign(AnyInteger);
    try std.testing.expect(void == SignedAnyInteger(1)(void));
    try std.testing.expect(u8 == SignedAnyInteger(2)(u8));

    // try std.testing.expect(void == SignedAnyInteger(false)(void));
}
