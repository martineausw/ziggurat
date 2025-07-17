//! Consists of `Term` abstract with some implementations and
//! `Sign` type to introduce type constraints within function
//! signatures
//!
//! Includes arbitrarily axiomatic implementations that are
//! representative of primitive types (e.g. `bool`, `float`, ...)
//! and aggregate types (e.g. `struct`, `union`, ...)
const std = @import("std");

const Params = @import("params.zig");

/// `Term` abstract
///
/// Defines a condition that is evaluated when supplied with an argument.
/// Used by `Sign` to cease control flow when evaluation results to a false
/// value.
///
/// Let `actual` be defined as a single arbitrary argument that gets passed
/// through all evaluation steps. `actual` may or may not be indexable and
/// may have meta-data, as given by `@typeInfo(...)`.
pub const Term = struct {
    /// Function pointer that is invoked by `Sign` or other `Term` wrappers.
    ///
    /// `actual: anytype` argument to be evaluated
    /// by the term.
    ///
    /// `Sign` expects final evaluation result to be true in order to continue.
    eval: *const fn (actual: anytype) bool,

    /// Optional function pointer invoked by `Sign` or other `Term` wrappers
    /// when `eval` returns false.
    onFail: ?*const fn (args: anytype) void = null,

    /// Internal dispatch of `eval` function pointer necessary for interface
    /// pattern.
    fn evalFn(self: Term, actual: anytype) bool {
        return self.eval(actual);
    }

    /// Assert term evaluates to true. Abandons control flow when evaluation
    /// result is false.
    ///
    /// - Pneumonically based on "mandatory/mandate"
    pub fn man(self: Term) Term {
        return struct {
            fn eval(actual: anytype) bool {
                if (!self.eval(actual)) unreachable;
                return true;
            }

            fn impl() Term {
                return .{ .eval = eval };
            }
        }.impl();
    }

    /// Evaluate term at index. Assumes `actual` is indexable.
    pub fn at(self: Term, index: usize) Term {
        return struct {
            fn eval(actual: anytype) bool {
                return self.eval(actual[index]);
            }

            fn impl() Term {
                return .{ .eval = eval };
            }
        }.impl();
    }

    /// Negates evaluation result of term.
    pub fn not(self: Term) Term {
        return struct {
            fn eval(actual: anytype) bool {
                return !self.eval(actual);
            }

            fn impl() Term {
                return .{ .eval = eval };
            }
        }.impl();
    }

    /// Boolean AND operation of evaluation results.
    ///
    /// - Pneumonically based on "necessarily/necessary"
    pub fn nec(self: Term, term: Term) Term {
        return struct {
            fn eval(actual: anytype) bool {
                return self.eval(actual) and term.eval(actual);
            }

            fn impl() Term {
                return .{ .eval = eval };
            }
        }.impl();
    }

    /// Boolean OR operation of evaluation results
    ///
    /// - Pneumonically based on "optionally/optional/opt-in"
    pub fn opt(self: Term, term: Term) Term {
        return struct {
            fn eval(args: anytype) bool {
                return self.eval(args) or term.eval(args);
            }

            fn impl() Term {
                return .{ .eval = eval };
            }
        }.impl();
    }
};

/// Special case implementation for boolean types.
///
/// Checks `actual` against `?bool` value, if specified (not null):
///
/// Always evaluates to true if set to null, otherwise, `actual`
/// is expected to be equal to `bool`.
pub fn Bool(expect: Params.Bool) Term {
    return struct {
        fn eval(actual: anytype) bool {
            const e = (expect orelse return true);
            return e == actual;
        }

        fn impl() Term {
            return .{ .eval = eval };
        }
    }.impl();
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
pub fn Float(params: Params.Int) Term {
    return struct {
        fn eval(actual: anytype) bool {
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

/// Example:
/// ```
/// const AnyIntTerm = Int(.{})
/// fn foo(x: anytype) Sign(AnyIntTerm)(x)(void) {
///     ...
/// }
/// ```
///
/// Implementation uses monad(?) pattern, or a series of closures. Calling is as follows:
///
/// ```
/// Sign(term_value: Term)(argument_value: anytype)(function_return_type: type)
/// ```
///
/// Wraps the final term and invoked at return value position of a function signature.
///
/// Term must evaluate to true to continue.
pub fn Sign(comptime term: Term) fn (actual: anytype) fn (comptime return_type: type) type {
    return struct {
        pub fn validate(actual: anytype) fn (comptime return_type: type) type {
            if (!term.eval(actual)) {
                // Check if onFail function is defined.
                if (term.onFail) |onFail| {
                    onFail(actual);
                } else {
                    // Exit if contract validation fails
                    unreachable;
                }
            }
            return struct {
                pub fn returns(comptime ret_type: type) type {
                    return ret_type;
                }
            }.returns;
        }
    }.validate;
}

test Sign {
    const term_value = @as(Term, Int(.{}));
    const argument_value = @as(comptime_int, 0);
    const return_type = @as(@TypeOf(void), void);

    _ = Sign(term_value)(argument_value)(return_type);
    const Signed = Sign(term_value);
    _ = Signed(argument_value)(return_type);
}
