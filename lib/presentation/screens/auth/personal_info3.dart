import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import 'package:tarek_proj/presentation/screens/auth/personal_info4.dart';

class PersonalInfo3 extends StatefulWidget {
  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final String arabicName;
  final String jobTitle;

  const PersonalInfo3({
    super.key,
    required this.email,
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

  bool isValidPhoneNumber(String phone) {
    // Starts with 01, followed by exactly 9 digits. Total 11 digits.
    final RegExp phoneRegex = RegExp(r'^01[0-9]{9}$');
    return phoneRegex.hasMatch(phone);
  }

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
    String phone = phoneController.text.trim();
    String whatsapp = whatsappController.text.trim();
    String birthDate = birthDateController.text.trim();

    if (phone.isEmpty || birthDate.isEmpty) {
      showErrorDialog("Error", "Please fill in all fields.");
      return;
    }

    if (!isValidPhoneNumber(phone)) {
      showErrorDialog("Invalid Phone", "Please enter a valid phone number.");
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PersonalInfo4(
          email: widget.email,
          password: widget.password,
          firstName: widget.firstName,
          lastName: widget.lastName,
          arabicName: widget.arabicName,
          jobTitle: widget.jobTitle,
          phone: phone,
          whatsapp: whatsapp.isEmpty ? phone : whatsapp,
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
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.phone, color: Colors.indigo),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 20, horizontal: 20),
                    hintText: '01234567890',
                    hintStyle: const TextStyle(color: Colors.black),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.8),
                  ),
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
                TextField(
                  controller: whatsappController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    prefixIcon:
                        const Icon(Icons.mark_chat_unread, color: Colors.green),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 20, horizontal: 20),
                    hintText: '01234567890 (Optional if same)',
                    hintStyle: const TextStyle(color: Colors.black54),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.8),
                  ),
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
