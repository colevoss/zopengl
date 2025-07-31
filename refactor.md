## Datastructures

For now we can have multiple Vertex Buffer Objects. 1 per unique mesh
This would mean that we have one VBO per VAO

EBOs are weird since they are registered per VAO and can't be batched like VBOs

### Objects/Model Instances

* transform
* rotation
* scale
* model_id
* materia_id?

### Models

List of models that contain id of root mesh and last mesh???

```zig
const Model = struct {
    mesh_start: u32,
    mesh_end: u32,

    // This will need to be refactored when we have parented models/meshes
    fn draw(self: *Model) {
        for (engine.meshes[self.mesh_start..self.mesh_end]) |mesh| {
            mesh.draw();
        }
    }
};
```

### Meshes

Loop through mesh slice defined by model start/end mesh

## Order of operations

1. use shader
2. Set uniforms
    1. model/view/projection
    2. set directional light uniforms
    3. set light uniforms per light
3. draw model -> loop over meshes and draw
    1. process textures
        1. activate
        2. set sampler uniform on shader
        3. bind texture
    2. bind vertex array
    3. draw elements
4. Draw lights??

