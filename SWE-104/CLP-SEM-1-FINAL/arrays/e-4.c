#include <stdio.h>

int main() {
  int rows, cols;

  // Input the dimensions of the matrix!
  printf("Enter the number of rows and columns: ");
  scanf("%d %d", &rows, &cols);

  int matrix[rows][cols];
  int transpose[cols][rows];

  // Input the matrix elements
  printf("Enter the elements of the matrix:\n");
  for (int i = 0; i < rows; i++) {
    for (int j = 0; j < cols; j++) {
      scanf("%d", &matrix[i][j]);
    }
  }

  // Display the original matrix
  printf("\nOriginal Matrix:\n");
  for (int i = 0; i < rows; i++) {
    for (int j = 0; j < cols; j++) {
      printf("%d ", matrix[i][j]);
    }
    printf("\n");
  };

  // Find the transpose of the matrix
  for (int i = 0; i < rows; i++) {
    for (int j = 0; j < cols; j++) {
      transpose[j][i] = matrix[i][j];
    }
  };

  // Display the transposed matrix
  printf("\nTransposed Matrix:\n");
  for (int i = 0; i < cols; i++) {
    for (int j = 0; j < rows; j++) {
      printf("%d ", transpose[i][j]);
    }
    printf("\n");
  };

  return 0;
}
