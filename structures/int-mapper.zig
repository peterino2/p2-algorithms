const std = @import("std");

pub fn IntMapperUnmanaged(comptime IntType: type) type {
    return struct {
        capacity: usize,
        smallMap: []IntType,
    };
}
