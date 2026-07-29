import 'package:flutter/material.dart';

// Color Palette Definition for the Snippet
class StormyColors {
  static const Color darkSlate = Color(0xFF384959);
  static const Color iceBlue = Color(0xFFBDDDFC);
  static const Color mutedBlueGrey = Color(0xFF6A89A7);
  static const Color pureWhite = Color(0xFFFFFFFF);
}

class CreateTaskFormSnippet extends StatefulWidget {
  const CreateTaskFormSnippet({super.key});

  @override
  State<CreateTaskFormSnippet> createState() => _CreateTaskFormSnippetState();
}

class _CreateTaskFormSnippetState extends State<CreateTaskFormSnippet> {
  String _difficulty = 'ง่าย';
  String _volume = 'น้อย';
  String _risk = 'ไม่มี';

  bool _isRecurring = false;
  String _priority = 'ต่ำ';

  // Section Title Helper
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 24.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: StormyColors.darkSlate,
        ),
      ),
    );
  }

  // Pill Selection Buttons (Difficulty, Volume, Risk)
  Widget _buildSelectionPills(
    List<String> options,
    String selectedValue,
    Function(String) onChanged,
  ) {
    return Row(
      children: options.map((option) {
        final isSelected = selectedValue == option;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6.0),
            child: GestureDetector(
              onTap: () => onChanged(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 14.0),
                decoration: BoxDecoration(
                  color: isSelected
                      ? StormyColors.darkSlate
                      : StormyColors.iceBlue,
                  borderRadius: BorderRadius.circular(24.0),
                ),
                alignment: Alignment.center,
                child: Text(
                  option,
                  style: TextStyle(
                    color: isSelected
                        ? StormyColors.pureWhite
                        : StormyColors.darkSlate,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // Input Field Helper (Category, Location, Date, Time)
  Widget _buildInputField({
    required String label,
    required IconData icon,
    bool isDropdown = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: StormyColors.pureWhite,
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: TextFormField(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: StormyColors.mutedBlueGrey,
            fontSize: 14,
          ),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          prefixIcon: Icon(icon, color: StormyColors.mutedBlueGrey, size: 22),
          suffixIcon: isDropdown
              ? const Icon(
                  Icons.arrow_drop_down,
                  color: StormyColors.mutedBlueGrey,
                )
              : null,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: const BorderSide(
              color: StormyColors.mutedBlueGrey,
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: const BorderSide(
              color: StormyColors.darkSlate,
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16.0,
            horizontal: 12.0,
          ),
        ),
        readOnly: true, // Mockup purposes
        style: const TextStyle(
          color: StormyColors.darkSlate,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // Priority Selector Helper
  Widget _buildPrioritySelector() {
    final priorities = ['ต่ำ', 'ปานกลาง', 'สูง', 'ด่วน'];
    return Row(
      children: priorities.map((priority) {
        final isSelected = _priority == priority;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: GestureDetector(
              onTap: () => setState(() => _priority = priority),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                decoration: BoxDecoration(
                  color: isSelected
                      ? StormyColors.darkSlate
                      : StormyColors.iceBlue,
                  borderRadius: BorderRadius.circular(16.0),
                  border: Border.all(
                    color: isSelected
                        ? StormyColors.darkSlate
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? StormyColors.pureWhite
                            : StormyColors.mutedBlueGrey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      priority,
                      style: TextStyle(
                        color: isSelected
                            ? StormyColors.pureWhite
                            : StormyColors.mutedBlueGrey,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: StormyColors.pureWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('ความยาก'),
              _buildSelectionPills(
                ['ง่าย', 'ปานกลาง', 'ยาก'],
                _difficulty,
                (val) => setState(() => _difficulty = val),
              ),

              _buildSectionTitle('ปริมาณภารกิจ'),
              _buildSelectionPills(
                ['น้อย', 'ปานกลาง', 'มาก'],
                _volume,
                (val) => setState(() => _volume = val),
              ),

              _buildSectionTitle('ความเสี่ยง'),
              _buildSelectionPills(
                ['ไม่มี', 'ต่ำ', 'สูง'],
                _risk,
                (val) => setState(() => _risk = val),
              ),

              const SizedBox(height: 28),

              // Inputs Grid (2 columns layout)
              Row(
                children: [
                  Expanded(
                    child: _buildInputField(
                      label: 'หมวดหมู่',
                      icon: Icons.category,
                      isDropdown: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInputField(
                      label: 'สถานที่',
                      icon: Icons.location_on_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildInputField(
                      label: 'วันที่',
                      icon: Icons.calendar_today_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInputField(
                      label: 'เวลา',
                      icon: Icons.access_time,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Recurring Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ตั้งค่าการทำซ้ำ',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: StormyColors.darkSlate,
                    ),
                  ),
                  Switch(
                    value: _isRecurring,
                    onChanged: (val) => setState(() => _isRecurring = val),
                    activeThumbColor: StormyColors.pureWhite,
                    activeTrackColor: StormyColors.darkSlate,
                    inactiveThumbColor: StormyColors.pureWhite,
                    inactiveTrackColor: StormyColors.iceBlue,
                    trackOutlineColor: WidgetStateProperty.all(
                      Colors.transparent,
                    ),
                  ),
                ],
              ),

              _buildSectionTitle('ความสำคัญ'),
              _buildPrioritySelector(),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
