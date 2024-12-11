#include <stdio.h>

int isEven(int n) { return (n % 2 == 0); }

int main() {
  int n;
  printf("Enter your number : ");
  scanf("%d", &n);

  printf("Your number is %s.\n", isEven(n) ? "even" : "odd");
  return 0;
}
