import 'package:flutter/material.dart';
import 'package:ride_share_app/constants/colors.dart';

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const CircularProgressIndicator(
      color: AppColors.primaryColor,
    );
  }
}