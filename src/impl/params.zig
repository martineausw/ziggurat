//! Parameter definitions and generation to be used in Terms
//! to automate away some boilerplate
const std = @import("std");
const testing = std.testing;
const meta = std.meta;

const Type = std.builtin.Type;

/// Parametric specification of an integer with
/// inclusive min and max values with a divisible
/// field, `step`
pub const IntRange = struct {
    min: ?comptime_int = null,
    max: ?comptime_int = null,
    div: ?comptime_int = null,
};

test IntRange {
    const int_params: IntRange = .{};
    try testing.expect(?comptime_int == @TypeOf(int_params.min));
    try testing.expect(?comptime_int == @TypeOf(int_params.max));
    try testing.expect(?comptime_int == @TypeOf(int_params.div));
}

/// Parametric specification of a float with
/// inclusive min and max values and a tolerance field, `err`
pub const FloatRange = struct {
    min: ?comptime_float = null,
    max: ?comptime_float = null,
    err: comptime_float = 0.001,
};

test FloatRange {
    const float_params: FloatRange = .{};
    try testing.expect(?comptime_float == @TypeOf(float_params.min));
    try testing.expect(?comptime_float == @TypeOf(float_params.max));
    try testing.expect(comptime_float == @TypeOf(float_params.err));
}

/// Creates a struct fields from input type with fields of the same name
/// of optional bool types (`?bool`) to explicitly specify valid enum values
pub fn Filter(comptime T: type) type {
    return @Type(.{ .@"struct" = .{
        .is_tuple = false,
        .decls = &[_]Type.Declaration{},
        .layout = .auto,
        .fields = fields: {
            var temp_fields: [meta.fields(T).len]Type.StructField = undefined;
            for (0..meta.fields(T).len) |field_index| {
                const field = meta.fields(T)[field_index];

                temp_fields[field_index] = .{
                    .name = field.name,
                    .type = ?bool,
                    .alignment = meta.alignment(@typeInfo(T).@"enum".tag_type),
                    .is_comptime = false,
                    .default_value_ptr = @ptrCast(@as(*const ?bool, &null)),
                };
            }
            break :fields &temp_fields;
        },
    } });
}

test Filter {
    const SomeEnum = enum { a, b, c, d, e };

    const enum_params: Filter(SomeEnum) = .{};

    try testing.expect(?bool == @TypeOf(enum_params.a));
    try testing.expect(?bool == @TypeOf(enum_params.b));
    try testing.expect(?bool == @TypeOf(enum_params.c));
    try testing.expect(?bool == @TypeOf(enum_params.d));
    try testing.expect(?bool == @TypeOf(enum_params.e));
}

/// Creates a struct type where fields of argument are converted
/// to its 'parametric' equivalent
pub fn Fields(comptime T: type) type {
    return @Type(.{
        .@"struct" = .{
            .is_tuple = false,
            .decls = &[_]Type.Declaration{},
            .layout = .auto,
            .fields = fields: {

                // count valid paramatric types
                comptime var new_field_count: usize = 0;

                inline for (0..meta.fields(T).len) |field_index| {
                    const field = meta.fields(T)[field_index];
                    const paratype = Value(field.type);
                    if (paratype == void) continue;
                    new_field_count += 1;
                }

                if (new_field_count == 0) return void;

                comptime var temp_fields: [new_field_count]Type.StructField = undefined;
                comptime var temp_fields_index: usize = 0;

                inline for (0..meta.fields(T).len) |field_index| {
                    const field = meta.fields(T)[field_index];
                    const paratype = Value(field.type);
                    if (paratype == void) continue;

                    const new_default_value_ptr: ?*const anyopaque = switch (@typeInfo(field.type)) {
                        .comptime_int, .int => @ptrCast(@as(*const IntRange, &.{})),
                        .comptime_float, .float => @ptrCast(@as(*const FloatRange, &.{})),
                        .bool => @ptrCast(@as(*const ?bool, &null)),

                        inline .@"struct",
                        .@"union",
                        => @ptrCast(@as(*const (Fields(field.type)), &.{})),

                        .@"enum" => @ptrCast(@as(*const Filter(field.type), &.{})),

                        .pointer => switch (@typeInfo(@typeInfo(field.type).pointer.child)) {
                            .comptime_int, .int => @ptrCast(@as(*const IntRange, &.{})),
                            .comptime_float, .float => @ptrCast(@as(*const FloatRange, &.{})),
                            .bool => @ptrCast(@as(*const ?bool, &null)),
                            inline .@"struct",
                            .@"union",
                            .@"enum",
                            => @ptrCast(@as(*const Filter(@typeInfo(field.type).pointer.child), &.{})),
                            else => continue,
                        },
                        else => continue,
                    };

                    temp_fields[temp_fields_index] = .{
                        .name = field.name,
                        .type = paratype,
                        .alignment = field.alignment,
                        .is_comptime = false,
                        .default_value_ptr = new_default_value_ptr,
                    };

                    temp_fields_index += 1;
                }
                break :fields &temp_fields;
            },
        },
    });
}

test Fields {
    const SomeStruct = struct {
        foo: []const u8,
        bar: f128,
    };

    const some_struct_params: Fields(SomeStruct) = .{};

    try testing.expect(Value(u8) == @TypeOf(some_struct_params.foo));
    try testing.expect(FloatRange == @TypeOf(some_struct_params.bar));
}

fn Value(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .comptime_int, .int => IntRange,
        .comptime_float, .float => FloatRange,
        .bool => ?bool,
        inline .pointer, .optional, .vector, .array => |info| Value(info.child),
        inline .@"union", .@"struct" => Fields(T),
        .@"enum" => Filter(T),
        .type => void,
        .null => void,
        .undefined => void,
        .void => void,
        .noreturn => void,
        .@"opaque" => void,
        .@"fn" => void,
        .@"anyframe" => void,
        .frame => void,
        .error_set => void,
        .error_union => void,
        .enum_literal => void,
    };
}

test Value {
    try testing.expect(IntRange == Value(usize));
    try testing.expect(FloatRange == Value(f128));
    try testing.expect(?bool == Value(bool));
}
