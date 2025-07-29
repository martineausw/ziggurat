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
    });

    const impl_mod = b.createModule(.{
        .root_source_file = b.path("src/impl.zig"),
        .target = target,
        .optimize = optimize,
    });

    terms_mod.addImport("contract", contract_mod);
    terms_mod.addImport("params", params_mod);

    impl_mod.addImport("terms", terms_mod);
    impl_mod.addImport("params", params_mod);

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

    const params_unit_tests = b.addTest(.{
        .root_module = params_mod,
        .target = target,
    });

    const terms_unit_tests = b.addTest(.{
        .root_module = terms_mod,
        .target = target,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const run_terms_unit_tests = b.addRunArtifact(terms_unit_tests);
    const run_params_unit_tests = b.addRunArtifact(params_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_terms_unit_tests.step);
    test_step.dependOn(&run_params_unit_tests.step);
}
