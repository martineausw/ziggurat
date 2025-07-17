//! Parameter definitions and generation to be used in Terms.
//!
//!
const std = @import("std");
const meta = std.meta;

const Type = std.builtin.Type;

/// Parametric specification of an integer with
/// inclusive min and max values with a divisible
/// field, `step`
pub const Int = struct {
    type: ?type = null,
    min: ?comptime_int = null,
    max: ?comptime_int = null,
    div: ?comptime_int = null,
};

/// Parametric specification of a float with
/// inclusive min and max values and a tolerance field, `err`
pub const Float = struct {
    type: ?type = null,
    min: ?comptime_float = null,
    max: ?comptime_float = null,
    err: comptime_float = 0.001,
};

pub const Bool = ?bool;

/// Creates a type where fields of input type are converted
/// to `?bool` to explicitly specify allowance of enum values
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
                    .type = Bool,
                    .alignment = meta.alignment(@typeInfo(T).@"enum".tag_type),
                    .is_comptime = false,
                    .default_value_ptr = @ptrCast(@as(*const Bool, &null)),
                };
            }
            break :fields &temp_fields;
        },
    } });
}

pub fn Field(comptime T: type) type {
    return struct {
        expr: *const fn (comptime T) T,
    };
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
                        .comptime_int, .int => @ptrCast(@as(*const Int, &.{})),
                        .comptime_float, .float => @ptrCast(@as(*const Float, &.{})),
                        .bool => @ptrCast(@as(*const Bool, &null)),
                        .@"struct" => @ptrCast(@as(*const (Fields(field.type)), &.{})),
                        .@"union" => @ptrCast(@as(*const (Fields(field.type)), &.{})),
                        .@"enum" => @ptrCast(@as(*const Filter(field.type), &.{})),
                        .pointer => switch (@typeInfo(@typeInfo(field.type).pointer.child)) {
                            .comptime_int, .int => @ptrCast(@as(*const Int, &.{ .type = @typeInfo(field.type).pointer.child })),
                            .comptime_float, .float => @ptrCast(@as(*const Float, &.{ .type = @typeInfo(field.type).pointer.child })),
                            .bool => @ptrCast(@as(*const Bool, &null)),
                            .@"struct" => @ptrCast(@as(*const Fields(@typeInfo(field.type).pointer.child), &.{})),
                            .@"union" => @ptrCast(@as(*const Fields(@typeInfo(field.type).pointer.child), &.{})),
                            .@"enum" => @ptrCast(@as(*const Filter(@typeInfo(field.type).pointer.child), &.{})),
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

fn Value(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .comptime_int, .int => Int,
        .comptime_float, .float => Float,
        .bool => Bool,
        .pointer => |info| switch (@typeInfo(info.child)) {
            .@"opaque" => void,
            else => Value(info.child),
        },
        .optional => |info| Value(info.child),
        .vector => |info| Value(info.child),
        .array => |info| Value(info.child),
        .@"union" => Fields(T),
        .@"struct" => Fields(T),
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
