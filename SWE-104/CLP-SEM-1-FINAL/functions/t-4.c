#include <stdio.h>

int power(int n, int p) {
  if (p == 1) {
    return n;
  }
  return n * power(n, p - 1);
}

int main() {
  int n, p;
  printf("Enter your number : ");
  scanf("%d", &n);
  printf("Enter your powr number : ");
  scanf("%d", &p);

  printf("The result is - %d.\n", power(n, p));
  return 0;
}