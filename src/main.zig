const std = @import("std");
const wv_opt_sim = @import("wv_opt_sim");
const zigimg = @import("zigimg");

const FILE = "./mask.png";
const GRID_SPACING = 0.1;
const LIGHT_WAVELENGTH = 550e-6;

const xy = struct { x: usize, y: usize, f_size: f64 };

pub fn main() !void {
    const allocator = std.heap.smp_allocator;

    var read_buffer: [zigimg.io.DEFAULT_BUFFER_SIZE]u8 = undefined;

    var image = try zigimg.Image.fromFilePath(allocator, FILE, read_buffer[0..]);
    defer image.deinit(allocator);

    const SIZE = xy{ .x = image.width, .y = image.height, .f_size = @floatFromInt(image.width * image.height)};

    std.debug.print("Found image with size x: {}, y: {}, pixel format {}\n", .{ SIZE.x, SIZE.y, image.pixelFormat() });

    try image.convert(allocator, zigimg.PixelFormat.grayscale8);

    var mask1: []u8 = try allocator.alloc(u8, image.pixels.grayscale8.len);

    var i: usize = 0;
    while (i < mask1.len) : (i += 1) {
        mask1[i] = image.pixels.grayscale8[i].value;
    }
    const result = try proccess_mask(mask1, 20 * 20, SIZE, allocator);
    defer allocator.free(result);
    const postproc = try proc_out_img(result, allocator);
    defer allocator.free(postproc);
    var final = try zigimg.Image.fromRawPixels(allocator, SIZE.x, SIZE.y, postproc, zigimg.PixelFormat.grayscale8);
    defer final.deinit(allocator);

    var write_buffer: [zigimg.io.DEFAULT_BUFFER_SIZE]u8 = undefined;
    try final.writeToFilePath(allocator, "./zig_output.png", write_buffer[0..], .{ .png = .{} });
}

pub fn proc_out_img(n: []f64, allocator: std.mem.Allocator) ![]u8 {
    var c: []u8 = try allocator.alloc(u8, n.len);
    const max: f64 = std.mem.max(f64, n);
    var i: usize = 0;
    while (i < n.len) : (i += 1) {
        const m: u8 = @intFromFloat((n[i] / max) * 200);
        c[i] = m;
    }
    return c;
}

pub fn lin_to_flat(i: usize, sz: xy) xy {
    // assumes rows are sequential
    const x = i % sz.x;
    const y = (i - x) / sz.y;
    return xy{ .x = x, .y = y, .f_size = 0};
}

pub fn flat_to_lin(p: xy, sz: xy) usize {
    // assumes rows are sequential
    return p.x + (p.y * sz.x);
}

pub fn sum(numbers: []f64) f64 {
    var s: f64 = 0;
    for (numbers) |number| {
        s += number;
    }
    return s;
}

pub fn mean(numbers: []f64) f64 {
    return sum(numbers) / @as(f64, @floatFromInt(numbers.len));
}

pub fn area_num_int(p: xy, mask: []const u8, dist2: f64, size: xy, xcs: *f64, ycs: *f64) !f64 {
    var i: usize = 0;
    while (i < mask.len) : (i += 1) {
        if (mask[i] == 0) {
            continue;
        }
        const l = lin_to_flat(i, size);
        const dx: f64 = @as(f64, @floatFromInt(p.x)) - @as(f64, @floatFromInt(l.x));
        const dy: f64 = @as(f64, @floatFromInt(p.y)) - @as(f64, @floatFromInt(l.y));
        const distance: f64 = @sqrt(std.math.pow(f64, dx * GRID_SPACING, 2) + std.math.pow(f64, dy * GRID_SPACING, 2) + dist2);
        xcs.* += @as(f64, @floatFromInt(mask[i])) * @cos(distance);
        ycs.* += @as(f64, @floatFromInt(mask[i])) * @sin(distance);
    }
    return @sqrt(std.math.pow(f64, xcs.*/size.f_size/LIGHT_WAVELENGTH, 2) + std.math.pow(f64, ycs.*/size.f_size/LIGHT_WAVELENGTH, 2));
}

pub fn proccess_mask(mask: []const u8, dist2: f64, size: xy, allocator: std.mem.Allocator) ![]f64 {
    var xcs: f64 = 0;
    var ycs: f64 = 0;
    var result: []f64 = try allocator.alloc(f64, mask.len);
    var i: usize = 0;
    while (i < mask.len) : (i += 1) {
        result[i] = try area_num_int(lin_to_flat(i, size), mask, dist2, size, &xcs, &ycs);
        std.debug.print("{}\n", .{i});
        xcs = 0;
        ycs = 0;
    }
    return result;
}
