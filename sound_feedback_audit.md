# 🔊 รายงานตรวจสอบเสียง Feedback ที่หลงเหลือในแอป

## สรุปภาพรวม

ปัจจุบัน `theme.dart` ได้ตั้ง `enableFeedback: false` ไว้สำหรับ widget เหล่านี้แล้ว:

| Widget | Light Theme | Dark Theme |
|--------|:-----------:|:----------:|
| `ElevatedButton` | ✅ (L:118) | ✅ (L:410) |
| `TextButton` | ✅ (L:140) | ✅ (L:429) |
| `FloatingActionButton` | ✅ (L:151) | ✅ (L:365) |
| `BottomNavigationBar` | ✅ (L:160) | ✅ (L:372) |
| `IconButton` | ✅ (L:280) | ✅ (L:438) |

**แต่** widget ประเภท `InkWell` และ `ListTile` ไม่มีการตั้ง `enableFeedback` ในระดับ theme ทำให้ทุกตัวที่ใช้ในแอปยังมี **เสียง click ของระบบ** เป็น default

---

## ปัญหาที่พบ

### 1. `InkWell` ที่ยังมีเสียง feedback (ไม่มี `enableFeedback: false`)

Flutter `InkWell` มี `enableFeedback: true` เป็นค่า default และ **ไม่มี theme-level setting** ที่จะปิดได้ทั้งหมดในคราวเดียว ต้องใส่ `enableFeedback: false` ที่ตัว widget เองแต่ละจุด

#### ไฟล์ `create_task_modal.dart`

| บรรทัด | หน้าที่ของ InkWell | เสียงหลง |
|:------:|-------------------|:--------:|
| 749 | ปุ่ม Location Chip | ⚠️ |
| 816 | ปุ่มเพิ่มการแจ้งเตือนแบบกำหนดเอง | ⚠️ |
| 1031 | ปุ่มเปิด/ปิดส่วนภารกิจย่อย | ⚠️ |
| 1420 | ปุ่มเพิ่มสมาชิก | ⚠️ |
| 2232 | ปุ่มเลือกวันที่ | ⚠️ |
| 2300 | ปุ่มเลือกเวลา | ⚠️ |
| 2463 | **ตัวเลือกในหน้าซ้ำ (recurring options)** — จุดที่ผู้ใช้รายงาน | ⚠️ |
| 2584 | **ปุ่ม "ซ้ำ" หลัก** — จุดที่ผู้ใช้รายงาน | ⚠️ |
| 2731 | ตัวเลือกในหน้า priority | ⚠️ |
| 2809 | ปุ่ม priority หลัก | ⚠️ |
| 3492 | ปุ่มเลือกวันที่ (group task) | ⚠️ |
| 3563 | ปุ่มเลือกเวลา (group task) | ⚠️ |

#### ไฟล์ `custom_recurring_modal.dart`

| บรรทัด | หน้าที่ของ InkWell | เสียงหลง |
|:------:|-------------------|:--------:|
| 940 | ปุ่มเลือกวันที่ (Fixed Date) | ⚠️ |
| 1017 | ปุ่มเลือกเวลา (Fixed Date) | ⚠️ |

#### ไฟล์อื่นๆ

| ไฟล์ | บรรทัด | หน้าที่ |
|------|:------:|--------|
| `member_config_sheet.dart` | 1284, 1501 | ตัวเลือกสมาชิก |
| `frame_picker_widget.dart` | 340 | เลือกกรอบรูป |
| `bottom_nav_bar.dart` | 85 | แถบเมนูล่าง |
| `adaptive_nav_bar.dart` | 55 | แถบเมนูแบบ adaptive |
| `achievement_summary_card.dart` | 24 | การ์ดสรุปความสำเร็จ |
| `upcoming_tasks_screen.dart` | 552 | รายการงาน |
| `settings_screen.dart` | 257 | ตั้งค่า |
| `member_assignment_detail_screen.dart` | 552 | รายละเอียดงานที่มอบหมาย |
| `home_screen.dart` | 1559, 2342, 2630, 2675 | หน้าหลัก |
| `friends_screen.dart` | 427 | หน้าเพื่อน |
| `edit_profile_screen.dart` | 186 | แก้ไขโปรไฟล์ |
| `achievement_list_screen.dart` | 301 | รายการความสำเร็จ |

---

### 2. `ListTile` / `CheckboxListTile` / `SwitchListTile` ที่ยังมีเสียง feedback

`theme.dart` **ไม่มี** `listTileTheme` ถูกกำหนดเลย ทำให้ทุก `ListTile` ยังใช้ `enableFeedback: true` เป็นค่า default

| ไฟล์ | บรรทัด | ประเภท |
|------|:------:|--------|
| `member_config_sheet.dart` | 194 | `ListTile` |
| `member_config_sheet.dart` | 354 | `CheckboxListTile` |
| `custom_drawer.dart` | 255 | `ListTile` |
| `create_task_modal.dart` | 1755 | `CheckboxListTile` |
| `task_search_delegate.dart` | 170 | `ListTile` |
| `task_detail_screen.dart` | 1554, 2995, 3006, 3120 | `ListTile` |
| `settings_screen.dart` | 529 | `SwitchListTile` |
| `settings_screen.dart` | 566 | `ListTile` |
| `previews/settings_preview.dart` | 254 | `ListTile` |
| `edit_profile_screen.dart` | 101 | `ListTile` |

---

## วิธีแก้ไข

### วิธีที่ 1: แก้ที่ Theme (แนะนำ — แก้ทีเดียวครอบคลุม `ListTile`)

เพิ่ม `listTileTheme` ใน **ทั้ง light theme และ dark theme** ของ `theme.dart`:

```dart
// เพิ่มใน lightTheme และ darkTheme
listTileTheme: const ListTileThemeData(
  enableFeedback: false,
),
```

> **หมายเหตุ:** วิธีนี้จะปิดเสียงให้ `ListTile`, `CheckboxListTile`, `SwitchListTile` ทั้งหมดโดยอัตโนมัติ

---

### วิธีที่ 2: แก้ที่ตัว `InkWell` แต่ละจุด (จำเป็น — ไม่มี theme-level สำหรับ InkWell)

เพิ่ม `enableFeedback: false` ให้กับทุก `InkWell` ที่ระบุไว้ข้างต้น เช่น:

```dart
// ก่อนแก้
InkWell(
  onTap: _showRecurringBottomSheet,
  borderRadius: BorderRadius.circular(12.0),
  child: ...
)

// หลังแก้
InkWell(
  enableFeedback: false,   // ← เพิ่มบรรทัดนี้
  onTap: _showRecurringBottomSheet,
  borderRadius: BorderRadius.circular(12.0),
  child: ...
)
```

---

### วิธีที่ 3 (ทางเลือก): ครอบด้วย `Theme` widget เพื่อปิด feedback ทั้ง subtree

หากต้องการปิดเสียงให้กับ `InkWell` ทั้งหมดในระดับ subtree โดยไม่ต้องแก้ทีละจุด สามารถครอบ widget tree ระดับสูงด้วย:

```dart
Theme(
  data: Theme.of(context).copyWith(
    splashFactory: NoSplash.splashFactory,  // ปิด splash effect
  ),
  child: ... // subtree ที่ต้องการ
)
```

> **ข้อจำกัด:** วิธีนี้จะปิด **splash animation** แต่ไม่ได้ปิดเสียง click โดยตรง ดังนั้นสำหรับ `InkWell` ยังคง **ต้องใส่ `enableFeedback: false` ที่ตัว widget เอง**

---

## สรุปขั้นตอนแก้ไข

| ลำดับ | สิ่งที่ต้องทำ | ไฟล์ |
|:-----:|--------------|------|
| 1 | เพิ่ม `listTileTheme: ListTileThemeData(enableFeedback: false)` ทั้ง light/dark | `theme.dart` |
| 2 | เพิ่ม `enableFeedback: false` ให้ `InkWell` ทุกจุดใน `create_task_modal.dart` (12 จุด) | `create_task_modal.dart` |
| 3 | เพิ่ม `enableFeedback: false` ให้ `InkWell` ทุกจุดใน `custom_recurring_modal.dart` (2 จุด) | `custom_recurring_modal.dart` |
| 4 | เพิ่ม `enableFeedback: false` ให้ `InkWell` ในไฟล์อื่นๆ (12 จุด) | ดูตารางด้านบน |
