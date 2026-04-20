import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:tarek_proj/presentation/screens/auth/personal_info4.dart';

class PersonalInfo3 extends StatefulWidget {
  final String email;
  final String username;
  final String password;
  final String firstName;
  final String lastName;
  final String arabicName;
  final String jobTitle;

  const PersonalInfo3({
    super.key,
    required this.email,
    required this.username,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.arabicName,
    required this.jobTitle,
  });

  @override
  _PersonalInfo3State createState() => _PersonalInfo3State();
}

class _PersonalInfo3State extends State<PersonalInfo3> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController whatsappController = TextEditingController();
  final TextEditingController birthDateController = TextEditingController();

  String completePhoneNumber = '';
  String completeWhatsappNumber = '';

  void showErrorDialog(String title, String message) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      animType: AnimType.rightSlide,
      title: title,
      desc: message,
      btnOkOnPress: () {},
    ).show();
  }

  bool _isValidPhoneNumber(String phone) {
    return phone.length >= 8 && phone.startsWith('+');
  }

  // Removed manual validation since IntlPhoneField handles it

  void pickBirthDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(2000, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      setState(() {
        birthDateController.text =
            "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
      });
    }
  }

  void handleNext() {
    String birthDate = birthDateController.text.trim();

    if (completePhoneNumber.isEmpty || birthDate.isEmpty) {
      showErrorDialog("Error", "Please fill in all required fields.");
      return;
    }

    if (!_isValidPhoneNumber(completePhoneNumber)) {
      showErrorDialog("Invalid Phone",
          "Please enter a valid phone number with country code.");
      return;
    }

    if (completeWhatsappNumber.isNotEmpty &&
        !_isValidPhoneNumber(completeWhatsappNumber)) {
      showErrorDialog("Invalid WhatsApp",
          "Please enter a valid WhatsApp number with country code.");
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PersonalInfo4(
          email: widget.email,
          username: widget.username,
          password: widget.password,
          firstName: widget.firstName,
          lastName: widget.lastName,
          arabicName: widget.arabicName,
          jobTitle: widget.jobTitle,
          phone: completePhoneNumber,
          whatsapp: completeWhatsappNumber.isEmpty
              ? completePhoneNumber
              : completeWhatsappNumber,
          birthDate: birthDate,
        ),
      ),
    );
  }

  void handlePrevious() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ad here'),
        centerTitle: true,
      ),
      body: Container(
        height: MediaQuery.of(context).size.height,
        decoration: const BoxDecoration(
          image: DecorationImage(
            fit: BoxFit.cover,
            image: AssetImage(
              'images/bg.jpg',
            ),
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const SizedBox(height: 40),
                const Text(
                  '3 out 4',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 80),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 5, bottom: 5),
                    child: Text(
                      'Phone Number',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                IntlPhoneField(
                  controller: phoneController,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 20, horizontal: 20),
                    hintText: 'Phone Number',
                    hintStyle: const TextStyle(color: Colors.black),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.8),
                  ),
                  initialCountryCode: 'EG',
                  onChanged: (phone) {
                    completePhoneNumber = phone.completeNumber;
                  },
                ),
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 5, bottom: 5),
                    child: Text(
                      'WhatsApp Number',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                IntlPhoneField(
                  controller: whatsappController,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 20, horizontal: 20),
                    hintText: 'WhatsApp (Optional if same)',
                    hintStyle: const TextStyle(color: Colors.black54),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.8),
                  ),
                  initialCountryCode: 'EG',
                  onChanged: (phone) {
                    completeWhatsappNumber = phone.completeNumber;
                  },
                ),
                const SizedBox(height: 40),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.only(left: 5, bottom: 5),
                    child: Text(
                      'Birth Date',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                TextField(
                  controller: birthDateController,
                  readOnly: true,
                  onTap: pickBirthDate,
                  decoration: InputDecoration(
                    prefixIcon:
                        const Icon(Icons.calendar_today, color: Colors.indigo),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 20, horizontal: 20),
                    hintText: 'Select Date',
                    hintStyle: const TextStyle(color: Colors.black),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                        onPressed: handlePrevious,
                        child: const Text('Previous')),
                    ElevatedButton(
                        onPressed: handleNext, child: const Text('Next')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
