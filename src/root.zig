//! 0.14.1 microlibrary to introduce type constraints.

pub const impl = struct {
    pub const terms = @import("impl/terms").zig;
    pub const params = @import("impl/params").zig;
};

pub const contract = @import("contract.zig");
