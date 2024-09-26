const std = @import("std");
const mem = std.mem;
const eprint = std.debug.print;

fn getSecretFromFile(allocator: mem.Allocator, path: []const u8) ![5]u8 {
    const file_content = try std.fs.cwd().readFileAlloc(allocator, path, std.math.maxInt(usize));
    defer allocator.free(file_content);
    if (file_content.len == 0) return error.FileIsEmpty;

    const nlines = blk: {
        const lines = mem.count(u8, file_content, "\n");
        break :blk if (lines == 0) 1 else lines;
    };

    const secret = blk: {
        for (0..10) |_| {
            const rand_line = std.crypto.random.intRangeAtMost(usize, 1, nlines);
            var line_it = mem.splitScalar(u8, file_content, '\n');
            for (1..rand_line) |_| _ = line_it.next() orelse continue;

            const secret = mem.trim(u8, line_it.next() orelse continue, "-\r\n\t ");
            if (secret.len == 5 and !mem.containsAtLeast(u8, secret, 1, "-\r\n\t ")) break :blk secret;
        }
        return error.WrongFileFormat;
    };

    return secret[0..5].*;
}

fn showDiff(secret: []const u8, line: []const u8) void {
    for (secret, line) |s, l| {
        if (s == l) {
            eprint("\x1b[32m{c}", .{l});
        } else if (mem.containsAtLeast(u8, secret, 1, &.{l})) {
            eprint("\x1b[34m{c}", .{l});
        } else {
            eprint("\x1b[31m{c}", .{l});
        }
        eprint("\x1b[0m", .{});
    }
    eprint("\n", .{});
}

fn guess(secret: []const u8) !void {
    var input_buffer: [2048]u8 = undefined;
    var bin = std.io.bufferedReader(std.io.getStdIn().reader());
    var breader = bin.reader();
    var tries: u8 = 5;

    while (tries > 0) {
        eprint("remaining tries: {d}\nguess> ", .{tries});
        const line = try breader.readUntilDelimiterOrEof(&input_buffer, '\n') orelse {
            eprint("\r", .{});
            return error.InputEOF;
        };

        if (line.len != secret.len) {
            eprint("Please enter a word which is 5 characters long (ex: apple)\n", .{});
            continue;
        }

        showDiff(secret, line);
        if (mem.eql(u8, secret, line)) {
            eprint("Congrats !!!\n", .{});
            break;
        }

        tries -= 1;
    } else eprint("Too bad...\n", .{});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(gpa.deinit() == .ok);
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len != 2) return eprint("usage: {s} [file]\n", .{args[0]});

    eprint(
        \\Rules:
        \\  - You have 5 guesses
        \\  - You can only guess using 5 letters words
        \\  - You can only guess using lowercase letters
        \\  - Green means correct at the right position
        \\  - Blue means correct at the wrong position
        \\  - Red means incorrect
        \\Good luck!
        \\
        \\
    , .{});

    const secret = try getSecretFromFile(allocator, args[1]);
    try guess(&secret);
}
