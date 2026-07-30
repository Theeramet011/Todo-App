# 🔊 รายงานตรวจสอบ: เสียงเลื่อน CupertinoPicker ไม่ดังบนเครื่องจริง

## สรุปปัญหา

เสียง "คลิก" เวลาเลื่อนตัวเลือกจำนวนและหน่วยใน `CupertinoPicker` (หน้าตั้งค่าความถี่ซ้ำ) **ทำงานได้ปกติบน Emulator แต่ไม่มีเสียงบนเครื่องจริง (Android)**

---

## สาเหตุ

### โค้ดปัจจุบันที่มีปัญหา

ไฟล์ [`custom_recurring_modal.dart`](file:///C:/Users/A/OneDrive/Desktop/todoapp/lib/widgets/custom_recurring_modal.dart#L158-L164)

```dart
void _playScrollSound() {
  final isSoundEnabled =
      context.read<AuthProvider>().currentUser?.isSoundEnabled ?? true;
  if (isSoundEnabled) {
    SystemSound.play(SystemSoundType.click);  // ← ปัญหาอยู่ตรงนี้
  }
}
```

### ทำไมถึงไม่ดังบนเครื่องจริง?

`SystemSound.play(SystemSoundType.click)` เป็น API ของ Flutter ที่ส่งคำสั่งไปยัง **ระบบปฏิบัติการ** ให้เล่นเสียง "คลิก" ของระบบ

| สภาพแวดล้อม | ผลลัพธ์ | เหตุผล |
|:-----------:|:-------:|--------|
| Android Emulator | ✅ มีเสียง | Emulator ใช้ AOSP มาตรฐาน ซึ่งรองรับ `SystemSoundType.click` |
| เครื่อง Android จริง | ❌ ไม่มีเสียง | ผู้ผลิตส่วนใหญ่ (Samsung, Xiaomi, OPPO, Huawei ฯลฯ) **ปิดหรือไม่ได้ implement** เสียง click ของระบบสำหรับแอปบุคคลที่สาม |
| iOS (ถ้ามี) | ⚠️ อาจไม่ดัง | iOS รองรับเฉพาะบาง `SystemSoundType` เท่านั้น |

> **สรุป:** นี่เป็น **ข้อจำกัดระดับ platform** ที่เป็นปัญหาที่รู้กันทั่วไป (known issue) ของ Flutter — ไม่ใช่บั๊กในโค้ดของเรา แต่เราเลือกใช้ API ที่ไม่น่าเชื่อถือบนเครื่องจริง

### จุดที่ใช้ `SystemSound.play` ในโปรเจกต์

| ไฟล์ | บรรทัด | ใช้ตอน |
|------|:------:|--------|
| `custom_recurring_modal.dart` | 162 | เลื่อน CupertinoPicker (จำนวน + หน่วย) |

> มีเพียงจุดเดียวในโปรเจกต์ที่ใช้ `SystemSound.play`

---

## วิธีแก้ไข

### วิธีที่ 1: ใช้ `audioplayers` เล่นไฟล์เสียงคลิกเอง (แนะนำ — เชื่อถือได้ทุกเครื่อง)

เนื่องจากโปรเจกต์มี dependency `audioplayers: ^6.7.1` อยู่แล้ว และมี `SoundService` ที่ใช้งานอยู่ เราสามารถเพิ่มเสียง "tick/click" เข้าไปใน `SoundService` ได้เลย

#### ขั้นตอน:

**1. เพิ่มไฟล์เสียง:**
- หาไฟล์เสียงคลิกสั้นๆ (เช่น `tick.mp3` หรือ `click.mp3`) ขนาดเล็ก (~1-5KB)
- วางไว้ที่ `assets/sounds/tick.mp3`

**2. ลงทะเบียนใน `pubspec.yaml`:**
```yaml
flutter:
  assets:
    - assets/sounds/   # ← ควรมีอยู่แล้ว (ถ้ายังไม่มีให้เพิ่ม)
```

**3. เพิ่มเมธอดใน `SoundService`:**

```dart
// sound_service.dart — เพิ่มส่วนนี้

static const _tickAsset = 'sounds/tick.mp3';

final AudioPlayer _tickPlayer = AudioPlayer(playerId: 'tick_sound');

Future<void> playTickSound({required bool isSoundEnabled}) {
  return _play(
    player: _tickPlayer,
    assetPath: _tickAsset,
    isSoundEnabled: isSoundEnabled,
  );
}

// อัปเดต _configurePlayers() ให้ครอบคลุม _tickPlayer ด้วย:
Future<void> _configurePlayers() async {
  if (_isConfigured) return;
  await Future.wait([
    _taskCompletePlayer.setReleaseMode(ReleaseMode.stop),
    _levelUpPlayer.setReleaseMode(ReleaseMode.stop),
    _fastCompletionFailPlayer.setReleaseMode(ReleaseMode.stop),
    _tickPlayer.setReleaseMode(ReleaseMode.stop),           // ← เพิ่ม
    _taskCompletePlayer.setSource(AssetSource(_taskCompleteAsset)),
    _levelUpPlayer.setSource(AssetSource(_levelUpAsset)),
    _fastCompletionFailPlayer.setSource(AssetSource(_fastCompletionFailAsset)),
    _tickPlayer.setSource(AssetSource(_tickAsset)),          // ← เพิ่ม
  ]);
  _isConfigured = true;
}
```

**4. แก้ไข `_playScrollSound()` ใน `custom_recurring_modal.dart`:**

```dart
// ก่อนแก้
void _playScrollSound() {
  final isSoundEnabled =
      context.read<AuthProvider>().currentUser?.isSoundEnabled ?? true;
  if (isSoundEnabled) {
    SystemSound.play(SystemSoundType.click);
  }
}

// หลังแก้
void _playScrollSound() {
  final isSoundEnabled =
      context.read<AuthProvider>().currentUser?.isSoundEnabled ?? true;
  SoundService.instance.playTickSound(isSoundEnabled: isSoundEnabled);
}
```

**5. ลบ import ที่ไม่จำเป็น (ถ้าไม่ได้ใช้ที่อื่น):**
```diff
- import 'package:flutter/services.dart';
+ import '../services/sound_service.dart';
```

> **ข้อดี:** ใช้ไฟล์เสียงของเราเอง → ดังเหมือนกันทุกเครื่อง ทุก OS ไม่ขึ้นกับ OEM
> **ข้อเสีย:** ต้องหาไฟล์เสียง tick.mp3 มาเพิ่ม (ขนาดเล็กมาก ~1-5KB)

---

### วิธีที่ 2: ใช้ `HapticFeedback` แทนเสียง (ทางเลือก — ไม่ต้องเพิ่มไฟล์)

ถ้าไม่ต้องการเสียงจริงๆ แต่ต้องการ "feedback" ตอนเลื่อน สามารถใช้การสั่น (haptic) แทนได้ ซึ่งทำงานได้เชื่อถือบนเครื่องจริงทุกรุ่น

```dart
// ก่อนแก้
void _playScrollSound() {
  final isSoundEnabled =
      context.read<AuthProvider>().currentUser?.isSoundEnabled ?? true;
  if (isSoundEnabled) {
    SystemSound.play(SystemSoundType.click);
  }
}

// หลังแก้
void _playScrollSound() {
  final isSoundEnabled =
      context.read<AuthProvider>().currentUser?.isSoundEnabled ?? true;
  if (isSoundEnabled) {
    HapticFeedback.selectionClick();  // สั่นเบาๆ ทุกครั้งที่เลื่อน
  }
}
```

> **ข้อดี:** ไม่ต้องเพิ่มไฟล์เสียง, ใช้ API มาตรฐานที่เชื่อถือได้บนทุกเครื่อง
> **ข้อเสีย:** ไม่มี "เสียง" จริง เป็นแค่การสั่น (แต่ให้ประสบการณ์ที่ดีในการเลื่อน picker)

---

### วิธีที่ 3: ใช้ทั้งสองอย่างร่วมกัน (แนะนำสูงสุด)

รวมวิธีที่ 1 และ 2 เข้าด้วยกัน เพื่อให้ผู้ใช้ได้ทั้งเสียงและ haptic feedback:

```dart
void _playScrollSound() {
  final isSoundEnabled =
      context.read<AuthProvider>().currentUser?.isSoundEnabled ?? true;
  if (isSoundEnabled) {
    HapticFeedback.selectionClick();
    SoundService.instance.playTickSound(isSoundEnabled: true);
  }
}
```

---

## สรุปขั้นตอนแก้ไข

| ลำดับ | สิ่งที่ต้องทำ | ไฟล์ |
|:-----:|--------------|------|
| 1 | หาไฟล์เสียง `tick.mp3` ขนาดเล็ก วางใน `assets/sounds/` | `assets/sounds/tick.mp3` |
| 2 | เพิ่ม `playTickSound()` + พรีโหลด `_tickPlayer` ใน `SoundService` | `sound_service.dart` |
| 3 | เปลี่ยน `_playScrollSound()` จาก `SystemSound.play()` → `SoundService.instance.playTickSound()` | `custom_recurring_modal.dart` |
| 4 | (ถ้าต้องการ) เพิ่ม `HapticFeedback.selectionClick()` ร่วมด้วย | `custom_recurring_modal.dart` |
| 5 | ลบ `import 'package:flutter/services.dart'` ถ้าไม่ได้ใช้ที่อื่นในไฟล์ | `custom_recurring_modal.dart` |
