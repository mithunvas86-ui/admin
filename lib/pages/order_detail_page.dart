import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OrderDetailPage extends StatelessWidget {
  final String orderId;
  const OrderDetailPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Order #$orderId', style: GoogleFonts.chivo(fontSize: 24, fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: Text('Order Details', style: GoogleFonts.chivo(fontSize: 18)),
      ),
    );
  }
}
