import 'package:flutter/material.dart';
import 'constants.dart';
import 'buyer_purchases_page.dart';
import 'utils/page_transitions.dart';

class OrderConfirmationPage extends StatelessWidget {
  const OrderConfirmationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.charcoalBlack,
      appBar: AppBar(
        backgroundColor: AppColors.deepSlateGray,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.coolGray),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Order Confirmation',
          style: TextStyle(color: AppColors.coolGray),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Success icon with circle background
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.mutedTeal.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                color: AppColors.mutedTeal,
                size: 80,
              ),
            ),
            const SizedBox(height: 32),
            
            // Thank you message
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Thank you for your purchase!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Order confirmation message
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Your order has been successfully processed and will be shipped soon.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.coolGray,
                ),
              ),
            ),
            const SizedBox(height: 48),
            
            // Go to my purchases button
            ElevatedButton(
              onPressed: () {
                // Navigate to My Purchases page
                Navigator.pushReplacement(
                  context,
                  DarkPageReplaceRoute(page: const MyPurchasesPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.mutedTeal,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Go to My Purchases',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Continue shopping link
            TextButton(
              onPressed: () {
                // Navigate back to home page
                Navigator.popUntil(context, (route) => route.isFirst);
              },
              child: Text(
                'Continue Shopping',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.mutedTeal,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
