import 'package:flutter/material.dart';

void main() {
  runApp(const MaterialApp(home: TestWidget()));
}

class TestWidget extends StatefulWidget {
  const TestWidget({super.key});

  @override
  State<TestWidget> createState() => _TestWidgetState();
}

class _TestWidgetState extends State<TestWidget> {
  String _initialValue = "First";
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              initialValue: _initialValue,
              validator: (val) {
                debugPrint('Validator called with: "$val"');
                return null;
              },
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _initialValue = "Second";
                });
              },
              child: const Text("Update initialValue"),
            ),
            ElevatedButton(
              onPressed: () {
                _formKey.currentState!.validate();
              },
              child: const Text("Validate"),
            ),
          ],
        ),
      ),
    );
  }
}
