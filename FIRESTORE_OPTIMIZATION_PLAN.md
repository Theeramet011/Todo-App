# แผนลด Firestore Reads ให้อยู่ในโควต้าฟรี (50K/day)

## สถานการณ์ปัจจุบัน
- **ใช้งานจริง**: 244K reads/day (เกินโควต้า 50K ไป ~5 เท่า)
- **สาเหตุหลัก**: มี real-time listeners (`.snapshots()`) หลายตัวที่เปิดพร้อมกัน ทุกครั้งที่มีการเปลี่ยนแปลงข้อมูลแม้เพียงเล็กน้อย จะเกิดการ read ทั้ง collection ใหม่

## การวิเคราะห์จุดที่มีปัญหา

### 🔴 ปัญหาวิกฤต #1: ฟัง collection `users` ทั้งหมด (ร้ายแรงที่สุด)

ใน `lib/providers/task_provider.dart` บรรทัด 409-418 มีโค้ด:

```dart
_firestore.collection('users').snapshots().listen(...)
```

**ฟังการเปลี่ยนแปลงของ user ทุกคนในระบบ!** ถ้ามี user 100 คน ทุกครั้งที่ user คนใดคนหนึ่งเปลี่ยนข้อมูล → อ่าน 100 documents ใหม่ทั้งหมด ยิ่งมีคนใช้เยอะ ยิ่งเกิด reads ทวีคูณ

### 🔴 ปัญหาวิกฤต #2: ฟัง collection `projects` ทั้งหมด

ใน `lib/providers/task_provider.dart` บรรทัด 397-407 มีโค้ด:

```dart
_firestore.collection('projects').snapshots().listen(...)
```

**ฟัง project ทุกอันในระบบ** แม้ว่าจะ filter ฝั่ง client ด้วย `_applyProjectFilter()` ก็ยัง **เสีย reads สำหรับ project ทุกอันที่ไม่เกี่ยวข้องด้วย**

### 🟡 ปัญหาปานกลาง #3: Notification streams ซ้ำซ้อน

ใน `lib/screens/home_screen.dart` มี 2 จุดที่ฟัง notifications:
1. **_NotificationBellButton** (L630-635): ฟัง unread notifications แบบ real-time เพื่อแสดง badge
2. **NotificationPanel** (L831-835): ฟัง notifications อีกครั้งเมื่อเปิด panel

ทั้ง 2 อันนี้อาจทำงานพร้อมกันได้

### 🟡 ปัญหาปานกลาง #4: Task query ไม่มี limit

ใน `lib/providers/task_provider.dart` บรรทัด 457-476:

```dart
_firestore.collection('tasks')
    .where(Filter.or(...))
    .snapshots()
```

**ไม่มี `.limit()`** → ดึง task ทุกอัน รวมถึงที่เสร็จไปนานแล้ว (151+ งานที่เสร็จ)

### 🟢 ปัญหาเล็กน้อย #5: Auth provider ฟัง user profile ซ้ำ

ใน `lib/providers/auth_provider.dart` บรรทัด 515-530 ฟัง `users/{uid}` real-time ซ้ำกับ task_provider ที่ก็ฟัง `users` collection อยู่แล้ว (แต่หลังจากแก้ #1 จะไม่ซ้ำแล้ว)

---

## Proposed Changes

### 1. แก้ปัญหา `users` collection — ลดได้ ~60-70% ของ reads ทั้งหมด

#### [MODIFY] `lib/providers/task_provider.dart`

**เปลี่ยนจาก**: ฟัง `collection('users').snapshots()` ทั้ง collection  
**เป็น**: ใช้ **on-demand fetching** — ดึงข้อมูล user เฉพาะเมื่อต้องการ + cache ไว้ใน memory

```dart
// ลบออก:
_firestore.collection('users').snapshots().listen(...)

// เพิ่ม:
final Map<String, User> _userCache = {};

Future<User?> fetchUser(String userId) async {
  if (_userCache.containsKey(userId)) return _userCache[userId];
  final doc = await _firestore.collection('users').doc(userId).get();
  if (!doc.exists) return null;
  final user = User.fromMap(doc.data()!, doc.id);
  _userCache[userId] = user;
  return user;
}

void invalidateUserCache([String? userId]) {
  if (userId != null) {
    _userCache.remove(userId);
  } else {
    _userCache.clear();
  }
}
```

**เหตุผล**: ข้อมูล user อื่นๆ (ชื่อ, avatar) แทบไม่เปลี่ยนแปลง ไม่จำเป็นต้อง real-time สามารถ cache + refresh เมื่อจำเป็น

---

### 2. แก้ปัญหา `projects` collection — ลดได้ ~15-20%

#### [MODIFY] `lib/providers/task_provider.dart`

**เปลี่ยนจาก**: ฟัง `collection('projects').snapshots()` ทั้ง collection  
**เป็น**: ฟังเฉพาะ projects ที่เกี่ยวข้องกับ user ปัจจุบัน

```dart
// เปลี่ยนเป็น:
_firestore.collection('projects')
    .where(Filter.or(
      Filter('leaderId', isEqualTo: userId),
      Filter('memberIds', arrayContains: userId),
    ))
    .snapshots()
    .listen(...)
```

**เหตุผล**: ฟิลเตอร์ฝั่ง Firestore แทนฝั่ง client ทำให้อ่านเฉพาะ documents ที่เกี่ยวข้อง

---

### 3. จำกัด Task query + แยก completed tasks

#### [MODIFY] `lib/providers/task_provider.dart`

เพิ่มการจำกัดจำนวน + ไม่ดึง task ที่อยู่ในถังขยะ (ถ้าเป็นไปได้ตาม Firestore index):

**ทางเลือก A** (แนะนำ): เพิ่ม field `isDeleted` ใน Firestore query

```dart
_firestore.collection('tasks')
    .where(Filter.or(
      Filter('assigneeIds', arrayContains: userId),
      Filter('creatorId', isEqualTo: userId),
    ))
    .where('isDeleted', isEqualTo: false)  // ถ้า index รองรับ
    .snapshots()
```

**ทางเลือก B**: เปลี่ยน completed tasks เป็น on-demand (ไม่ real-time)
- หน้า completed_tasks_screen ไม่จำเป็นต้อง real-time
- ดึงด้วย `.get()` เมื่อเปิดหน้า + pull-to-refresh

---

### 4. รวม Notification stream

#### [MODIFY] `lib/screens/home_screen.dart`

**ทางเลือกที่แนะนำ**: ใช้ stream เดียวสำหรับทั้ง badge + panel
- สร้าง `NotificationProvider` ที่ฟัง notifications stream เพียงครั้งเดียว
- ทั้ง bell icon และ panel ใช้ข้อมูลจาก provider เดียวกัน

**หรือ**: เปลี่ยน bell icon ให้ใช้ count จาก notifications collection ด้วย `AggregateQuery` (ถ้ารองรับ)

---

## สรุปผลลัพธ์ที่คาดหวัง

| การเปลี่ยนแปลง | Reads ที่ลดได้ (ประมาณ) | ความยากในการ implement |
|---|---|---|
| #1 ยกเลิกฟัง `users` ทั้ง collection | **~60-70%** | ปานกลาง |
| #2 ฟิลเตอร์ `projects` ฝั่ง server | **~15-20%** | ง่าย |
| #3 จำกัด task query | **~5-10%** | ปานกลาง |
| #4 รวม notification stream | **~3-5%** | ง่าย |

> **สำคัญ**: การแก้ปัญหา #1 เพียงอย่างเดียวก็น่าจะลดการ reads ได้มากพอที่จะกลับเข้าสู่โควต้าฟรี เพราะการฟัง `users` collection ทั้งหมดนั้นเป็นตัวทวีคูณ reads อย่างมาก — ทุกการเปลี่ยนแปลงของ user ใดก็ตามจะเกิด read สำหรับ user ทุกคนในระบบ

## Open Questions

1. **ต้องการให้ implement ทุกข้อ หรือเริ่มจากข้อ #1 (ยกเลิกฟัง users ทั้ง collection) ก่อน?** — ข้อ #1 น่าจะลด reads ได้มากที่สุดและเห็นผลทันที
2. **หน้า completed tasks (151 งาน) ต้องการ real-time ไหม?** — ถ้าไม่จำเป็น สามารถเปลี่ยนเป็น `.get()` + pull-to-refresh ได้
3. **มี Composite Index ที่จำเป็นใน Firestore ไหม?** — การเพิ่ม filter `projects` ฝั่ง server อาจต้องสร้าง index ใหม่

## Verification Plan

### Manual Verification
- ดู Firebase Console → Usage → Reads ว่าลดลงอย่างมีนัยสำคัญหรือไม่ (ควรลดจาก 244K → ต่ำกว่า 50K)
- ทดสอบว่าทุกหน้ายังแสดงข้อมูลถูกต้อง (home, calendar, upcoming, completed)
- ทดสอบว่า user data (ชื่อ, avatar) ยังแสดงถูกต้องหลังเปลี่ยนเป็น cache
