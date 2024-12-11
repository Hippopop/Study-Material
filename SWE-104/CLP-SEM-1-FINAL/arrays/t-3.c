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

  int odd[l];
  int even[l];
  int eCount = 0;
  int oCount = 0;

  for (int i = l - 1; i >= 0; i--)
    if (arr[i] % 2 == 0) {
      even[eCount] = arr[i];
      eCount++;
    } else {
      odd[oCount] = arr[i];
      oCount++;
    }

  if (eCount != 0) {
    printf("%d even number are as follows :", eCount);
    for (int i = 0; i < eCount; i++) {
      printf(" %d", even[i]);
    }
    printf(".\n");
  }

  if (oCount != 0) {
    printf("%d odd number are as follows :", oCount);
    for (int i = 0; i < oCount; i++) {
      printf(" %d", odd[i]);
    }
    printf(".\n");
  }

  return 0;
}