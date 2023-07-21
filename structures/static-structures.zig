pub fn StaticArrayList(comptime T: type, comptime size: usize) type {
    return struct {
        data: [size]T,
    };
}
