#include <stdio.h>

void printBinary(int decimal) {
  int binary[32];
  int index = 0;

  printf("The binary form of your number will look like : ");
  if (decimal == 0) {
    printf("0.\n");
    return;
  }

  while (decimal > 0) {
    binary[index] = decimal % 2;
    decimal = decimal / 2;
    index++;
  }

  for (int i = index - 1; i >= 0; i--) {
    printf("%d", binary[i]);
  }
  printf(".\n");
}

int main() {
  int n;
  printf("Enter your number : ");
  scanf("%d", &n);

  printBinary(n);
  return 0;
}