const std = @import("std");
const rl = @import("raylib");

const MapObject = enum(u3) { player, wall, floor, box, target };

const MapConversionError = error{
    UndefinedMapObjectNumber,
};

const MoveDirection = enum { left, down, up, right };

const SingleCellSize: u8 = 50;

const GameInfo = struct {
    // TODO: Make map size dynamic and include several boxes and targets
    map: [10][10]MapObject,
    player_coordinates: [2]u8,
    box_coordinates: [2]u8,
    target_coordinates: [2]u8,
    overlapped_targets: [2]u8,

    fn level_finished(self: *GameInfo) bool {
        if (self.box_coordinates[0] == self.target_coordinates[0] and
            self.box_coordinates[1] == self.target_coordinates[1])
        {
            return true;
        }
        return false;
    }

    fn playerMove(self: *GameInfo, direction: MoveDirection) void {
        var positive_number: bool = undefined;
        var x_axis_movement: u8 = 0;
        var y_axis_movement: u8 = 0;

        switch (direction) {
            MoveDirection.left => {
                if (self.player_coordinates[0] <= 1) {
                    return;
                }

                positive_number = false;
                x_axis_movement = 1;
            },

            MoveDirection.down => {
                if (self.player_coordinates[1] > 7) {
                    return;
                }

                positive_number = true;
                y_axis_movement = 1;
            },

            MoveDirection.up => {
                if (self.player_coordinates[1] <= 1) {
                    return;
                }

                positive_number = false;
                y_axis_movement = 1;
            },

            MoveDirection.right => {
                if (self.player_coordinates[0] > 7) {
                    return;
                }

                positive_number = true;
                x_axis_movement = 1;
            },
        }

        if (positive_number) {
            if (self.map[self.player_coordinates[1] + y_axis_movement][self.player_coordinates[0] + x_axis_movement] == MapObject.box) {
                if (self.map[self.box_coordinates[1] + y_axis_movement][self.box_coordinates[0] + x_axis_movement] == MapObject.wall) {
                    return;
                }
                self.map[self.box_coordinates[1] + y_axis_movement][self.box_coordinates[0] + x_axis_movement] = MapObject.box;
                self.box_coordinates[0] = self.box_coordinates[0] + x_axis_movement;
                self.box_coordinates[1] = self.box_coordinates[1] + y_axis_movement;
            }

            self.map[self.player_coordinates[1] + y_axis_movement][self.player_coordinates[0] + x_axis_movement] = MapObject.player;
            self.map[self.player_coordinates[1]][self.player_coordinates[0]] = MapObject.floor;

            if (self.map[self.target_coordinates[1]][self.target_coordinates[0]] == MapObject.floor) {
                self.map[self.target_coordinates[1]][self.target_coordinates[0]] = MapObject.target;
            }

            self.player_coordinates[0] = self.player_coordinates[0] + x_axis_movement;
            self.player_coordinates[1] = self.player_coordinates[1] + y_axis_movement;
        } else {
            if (self.map[self.player_coordinates[1] - y_axis_movement][self.player_coordinates[0] - x_axis_movement] == MapObject.box) {
                if (self.map[self.box_coordinates[1] - y_axis_movement][self.box_coordinates[0] - x_axis_movement] == MapObject.wall) {
                    return;
                }
                self.map[self.box_coordinates[1] - y_axis_movement][self.box_coordinates[0] - x_axis_movement] = MapObject.box;
                self.box_coordinates[0] = self.box_coordinates[0] - x_axis_movement;
                self.box_coordinates[1] = self.box_coordinates[1] - y_axis_movement;
            }

            self.map[self.player_coordinates[1] - y_axis_movement][self.player_coordinates[0] - x_axis_movement] = MapObject.player;
            self.map[self.player_coordinates[1]][self.player_coordinates[0]] = MapObject.floor;

            // TODO: Replace with better logic for recovering box target
            if (self.map[self.target_coordinates[1]][self.target_coordinates[0]] == MapObject.floor) {
                self.map[self.target_coordinates[1]][self.target_coordinates[0]] = MapObject.target;
            }

            self.player_coordinates[0] = self.player_coordinates[0] - x_axis_movement;
            self.player_coordinates[1] = self.player_coordinates[1] - y_axis_movement;
        }
    }
};

fn changeLevel(map_name: []const u8) GameInfo {
    const next_level: GameInfo = try convertFromFileToMap(map_name);
    return next_level;
}

fn convertFromFileToMap(map_name: []const u8) !GameInfo {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var file = try std.fs.cwd().openFile(map_name, .{});
    defer file.close();

    var buffered = std.io.bufferedReader(file.reader());
    var reader = buffered.reader();

    var arr = std.ArrayList(u8).init(allocator);
    defer arr.deinit();

    var player_y: u8 = undefined;
    var player_x: u8 = undefined;
    var box_x: u8 = undefined;
    var box_y: u8 = undefined;
    var target_x: u8 = undefined;
    var target_y: u8 = undefined;
    var map: [10][10]MapObject = undefined;

    var i: u8 = 0;
    while (true) : (i += 1) {
        reader.streamUntilDelimiter(arr.writer(), '\n', null) catch |err| switch (err) {
            error.EndOfStream => break,
            else => return err,
        };

        for (arr.items, 0..) |object_number, j| {
            if (object_number == '0') {
                player_x = @intCast(j);
                player_y = @intCast(i);
                map[i][j] = MapObject.player;
            } else if (object_number == '1') {
                map[i][j] = MapObject.wall;
            } else if (object_number == '2') {
                map[i][j] = MapObject.floor;
            } else if (object_number == '3') {
                box_x = @intCast(j);
                box_y = @intCast(i);
                map[i][j] = MapObject.box;
            } else if (object_number == '4') {
                target_x = @intCast(j);
                target_y = @intCast(i);
                map[i][j] = MapObject.target;
            } else {
                return MapConversionError.UndefinedMapObjectNumber;
            }
        }
        arr.clearRetainingCapacity();
    }

    return GameInfo{
        .map = map,
        .player_coordinates = .{ player_x, player_y },
        .box_coordinates = .{ box_x, box_y },
        .target_coordinates = .{ target_x, target_y },
        .overlapped_targets = .{ 0, 0 },
    };
}

fn drawMap(map: [10][10]MapObject) void {
    var x: i16 = SingleCellSize;
    var y: i16 = SingleCellSize;

    for (map) |row| {
        for (row) |map_object| {
            switch (map_object) {
                MapObject.player => {
                    rl.drawRectangle(x, y, SingleCellSize, SingleCellSize, rl.Color.green);
                },

                MapObject.wall => {
                    rl.drawRectangle(x, y, SingleCellSize, SingleCellSize, rl.Color.red);
                },

                MapObject.floor => {
                    rl.drawRectangle(x, y, SingleCellSize, SingleCellSize, rl.Color.white);
                },

                MapObject.box => {
                    rl.drawRectangle(x, y, SingleCellSize, SingleCellSize, rl.Color.brown);
                },

                MapObject.target => {
                    rl.drawRectangle(x, y, SingleCellSize, SingleCellSize, rl.Color.blue);
                },
            }
            x += SingleCellSize;
        }
        x = SingleCellSize;
        y += SingleCellSize;
    }
}

pub fn main() anyerror!void {
    var game_info: GameInfo = try convertFromFileToMap("maps/map1.txt");

    const screenWidth = 800;
    const screenHeight = 600;

    rl.initWindow(screenWidth, screenHeight, "Sokoban");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    while (!rl.windowShouldClose()) {
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);

        drawMap(game_info.map);

        if (rl.isKeyPressed(rl.KeyboardKey.key_left) or rl.isKeyPressed(rl.KeyboardKey.key_h)) {
            game_info.playerMove(MoveDirection.left);
        } else if (rl.isKeyPressed(rl.KeyboardKey.key_down) or rl.isKeyPressed(rl.KeyboardKey.key_j)) {
            game_info.playerMove(MoveDirection.down);
        } else if (rl.isKeyPressed(rl.KeyboardKey.key_up) or rl.isKeyPressed(rl.KeyboardKey.key_k)) {
            game_info.playerMove(MoveDirection.up);
        } else if (rl.isKeyPressed(rl.KeyboardKey.key_right) or rl.isKeyPressed(rl.KeyboardKey.key_l)) {
            game_info.playerMove(MoveDirection.right);
        }

        if (game_info.level_finished()) {
            game_info = try convertFromFileToMap("maps/map2.txt");
        }
    }
}
