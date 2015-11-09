import dge.game;

enum uint screenWidth = 800;
enum uint screenHeight = 600;
enum aspectRatio = cast(float)screenWidth / screenHeight;

int main(string[] args) {
  Game.initLibraries();
  scope(exit) Game.finalizeLibraries();

  Window window = new Window(800, 600);
  window.open();
  scope(exit) window.close();

  //TODO: refactor so window doesn't construct scene.
  Scene scene = window.scene();

  Game game = new Game(window);

  CameraNode camera = new CameraNode(perspectiveMatrix(aspectRatio, 30.0, 0.001, 10000));
  camera.position = Vector3(0, 0, 4);
  scene.add(camera);

  LightNode light = new LightNode;
  light.diffuse = Color(1f, 1f, 1f, 1f);
  light.position = Vector3(0, 4, 1);
  scene.add(light);

  MeshNode m = new MeshNode(rectangle(1, 1));
  scene.add(m);

  game.mainLoop();

  return 0;
}
