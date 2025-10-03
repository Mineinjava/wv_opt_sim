const std = @import("std");
const wv_opt_sim = @import("wv_opt_sim");
const zigimg = @import("zigimg");

const FILE = "./mask.png";
const GRID_SPACING = 0.1;
const GRID_SPACING_2: f64 = GRID_SPACING * GRID_SPACING;
const LIGHT_WAVELENGTH = 550e-6;

const xy = struct { x: usize, y: usize, f_size: f64 };

pub fn main() !void {
    const allocator = std.heap.smp_allocator;

    var read_buffer: [zigimg.io.DEFAULT_BUFFER_SIZE]u8 = undefined;

    var image = try zigimg.Image.fromFilePath(allocator, FILE, read_buffer[0..]);
    defer image.deinit(allocator);

    const SIZE = xy{ .x = image.width, .y = image.height, .f_size = @floatFromInt(image.width * image.height) };

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
    return xy{ .x = x, .y = y, .f_size = 0 };
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

pub fn subtract_abs(a: u64, b: u64) u64 {
    return if (a > b) a - b else b - a;
}

pub fn area_num_int(p: xy, mask: []const u8, dist2: f64, size: xy, xcs: *f64, ycs: *f64, normalizer:f64) !f64 {
    var i: usize = 0;
    while (i < mask.len) : (i += 1) {
        if (mask[i] == 0) {
            continue;
        }
        const l = lin_to_flat(i, size);
        const dx2: u64 = subtract_abs(p.x, l.x);
        const dy2: u64 = subtract_abs(p.y, l.y);
        const planedist: f64 = @floatFromInt(dx2*dx2 + dy2*dy2);

        const distance: f64 = @sqrt(planedist * GRID_SPACING_2 + dist2)/LIGHT_WAVELENGTH;

        const maskValueFloat: f64 = @floatFromInt(mask[i]);

        xcs.* += maskValueFloat * @cos(distance); // range is 0-255
        ycs.* += maskValueFloat * @sin(distance);
    }
    return @sqrt(std.math.pow(f64, xcs.*, 2) + std.math.pow(f64, ycs.*, 2)) / normalizer;
}

pub fn proccess_mask(mask: []const u8, dist2: f64, size: xy, allocator: std.mem.Allocator) ![]f64 {
    var xcs: f64 = 0;
    var ycs: f64 = 0;
    var result: []f64 = try allocator.alloc(f64, mask.len);
    var i: usize = 0;
    const normalizer = size.f_size * size.f_size;
    while (i < mask.len) : (i += 1) {
        result[i] = try area_num_int(lin_to_flat(i, size), mask, dist2, size, &xcs, &ycs, normalizer);
        std.debug.print("{}\n", .{i});
        xcs = 0;
        ycs = 0;
    }
    return result;
}
