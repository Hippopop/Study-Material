#include <stdio.h>

int fact(int n) {
  if (n == 1)
    return 1;
  return n * fact(n - 1);
}

int isStrong(int n) {
  int num = n;
  int sum = 0;
  while (n > 0) {
    sum += fact(n % 10);
    n /= 10;
  }
  return sum == num;
}

int main() {
  int n;
  printf("Enter your number : ");
  scanf("%d", &n);

  printf("Your number %s strong number.\n", isStrong(n) ? "is a" : "isn't a");
  return 0;
}
