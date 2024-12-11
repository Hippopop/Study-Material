#include <stdio.h>

int main() {
  // Array initialization start!
  int size;
  printf("Enter the size of your array: ");
  scanf("%d", &size);

  int array[size];
  for (int i = 0; i < size; i++) {
    printf("Enter array value for index - %d: ", i);
    scanf("%d", &array[i]);
  }
  printf("\n");
  // Array initialization end!

  int visited[size];
  for (int i = 0; i < size; i++) {
    visited[i] = 0;
  }

  for (int i = 0; i < size; i++) {
    if (visited[i] == 1) {
      continue;
    }

    int count = 1;
    for (int j = i + 1; j < size; j++) {
      if (array[i] == array[j]) {
        count++;
        visited[j] = 1;
      }
    }
    printf("Element %d appears %d times\n", array[i], count);
  }

  return 0;
}
