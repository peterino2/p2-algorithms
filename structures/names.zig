const std = @import("std");
const paged_vector = @import("paged-vector.zig");

const PagedVectorAdvanced = paged_vector.PagedVectorAdvanced;

pub const NameRegistryStatus = enum {
    Ok,
    OutOfMemory,
};

pub const NameInvalid: Name = .{ .index = 0 };

const NameInvalidComptimeString = "Invalid";

// trying out a names scheme similar in vein to unreal engine's FNames
pub const NameRegistry = struct {
    allocator: std.mem.Allocator,
    map: std.StringHashMapUnmanaged(usize),
    pagedVector: PagedVectorAdvanced([]const u8, 1024),
    stringArena: std.heap.ArenaAllocator,

    // with this system errors should be EXCEEDINGLY rare, and in most cases they
    // should have no problem
    errorStatus: NameRegistryStatus = .Ok,

    pub fn init(allocator: std.mem.Allocator) !@This() {
        var self = @This(){
            .allocator = allocator,
            .stringArena = std.heap.ArenaAllocator.init(allocator),
            .map = .{},
            .pagedVector = try PagedVectorAdvanced([]const u8, 1024).init(allocator),
        };

        _ = self.cname(NameInvalidComptimeString);
        return self;
    }

    pub fn count(self: @This()) usize {
        return self.pagedVector.len();
    }

    pub fn name(self: *@This(), nameString: []const u8) Name {
        return self.MakeNameInner(nameString, true);
    }

    pub fn cname(self: *@This(), comptime comptimeString: []const u8) Name {
        return self.MakeNameInner(comptimeString, false);
    }

    fn MakeNameInner(self: *@This(), nameString: []const u8, shouldCopy: bool) Name {
        var newString = nameString;
        // check if the string exists if it does just return it as a name.
        if (self.map.get(newString)) |index| {
            return .{ .index = index };
        }

        //
        if (shouldCopy) {
            var allocator = self.stringArena.allocator();
            newString = allocator.dupe(u8, nameString) catch {
                self.errorStatus = .OutOfMemory;
                return NameInvalid;
            };
        }

        // add to registry
        var newIndex = self.pagedVector.len();
        self.pagedVector.append(self.allocator, newString) catch {
            self.errorStatus = .OutOfMemory;
            return NameInvalid;
        };

        self.map.put(self.allocator, newString, newIndex) catch {
            self.errorStatus = .OutOfMemory;
            return NameInvalid;
        };

        return .{ .index = newIndex };
    }

    pub fn deinit(self: *@This()) void {
        self.map.deinit(self.allocator);
        self.pagedVector.deinit(self.allocator);
        self.stringArena.deinit();
    }
};

pub var gRegistry: *NameRegistry = undefined;

pub fn createNameRegistry(allocator: std.mem.Allocator) !*NameRegistry {
    gRegistry = try allocator.create(NameRegistry);
    gRegistry.* = try NameRegistry.init(allocator);
    return gRegistry;
}

pub fn getRegistry() *NameRegistry {
    return gRegistry;
}

pub fn destroyNameRegistry() void {
    var allocator = gRegistry.allocator;
    gRegistry.deinit();
    allocator.destroy(gRegistry);
}

// To make a Name, create one from a registry.
pub const Name = struct {
    index: usize = 0,

    pub fn utf8(self: @This(), registry: *const NameRegistry) []const u8 {
        return registry.pagedVector.get(self.index).*;
    }

    pub fn eql(self: @This(), other: @This()) bool {
        return self.index == other.index;
    }
};

test "zname initialization and lookup" {
    _ = try createNameRegistry(std.testing.allocator);
    defer destroyNameRegistry();

    const testComptimeName = "This is a name test";
    const testComptimeName2 = "This is another name test";

    var r = getRegistry();
    var name = r.cname(testComptimeName);
    var name2 = r.name(testComptimeName);
    var name4 = r.name(testComptimeName2);

    var fmtString = try std.fmt.allocPrint(std.testing.allocator, "morty I did horrible things to your {s}.", .{"locally elected representative"});
    defer std.testing.allocator.free(fmtString);

    var name3 = r.name(fmtString);

    try std.testing.expectEqualSlices(u8, testComptimeName, name.utf8(r));
    try std.testing.expectEqualSlices(u8, testComptimeName, name2.utf8(r));
    try std.testing.expect(name2.eql(name));
    try std.testing.expect(!name3.eql(name));

    var uninitializedName: Name = .{};
    try std.testing.expect(uninitializedName.eql(r.name("Invalid")));
    try std.testing.expect(!name4.eql(name3));

    try std.testing.expectEqualSlices(u8, name3.utf8(r), fmtString);
}
