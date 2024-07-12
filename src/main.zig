const std = @import("std");
const rl = @import("raylib");

const MapObject = enum(u3) { player, wall, floor, box, target };

const MapConversionError = error{
    UndefinedMapObjectNumber,
};

fn convertFromFileToMap() ![10][10]MapObject {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var file = try std.fs.cwd().openFile("maps/map1.txt", .{});
    defer file.close();

    var buffered = std.io.bufferedReader(file.reader());
    var reader = buffered.reader();

    var arr = std.ArrayList(u8).init(allocator);
    defer arr.deinit();

    var map: [10][10]MapObject = undefined;
    var i: u8 = 0;
    while (true) : (i += 1) {
        reader.streamUntilDelimiter(arr.writer(), '\n', null) catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };

        for (arr.items, 0..) |object_number, j| {
            if (object_number == '0') {
                map[i][j] = MapObject.player;
            } else if (object_number == '1') {
                map[i][j] = MapObject.wall;
            } else if (object_number == '2') {
                map[i][j] = MapObject.floor;
            } else if (object_number == '3') {
                map[i][j] = MapObject.box;
            } else if (object_number == '4') {
                map[i][j] = MapObject.target;
            } else {
                return MapConversionError.UndefinedMapObjectNumber;
            }
        }
        arr.clearRetainingCapacity();
    }

    return map;
}

fn drawMap(map: [10][10]MapObject) void {
    var x: i16 = 50;
    var y: i16 = 50;

    for (map) |row| {
        for (row) |map_object| {
            switch (map_object) {
                MapObject.player => {
                    rl.drawRectangle(x, y, 50, 50, rl.Color.green);
                },

                MapObject.wall => {
                    rl.drawRectangle(x, y, 50, 50, rl.Color.red);
                },

                MapObject.floor => {
                    rl.drawRectangle(x, y, 50, 50, rl.Color.white);
                },

                MapObject.box => {
                    rl.drawRectangle(x, y, 50, 50, rl.Color.brown);
                },

                MapObject.target => {
                    rl.drawRectangle(x, y, 50, 50, rl.Color.blue);
                },
            }
            x += 50;
        }
        x = 50;
        y += 50;
    }
}

pub fn main() anyerror!void {
    const map: [10][10]MapObject = try convertFromFileToMap();

    const screenWidth = 800;
    const screenHeight = 600;

    rl.initWindow(screenWidth, screenHeight, "Sokoban");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);

        drawMap(map);
    }
}
