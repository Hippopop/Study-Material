#include <stdio.h>

int r_sum(int n) {
  if (n > 0)
    return (n % 10) + r_sum(n / 10);
  return 0;
}

int main() {
  int n;
  printf("Enter your number : ");
  scanf("%d", &n);

  printf("The sum of all digits are : %d.\n", r_sum(n));
  return 0;
}