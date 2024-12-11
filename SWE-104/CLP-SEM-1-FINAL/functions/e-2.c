#include <stdio.h>

int add(int n, int p) { return n + p; }
int subtract(int n, int p) { return n - p; }
int multiply(int n, int p) { return n * p; }
float divide(int n, int p) { return (float)n / p; }

int main() {
  int n, p;
  printf("Enter your first number : ");
  scanf("%d", &n);
  printf("Enter your second number : ");
  scanf("%d", &p);
  printf("\n\n");

  int opt;

  printf("Pick an operation from the list to perform :\n");
  printf("1. Add.\n2. Subtract.\n3. Multiply.\n4. Divide.\n\n");
  printf("Your option : ");
  scanf("%d", &opt);

  switch (opt) {
  case 1:
    printf("Your result is : %d.\n", add(n, p));
    break;
  case 2:
    printf("Your result is : %d.\n", subtract(n, p));
    break;
  case 3:
    printf("Your result is : %d.\n", multiply(n, p));
    break;
  case 4:
    printf("Your result is : %.2f.\n", divide(n, p));
    break;
  default:
    printf("You've entered and invalid option.\n");
  }
  return 0;
}