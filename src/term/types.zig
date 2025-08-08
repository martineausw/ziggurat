//! Implementations of `Term` abstract class for convenience or reference.
const std = @import("std");
const testing = std.testing;
const Term = @import("Term.zig");

fn getPaddingLevel(str: [:0]const u8) usize {
    return std.mem.lastIndexOf(u8, str, " " ** 4) orelse 1;
}

fn getNewLinePad(padding_level: usize) []const u8 {
    return std.fmt.comptimePrint("\n{s}", .{(" " ** 4) ** padding_level});
}

fn appendToString(str: []const u8, fmt: []const u8, args: anytype) []const u8 {
    return str ++ std.fmt.comptimePrint(fmt, args);
}

const ValueError = error{InvalidType};

const IntervalError = error{
    ExceedsMax,
    ExceedsMin,
};

const FilterError = error{
    ActiveExclusion,
    InactiveInclusions,
};

/// Expects type value.
///
/// `actual` is type value, otherwise returns `ValueError.UnexpectedType`.
pub const IsType: Term = .{
    .name = "IsType",

    .eval = struct {
        /// Expects `type` argument
        fn eval(actual: anytype) ValueError!bool {
            return switch (@typeInfo(@TypeOf(actual))) {
                .type => true,
                else => ValueError.InvalidType,
            };
        }
    }.eval,
    .onError = struct {
        fn onError(err: anyerror, term: Term, actual: anytype) void {
            switch (err) {
                ValueError.InvalidType => @compileError(std.fmt.comptimePrint(
                    "{s}.{s} expects `type`, actual: {s}",
                    .{
                        term.name,
                        @errorName(err),
                        @typeName(@TypeOf(actual)),
                    },
                )),
            }
        }
    }.onError,
};

test IsType {
    try testing.expect(true == try IsType.eval(bool));
    try testing.expect(true == try IsType.eval(usize));
    try testing.expect(true == try IsType.eval(i64));
    try testing.expect(true == try IsType.eval(f128));
    try testing.expect(true == try IsType.eval(struct {}));
    try testing.expect(true == try IsType.eval(enum {}));
    try testing.expect(true == try IsType.eval(union {}));
}

pub fn IntervalParams(comptime T: type) type {
    return struct {
        min: ?T = null,
        max: ?T = null,

        pub fn eval(self: IntervalParams(T), actual: T) IntervalError!bool {
            if (!((self.min orelse actual) <= actual)) return IntervalError.ExceedsMin;
            if (!((self.max orelse actual) >= actual)) return IntervalError.ExceedsMax;
            return true;
        }

        pub fn onError(self: IntervalParams(T), err: IntervalError, term: Term, actual: anytype) void {
            const print_val = switch (err) {
                IntervalError.ExceedsMin => self.min.?,
                IntervalError.ExceedsMax => self.max.?,
            };
            @compileError(std.fmt.comptimePrint("{s}.{s}: {d} actual: @as({s}, {d})", .{
                term.name,
                @errorName(err),
                print_val,
                @typeName(T),
                actual,
            }));
        }
    };
}

/// Expects integer value.
///
/// Given type `T` is integer type, otherwise returns error from `TypeWithInfo`.
///
/// `actual` is greater-than-or-equal-to given `params.min`, otherwise
/// `IntervalError.ViolatedMin`.
///
/// `actual` is less-than-or-equal-to given `params.max`, otherwise
/// returns `IntervalError.ViolatedMax`.
pub fn IntWithinInterval(comptime T: type, params: IntervalParams(T)) Term {
    const Error = ValueError || FilterError || IntervalError;

    const ValidType = TypeWithInfo(.{
        .int = true,
        .comptime_int = true,
    });

    return .{
        .name = "IntWithinInterval",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                // ValueError || FilterError
                _ = ValidType.eval(T) catch |err| return err;

                // IntervalError
                _ = params.eval(actual) catch |err| return err;

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, term: Term, actual: anytype) void {
                switch (@as(IntervalError, err)) {
                    ValueError.InvalidType,
                    FilterError.ActiveExclusion,
                    FilterError.InactiveInclusions,
                    => ValidType.onError(err, term, actual),

                    IntervalError.ExceedsMin,
                    IntervalError.ExceedsMax,
                    => params.onError(err, term, actual),
                }
            }
        }.onError,
    };
}

test IntWithinInterval {
    const IntRange: Term = IntWithinInterval(usize, .{
        .min = @as(usize, 1),
        .max = @as(usize, 2),
    });

    try testing.expect(false == IntRange.eval(0) catch false);
    try testing.expect(true == try IntRange.eval(1));
    try testing.expect(true == try IntRange.eval(2));
    try testing.expect(false == IntRange.eval(3) catch false);
}

pub const InfoParams = struct {
    type: ?bool = null,
    void: ?bool = null,
    bool: ?bool = null,
    noreturn: ?bool = null,
    int: ?bool = null,
    float: ?bool = null,
    pointer: ?bool = null,
    array: ?bool = null,
    @"struct": ?bool = null,
    comptime_float: ?bool = null,
    comptime_int: ?bool = null,
    undefined: ?bool = null,
    null: ?bool = null,
    optional: ?bool = null,
    error_union: ?bool = null,
    error_set: ?bool = null,
    @"enum": ?bool = null,
    @"union": ?bool = null,
    @"fn": ?bool = null,
    @"opaque": ?bool = null,
    frame: ?bool = null,
    @"anyframe": ?bool = null,
    vector: ?bool = null,
    enum_literal: ?bool = null,

    pub fn eval(self: InfoParams, T: type) FilterError!bool {
        if (@field(self, @tagName(@typeInfo(T)))) |param| {
            if (!param) return FilterError.ActiveExclusion;
            return true;
        }

        inline for (std.meta.fields(@TypeOf(self))) |field| {
            if (@field(self, field.name)) |value| {
                if (value) return FilterError.InactiveInclusions;
            }
        }
        return true;
    }

    pub fn onError(err: FilterError, term: Term, actual: anytype) void {
        switch (@as(FilterError, err)) {
            FilterError.ActiveExclusion,
            FilterError.InactiveInclusions,
            => @compileError(std.fmt.comptimePrint(
                "{s}.{s}: {s}",
                .{
                    term.name,
                    @errorName(err),
                    @tagName(@typeInfo(actual)),
                },
            )),
        }
    }
};

/// Expects type value.
///
/// `actual` is a type value, otherwise returns error from `IsType`.
///
/// `actual` active tag of `Type` belongs to the set of `InfoParams` fields
/// set to true, otherwise returns `FilterError.IgnoresInclusions`.
///
/// `actual` active tag of `Type` does not belong to the set of `InfoParams` fields
/// set to false, otherwise returns `FilterError.UsesExclusion`.
pub fn TypeWithInfo(params: InfoParams) Term {
    const Error = ValueError || FilterError;

    return .{
        .name = "TypeWithInfo",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                // ValueError
                _ = IsType.eval(actual) catch |err| return err;
                // FilterError
                _ = params.eval(actual) catch |err| return err;

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, term: Term, actual: anytype) void {
                switch (@as(FilterError, err)) {
                    ValueError.InvalidType,
                    => IsType.onError(err, term, actual),

                    FilterError.ActiveExclusion,
                    FilterError.InactiveInclusions,
                    => params.onError(err, term, actual),
                }
            }
        }.onError,
    };
}

test TypeWithInfo {
    const NumberTypes = TypeWithInfo(.{
        .int = true,
        .float = true,
        .comptime_int = true,
        .comptime_float = true,
    });

    try testing.expect(true == NumberTypes.eval(usize) catch false);
    try testing.expect(true == NumberTypes.eval(i64) catch false);
    try testing.expect(true == NumberTypes.eval(f128) catch false);
    try testing.expect(true == NumberTypes.eval(comptime_int) catch false);
    try testing.expect(true == NumberTypes.eval(comptime_float) catch false);

    const NotNumberTypes = TypeWithInfo(.{
        .int = false,
        .float = false,
        .comptime_int = false,
        .comptime_float = false,
    });

    try testing.expect(false == NotNumberTypes.eval(usize) catch false);
    try testing.expect(false == NotNumberTypes.eval(i64) catch false);
    try testing.expect(false == NotNumberTypes.eval(f128) catch false);
    try testing.expect(false == NotNumberTypes.eval(comptime_int) catch false);
    try testing.expect(false == NotNumberTypes.eval(comptime_float) catch false);

    const OnlyParameterizedTypes = TypeWithInfo(.{
        .optional = true,
        .pointer = true,
        .array = true,
        .vector = true,
    });

    try testing.expect(true == try OnlyParameterizedTypes.eval([]const u8));
    try testing.expect(true == try OnlyParameterizedTypes.eval(?bool));
    try testing.expect(true == try OnlyParameterizedTypes.eval(@Vector(5, usize)));
    try testing.expect(true == try OnlyParameterizedTypes.eval([5]comptime_int));
}

/// Expects runtime number type value.
///
/// `actual` is a runtime integer or runtime float type value, otherwise returns
/// error from `TypeWithInfo`.
///
/// `actual` type info `bits` is within given `params`, otherwise returns error
/// from `IntWithinInterval`.
pub fn InfoWithBits(params: IntervalParams(u16)) Term {
    const Error = ValueError || IntervalError || FilterError;

    const ValidInfo = TypeWithInfo(.{
        .int = true,
        .float = true,
    });

    return .{
        .name = "InfoWithBits",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                // FilterError || ValueError
                _ = ValidInfo.eval(actual) catch |err| return err;

                const info = switch (@typeInfo(actual)) {
                    inline .int, .float => |info| info,
                    else => unreachable,
                };

                // IntervalError
                _ = params.eval(info.bits) catch |err| return err;

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, term: Term, actual: anytype) void {
                switch (err) {
                    ValueError.InvalidType,
                    FilterError.UsesExclusion,
                    FilterError.IgnoresInclusions,
                    => ValidInfo.onError(err, term, actual),

                    IntervalError.ExceedsMin,
                    IntervalError.ExceedsMax,
                    => params.onError(err, term, actual),
                }
            }
        }.onError,
    };
}

test InfoWithBits {
    const Exactly8B = InfoWithBits(.{
        .min = 64,
        .max = 64,
    });

    try testing.expect(true == Exactly8B.eval(i64) catch false);
    try testing.expect(true == Exactly8B.eval(u64) catch false);
    try testing.expect(true == Exactly8B.eval(f64) catch false);

    const Min2B = InfoWithBits(.{
        .min = 16,
    });

    try testing.expect(false == Min2B.eval(i8) catch false);
    try testing.expect(false == Min2B.eval(u8) catch false);
    try testing.expect(false == Min2B.eval(i15) catch false);
    try testing.expect(true == Min2B.eval(i16) catch false);
    try testing.expect(true == Min2B.eval(u16) catch false);
    try testing.expect(true == Min2B.eval(f16) catch false);
}

const InfoWithLenError = FilterError || IntervalError;

/// Expects array or vector type value.
///
/// `actual` is an array or vector type value, otherwise returns
/// error from `TypeWithInfo`.
///
/// `actual` type info `len` is within given `params`, otherwise returns error
/// from `IntWithinInterval`.
pub fn InfoWithLen(params: IntervalParams(comptime_int)) Term {
    const Error = ValueError || FilterError || IntervalError;

    const ValidInfo = TypeWithInfo(.{
        .array = true,
        .vector = true,
    });

    return .{
        .name = "InfoHasLen",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                // ValueError || FilterError
                _ = ValidInfo.eval(actual) catch |err| return err;

                const info = switch (@typeInfo(actual)) {
                    inline .array, .vector => |info| info,
                    else => unreachable,
                };

                // IntervalError
                _ = params.eval(info.len) catch |err| return err;

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, term: Term, actual: anytype) void {
                switch (@as(InfoWithLenError, err)) {
                    FilterError.InactiveInclusions,
                    FilterError.ActiveExclusion,
                    => ValidInfo.onError(err, term, actual),

                    IntervalError.ExceedsMin,
                    IntervalError.ExceedsMax,
                    => params.onError(err, term, actual),
                }
            }
        }.onError,
    };
}

test InfoWithLen {
    testing.log_level = .debug;
    const MinOneElem = InfoWithLen(.{ .min = 1 });

    try testing.expect(false == MinOneElem.eval(@Vector(0, i8)) catch false);
    try testing.expect(true == MinOneElem.eval(@Vector(1, bool)) catch false);

    const MaxTenElem = InfoWithLen(.{ .max = 10 });

    try testing.expect(true == MaxTenElem.eval(@Vector(3, usize)) catch false);
    try testing.expect(true == MaxTenElem.eval([10][11]usize) catch false);
    try testing.expect(false == MaxTenElem.eval([11][10]f64) catch false);
}

pub const InfoHasChild: Term = .{
    .name = "InfoHasChild",
    .eval = TypeWithInfo(.{
        .pointer = true,
        .optional = true,
        .array = true,
        .vector = true,
    }).eval,
    .onError = TypeWithInfo(.{
        .pointer = true,
        .optional = true,
        .array = true,
        .vector = true,
    }).onError,
};

test InfoHasChild {
    try testing.expect(true == try InfoHasChild.eval([3]usize));
    try testing.expect(true == try InfoHasChild.eval(?bool));
    try testing.expect(true == try InfoHasChild.eval(*const u8));
    try testing.expect(true == try InfoHasChild.eval([]volatile f128));
    try testing.expect(true == try InfoHasChild.eval(*struct {}));
    try testing.expect(true == try InfoHasChild.eval(@Vector(3, f16)));
}

/// Expects pointer, optional, array, or vector type value.
///
/// `actual` is a pointer, optional, array or vector type value, otherwise returns
/// error from `TypeWithInfo`.
///
/// given `ChildTerm` evaluates `actual` type info field `child` to true, otherwise
/// returns error from `ChildTerm`.
pub fn InfoWithChild(ChildTerm: Term) Term {
    const ValidInfo = TypeWithInfo(.{
        .pointer = true,
        .optional = true,
        .array = true,
        .vector = true,
    });
    return .{
        .name = "InfoWithChild",
        .eval = struct {
            fn eval(actual: anytype) anyerror!bool {
                // FilterError || ValueError
                _ = try InfoHasChild.eval(actual);
                //
                _ = try ChildTerm.eval(std.meta.Child(actual));
                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, term: Term, actual: anyerror) void {
                switch (err) {
                    ValueError.InvalidType,
                    FilterError.ActiveExclusion,
                    FilterError.InactiveInclusions,
                    => ValidInfo.onError(err, term, actual),

                    else => ChildTerm.onError(err, term, actual),
                }
            }
        }.onError,
    };
}

test InfoWithChild {
    const OptionalIntType = InfoWithChild(.{
        .name = "OptionalIntType",
        .eval = struct {
            fn eval(actual: anytype) !bool {
                return switch (@typeInfo(actual)) {
                    .int => true,
                    else => false,
                };
            }
        }.eval,
    });

    try testing.expect(true == OptionalIntType.eval(?i16) catch false);
    // try testing.expect(false == OptionalIntType.eval(?f16) catch false);
}

pub const IntInfoParams = struct {
    bits: IntervalParams(u16) = .{},
    signedness: ?std.builtin.Signedness = null,
};

const IntTypeError = error{
    InvalidSignedness,
} || FilterError || IntervalError;

/// Expects runtime int type value.
///
/// `actual` is runtime integer type value, otherwise returns error from
/// `TypeWithInfo`.
///
/// `actual` type info `bits` is within given `params`, otherwise returns error
/// from `InfoWithBits`.
///
/// `actual` type info `signedness` is equal to given `params`, otherwise returns
/// `IntTypeError.InvalidSignedness`.
pub fn IntType(params: IntInfoParams) Term {
    const Error = IntTypeError;

    const ValidType = TypeWithInfo(.{
        .int = true,
    });

    const IntBits = InfoWithBits(params.bits);

    return .{
        .name = "IntType",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                // ValueError || FilterError
                _ = ValidType.eval(actual) catch |err| return err;

                // IntervalError
                _ = IntBits.eval(actual) catch |err| return err;

                const info = switch (@typeInfo(actual)) {
                    .int => |info| info,
                    else => unreachable,
                };

                // InvalidSignedness
                if (!((params.signedness orelse info.signedness) == info.signedness)) return Error.InvalidSignedness;

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, term: Term, actual: anytype) void {
                switch (err) {
                    ValueError.InvalidType,
                    FilterError.ActiveExclusion,
                    FilterError.InactiveInclusions,
                    => ValidType.onError(err, term, actual),

                    IntervalError.ExceedsMin,
                    IntervalError.ExceedsMax,
                    => IntBits.onError(err, term, actual),

                    IntTypeError.InvalidSignedness,
                    => std.fmt.comptimePrint("{s}.{s} expects {s}, actual: {s}", .{
                        term.name,
                        @errorName(err),
                        @tagName(params.signedness),
                        @typeName(actual),
                    }),
                }
            }
        }.onError,
    };
}

test IntType {
    const SignedInt = IntType(
        .{ .signedness = .signed },
    );

    try testing.expect(true == SignedInt.eval(i16) catch false);
    try testing.expect(true == SignedInt.eval(i128) catch false);
    try testing.expect(false == SignedInt.eval(usize) catch false);
    try testing.expect(false == SignedInt.eval(f16) catch false);
}

pub const FloatInfoParams = struct {
    bits: IntervalParams(u16) = .{},
};

/// Expects runtime float type value.
///
/// `actual` is runtime float type value, otherwise returns error from
/// `TypeWithInfo`.
///
/// `actual` type info `bits` is within given `params`, otherwise returns error
/// from `InfoWithBits`.
pub fn FloatType(params: FloatInfoParams) Term {
    const Error = ValueError || FilterError || IntervalError;
    const ValidType = TypeWithInfo(.{
        .float = true,
    });

    const FloatBits = InfoWithBits(params.bits);

    return .{
        .name = "FloatType",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                // ValueError || FilterError
                _ = try ValidType.eval(actual);
                // IntervalError
                _ = try FloatBits.eval(actual);
                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, term: Term, actual: anytype) void {
                switch (@as(IntTypeError, err)) {
                    ValueError.InvalidType,
                    FilterError.ActiveExclusion,
                    FilterError.InactiveInclusions,
                    => ValidType.onError(err, term, actual),

                    IntervalError.ExceedsMin,
                    IntervalError.ExceedsMax,
                    => FloatBits.onError(err, term, actual),
                }
            }
        }.onError,
    };
}

test FloatType {
    const Float32 = FloatType(.{
        .bits = .{
            .min = 32,
            .max = 32,
        },
    });

    try testing.expect(false == Float32.eval(f16) catch false);
    try testing.expect(true == Float32.eval(f32) catch false);
    try testing.expect(false == Float32.eval(f128) catch false);
}

/// - `null`, no preference
/// - `true`, belongs to whitelist, at least one element of whitelist
///   is expected, "pseudo-`union`"
/// - `false`, belongs to blacklist, element should not be used
const SizeParams = struct {
    one: ?bool = null,
    many: ?bool = null,
    slice: ?bool = null,
    c: ?bool = null,

    pub fn eval(self: SizeParams, comptime size: std.builtin.Type.Pointer.Size) PointerTypeError!bool {
        if (@field(self, @tagName(size))) |param| {
            if (!param) return PointerTypeError.UsesInvalidSize;
            return true;
        }

        inline for (std.meta.fields(@TypeOf(self))) |field| {
            if (@field(self, field.name)) |value| {
                if (value) return PointerTypeError.IgnoresValidSizes;
            }
        }
        return true;
    }

    pub fn onError(err: anyerror, term: Term, actual: anytype) void {
        switch (err) {
            PointerTypeError.ActiveExclusion,
            PointerTypeError.InactiveInclusions,
            => @compileError(std.fmt.comptimePrint(
                "{s}.{s}: {s}",
                .{
                    term.name,
                    @errorName(err),
                    @tagName(actual),
                },
            )),
        }
    }
};

pub const PointerInfoParams = struct {
    size: SizeParams = .{},
    /// - `null`, no preference
    /// - `true`, pointer must be `const` qualified
    /// - `false`, pointer must _not_ be `const` qualified
    is_const: ?bool = null,
    /// - `null`, no preference
    /// - `true`, pointer must be `volatile` qualified
    /// - `false`, pointer must _not_ be `volatile` qualified
    is_volatile: ?bool = null,
    /// - `null`, no preference
    /// - `true`, pointer must have a sentinel element
    /// - `false`, pointer must _not_ have a sentinel element
    sentinel: ?bool = null,
};

const PointerTypeError = error{
    UsesInvalidSize,
    IgnoresValidSizes,
    InvalidConstQualifier,
    InvalidVolatileQualifier,
    InvalidSentinel,
} || ValueError || FilterError;

/// Expects pointer type value.
///
/// Evaluates:
///
/// Passes pointer type into `TypeWithInfo`, returns associated errors.
///
/// `actual` active tag of `size` belongs to the set of `InfoParams` fields
/// set to true, otherwise returns `PointerTypeError.IgnoresNeeded`.
///
/// `actual` active tag of `Type` does not belong to the set of `InfoParams` fields
/// set to false, otherwise returns `PointerTypeError.InvalidSize`.
///
/// `actual` type info `is_const` is equal to given params, otherwise
/// returns `PointerTypeError.InvalidConstQualifier`.
///
/// `actual` type info `is_volatile` is equal to given params, otherwise
/// returns `PointerTypeError.InvalidVolatileQualifier`.
///
/// `actual` type info `sentinel()` is not-null when given params is true or null
/// when given params is false, otherwise returns
/// `PointerTypeError.InvalidSentinel`.
pub fn PointerType(params: PointerInfoParams) Term {
    const Error = PointerTypeError;
    const ValidInfo = TypeWithInfo(.{
        .pointer = true,
    });

    return .{
        .name = "PointerType",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                // ValueError || FilterError
                _ = try ValidInfo.eval(actual);

                const info = switch (@typeInfo(actual)) {
                    .pointer => |info| info,
                    else => unreachable,
                };

                _ = try params.size.eval(info.size);

                if (params.is_const) |is_const|
                    if (info.is_const != is_const) return PointerTypeError.InvalidConstQualifier;
                if (params.is_volatile) |is_const|
                    if (info.is_const != is_const) return PointerTypeError.InvalidVolatileQualifier;
                if (params.sentinel) |sentinel|
                    if (sentinel != if (info.sentinel()) |_| true else false)
                        return PointerTypeError.InvalidSentinel;

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, term: Term, actual: anytype) void {
                switch (@as(PointerTypeError, err)) {
                    ValueError.InvalidType,
                    FilterError.ActiveExclusion,
                    FilterError.InactiveInclusions,
                    => ValidInfo.onError(err, term, actual),

                    PointerTypeError.UsesExcludedPointerSize,
                    PointerTypeError.IgnoresNeededPointerSizes,
                    => params.size.onError(err, term, actual),

                    PointerTypeError.InvalidConstQualifier,
                    => std.fmt.comptimePrint("{s}.{s} expects {s}", .{
                        term.name,
                        @errorName(err),
                        if (params.is_const.?) "const" else "const omitted",
                    }),
                    PointerTypeError.InvalidVolatileQualifier,
                    => std.fmt.comptimePrint("{s}.{s} expects {s}", .{
                        term.name,
                        @errorName(err),
                        if (params.is_const.?) "volatile" else "volatile omitted",
                    }),
                    PointerTypeError.InvalidSentinel,
                    => std.fmt.comptimePrint("{s}.{s} expects {s}", .{
                        term.name,
                        @errorName(err),
                        if (params.is_const.?) "sentinel value" else "sentinel value omitted",
                    }),
                }
            }
        }.onError,
    };
}

test PointerType {
    const ConstPointer = PointerType(.{
        .is_const = true,
    });

    try testing.expect(true == ConstPointer.eval(*const struct {}) catch false);
    try testing.expect(true == ConstPointer.eval([]const u8) catch false);
    try testing.expect(true == ConstPointer.eval([*]const @Vector(3, usize)) catch false);
    try testing.expect(false == ConstPointer.eval([]i16) catch false);
    try testing.expect(false == ConstPointer.eval(*bool) catch false);
}

pub const SlicePointerTypeParams = struct {
    is_const: ?bool = null,
    is_volatile: ?bool = null,
    sentinel: ?bool = null,
};

/// Expects slice type value.
///
/// `actual` is slice pointer type value, otherwise returns error
/// from `PointerType`
pub fn SlicePointerType(params: SlicePointerTypeParams) Term {
    _ = PointerTypeError;

    const ValidPointerType = PointerType(.{
        .size = .{
            .slice = true,
        },
        .is_const = params.is_const,
        .is_volatile = params.is_volatile,
        .sentinel = params.sentinel,
    });

    return .{
        .name = "SlicePointerType",
        .eval = ValidPointerType.eval,
        .onFail = ValidPointerType.onFail,
    };
}

test SlicePointerType {
    const SliceType = SlicePointerType(.{});

    try testing.expect(false == SliceType.eval(*const struct {}) catch false);
    try testing.expect(true == SliceType.eval([]const u8) catch false);
    try testing.expect(false == SliceType.eval([*]const @Vector(3, usize)) catch false);
    try testing.expect(true == SliceType.eval([]i16) catch false);
    try testing.expect(false == SliceType.eval(*bool) catch false);
}

pub const SlicePointerParams = struct {
    info: SlicePointerTypeParams = .{},
    len: IntervalParams(usize) = .{},
};

/// Expects slice value.
///
/// `actual` is slice pointer value, otherwise returns error
/// from `SlicePointerType`
///
/// `actual` type info `len` is within given params, otherwise
/// returns error from `InfoWithLen`
pub fn SlicePointer(params: SlicePointerParams) Term {
    const Error = PointerTypeError;

    const ValidSliceType = SlicePointerType(params.info);
    const ValidLen = IntWithinInterval(usize, params.len);

    return .{
        .name = "SlicePointer",
        .eval = struct {
            fn eval(actual: anytype) Error!bool {
                // ValueError || FilterError
                _ = ValidSliceType.eval(@TypeOf(actual)) catch |err| return err;
                // IntervalError
                _ = ValidLen.eval(actual.len) catch |err| return err;
                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, term: Term, actual: anytype) void {
                switch (err) {
                    ValueError.InvalidType,
                    FilterError.ActiveExclusion,
                    FilterError.InactiveInclusions,
                    => ValidSliceType.onError(err, term, actual),

                    IntervalError.ExceedsMin,
                    IntervalError.ExceedsMax,
                    => ValidLen.onError(err, term, actual),
                }
            }
        }.onError,
    };
}

test SlicePointer {
    const Slice = SlicePointer(.{
        .info = .{
            .is_const = true,
        },
        .len = .{
            .min = 5,
        },
    });

    try testing.expect(true == Slice.eval(@as([]const u8, "hello")) catch false);
}

test {
    testing.refAllDecls(@This());
}
