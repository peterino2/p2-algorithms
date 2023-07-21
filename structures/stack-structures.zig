pub fn StackArrayList(comptime T: type, comptime size: usize) type {
    return struct {
        data: [size]T,
        items: []T,

        pub fn new() @This() {}
    };
}
