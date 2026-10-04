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

# PhonePe
-dontwarn com.phonepe.**
-keep class com.phonepe.** { *; }

# AppLovin MAX. Its Open Measurement library mentions Amazon's Privacy Pass
# attestation, which is optional and not shipped: without this R8 stops the
# release build on the missing classes (build/app/outputs/mapping/release/
# missing_rules.txt names them). Only used when Amazon's SDK is present.
-dontwarn com.amazon.privacypass.**
-dontwarn com.iab.omid.library.applovin.**
