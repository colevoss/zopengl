const std = @import("std");
const Texture = @import("Texture.zig");
pub const c = @cImport({
    @cInclude("assimp/postprocess.h");
    @cInclude("assimp/cimport.h");
    @cInclude("assimp/scene.h");
});

pub const Scene = c.struct_aiScene;
pub const Node = c.struct_aiNode;
pub const Mesh = c.struct_aiMesh;
pub const Material = c.struct_aiMaterial;

const log = std.log.scoped(.assimp);

pub const Error = error{
    GetTextureError,
    ReadFileError,
    IncompleteError,
    MissingRootNodeError,
    MissingMaterial,
};

pub fn importFile(path: []const u8) Error!Scene {
    const import_result = c.aiImportFile(
        path.ptr,
        c.aiProcess_Triangulate | c.aiProcess_FlipUVs,
    );

    if (import_result == null) {
        logErrorPath(path);
        return Error.ReadFileError;
    }

    const s = import_result.*;

    // if (scene) |s| {
    if (s.mFlags & c.AI_SCENE_FLAGS_INCOMPLETE == 1) {
        logErrorPath(path);
        return Error.IncompleteError;
    }

    const rootNode: ?*Node = s.mRootNode;

    if (rootNode == null) {
        logErrorPath(path);
        return Error.MissingRootNodeError;
    }

    return s;
    // return scene;
    // } else {
    //     logError();
    //     return Error.ReadFileError;
    // }
}

pub fn sceneMaterial(scene: *Scene, material_id: u32) Error!*Material {
    return scene.mMaterials[material_id] orelse {
        log.warn("Missing material in scene {d}", .{material_id});
        return Error.MissingMaterial;
    };
}

pub fn materialTextureCount(material: *Material, texture_type: Texture.Type) u32 {
    return c.aiGetMaterialTextureCount(material, textureType(texture_type));
}

// pub const MaterialTexture = struct {
//     index: u32,
//     type: TextureType,
//     path: []const u8,
//
//     pub fn deinit(self: MaterialTexture, gpa: std.mem.Allocator) void {
//         gpa.
//     }
// };

pub fn getMaterialTexture(gpa: std.mem.Allocator, material: *Material, texture_type: Texture.Type, index: u32) ![]const u8 {
    var ai_string: c.struct_aiString = .{};
    const result = c.aiGetMaterialTexture(
        material,
        textureType(texture_type),
        index,
        &ai_string,
        null,
        null,
        null,
        null,
        null,
        null,
    );

    if (result == @intFromEnum(Return.failure)) {
        logError();
        return Error.GetTextureError;
    }

    return try gpa.dupe(u8, ai_string.data[0..ai_string.length]);

    // return ai_string.data[0..ai_string.length];
}

pub const Return = enum(c_int) {
    success = c.AI_SUCCESS,
    failure = c.AI_FAILURE,
};

fn textureType(texture_type: Texture.Type) c_uint {
    return switch (texture_type) {
        .diffuse => c.aiTextureType_DIFFUSE,
        .specular => c.aiTextureType_SPECULAR,
    };
}

fn logErrorPath(path: []const u8) void {
    const err = c.aiGetErrorString();

    log.err("error reading model file ({s}): {s}", .{
        path,
        err,
    });
}

fn logError() void {
    const err = c.aiGetErrorString();

    log.err("error reading model file: {s}", .{
        err,
    });
}
