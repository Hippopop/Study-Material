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

  printf("The state of duplicates in the array looks like : \n");
  for (int i = l - 1; i >= 0; i--) {
    int val = arr[i];
    int repeat = 0;
    for (int j = l - 1; j >= 0; j--)
      if (arr[j] == val && i != j)
        repeat++;
    printf("Number (%d) @(%d) has (%d) duplicates.\n", val, i, repeat);
  }

  return 0;
}