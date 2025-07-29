const std = @import("std");
const assimp = @import("assimp.zig");
const Mesh = @import("Mesh.zig");
const TextureLoader = @import("TextureLoader.zig");
const Shader = @import("Shader.zig");

const testing = std.testing;

const Allocator = std.mem.Allocator;

const Model = @This();
const AssimpScene = assimp.struct_aiScene;

const log = std.log.scoped(.model);

allocator: Allocator,
dir: []const u8,
path: []const u8,
meshes: std.ArrayList(Mesh),

pub fn init(gpa: Allocator, path: []const u8) Model {
    const dir = std.fs.path.dirname(path) orelse "";
    return .{
        .allocator = gpa,
        .path = path,
        .dir = dir,
        .meshes = std.ArrayList(Mesh).init(gpa),
    };
}

pub fn deinit(self: *Model) void {
    for (self.meshes.items) |*m| {
        m.deinit(self.allocator);
    }

    self.meshes.deinit();
}

pub fn draw(self: *const Model, shader: *const Shader) void {
    for (self.meshes.items) |mesh| {
        mesh.draw(shader);
    }
}

pub fn load(self: *Model, texture_loader: *TextureLoader) !void {
    log.debug("loading model: {s}", .{self.path});
    var scene = try assimp.importFile(self.path);

    const root_node: *assimp.Node = scene.mRootNode orelse {
        log.warn("Null root node for model {s}", .{self.path});
        return assimp.Error.MissingRootNodeError;
    };

    try self.processNode(texture_loader, root_node, &scene);
}

pub fn processNode(self: *Model, texture_loader: *TextureLoader, node: *assimp.Node, scene: *assimp.Scene) !void {
    const mesh_count = node.mNumMeshes;

    var i: u32 = 0;

    while (i < mesh_count) {
        const mesh_id = node.mMeshes[i];
        const ai_mesh: *assimp.Mesh = scene.mMeshes[mesh_id] orelse {
            log.warn("Skipped processing mesh {d}", .{mesh_id});
            continue;
        };

        const processed_mesh = try self.processMesh(texture_loader, ai_mesh, scene);
        try self.meshes.append(processed_mesh);

        i += 1;
    }

    const node_count = node.mNumChildren;

    i = 0;

    while (i < node_count) {
        const child_node: *assimp.Node = node.mChildren[i] orelse {
            log.warn("Skipped processing child node {d}", .{i});
            continue;
        };

        try self.processNode(texture_loader, child_node, scene);

        i += 1;
    }
}

pub fn processMesh(self: *Model, texture_loader: *TextureLoader, ai_mesh: *assimp.Mesh, ai_scene: *assimp.Scene) !Mesh {
    var mesh: Mesh = .init;
    try mesh.loadFromAssimp(self.allocator, texture_loader, ai_mesh, ai_scene, self.dir);

    return mesh;
}
