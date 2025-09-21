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
  final String _jwtToken="eyJhbGciOiJSUzI1NiJ9.eyJkYXRhIjp7Im9wcyI6ImF1dGgiLCJjbGllbnRfdXVpZCI6IjAxZWIwOGE1LTk3NWEtNDRlMi1hMzRmLWNlZTc1ZmM4NDhjMCIsInRlcm1pbmFsX2lkIjoiMDIxMTY1MzQwMDExNjUzNCJ9fQ.bRhzhfiUpYVOJQ9CYVl6sLjSJYcbWQFD1TOfPskXNwly_mbXjk4MotoQUDuchBc9-WO8Rrj68EH4gn0Qk4eBC5ZlmlHtbuTeEFAWuMlkvjolbnBRPJ94NZJVA4pb8tpV5IFMHlAWTxsuq6OvinQj7Gv6DlGRr1c-2PPe5kj2IRQdNbdrduR6ScQ8r_vbtJcWVstcndUZbUWqPvGUpc55FEK9O5ML2oJZy9RgrE1O703TpnZCyXE_jOj39qtlxPhx-Ad5pJLtsrJlcTvN_9mN5LEZiJywJ4TFhV5bLHM2AK";

  @override
  void initState() {
    _nearPay.initialize();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 16,
          children: [
            ElevatedButton(
              onPressed: (){
                _nearPay.loginWithJWT(_jwtToken);
              },
              child: Center(child: Text("Login with jwt")),
            ),
            ElevatedButton(
              onPressed: (){
                _nearPay.purchaseDirectly( amount: 30, transactionUuid: '17b4b585-8b2f-4a5e-9340-184735b65412');
              },
              child: Center(child: Text("Purchase with 30 sar")),
            ),
            ElevatedButton(
              onPressed: (){
                _nearPay.refundDirectly( amount: 30, transactionUuid: '17b4b585-8b2f-4a5e-9340-184735b65412', refundUuid: '17b4b585-8b2f-4a5e-9340-184735b655432');

              },
              child: Center(child: Text("Refund 30 sar")),
            ),
          ],
        ),
      ),
    );
  }
}
