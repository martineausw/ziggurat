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

const IsTypeError = error{
    UnexpectedType,
};

const IsType: Term = .{
    .name = "IsType",
    .eval = struct {
        fn eval(actual: anytype) IsTypeError!bool {
            return switch (@typeInfo(@TypeOf(actual))) {
                .type => true,
                else => IsTypeError.UnexpectedType,
            };
        }
    }.eval,
    .onError = struct {
        fn onErr(err: anyerror, term: Term, actual: anytype) void {
            switch (err) {
                .InvalidArgument => @compileError(std.fmt.comptimePrint(
                    "{s}.{s} expects `type`, actual: {s}",
                    .{
                        term.name,
                        @errorName(err),
                        @typeName(@TypeOf(actual)),
                    },
                )),
                else => @panic(std.fmt.comptimePrint("{s}.{s}: unhandled error", .{ term.name, @errorName(err) })),
            }
        }
    }.onErr,
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

pub fn RangeParams(comptime T: type) type {
    _ = TypeWithInfo(.{ .int = true, .comptime_int = true }).eval(T) catch
        @compileError("RangeParams: unexpected type");

    return struct {
        min: ?T = null,
        max: ?T = null,
    };
}

const ValuesWithinRangeError = error{ Under, Over };

pub fn ValueWithinRange(comptime T: type, params: RangeParams(T)) Term {
    return .{
        .name = "ValueWithinRange",
        .eval = struct {
            fn eval(actual: anytype) ValuesWithinRangeError!bool {
                if ((params.min orelse actual) > actual) return ValuesWithinRangeError.Under;
                if ((params.max orelse actual) < actual) return ValuesWithinRangeError.Over;
                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, term: Term, actual: anytype) void {
                switch (@as(ValuesWithinRangeError, err)) {
                    .Under => @compileError(std.fmt.comptimePrint("{s}.{s}: min: {d} > @as({s}, {d})", .{
                        term.name,
                        @errorName(err),
                        params.min.?,
                        @typeName(T),
                        actual,
                    })),
                    .Over => @compileError(std.fmt.comptimePrint("{s}.{s}: max: {d} > @as({s}, {d})", .{
                        term.name,
                        @errorName(err),
                        params.max.?,
                        @typeName(T),
                        actual,
                    })),
                    else => @panic(std.fmt.comptimePrint("{s}: unexpected error", .{term.name})),
                }
            }
        }.onError,
    };
}

test ValueWithinRange {
    const IntRange: Term = ValueWithinRange(usize, .{
        .min = @as(usize, 1),
        .max = @as(usize, 2),
    });

    try testing.expect(false == IntRange.eval(0) catch false);
    try testing.expect(true == try IntRange.eval(1));
    try testing.expect(true == try IntRange.eval(2));
    try testing.expect(false == IntRange.eval(3) catch false);
}

const InfoParams = struct {
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
};

const TypesWithInfoError = error{
    UnsatisfiedBlacklist,
    UnsatisfiedWhitelist,
};

pub fn TypeWithInfo(params: InfoParams) Term {
    return .{
        .name = "TypeWithInfo",
        .eval = struct {
            fn eval(actual: anytype) TypesWithInfoError!bool {
                _ = try IsType.eval(actual);

                // fail at blacklisted field
                if (@field(params, @tagName(@typeInfo(actual)))) |param| {
                    if (!param) return TypesWithInfoError.UnsatisfiedBlacklist;
                    return true;
                }

                // fail at unused whitelist
                inline for (std.meta.fields(@TypeOf(params))) |field| {
                    if (@field(params, field.name)) |param_field| {
                        if (param_field) return false;
                    }
                }

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, term: Term, actual: anytype) void {
                switch (@as(TypesWithInfoError, err)) {
                    .UnsatisfiedBlacklist => @compileError(std.fmt.comptimePrint(
                        "{s}.{s}: {s}",
                        .{
                            term.name,
                            @errorName(err),
                            @tagName(@typeInfo(actual)),
                        },
                    )),
                    .UnsatisfiedWhitelist => @compileError(std.fmt.comptimePrint(
                        "{s}.{s}: {s}",
                        .{
                            term.name,
                            @errorName(err),
                            @tagName(@typeInfo(actual)),
                        },
                    )),
                    else => @panic(std.fmt.comptimePrint("{s}: unexpected error", .{@errorName(err)})),
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

const InfoWithBitsError = TypesWithInfoError || ValuesWithinRangeError;

pub fn InfoWithBits(params: RangeParams(u16)) Term {
    const ValidInfo = TypeWithInfo(.{
        .int = true,
        .float = true,
    });

    const ValidBitRange = ValueWithinRange(u16, params);

    return .{
        .name = "InfoWithBits",
        .eval = struct {
            /// assumes actual is `type`
            fn eval(actual: anytype) InfoWithBitsError!bool {
                _ = try ValidInfo.eval(actual);

                const info = switch (@typeInfo(actual)) {
                    inline .int, .float => |info| info,
                    else => unreachable,
                };

                _ = try ValidBitRange.eval(info.bits);

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, term: Term, actual: anytype) void {
                switch (@as(InfoWithBitsError, err)) {
                    .UnsatisfiedWhitelist, .UnsatisfiedBlacklist => ValidInfo.onError(err, term, actual),
                    .Over, .Under => ValidBitRange.onError(err, term, actual),
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

const InfoWithLenError = TypesWithInfoError || ValuesWithinRangeError;

pub fn InfoWithLen(params: RangeParams(comptime_int)) Term {
    const ValidInfo = TypeWithInfo(.{
        .array = true,
        .vector = true,
    });

    const ValidLenRange = ValueWithinRange(comptime_int, params);

    return .{
        .name = "InfoHasLen",
        .eval = struct {
            fn eval(actual: anytype) InfoWithLenError!bool {
                _ = try ValidInfo.eval(actual);

                const info = switch (@typeInfo(actual)) {
                    inline .array, .vector => |info| info,
                    else => unreachable,
                };

                _ = try ValidLenRange.eval(info.len);

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, term: Term, actual: anytype) void {
                switch (@as(InfoWithLenError, err)) {
                    .UnsatisfiedWhitelist, .UnsatisfiedBlacklist => ValidInfo.onError(err, term, actual),
                    .Over, .Under => ValidLenRange.onError(err, term, actual),
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

const InfoHasChild: Term = .{
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

pub fn InfoWithChild(ChildTerm: Term) Term {
    const ValidInfo = TypeWithInfo(.{
        .pointer = true,
        .optional = true,
        .array = true,
        .vector = true,
    });
    return .{
        .name = "ApplyToChildType",
        .eval = struct {
            fn eval(actual: anytype) anyerror!bool {
                _ = try InfoHasChild.eval(actual);
                _ = try ChildTerm.eval(std.meta.Child(actual));
                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, term: Term, actual: anyerror) void {
                switch (err) {
                    .UnsatisfiedBlacklist, .UnsatisfiedWhitelist => ValidInfo.onError(err, term, actual),
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

const IntInfoParams = struct {
    bits: RangeParams(u16) = .{},
    signedness: ?std.builtin.Signedness = null,
};

const IntTypeError = error{IncorrectSignedness} || TypesWithInfoError || ValuesWithinRangeError;

pub fn IntType(params: IntInfoParams) Term {
    const ValidType = TypeWithInfo(.{
        .int = true,
    });

    const ValidBitRange = InfoWithBits(params.bits);

    return .{
        .name = "TypeIsInt",
        .eval = struct {
            fn eval(actual: anytype) !bool {
                _ = try ValidType.eval(actual);

                _ = try ValidBitRange.eval(actual);

                const info = switch (@typeInfo(actual)) {
                    .int => |info| info,
                    else => return error.UnexpectedType,
                };

                if ((params.signedness orelse info.signedness) != info.signedness) return IntTypeError.IncorrectSignedness;

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, term: Term, actual: anytype) void {
                switch (@as(IntTypeError, err)) {
                    .IncorrectSignedness => std.fmt.comptimePrint("{s}.{s} expects {s}, actual: {s}", .{
                        term.name,
                        @errorName(err),
                        @tagName(params.signedness),
                        @typeName(actual),
                    }),
                    .UnsatisfiedBlacklist, .UnsatisfiedWhitelist => ValidType.onError(err, term, actual),
                    .Over, .Under => ValidBitRange.onError(err, term, actual),
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

const FloatInfoParams = struct {
    bits: RangeParams(u16) = .{},
};

pub fn FloatType(params: FloatInfoParams) Term {
    const ValidType = TypeWithInfo(.{
        .float = true,
    });

    const ValidBitRange = InfoWithBits(params.bits);

    return .{
        .name = "TypeIsFloat",
        .eval = struct {
            fn eval(actual: anytype) !bool {
                _ = try ValidType.eval(actual);
                _ = try ValidBitRange.eval(actual);
                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, term: Term, actual: anytype) void {
                switch (@as(IntTypeError, err)) {
                    .IncorrectSignedness => std.fmt.comptimePrint("{s}.{s} expects {s}, actual: {s}", .{
                        term.name,
                        @errorName(err),
                        @tagName(params.signedness),
                        @typeName(actual),
                    }),
                    .UnsatisfiedBlacklist, .UnsatisfiedWhitelist => ValidType.onError(err, term, actual),
                    .Over, .Under => ValidBitRange.onError(err, term, actual),
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
const Size = struct {
    one: ?bool = null,
    many: ?bool = null,
    slice: ?bool = null,
    c: ?bool = null,
};

const PointerInfoParams = struct {
    size: Size = .{},
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

const PointerTypeError = error{ IncorrectConst, IncorrectVolatile, IncorrectSentinel } || TypesWithInfoError;

pub fn PointerType(params: PointerInfoParams) Term {
    const ValidInfo = TypeWithInfo(.{
        .pointer = true,
    });

    return .{
        .name = "TypeIsPointer",
        .eval = struct {
            fn eval(actual: anytype) !bool {
                _ = try ValidInfo.eval(actual);

                const info = switch (@typeInfo(actual)) {
                    .pointer => |info| info,
                    else => unreachable,
                };

                if (@field(params.size, @tagName(info.size))) |param| {
                    if (!param) return TypesWithInfoError.UnsatisfiedBlacklist;
                    return true;
                }

                // fail at unused whitelist
                inline for (std.meta.fields(@TypeOf(params.size))) |field| {
                    if (@field(params.size, field.name)) |param_field| {
                        if (param_field) return TypesWithInfoError.UnsatisfiedWhitelist;
                    }
                }

                if (params.is_const) |is_const| if (info.is_const != is_const) return PointerTypeError.IncorrectConst;
                if (params.is_volatile) |is_const| if (info.is_const != is_const) return PointerTypeError.IncorrectVolatile;
                if (params.sentinel) |sentinel|
                    if (sentinel != if (info.sentinel()) |_| true else false) return PointerTypeError.IncorrectSentinel;

                return true;
            }
        }.eval,
        .onError = struct {
            fn onError(err: anyerror, term: Term, actual: anytype) void {
                switch (@as(PointerTypeError, err)) {
                    .UnsatisfiedBlacklist, .UnsatisfiedWhitelist => ValidInfo.onError(err, term, actual),
                    .IncorrectConst => std.fmt.comptimePrint("{s}.{s} expects {s}", .{
                        term.name,
                        @errorName(err),
                        if (params.is_const.?) "const" else "const omitted",
                    }),
                    .IncorrectVolatile => std.fmt.comptimePrint("{s}.{s} expects {s}", .{
                        term.name,
                        @errorName(err),
                        if (params.is_const.?) "volatile" else "volatile omitted",
                    }),
                    .IncorrectSentinel => std.fmt.comptimePrint("{s}.{s} expects {s}", .{
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

const SlicePointerTypeParams = struct {
    is_const: ?bool = null,
    is_volatile: ?bool = null,
    sentinel: ?bool = null,
};

pub fn SlicePointerType(params: SlicePointerTypeParams) Term {
    const ValidPointerType = PointerType(.{
        .size = .{
            .slice = true,
            .many = false,
            .c = false,
            .one = false,
        },
        .is_const = params.is_const,
        .is_volatile = params.is_volatile,
        .sentinel = params.sentinel,
    });

    return .{
        .name = "TypeIsSlice",
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

const SlicePointerParams = struct {
    info: SlicePointerTypeParams = .{},
    len: RangeParams(usize) = .{},
};

pub fn SlicePointer(params: SlicePointerParams) Term {
    const ValidSliceType = SlicePointerType(params.info);
    const ValidLenRange = ValueWithinRange(usize, params.len);

    return .{ .name = "TypeIsSlice", .eval = struct {
        fn eval(actual: anytype) !bool {
            _ = try ValidSliceType.eval(@TypeOf(actual));
            _ = try ValidLenRange.eval(actual.len);
            return true;
        }
    }.eval, .onError = struct {
        fn onError(err: anyerror, term: Term, actual: anytype) void {
            switch (err) {
                .UnsatisfiedBlacklist, .UnsatisfiedWhitelist => ValidSliceType.onError(err, term, actual),
                .Over, .Under => ValidLenRange.onError(err, term, actual),
                else => @panic("unexpected error"),
            }
        }
    }.onError };
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
