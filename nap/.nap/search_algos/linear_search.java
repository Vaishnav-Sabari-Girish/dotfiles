/*
* Linear Search LeetCode
*/ 

class Solution {
    public int search(int[] nums, int target) {
      for(int i = 0; i < num.length; i++){
        if(target == nums[i]){
          return i;
        }
      }
      return -1;
    }
}
