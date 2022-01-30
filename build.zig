const std = @import("std");

pub fn build(b: *std.build.Builder) void {
    const lib = b.addSharedLibrary("lingword", "src/main.zig", .unversioned);
    lib.setTarget(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
    lib.setBuildMode(.ReleaseSmall);

    lib.import_memory = true;
    lib.initial_memory = 65536;
    lib.max_memory = 65536;
    lib.global_base = 6560;
    lib.stack_size = 8192;

    lib.install();
}
