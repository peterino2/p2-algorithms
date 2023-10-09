const std = @import("std");

// it's like an normal vector/ arraylist except it never invalidates old pointers.
// and never causes re-allocations. (excepting in the control block, which is just a vector of things)
//
// it has a growth factor, which can be configured.
//

pub fn PagedVectorAdvanced(comptime T: type, comptime growth: usize) type {
    return struct {
        const Page = struct {
            data: [growth]T = undefined,
            len: u32 = 0,
        };

        pages: std.ArrayListUnmanaged(*Page) = .{},
        head: *T,

        pub fn init(allocator: std.mem.Allocator) !@This() {
            var rv = @This(){
                .pages = .{},
                .head = undefined,
            };

            var page = try allocator.create(Page);
            page.* = .{};
            try rv.pages.append(allocator, page);
            rv.head = &rv.pages.items[0].data[0];
            return rv;
        }

        pub fn capacity(self: @This()) usize {
            return self.pages.items.len * growth;
        }

        pub fn usage(self: @This()) usize {
            return (self.pages.items.len - 1) * growth + self.pages.items[self.pages.items.len - 1].len;
        }

        pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
            for (self.pages.items) |page| {
                allocator.destroy(page);
            }

            self.pages.deinit(allocator);
        }

        fn expand(self: *@This(), allocator: std.mem.Allocator) !void {
            var page = try allocator.create(Page);
            page.* = .{};
            try self.pages.append(allocator, page);
        }

        pub fn append(self: *@This(), allocator: std.mem.Allocator, value: T) !void {
            self.head.* = value;
            var currentPage = self.pages.items[self.pages.items.len - 1];
            currentPage.len += 1;
            if (currentPage.len >= growth) {
                try self.expand(allocator);
                var appendedPage = self.pages.items[self.pages.items.len - 1];
                self.head = &appendedPage.data[appendedPage.len];
            } else {
                self.head = &currentPage.data[currentPage.len];
            }
        }

        pub fn appendSlice(self: *@This(), allocator: std.mem.Allocator, slice: []const T) !void {
            for (slice) |value| {
                try self.append(allocator, value);
            }
        }

        pub fn getMutable(self: *@This(), index: usize) *T {
            const pageIndex = std.math.divFloor(usize, index, growth) catch unreachable;
            return &self.pages.items[pageIndex].data[index % growth];
        }

        pub fn get(self: @This(), index: usize) *const T {
            const pageIndex = std.math.divFloor(usize, index, growth) catch unreachable;
            return &self.pages.items[pageIndex].data[index % growth];
        }
    };
}

pub fn PagedVectorUnmanaged(comptime T: type) type {
    return PagedVectorAdvanced(T, 1024);
}

pub fn PagedVector(comptime T: type) type {
    return struct {
        const VectorType = PagedVectorAdvanced(T, 1024);

        vector: VectorType,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) !@This() {
            return .{
                .vector = try VectorType.init(allocator),
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *@This()) void {
            self.vector.deinit(self.allocator);
        }

        pub fn appendSlice(self: *@This(), slice: []const T) !void {
            try self.vector.appendSlice(self.allocator, slice);
        }

        pub fn append(self: *@This(), value: T) !void {
            try self.vector.append(self.allocator, value);
        }

        pub fn get(self: *const @This(), index: usize) *const T {
            self.vector.get(index);
        }

        pub fn getMutable(self: *@This(), index: usize) *T {
            self.vector.getMutable(index);
        }

        pub fn usage(self: @This()) usize {
            return self.vector.usage();
        }

        pub fn capacity(self: @This()) usize {
            return self.vector.capacity();
        }
    };
}

test "simple loading multiple pages." {
    const TestStruct = struct {
        lmao: usize,
    };

    var allocator = std.testing.allocator;
    var vector = try PagedVectorAdvanced(TestStruct, 1024).init(std.testing.allocator);
    defer vector.deinit(allocator);

    for (0..128) |j| {
        try vector.append(allocator, .{ .lmao = j });
    }

    var ptr = vector.get(0);
    var mutable = vector.getMutable(127);

    for (0..4096) |i| {
        try vector.append(allocator, .{ .lmao = i });
    }

    // testing that pointers are not invalidated
    std.debug.assert(ptr == vector.get(0));
    std.debug.assert(mutable == vector.getMutable(127));

    std.debug.assert(vector.getMutable(4092) == vector.getMutable(4092));

    // 4096 + 128 = 4224 = 4 pages + 128 extra entries
    std.debug.assert(vector.pages.items.len == 5);
    std.debug.assert(vector.capacity() == 1024 * 5);
    std.debug.assert(vector.usage() == 128 + 1024 * 4);

    // 4092 - 3072 =  offset of 1020 in the third page.
    var ptr4092 = vector.getMutable(4092);
    std.debug.assert(vector.getMutable(4092) == &vector.pages.items[3].data[1020]);

    for (0..1024) |_| {
        try vector.append(allocator, .{ .lmao = 0 });
    }
    std.debug.assert(vector.getMutable(4092) == ptr4092);
}

test "managed version" {
    var allocator = std.testing.allocator;

    var vec = try PagedVector(struct { lmao: u64 }).init(allocator);
    defer vec.deinit();

    for (0..8192) |i| {
        try vec.append(.{ .lmao = i });
    }

    std.debug.assert(vec.vector.pages.items.len == 9);
}
