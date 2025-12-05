import 'package:flutter/material.dart';

class Responsive {
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 650;

  static bool isTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= 650 &&
      MediaQuery.of(context).size.width < 1100;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1100;

  static double getWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double getHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  static EdgeInsets getPadding(BuildContext context) {
    if (isMobile(context)) {
      return const EdgeInsets.all(16);
    } else if (isTablet(context)) {
      return const EdgeInsets.all(24);
    } else {
      return const EdgeInsets.all(40);
    }
  }

  static double getFontSize(BuildContext context, double baseSize) {
    if (isMobile(context)) {
      return baseSize * 0.8;
    } else if (isTablet(context)) {
      return baseSize * 0.9;
    } else {
      return baseSize;
    }
  }

  static int getCrossAxisCount(BuildContext context, {
    int mobileCount = 2,
    int tabletCount = 3,
    int desktopCount = 4,
  }) {
    if (isMobile(context)) {
      return mobileCount;
    } else if (isTablet(context)) {
      return tabletCount;
    } else {
      return desktopCount;
    }
  }

  static double getCardHeight(BuildContext context) {
    if (isMobile(context)) {
      return 200;
    } else if (isTablet(context)) {
      return 240;
    } else {
      return 280;
    }
  }

  static double getHorizontalScrollHeight(BuildContext context) {
    if (isMobile(context)) {
      return 220;
    } else if (isTablet(context)) {
      return 240;
    } else {
      return 260;
    }
  }

  static SliverGridDelegate getGridDelegate(BuildContext context) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: getCrossAxisCount(context),
      childAspectRatio: isMobile(context) ? 0.7 : 0.75,
      crossAxisSpacing: isMobile(context) ? 12 : 16,
      mainAxisSpacing: isMobile(context) ? 12 : 16,
    );
  }
}
