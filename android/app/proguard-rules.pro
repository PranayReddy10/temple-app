# Release builds are shrunk by R8. The payment SDKs reach their classes by
# reflection and by callbacks named at runtime, so without these rules a
# release build compiles fine and then fails the moment checkout opens.

# Razorpay (https://razorpay.com/docs/payments/payment-gateway/android-integration/standard/)
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** { *; }
-optimizations !method/inlining/
-keepclasseswithmembers class * {
  public void onPayment*(...);
}

# Cashfree
-dontwarn com.cashfree.**
-keep class com.cashfree.** { *; }
