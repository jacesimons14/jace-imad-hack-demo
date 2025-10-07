/// Manages 3D model assets for AR rendering.
///
/// This class provides URLs and configuration for 3D models that can be
/// rendered on detected ArUco markers.
class ModelManager {
  /// Returns a list of available 3D models.
  static List<ARModel> getAvailableModels() {
    return [
      // Sample models using online GLB files
      const ARModel(
        id: 'cube',
        name: 'Cube',
        description: 'Simple textured cube',
        url:
            'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/Box/glTF-Binary/Box.glb',
        scale: 0.1,
      ),
      const ARModel(
        id: 'duck',
        name: 'Duck',
        description: 'Classic glTF duck model',
        url:
            'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/Duck/glTF-Binary/Duck.glb',
        scale: 0.01,
      ),
      const ARModel(
        id: 'helmet',
        name: 'Helmet',
        description: 'Damaged helmet model',
        url:
            'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/DamagedHelmet/glTF-Binary/DamagedHelmet.glb',
        scale: 0.5,
      ),
      const ARModel(
        id: 'arrow',
        name: 'Arrow',
        description: 'Simple arrow pointing up',
        url:
            'https://raw.githubusercontent.com/KhronosGroup/glTF-Sample-Models/master/2.0/ReciprocatingSaw/glTF-Binary/ReciprocatingSaw.glb',
        scale: 0.1,
      ),
    ];
  }

  /// Gets a model by ID.
  static ARModel? getModelById(String id) {
    try {
      return getAvailableModels().firstWhere((model) => model.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Gets the default model.
  static ARModel getDefaultModel() {
    return getAvailableModels().first;
  }
}

/// Represents a 3D model that can be rendered in AR.
class ARModel {
  const ARModel({
    required this.id,
    required this.name,
    required this.description,
    required this.url,
    this.scale = 1.0,
  });

  /// Unique identifier for the model.
  final String id;

  /// Display name of the model.
  final String name;

  /// Description of the model.
  final String description;

  /// URL to the GLB/GLTF model file.
  final String url;

  /// Default scale for the model.
  final double scale;

  @override
  String toString() => 'ARModel($id: $name)';
}
