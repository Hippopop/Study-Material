#include <math.h>
#include <stdio.h>

int main() {
  // Array initialization start!
  int size;
  printf("Enter the length of your array : ");
  scanf("%d", &size);

  int array[size];
  for (int i = 0; i < size; i++) {
    printf("Enter value for position (%d) : ", (i + 1));
    scanf("%d", &array[i]);
  }

  if (size <= 0)
    return 0;
  // Array initialization end!

  // Mean calculation!
  double sum = 0.0;
  for (int i = 0; i < size; i++) {
    sum += array[i];
  }
  double mean = sum / size;
  printf("The mean for this array is : %.3f\n", mean);

  //  First, sort the data
  for (int i = 0; i < size - 1; i++) {
    for (int j = i + 1; j < size; j++) {
      if (array[i] > array[j]) {
        double temp = array[i];
        array[i] = array[j];
        array[j] = temp;
      }
    }
  }

  // Calculate median.
  float median;
  if (size % 2 == 0) {
    median = (array[(int)(size / 2) - 1] + array[(int)(size / 2)]) / 2.0;
  } else {
    median = array[(int)(size / 2)];
  }
  printf("The median for this array is : %.3f\n", median);

  // Calculate standard deviation!
  double squareSum = 0.0;
  for (int i = 0; i < size; i++) {
    squareSum += (array[i] - mean) * (array[i] - mean);
  }
  double standardDeviation = sqrt(squareSum / (size - 1));
  printf("The standard deviation for this array is : %.3f\n", standardDeviation);

  return 0;
}