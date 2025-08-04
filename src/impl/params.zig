//! Parameter definitions and generation to be used in Terms
//! to automate away some boilerplate
const std = @import("std");
const testing = std.testing;
const meta = std.meta;

const Type = std.builtin.Type;

fn isSupported(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .comptime_int,
        .comptime_float,
        .int,
        .float,
        .bool,
        .@"struct",
        .@"enum",
        .@"union",
        .pointer,
        .array,
        .vector,
        .optional,
        => true,
        else => false,
    };
}

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
pub fn FieldsToToggles(comptime T: type) type {
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

test FieldsToToggles {
    const SomeEnum = enum { a, b, c, d, e };

    const enum_params: FieldsToToggles(SomeEnum) = .{};

    try testing.expect(?bool == @TypeOf(enum_params.a));
    try testing.expect(?bool == @TypeOf(enum_params.b));
    try testing.expect(?bool == @TypeOf(enum_params.c));
    try testing.expect(?bool == @TypeOf(enum_params.d));
    try testing.expect(?bool == @TypeOf(enum_params.e));
}

/// Creates a struct type where fields of argument are converted
/// to its 'parametric' equivalent
pub fn FieldsToParams(comptime T: type) type {
    return @Type(.{
        .@"struct" = .{
            .is_tuple = false,
            .decls = &[_]Type.Declaration{},
            .layout = .auto,
            .fields = fields: {

                // count valid paramatric types
                var new_field_count: usize = 0;

                inline for (0..meta.fields(T).len) |field_index| {
                    const field = meta.fields(T)[field_index];
                    if (ParamType(field.type) == void) continue;
                    new_field_count += 1;
                }

                if (new_field_count == 0) return void;

                var temp_fields: [new_field_count]Type.StructField = undefined;
                var temp_fields_index: usize = 0;

                inline for (0..meta.fields(T).len) |field_index| {
                    const field = meta.fields(T)[field_index];

                    const param_type = if (ParamType(field.type) != void) ParamType(field.type) else continue;
                    if (!isSupported(field.type)) continue;

                    const default_value_ptr = getDefaultValuePtr(field.type);

                    temp_fields[temp_fields_index] = .{
                        .name = field.name,
                        .type = param_type,
                        .alignment = field.alignment,
                        .is_comptime = false,
                        .default_value_ptr = default_value_ptr,
                    };

                    temp_fields_index += 1;
                }
                break :fields &temp_fields;
            },
        },
    });
}

test FieldsToParams {
    const SomeStruct = struct {
        foo: []const u8,
        bar: f128,
    };

    const some_struct_params: FieldsToParams(SomeStruct) = .{};

    try testing.expect(ParamType(u8) == @TypeOf(some_struct_params.foo));
    try testing.expect(FloatRange == @TypeOf(some_struct_params.bar));
}

fn ParamType(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .comptime_int, .int => IntRange,
        .comptime_float, .float => FloatRange,
        .bool => ?bool,
        inline .pointer, .optional, .vector, .array => |info| ParamType(info.child),
        inline .@"union", .@"struct" => FieldsToParams(T),
        .@"enum" => FieldsToToggles(T),
        else => void,
    };
}

test ParamType {
    try testing.expect(IntRange == ParamType(usize));
    try testing.expect(FloatRange == ParamType(f128));
    try testing.expect(?bool == ParamType(bool));
}

fn getDefaultValuePtr(comptime T: type) ?*const anyopaque {
    return switch (@typeInfo(T)) {
        .comptime_int, .int => @ptrCast(@as(*const IntRange, &.{})),
        .comptime_float, .float => @ptrCast(@as(*const FloatRange, &.{})),
        .bool => @ptrCast(@as(*const ?bool, &null)),
        .pointer, .array, .vector, .optional => getDefaultValuePtr(std.meta.Child(T)),
        .@"struct", .@"union" => @ptrCast(@as(*const (FieldsToParams(T)), &.{})),
        .@"enum" => @ptrCast(@as(*const FieldsToToggles(T), &.{})),
        else => void{},
    };
}
