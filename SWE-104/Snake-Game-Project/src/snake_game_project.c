#include <curses.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define MAX_SCORE 256
#define FRAME_TIME 110000

typedef struct {
  int x;
  int y;
} coords;

int score = 0;
char score_message[16];
bool is_running = true;
int screen_width = 46;
int screen_height = 20;

WINDOW *win;
coords berry;
coords dir = {1, 0};
coords head = {0, 0};
coords segments[MAX_SCORE + 1];

// Cheeck if coordinate a, and coordinate b
// are same. Which means they collided!
bool collide(coords a, coords b) {
  if (a.x == b.x && a.y == b.y) {
    return true;
  } else
    return false;
}

// Check if the gived coordinate collided with
// any of the points that snake body is currently at.
bool collide_snake_body(coords point) {
  for (int i = 0; i < score; i++) {
    if (collide(point, segments[i])) {
      return true;
    }
  }
  return false;
}

// Spawn a berry at a random point of the screen!
coords spawn_berry() {
  coords berry = {
      1 + rand() % (screen_width - 2),
      1 + rand() % (screen_height - 2),
  };
  do {
    berry.x = 1 + rand() % (screen_width - 2);
    berry.y = 1 + rand() % (screen_height - 2);
  } while (
    collide(head, berry) || collide_snake_body(berry)
  );
  return berry;
}

void draw_border(int y, int x, int width, int height) {
  // top row
  mvaddch(y, x, ACS_ULCORNER);
  mvaddch(y, x + width * 2 + 1, ACS_URCORNER);
  for (int i = 1; i < width * 2 + 1; i++) {
    mvaddch(y, x + i, ACS_HLINE);
  }
  // vertical lines
  for (int i = 1; i < height + 1; i++) {
    mvaddch(y + i, x, ACS_VLINE);
    mvaddch(y + i, x + width * 2 + 1, ACS_VLINE);
  }
  // bottom row
  mvaddch(y + height + 1, x, ACS_LLCORNER);
  mvaddch(y + height + 1, x + width * 2 + 1, ACS_LRCORNER);
  for (int i = 1; i < width * 2 + 1; i++) {
    mvaddch(y + height + 1, x + i, ACS_HLINE);
  }
}

void quit_game() {
  // exit cleanly from application
  endwin();
  // clear screen, place cursor on top, and un-hide cursor
  printf("\e[1;1H\e[2J");
  printf("\e[?25h");
  exit(0);
}

void restart_game() {
  head.x = 0;
  head.y = 0;
  dir.x = 1;
  dir.y = 0;
  score = 0;
  sprintf(score_message, "[ Score: %d ]", score);
  is_running = true;
}

void init() {
  srand(time(NULL));
  // initialize window
  win = initscr();
  // take player input and hide cursor
  keypad(win, true);
  noecho();
  nodelay(win, true);
  curs_set(0);

  // initialize color
  if (has_colors() == FALSE) {
    endwin();
    fprintf(stderr, "Your terminal does not support color\n");
    exit(1);
  }
  start_color();
  use_default_colors();
  init_pair(1, COLOR_RED, -1);
  init_pair(2, COLOR_GREEN, -1);
  init_pair(3, COLOR_YELLOW, -1);

  berry.x = rand() % screen_width;
  berry.y = rand() % screen_height;

  // update score message
  sprintf(score_message, "[ Score: %d ]", score);
}

void process_input() {
  int pressed = wgetch(win);
  if (pressed == KEY_LEFT) {
    if (dir.x == 1) {
      return;
    }
    dir.x = -1;
    dir.y = 0;
  }
  if (pressed == KEY_RIGHT) {
    if (dir.x == -1) {
      return;
    }
    dir.x = 1;
    dir.y = 0;
  }
  if (pressed == KEY_UP) {
    if (dir.y == 1) {
      return;
    }
    dir.x = 0;
    dir.y = -1;
  }
  if (pressed == KEY_DOWN) {
    if (dir.y == -1) {
      return;
    }
    dir.x = 0;
    dir.y = 1;
  }
  if (pressed == ' ') {
    if (!is_running)
      restart_game();
  }
  if (pressed == '\e') {
    is_running = false;
    quit_game();
  }
}

void game_over() {
  while (is_running == false) {
    process_input();

    mvaddstr(screen_height / 2, screen_width - 16,
             "              Game Over          ");
    mvaddstr(screen_height / 2 + 1, screen_width - 16,
             "[SPACE] to restart, [ESC] to quit ");
    attron(COLOR_PAIR(3));
    draw_border(screen_height / 2 - 1, screen_width - 17, 17, 2);
    attroff(COLOR_PAIR(3));

    usleep(FRAME_TIME);
  }
}

void update() {
  // update snake segments
  for (int i = score; i > 0; i--) {
    segments[i] = segments[i - 1];
  }
  segments[0] = head;

  // move snake
  head.x += dir.x;
  head.y += dir.y;

  // collide with body or walls
  if (collide_snake_body(head) || head.x < 0 || head.y < 0 ||
      head.x >= screen_width || head.y >= screen_height) {
    is_running = false;
    game_over();
  }

  // eating a berry
  if (collide(head, berry)) {
    if (score < MAX_SCORE) {
      score += 1;
      sprintf(score_message, "[ Score: %d ]", score);
    } else {
      // WIN!
      printf("You Win!");
    }
    berry = spawn_berry();
  }

  usleep(FRAME_TIME);
}

void draw() {
  erase();

  attron(COLOR_PAIR(1));
  mvaddch(berry.y + 1, berry.x * 2 + 1, '@');
  attroff(COLOR_PAIR(1));

  // draw snake
  attron(COLOR_PAIR(2));
  for (int i = 0; i < score; i++) {
    mvaddch(segments[i].y + 1, segments[i].x * 2 + 1, ACS_DIAMOND);
  }
  mvaddch(head.y + 1, head.x * 2 + 1, 'O');
  attroff(COLOR_PAIR(2));

  attron(COLOR_PAIR(3));
  draw_border(0, 0, screen_width, screen_height);
  attroff(COLOR_PAIR(3));
  mvaddstr(0, screen_width - 5, score_message);
}

int main(int argc, char *argv[]) {
  // process user args
  if (argc == 1) {
  } else if (argc == 3) {
    if (!strcmp(argv[1], "-d")) {
      if (sscanf(argv[2], "%dx%d", &screen_width, &screen_height) != 2) {
        printf("Usage: snake [options]\nOptions:\n -d [width]x[height]"
               "\tdefine dimensions of the screen\n\nDefault dimensions are "
               "25x20\n");
        exit(1);
      }
    }
  } else {
    printf(
        "Usage: snake [options]\nOptions:\n -d [width]x[height]"
        "\tdefine dimensions of the screen\n\nDefault dimensions are 25x20\n");
    exit(1);
  }

  init();
  while (is_running) {
    process_input();
    update();
    draw();
  }
  quit_game();
  return 0;
}
