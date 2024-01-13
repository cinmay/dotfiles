function sum(a:Number, b:Number) {

        if (a === b) {
console.log("a is equal to b");
    
}
      else {
    console.log("a is not equal to b");
  }
  if (a < b) {
    console.log("a is less than b");
  }

  return a + b;
}
module.exports = sum;
