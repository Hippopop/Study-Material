# Global configuration!
OUTPUT_DIRECTORY = bin

# Configure for any C file!
C_NAME = snake_game_project
C_COMPILER = gcc
C_FILE_NAME = $(C_NAME).c
C_OUTPUT_DIR = $(OUTPUT_DIRECTORY)
C_OUTPUT_PATH = $(C_OUTPUT_DIR)/$(C_NAME).out
C_I = $(C_FILE_NAME)


all: crun

cbuild:
	mkdir -p $(C_OUTPUT_DIR)
	$(C_COMPILER) $(C_I) -lncurses -o $(C_OUTPUT_PATH)

crun: cbuild
	./$(C_OUTPUT_PATH)

clean:
	rm -rf $(OUTPUT_DIRECTORY)
