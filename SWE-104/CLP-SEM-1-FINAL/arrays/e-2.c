#include <stdio.h>

int main() {
  int decimal;
  printf("Enter a decimal number: ");
  scanf("%d", &decimal);

  printf("Binary equivalent of %d is: ", decimal);
  int binary[32];
  int index = 0;

  // if the number is 0!
  if (decimal == 0) {
    printf("0");
    return 0;
  }

  while (decimal > 0) {
    binary[index] = decimal % 2;
    decimal = decimal / 2;
    index++;
  }

  for (int i = index - 1; i >= 0; i--) {
    printf("%d", binary[i]);
  }
  printf("\n");
  return 0;
}