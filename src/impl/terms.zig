//! Includes "proof-of-concept" implementation  that are
//! representative of primitive types (e.g. `bool`, `float`, ...)
//! and aggregate types (e.g. `struct`, `union`, ...)
const std = @import("std");
const testing = std.testing;

const Params = @import("params");
const Term = @import("contract").Term;
const Sign = @import("contract").Sign;

pub fn Negate(term: Term) Term {
    return .{
        .name = std.fmt.comptimePrint("(NOT {s})", .{term.name}),
        .eval = struct {
            fn eval(actual: anytype) bool {
                return !term.eval(actual);
            }
        }.eval,
        .onFail = term.onFail,
    };
}

test Negate {
    const AlwaysTrue: Term = .{
        .name = "AlwaysTrue",
        .eval = struct {
            fn eval(_: anytype) bool {
                return true;
            }
        }.eval,
    };

    try testing.expect(false == Negate(AlwaysTrue).eval(void));
}

pub fn Conjoin(term0: Term, term1: Term) Term {
    return .{
        .name = std.fmt.comptimePrint("({s} AND {s})", .{ term0.name, term1.name }),
        .eval = struct {
            fn eval(actual: anytype) bool {
                const eval0 = term0.eval(actual);
                const eval1 = term1.eval(actual);

                return eval0 and eval1;
            }
        }.eval,
        .onFail = struct {
            fn onFail(label: [:0]const u8, actual: anytype) [:0]const u8 {
                var errstr: [:0]const u8 = undefined;
                if (!term0.eval(actual)) {
                    errstr = term0.onFail("  " ++ term0.name, actual);
                }
                if (!term1.eval(actual)) {
                    errstr = term1.onFail("  " ++ term1.name, actual);
                }
                return std.fmt.comptimePrint("{s}: {s}", .{ label, errstr });
            }
        }.onFail,
    };
}

test Conjoin {
    const AlwaysTrue: Term = .{
        .name = "AlwaysTrue",
        .eval = struct {
            fn eval(_: anytype) bool {
                return true;
            }
        }.eval,
    };
    const AlwaysFalse: Term = .{
        .name = "AlwaysFalse",
        .eval = struct {
            fn eval(_: anytype) bool {
                return false;
            }
        }.eval,
    };

    try testing.expect(true == Conjoin(AlwaysTrue, AlwaysTrue).eval(void));
    try testing.expect(false == Conjoin(AlwaysTrue, AlwaysFalse).eval(void));
}

pub fn Disjoin(term0: Term, term1: Term) Term {
    return .{
        .name = std.fmt.comptimePrint(
            "({s} OR {s})",
            .{ term0.name, term1.name },
        ),
        .eval = struct {
            fn eval(actual: anytype) bool {
                const eval0 = term0.eval(actual);
                const eval1 = term1.eval(actual);

                return eval0 or eval1;
            }
        }.eval,
        .onFail = struct {
            fn onFail(label: [:0]const u8, _: anytype) [:0]const u8 {
                return std.fmt.comptimePrint("{s}: {s} OR {s}", .{
                    label,
                    term0.name,
                    term1.name,
                });
            }
        }.onFail,
    };
}

test Disjoin {
    const AlwaysTrue: Term = .{
        .name = "AlwaysTrue",
        .eval = struct {
            fn eval(_: anytype) bool {
                return true;
            }
        }.eval,
    };
    const AlwaysFalse: Term = .{
        .name = "AlwaysFalse",
        .eval = struct {
            fn eval(_: anytype) bool {
                return false;
            }
        }.eval,
    };

    try testing.expect(true == Disjoin(AlwaysTrue, AlwaysTrue).eval(void));
    try testing.expect(true == Disjoin(AlwaysTrue, AlwaysFalse).eval(void));
    try testing.expect(false == Disjoin(AlwaysFalse, AlwaysFalse).eval(void));
}

/// Special case implementation for boolean types.
///
/// Checks `actual` against `?bool` value, if specified (not null):
///
/// Always evaluates to true if set to null, otherwise, `actual`
/// is expected to be equal to `bool`.
pub fn Bool(params: ?bool) Term {
    return .{
        .name = "Bool",
        .eval = struct {
            fn eval(actual: anytype) bool {
                switch (@typeInfo(@TypeOf(actual))) {
                    .bool => {},
                    else => return false,
                }
                const expect = (params orelse return true);
                return expect == actual;
            }
        }.eval,
        .onFail = struct {
            fn onFail(label: [:0]const u8, actual: anytype) [:0]const u8 {
                switch (@typeInfo(@TypeOf(actual))) {
                    .bool => {},
                    else => std.fmt.comptimePrint("{s}: expected bool", .{label}),
                }
                return std.fmt.comptimePrint(
                    "{s}: {s} != @as({s}, {any})",
                    .{
                        label,
                        if (params.?) "true" else "false",
                        @typeName(@TypeOf(actual)),
                        actual,
                    },
                );
            }
        }.onFail,
    };
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
pub fn Int(params: Params.IntRange) Term {
    return .{
        .name = "Int",
        .eval = struct {
            fn eval(actual: anytype) bool {
                switch (@typeInfo(@TypeOf(actual))) {
                    .int, .comptime_int => {},
                    else => return false,
                }

                const min = (params.min orelse actual) <= actual;
                const max = actual <= (params.max orelse actual);
                const div = actual % (params.div orelse actual) == 0;
                return min and max and div;
            }
        }.eval,
        .onFail = struct {
            fn onFail(label: [:0]const u8, actual: anytype) [:0]const u8 {
                switch (@typeInfo(@TypeOf(actual))) {
                    .comptime_int, .int => {},
                    else => return std.fmt.comptimePrint(
                        "{s}: expected comptime_int or int",
                        .{label},
                    ),
                }

                var str: []const u8 = label ++ ":";
                const padding = std.mem.lastIndexOf(u8, label, "    ");
                const prefix = "\n" ++ "    " ** (if (padding) |p| p + 1 else 1);

                const min = (params.min orelse actual) <= actual;

                if (!min) {
                    str = str ++ std.fmt.comptimePrint(
                        prefix ++ "min: {d} < @as({s}, {any})",
                        .{
                            params.min.?,
                            @typeName(@TypeOf(actual)),
                            actual,
                        },
                    );
                }

                const max = (params.max orelse actual) >= actual;

                if (!max) {
                    str = str ++ std.fmt.comptimePrint(
                        prefix ++ "max: {d} < @as({s}, {any})",
                        .{
                            params.max.?,
                            @typeName(@TypeOf(actual)),
                            actual,
                        },
                    );
                }

                const div = actual % (params.div orelse actual) == 0;

                if (!div) {
                    str = str ++ std.fmt.comptimePrint(
                        prefix ++ "div: @as({s}, {any}) % {d} != 0",
                        .{
                            @typeName(@TypeOf(actual)),
                            actual,
                            params.div.?,
                        },
                    );
                }

                return std.fmt.comptimePrint("{s}", .{str});
            }
        }.onFail,
    };
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
pub fn Float(params: Params.FloatRange) Term {
    return .{
        .name = "Float",
        .eval = struct {
            fn eval(actual: anytype) bool {
                switch (@typeInfo(@TypeOf(actual))) {
                    .float, .comptime_float => {},
                    else => return false,
                }

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
        }.eval,
        .onFail = struct {
            fn onFail(label: [:0]const u8, actual: anytype) [:0]const u8 {
                switch (@typeInfo(@TypeOf(actual))) {
                    .comptime_float, .float => {},
                    else => return std.fmt.comptimePrint(
                        "{s}: expected comptime_float or float",
                        .{label},
                    ),
                }

                var str: []const u8 = label ++ ":";
                const padding = std.mem.lastIndexOf(u8, label, "    ");
                const prefix = "\n" ++ "    " ** (if (padding) |p| p + 1 else 1);

                const min = (params.min orelse actual) <= actual;

                if (!min) {
                    str = str ++ std.fmt.comptimePrint(
                        prefix ++ "min: {d} (+/- {d}) > @as({s}, {any})",
                        .{
                            params.min.?,
                            params.err,
                            @typeName(@TypeOf(actual)),
                            actual,
                        },
                    );
                }

                const max = (params.max orelse actual) >= actual;

                if (!max) {
                    str = str ++ std.fmt.comptimePrint(
                        prefix ++ "max: {d} (+/- {d}) > @as({s}, {any})",
                        .{
                            params.max.?,
                            params.err,
                            @typeName(@TypeOf(actual)),
                            actual,
                        },
                    );
                }

                return std.fmt.comptimePrint("{s}", .{str});
            }
        }.onFail,
    };
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
pub fn Filter(comptime T: type) fn (Params.FieldsToToggles(T)) Term {
    return struct {
        fn define(params: Params.FieldsToToggles(T)) Term {
            return .{
                .name = "Filter " ++ @typeName(T),
                .eval = struct {
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
                }.eval,
                .onFail = struct {
                    fn onFail(label: [:0]const u8, actual: anytype) [:0]const u8 {
                        // Check if used field has explicit setting in params
                        if (@field(params, @tagName(actual))) |field| {
                            return std.fmt.comptimePrint(
                                "{s}: unexpected use of value: {s}",
                                .{
                                    label,
                                    field.name,
                                },
                            );
                        }

                        var str: []const u8 = std.fmt.comptimePrint(
                            "{s}: expected values\n",
                            .{label},
                        );
                        const padding = std.mem.lastIndexOf(u8, label, " ");
                        const prefix = "\n" ++ " " ** (if (padding) |p| p + 3 else 2);

                        // Iterate remaining fields of params
                        inline for (std.meta.fields(@TypeOf(params))) |field| {
                            // Check if current param field has explicit setting
                            if (@field(params, field.name)) |f| {
                                // Return false if param field is set to true and unused.
                                if (f)
                                    str = str ++ prefix ++ field.name;
                            }
                        }

                        return str;
                    }
                }.onFail,
            };
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
pub fn Fields(comptime T: type) fn (Params.FieldsToParams(T)) Term {
    return struct {
        fn define(params: Params.FieldsToParams(T)) Term {
            return .{
                .name = "Fields " ++ @typeName(T),
                .eval = struct {
                    fn eval(actual: anytype) bool {
                        var valid = true;

                        inline for (std.meta.fields(T)) |field| {
                            // Check if param has current field
                            if (!@hasField(@TypeOf(params), field.name)) continue;

                            const param_field = @field(params, field.name);

                            // Check if actual value can contain fields
                            switch (@typeInfo(@TypeOf(actual))) {
                                .@"struct",
                                .@"union",
                                .@"enum",
                                => {
                                    const actual_field = @field(actual, field.name);

                                    valid = valid and switch (@typeInfo(field.type)) {
                                        .int, .comptime_int => Int(param_field).eval(actual_field),
                                        .float, .comptime_float => Float(param_field).eval(actual_field),
                                        .@"enum" => Filter(field.type)(param_field).eval(actual_field),
                                        .@"struct",
                                        .@"union",
                                        .pointer,
                                        .optional,
                                        .vector,
                                        .array,
                                        => Fields(field.type)(param_field).eval(actual_field),
                                        else => return false,
                                    };
                                },
                                else => continue,
                            }
                        }
                        return valid;
                    }
                }.eval,
                .onFail = struct {
                    fn onFail(label: [:0]const u8, actual: anytype) [:0]const u8 {
                        var str: []const u8 = label ++ ":";
                        const padding = std.mem.lastIndexOf(u8, label, "    ");
                        const prefix = "\n" ++ "    " ** (if (padding) |p| p + 1 else 1);

                        _ = std.meta.fields(@TypeOf(actual));

                        inline for (std.meta.fields(T)) |field| {
                            // Check if param has current field
                            if (!@hasField(@TypeOf(params), field.name))
                                continue;

                            const param_field = @field(params, field.name);

                            // Check if actual value can contain fields
                            _ = std.meta.fields(@TypeOf(actual));

                            const actual_field = @field(actual, field.name);

                            switch (@typeInfo(field.type)) {
                                .comptime_int,
                                .int,
                                => if (!Int(param_field).eval(actual_field)) {
                                    str = str ++ Int(param_field).onFail(
                                        prefix ++ Int(param_field).name,
                                        actual_field,
                                    );
                                },
                                .comptime_float,
                                .float,
                                => if (!Float(param_field).eval(actual_field)) {
                                    str = str ++ Float(param_field).onFail(
                                        prefix ++ Float(param_field).name,
                                        actual_field,
                                    );
                                },
                                .@"enum",
                                => if (!Filter(field.type)(param_field).eval(actual_field)) {
                                    str = str ++ Filter(field.type)(param_field).onFail(
                                        prefix ++ Filter(field.type)(param_field).name,
                                        actual_field,
                                    );
                                },
                                .@"struct",
                                .@"union",
                                .pointer,
                                .optional,
                                .vector,
                                .array,
                                => if (!Fields(field.type)(param_field).eval(actual_field)) {
                                    str = str ++ Fields(field.type)(param_field).onFail(
                                        prefix ++ Fields(field.type)(param_field).name,
                                        actual_field,
                                    );
                                },

                                else => continue,
                            }
                        }

                        return std.fmt.comptimePrint("{s}", .{str});
                    }
                }.onFail,
            };
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

    const FooParams: Params.FieldsToParams(Foo) = .{
        .bar = @as(?bool, null),
        .zig = @as(Params.IntRange, .{
            .min = @as(?comptime_int, null),
            .max = @as(?comptime_int, null),
            .div = @as(?comptime_int, null),
        }),
        .zag = @as(Params.FloatRange, .{
            .min = @as(?comptime_float, null),
            .max = @as(?comptime_float, null),
            .err = @as(comptime_float, 0.001),
        }),
        .fizz = @as(Params.FieldsToParams(struct { buzz: usize, fizzbuzz: *const usize }), .{
            .buzz = @as(Params.IntRange, .{
                .min = @as(?comptime_int, null),
                .max = @as(?comptime_int, null),
                .div = @as(?comptime_int, null),
            }),
            .fizzbuzz = @as(Params.IntRange, .{}),
        }),
    };

    _ = (FooParams);
}

/// Checks if argument is at least a superset of function pointer
/// fields of the expected type.
///
/// Assumes all function pointers are top-level fie≥ds of both the
/// expected type and actual argument.
pub fn Implements(comptime T: type) Term {
    return .{
        .name = "Implements " ++ @typeName(T),
        .eval = struct {
            fn eval(actual: anytype) bool {
                inline for (std.meta.fields(T)) |field| {
                    const expect_fn_info = switch (@typeInfo(field.type)) {
                        .pointer => @typeInfo(std.meta.Child(field.type)).@"fn",
                        else => continue,
                    };

                    if (!@hasField(@TypeOf(actual), field.name)) {
                        return false;
                    }

                    const actual_fn_field = @field(actual, field.name);
                    const actual_fn_info = @typeInfo(std.meta.Child(@TypeOf(actual_fn_field))).@"fn";

                    if (std.meta.activeTag(expect_fn_info.calling_convention) != std.meta.activeTag(actual_fn_info.calling_convention)) return false;
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

                return true;
            }
        }.eval,
        .onFail = struct {
            fn onFail(label: [:0]const u8, actual: anytype) [:0]const u8 {
                switch (@typeInfo(@TypeOf(actual))) {
                    .@"struct" => {
                        var str: []const u8 = std.fmt.comptimePrint(
                            "({s}):",
                            .{label},
                        );
                        const padding = std.mem.lastIndexOf(u8, label, "    ");
                        const prefix = "\n" ++ ("    " ** (if (padding) |p| p + 1 else 1));

                        inline for (std.meta.fields(T)) |field| {
                            if (!@hasField(@TypeOf(actual), field.name)) {
                                str = str ++ prefix ++ "missing implementation: " ++ field.name;
                            }
                        }
                        return std.fmt.comptimePrint("{s}\n", .{str});
                    },
                    else => return std.fmt.comptimePrint("{s}: expected struct", .{label}),
                }
            }
        }.onFail,
    };
}

test Implements {
    const SomeAbstract = struct {
        foo: *const fn () void,

        pub fn fooFn(self: @This()) void {
            self.foo();
        }
    };

    const SomeAbstractImpl: SomeAbstract = .{
        .foo = struct {
            fn foo() void {
                // do foo
            }
        }.foo,
    };

    const ImplementsSomeAbstract = Implements(SomeAbstract);

    try testing.expect(true == ImplementsSomeAbstract.eval(SomeAbstractImpl));
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
    .Int => Params.FieldsToParams(std.builtin.Type.Int),
    .Float => Params.FieldsToParams(std.builtin.Type.Float),
    .Array => Params.FieldsToParams(std.builtin.Type.Array),
    .Pointer => Params.FieldsToParams(std.builtin.Type.Pointer),
    .Vector => Params.FieldsToParams(std.builtin.Type.Vector),
}) Term {
    const PInfo = switch (T) {
        .Int => Params.FieldsToParams(std.builtin.Type.Int),
        .Float => Params.FieldsToParams(std.builtin.Type.Float),
        .Array => Params.FieldsToParams(std.builtin.Type.Array),
        .Pointer => Params.FieldsToParams(std.builtin.Type.Pointer),
        .Vector => Params.FieldsToParams(std.builtin.Type.Vector),
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
            return .{
                .name = "Info " ++ @typeName(TInfo),
                .eval = struct {
                    fn eval(actual: anytype) bool {
                        // Pass type info of actual value
                        return Fields(TInfo)(params).eval(switch (@typeInfo(@TypeOf(actual))) {
                            inline else => |info| info,
                        });
                    }
                }.eval,
                .onFail = Fields(TInfo)(params).onFail,
            };
        }
    }.define;
}

test Info {
    const IntInfo = std.builtin.Type.Int;

    const IntInfoParams: Params.FieldsToParams(IntInfo) = .{
        .signedness = @as(Params.FieldsToToggles(std.builtin.Signedness), .{
            .signed = null,
            .unsigned = null,
        }),
        .bits = @as(Params.IntRange, .{
            .min = null,
            .max = null,
            .div = null,
        }),
    };

    _ = Info(.Int)(IntInfoParams);
}

test "some ints" {
    const Default: Term = Int(.{
        .min = @as(?comptime_int, null),
        .max = @as(?comptime_int, null),
        .div = @as(?comptime_int, null),
    });

    try testing.expect(true == Default.eval(0));
    try testing.expect(true == Default.eval(1));

    const EvenInt: Term = Int(.{
        .div = @as(?comptime_int, 2),
    });

    try testing.expect(true == EvenInt.eval(0));
    try testing.expect(false == EvenInt.eval(1));

    const ZeroOrOne = Int(.{
        .min = @as(?comptime_int, 0),
        .max = @as(?comptime_int, 1),
    });

    try testing.expect(true == ZeroOrOne.eval(0));
    try testing.expect(true == ZeroOrOne.eval(1));

    const OnlyZero = Int(.{
        .min = 0,
        .max = 0,
    });

    try testing.expect(true == OnlyZero.eval(0));
    try testing.expect(false == OnlyZero.eval(1));
}

test "some floats" {
    const DefaultFloat: Term = Float(.{
        .min = @as(?comptime_float, null),
        .max = @as(?comptime_float, null),
        .err = @as(comptime_float, 0.001),
    });

    try testing.expect(true == DefaultFloat.eval(-0.5));
    try testing.expect(true == DefaultFloat.eval(0.5));

    const ApproxZero: Term = Float(.{
        .min = @as(?comptime_float, 0),
        .max = @as(?comptime_float, 0),
    });

    try testing.expect(true == ApproxZero.eval(0.0));
    try testing.expect(true == ApproxZero.eval(-0.001));
    try testing.expect(true == ApproxZero.eval(0.001));

    const ExactlyZero: Term = Float(.{
        .min = @as(?comptime_float, 0),
        .max = @as(?comptime_float, 0),
        .err = @as(comptime_float, 0),
    });

    try testing.expect(true == ExactlyZero.eval(0.0));
    try testing.expect(false == ExactlyZero.eval(-0.001));
    try testing.expect(false == ExactlyZero.eval(0.001));
}

test "some bools" {
    const DefaultBool = Bool(@as(?bool, null));
    try testing.expect(true == DefaultBool.eval(false));
    try testing.expect(true == DefaultBool.eval(true));

    const OnlyTrue = Bool(@as(?bool, true));
    try testing.expect(false == OnlyTrue.eval(false));
    try testing.expect(true == OnlyTrue.eval(true));

    const OnlyFalse = Bool(@as(?bool, false));
    try testing.expect(true == OnlyFalse.eval(false));
    try testing.expect(false == OnlyFalse.eval(true));
}

test "some fields" {
    const DefaultFields = Fields(struct {})(void{});

    try testing.expect(true == DefaultFields.eval(void));

    const OneField = Fields(struct { x: u8 })(.{});

    try testing.expect(true == OneField.eval(.{ .x = 1 }));
    try testing.expect(true == OneField.eval(.{ .x = 1 }));

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
    try testing.expect(true == NestedFields.eval(.{ .x = .{ .y = .{ .z = 0 } } }));
    try testing.expect(false == NestedFields.eval(.{ .x = .{ .y = .{ .z = 1 } } }));
}

test "some filters" {
    const DefaultFilter = Filter(enum { x })(.{});

    try testing.expect(true == DefaultFilter.eval((enum { x }).x));

    const OneFilter = Filter(enum { a })(.{ .a = @as(?bool, null) });

    try testing.expect(true == OneFilter.eval(enum { a }.a));

    const OneFilterExplicitUse = Filter(enum { a })(.{ .a = @as(?bool, true) });

    try testing.expect(true == OneFilterExplicitUse.eval(enum { a }.a));

    const OneFilterExplicitNoUse = Filter(enum { a })(.{ .a = @as(?bool, false) });

    try testing.expect(false == OneFilterExplicitNoUse.eval(enum { a }.a));
}

test "some signs" {
    const AnyInteger = Int(.{});
    const SignedAnyInteger = Sign(AnyInteger);
    try testing.expect(void == SignedAnyInteger(1)(void));
    try testing.expect(u8 == SignedAnyInteger(2)(u8));

    // try testing.expect(void == SignedAnyInteger(false)(void));
}

// test "intFail" {
//     const SomeIntTerm = Int(.{
//         .min = 0,
//         .max = 10,
//     });

//     _ = Sign(SomeIntTerm)(11)(void);
// }

// test "floatFail" {
//     const SomeFloatTerm = Float(.{
//         .min = 0,
//         .max = 10,
//     });

//     _ = Sign(SomeFloatTerm)(11.0)(void);
// }

// test "implementsFail" {
//     const SomeInterface = struct {
//         foo: *const fn () void,
//         bar: *const fn (x: anytype) void,
//     };

//     const SomeBar = struct {
//         foo: *const fn () void = struct {
//             fn foo() void {}
//         }.foo,
//     };

//     const ImplementsSomeInterfaceTerm = Implements(SomeInterface);

//     _ = Sign(ImplementsSomeInterfaceTerm)(SomeBar{})(void);
// }

// test "fieldsFail" {
//     const SomeStruct = struct {
//         x: usize,
//     };

//     const SomeStructTermParams: Params.FieldsToParams(SomeStruct) = .{
//         .x = .{
//             .min = 0,
//             .max = 10,
//         },
//     };
//     const SomeStructTerm = Fields(SomeStruct)(SomeStructTermParams);

//     _ = Sign(SomeStructTerm)(SomeStruct{ .x = 11 })(void);
// }
