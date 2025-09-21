import 'package:flutter/material.dart';
import 'package:flutter_terminal_sdk/models/data/payment_scheme.dart';
import 'package:flutter_terminal_sdk/models/data/purchase_response.dart';

import 'near_pay_impl.dart';

class NearPayExampleScreen extends StatefulWidget {
  const NearPayExampleScreen({super.key});

  @override
  State<NearPayExampleScreen> createState() => _NearPayExampleScreenState();
}

class _NearPayExampleScreenState extends State<NearPayExampleScreen> {
  final NearPayImpl _nearPay = NearPayImpl();
  String _status = "Ready";
  bool? _isProcessing ;
  final String _jwtToken="eyJhbGciOiJSUzI1NiJ9.eyJkYXRhIjp7Im9wcyI6ImF1dGgiLCJjbGllbnRfdXVpZCI6IjAxZWIwOGE1LTk3NWEtNDRlMi1hMzRmLWNlZTc1ZmM4NDhjMCIsInRlcm1pbmFsX2lkIjoiMDIxMTY1MzQwMDExNjUzNCJ9fQ.bRhzhfiUpYVOJQ9CYVl6sLjSJYcbWQFD1TOfPskXNwly_mbXjk4MotoQUDuchBc9-WO8Rrj68EH4gn0Qk4eBC5ZlmlHtbuTeEFAWuMlkvjolbnBRPJ94NZJVA4pb8tpV5IFMHlAWTxsuq6OvinQj7Gv6DlGRr1c-2PPe5kj2IRQdNbdrduR6ScQ8r_vbtJcWVstcndUZbUWqPvGUpc55FEK9O5ML2oJZy9RgrE1O703TpnZCyXE_jOj39qtlxPhx-Ad5pJLtsrJlcTvN_9mN5LEZiJywJ4TFhV5bLHM2AK";


  Future<void> _processPayment({
    required double amount,
    required PaymentScheme? scheme,
    required String transactionUuid,
    required String type,
    required String refundUuid
  }) async {
    setState(() {
      _isProcessing = true;
      _status = "Starting payment";
    });
    try {
      await _nearPay.completeStreamlinedPayment(
          refundUuid: refundUuid,
          type: type,
          transactionUuid: transactionUuid,
          jwtToken: _jwtToken,
          scheme: scheme,
          amount: amount,
          callbacks: DirectPaymentCallbacks(
              onTransactionCompleted: (NearPayResult nearPay) async {
                print("test response :: ${nearPay.message}");
                print("test response :: ${nearPay.error}");
                print("test response :: ${nearPay.response}");
              },
              onStatusUpdate: (value){
                setState(() {
                  if(value=="Reader closed")_isProcessing=false;
                });

              },
              onCardReaderUpdate: (value){
                setState(() {
                  if(value=="Reader closed")_isProcessing=false;
                });
              }

          )
      );

    } catch (e) {
      setState(() {
        _isProcessing = false;
        _status = "Error: $e";
      });
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          spacing: 16,
          children: [
            InkWell(
              onTap: (){
                _processPayment(amount: 30, scheme: PaymentScheme.VISA, transactionUuid: "17b4b585-8b2f-4a5e-9340-184735b65412", type: "_", refundUuid: "_");
              },
              child: Container(
                height: 60,
                child:  Text("Purchase with 30 sar"),
              ),
            ),
            InkWell(
              onTap: (){
                _processPayment(amount: 30, scheme: PaymentScheme.VISA, transactionUuid: "17b4b585-8b2f-4a5e-9340-184735b65412", type: "refund", refundUuid: "17b4b585-8b2f-4a5e-9340-184735b65590");
              },
              child: Container(
                height: 60,
                child:  Text("Refund 30 sar"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
