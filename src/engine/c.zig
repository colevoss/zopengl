pub const c = @cImport({
    @cInclude("GLFW/glfw3.h");
    @cInclude("assimp/postprocess.h");
    @cInclude("assimp/cimport.h");
    @cInclude("assimp/scene.h");
});
