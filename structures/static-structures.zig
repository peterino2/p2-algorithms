pub fn StaticArrayList(comptime T: type, comptime size: usize) type {
    return struct {
        _data: [size]T,
        len: u32 = 0,

        pub fn append(self: *@This(), value: T) !void {
            if (self.len >= size)
                return error.OutOfCapacity;

            self.data[self.len] = value;
            self.len += 1;
        }

        pub fn pop(self: *@This()) ?T {
            if (self.len == 0) {
                return null;
            }

            self.len -= 1;
            return self._data[self.len];
        }

        pub fn items(self: *@This()) ![]T {
            var ptr: []T = undefined;
            ptr.ptr = self._data;
            ptr.len = self.len;
            return ptr;
        }
    };
}

test "static array list" {
    var al = StaticArrayList(struct { x: u32 = 0 }, 42);

    for (0..42) |i| {
        try al.append(.{ .x = i });
    }
}
