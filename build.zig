const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const contract_mod = b.createModule(.{
        .root_source_file = b.path("src/contract.zig"),
        .target = target,
        .optimize = optimize,
    });

    const params_mod = b.createModule(.{
        .root_source_file = b.path("src/impl/params.zig"),
        .target = target,
        .optimize = optimize,
    });

    const terms_mod = b.createModule(.{
        .root_source_file = b.path("src/impl/terms.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "contract", .module = contract_mod }},
    });

    const impl_mod = b.createModule(.{ .root_source_file = b.path("src/impl.zig"), .target = target, .optimize = optimize, .imports = &.{
        .{ .name = "params", .module = params_mod },
        .{ .name = "terms", .module = terms_mod },
    } });

    lib_mod.addImport("impl", impl_mod);
    lib_mod.addImport("contract", contract_mod);

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "ziggurat",
        .root_module = lib_mod,
    });

    b.installArtifact(lib);

    const lib_unit_tests = b.addTest(.{
        .root_module = lib_mod,
        .target = target,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
