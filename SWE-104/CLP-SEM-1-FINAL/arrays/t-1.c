#include <stdio.h>

int main() {
  int l;
  printf("Enter the length of your array : ");
  scanf("%d", &l);

  int arr[l];
  for (int i = 0; i < l; i++) {
    printf("Enter value for position (%d) : ", (i + 1));
    scanf("%d", &arr[i]);
  }

  if (l <= 0)
    return 0;

  printf("The values in reverse looks like this : ");
  for (int i = l; i > 0; i--) {
    printf("%d ", arr[i - 1]);
  }
  printf("\n");

  return 0;
}