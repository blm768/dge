import dge.game;

int main(string[] args) {
  Game.initLibraries();

  Window window = new Window(800, 600);
  window.open();

  Game game = new Game(window);

  game.mainLoop();

  return 0;
}
