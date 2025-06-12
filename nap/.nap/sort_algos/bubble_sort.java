public class Main{
  public static void sort(int[] nums) {
    boolean swapped;
    for (int i = 0; i < nums.length - 1; i++) {
      swapped = false;

      for (int j = 0; j < nums.length - i - 1; j++) {
        if (nums[j] > nums[j+1]) {
          int temp = nums[j];
          nums[j] = nums[j+1];
          nums[j+1] = temp;

          swapped = true;
        }
      }

      if(!swapped){
        break;
      }
    }
  }
}
