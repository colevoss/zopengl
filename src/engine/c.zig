pub const c = @cImport({
    @cInclude("GLFW/glfw3.h");
});

pub const assimp = @cImport({
    @cInclude("assimp/postprocess.h");
    @cInclude("assimp/cimport.h");
    @cInclude("assimp/scene.h");
});
