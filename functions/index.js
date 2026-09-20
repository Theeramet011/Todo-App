// ไฟล์นี้เปรียบเสมือนสมองของระบบหลังบ้าน (Cloud Functions)
// ทำหน้าที่คอยตรวจสอบข้อมูล สั่งการ และส่งการแจ้งเตือนไปยังโทรศัพท์ของผู้ใช้งาน
const { HttpsError, onCall } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");
if (!admin.apps.length) {
  admin.initializeApp();
}

const FUNCTION_REGION = "asia-southeast1";
const TASK_REMINDER_CHANNEL_ID = "task_reminder_alerts_v3";
const TASK_COMMENT_CHANNEL_ID = "task_comment_alerts_v2";
const IN_APP_NOTIFICATION_CHANNEL_ID = TASK_REMINDER_CHANNEL_ID;
const CLIENT_PUSH_NOTIFICATION_TYPES = new Set([
  "Comment",
  "Group",
  "Submission",
  "Approved",
  "Rejected",
  "FriendRequest",
  "FriendAccepted",
]);

function androidChannelIdForNotificationType(notificationType) {
  return notificationType === "Comment"
    ? TASK_COMMENT_CHANNEL_ID
    : IN_APP_NOTIFICATION_CHANNEL_ID;
}

function androidNotificationPriorityForType(notificationType) {
  return notificationType === "Comment" ? "max" : "max";
}

function isInvalidFcmTokenError(err) {
  const code = asMessageText(err && err.code);
  const message = asMessageText(err && err.message).toLowerCase();
  return code === "messaging/registration-token-not-registered" ||
    code === "messaging/invalid-registration-token" ||
    message.includes("requested entity was not found");
}

function setRecipientRole(recipientRoles, userId, role) {
  if (typeof userId !== "string" || userId.trim().length === 0) return;

  const normalizedUserId = userId.trim();
  const currentRole = recipientRoles.get(normalizedUserId);
  if (currentRole === "leader") return;
  recipientRoles.set(normalizedUserId, role);
}

function setRecipientRoles(recipientRoles, userIds, role) {
  if (!Array.isArray(userIds)) return;
  for (const userId of userIds) {
    setRecipientRole(recipientRoles, userId, role);
  }
}

function memberRecords(taskData) {
  if (Array.isArray(taskData.members)) return taskData.members;
  if (taskData.members && typeof taskData.members === "object") {
    return Object.values(taskData.members);
  }
  return [];
}

function notificationRecipients(taskData, isPersonalTask, projectData = null) {
  const recipientRoles = new Map();
  const deletedForUserIds = new Set(
    Array.isArray(taskData.deletedForUserIds) ? taskData.deletedForUserIds : []
  );

  if (isPersonalTask) {
    setRecipientRole(recipientRoles, taskData.assigneeId, "personal");
    setRecipientRoles(recipientRoles, taskData.assigneeIds, "personal");
    setRecipientRole(recipientRoles, taskData.creatorId, "personal");
    setRecipientRole(recipientRoles, taskData.userId, "personal");
    return [...recipientRoles]
      .filter(([userId]) => !deletedForUserIds.has(userId))
      .map(([userId, role]) => ({userId, role}));
  }

  setRecipientRole(recipientRoles, taskData.assigneeId, "member");
  setRecipientRoles(recipientRoles, taskData.assigneeIds, "member");

  for (const member of memberRecords(taskData)) {
    if (!member || typeof member !== "object") continue;
    setRecipientRole(recipientRoles, member.id, "member");
    setRecipientRole(recipientRoles, member.userId, "member");
    setRecipientRoles(recipientRoles, member.coAssigneeIds, "member");
  }

  setRecipientRole(recipientRoles, taskData.creatorId, "leader");
  setRecipientRole(recipientRoles, taskData.leaderId, "leader");
  setRecipientRole(recipientRoles, taskData.ownerId, "leader");
  if (projectData) {
    setRecipientRole(recipientRoles, projectData.leaderId, "leader");
    setRecipientRole(recipientRoles, projectData.ownerId, "leader");
    setRecipientRole(recipientRoles, projectData.creatorId, "leader");
  }

  return [...recipientRoles]
    .filter(([userId]) => !deletedForUserIds.has(userId))
    .map(([userId, role]) => ({userId, role}));
}

function sanitizeForDisplay(text) {
  if (!text || typeof text !== "string") return text;
  let res = text;
  if (/^[\u0300-\u036F\u0E31\u0E33-\u0E3A\u0E47-\u0E4E]/.test(res)) {
    res = "\u200B" + res;
  }
  return res.replace(
    /([\x20-\x2F\x3A-\x40\x5B-\x60\x7B-\x7E])([\u0300-\u036F\u0E31\u0E33-\u0E3A\u0E47-\u0E4E])/g,
    "$1\u200B$2"
  );
}

function groupNotificationCopy(flagToUpdate, role, taskTitle) {
  const isLeader = role === "leader";

  if (flagToUpdate.startsWith("custom_")) {
    const minutesBefore = parseInt(flagToUpdate.replace("custom_", ""), 10);
    const timeLabel = Number.isFinite(minutesBefore)
      ? customReminderLabel(minutesBefore)
      : "กำหนด";
    return isLeader
      ? {
        title: `⏳ อีก ${timeLabel} ถึงเวลาตรวจงาน`,
        body: `ภารกิจ "${taskTitle}" ใกล้ถึงกำหนดแล้ว เตรียมติดตามและตรวจความพร้อมของทีมได้เลย`,
      }
      : {
        title: `⏳ อีก ${timeLabel} ส่งงานกลุ่ม!`,
        body: `ภารกิจ "${taskTitle}" ใกล้ถึงกำหนดแล้ว ทุกคนพร้อมไหม?`,
      };
  }

  if (flagToUpdate === "notified1Week") {
    return isLeader
      ? {
        title: "⏳ อีก 1 สัปดาห์ถึงกำหนดส่งงานสมาชิก",
        body: `ภารกิจ "${taskTitle}" จะถึงกำหนดส่งในอีก 1 สัปดาห์ เตรียมติดตามความคืบหน้าของทีมได้เลย`,
      }
      : {
        title: "⏳ อีก 1 สัปดาห์ส่งงานกลุ่ม!",
        body: `ภารกิจ "${taskTitle}" มีกำหนดส่งสัปดาห์หน้า ทุกคนพร้อมไหม?`,
      };
  }

  if (flagToUpdate === "notified1Day") {
    return isLeader
      ? {
        title: "🚨 พรุ่งนี้ครบกำหนดส่งงานสมาชิก",
        body: `ภารกิจ "${taskTitle}" จะครบกำหนดพรุ่งนี้ อย่าลืมเช็กความพร้อมของทีม`,
      }
      : {
        title: "🚨 พรุ่งนี้เดดไลน์ภารกิจกลุ่ม!",
        body: `อย่าลืมช่วยกันปั่นภารกิจ "${taskTitle}" นะ พรุ่งนี้ต้องส่งแล้ว!`,
      };
  }

  if (flagToUpdate === "notified1Hour") {
    return isLeader
      ? {
        title: "🔥 อีก 1 ชั่วโมงถึงเวลาตรวจงาน",
        body: `ภารกิจ "${taskTitle}" เหลือเวลาให้สมาชิกส่งอีก 60 นาที เตรียมตรวจงานได้เลย`,
      }
      : {
        title: "🔥 1 ชั่วโมงสุดท้ายของภารกิจกลุ่ม!",
        body: `เร่งมือเข้าทุกคน! ภารกิจ "${taskTitle}" จะหมดเวลารับส่งในอีก 60 นาทีนี้`,
      };
  }

  if (flagToUpdate === "notifiedExact") {
    return isLeader
      ? {
        title: "⏰ หมดเวลาส่งงานของเหล่าสมาชิกแล้ว",
        body: `ได้เวลาตรวจงาน "${taskTitle}" แล้วครับ`,
      }
      : {
        title: "⏰ หมดเวลาส่งงานกลุ่มแล้ว!",
        body: `ภารกิจ "${taskTitle}" ถึงกำหนดเวลาส่งอย่างเป็นทางการแล้ว`,
      };
  }

  if (flagToUpdate === "notifiedFollowUp") {
    return isLeader
      ? {
        title: "❓ ถึงเวลาตรวจความคืบหน้าทีมแล้ว",
        body: `ภารกิจ "${taskTitle}" เลยเวลาส่งมา 30 นาทีแล้ว เข้าไปตรวจงานหรือแจ้งสมาชิกได้เลย`,
      }
      : {
        title: "❓ ภารกิจกลุ่มเสร็จหรือยังครับ?",
        body: `ภารกิจ "${taskTitle}" เลยเวลาส่งมา 30 นาทีแล้ว อย่าลืมเข้าไปอัปเดตสถานะของทีมกันด้วยนะครับ`,
      };
  }

  return {
    title: "⏰ แจ้งเตือนภารกิจกลุ่ม",
    body: `ภารกิจ "${taskTitle}" มีการแจ้งเตือนใหม่`,
  };
}

function isGroupTask(taskData) {
  const type = (taskData.type || "").toString().toLowerCase();
  if (type.includes("group")) return true;
  if (typeof taskData.projectId === "string" && taskData.projectId.trim()) {
    return true;
  }
  if (Array.isArray(taskData.members) && taskData.members.length > 0) {
    return true;
  }
  if (
    taskData.members &&
    typeof taskData.members === "object" &&
    Object.keys(taskData.members).length > 0
  ) {
    return true;
  }
  return Array.isArray(taskData.assigneeIds) && taskData.assigneeIds.length > 1;
}

function notificationTypeForFlag(flagToUpdate) {
  if (flagToUpdate === "notifiedExact") return "Deadline";
  if (flagToUpdate === "notifiedFollowUp") return "Follow-up";
  if (
    flagToUpdate === "notified1Week" ||
    flagToUpdate === "notified1Day" ||
    flagToUpdate === "notified1Hour"
  ) {
    return "Reminder";
  }
  return "Update";
}

function customReminderLabel(minutesBefore) {
  if (minutesBefore >= 10080 && minutesBefore % 10080 === 0) {
    return `${minutesBefore / 10080} สัปดาห์`;
  }
  if (minutesBefore >= 1440 && minutesBefore % 1440 === 0) {
    return `${minutesBefore / 1440} วัน`;
  }
  if (minutesBefore >= 60 && minutesBefore % 60 === 0) {
    return `${minutesBefore / 60} ชั่วโมง`;
  }
  return `${minutesBefore} นาที`;
}

function asMessageText(value, fallback = "") {
  if (value === null || value === undefined) return fallback;
  const text = value.toString().trim();
  return text.length > 0 ? text : fallback;
}

function notificationDataPayload(notificationData, userId, notificationId) {
  const payload = {
    notificationId,
    recipientId: userId,
    title: asMessageText(notificationData.title),
    body: asMessageText(notificationData.body),
    notificationType: asMessageText(notificationData.type, "Update"),
    notificationStage: asMessageText(notificationData.notificationStage),
    notificationKey: asMessageText(
      notificationData.notificationKey,
      `${notificationId}-${userId}`
    ),
    click_action: "FLUTTER_NOTIFICATION_CLICK",
  };

  const optionalFields = [
    "taskId",
    "taskType",
    "recipientRole",
    "actorId",
    "actorName",
    "actorAvatarUrl",
    "commentId",
    "friendRequestId",
  ];

  for (const field of optionalFields) {
    const value = asMessageText(notificationData[field]);
    if (value) payload[field] = value;
  }

  return payload;
}

// ฟังก์ชันสำหรับส่งการแจ้งเตือนแบบด่วนเมื่อเกิดเหตุการณ์ต่างๆ ในแอป
// เช่น เมื่อมีคนแสดงความคิดเห็น หรือมีการตอบรับคำขอเป็นเพื่อน
exports.pushInAppNotification = onCall({
  region: FUNCTION_REGION,
}, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  const notifications = Array.isArray(request.data && request.data.notifications)
    ? request.data.notifications
    : [];

  if (notifications.length === 0) {
    return {sent: 0, skipped: 0, failed: 0};
  }

  if (notifications.length > 100) {
    throw new HttpsError(
      "invalid-argument",
      "A maximum of 100 notifications can be pushed per request."
    );
  }

  const db = admin.firestore();
  const messaging = admin.messaging();
  let sent = 0;
  let skipped = 0;
  let failed = 0;

  for (const item of notifications) {
    const userId = asMessageText(item && item.userId);
    const notificationId = asMessageText(item && item.notificationId);

    if (!userId || !notificationId) {
      skipped++;
      continue;
    }

    const notificationRef = db
      .collection("users")
      .doc(userId)
      .collection("notifications")
      .doc(notificationId);
    const snapshot = await notificationRef.get();

    if (!snapshot.exists) {
      skipped++;
      continue;
    }

    const notificationData = snapshot.data() || {};

    if (notificationData.suppressPush === true) {
      console.log(`ℹ️ ข้าม push จาก notification ${notificationId}: suppressPush=true`);
      skipped++;
      continue;
    }

    if (notificationData.deletedAt) {
      console.log(`ℹ️ ข้าม push จาก notification ${notificationId}: ถูกลบแล้ว`);
      skipped++;
      continue;
    }

    if (notificationData.pushStatus === "sent") {
      skipped++;
      continue;
    }

    const notificationType = asMessageText(notificationData.type, "Update");
    if (!CLIENT_PUSH_NOTIFICATION_TYPES.has(notificationType)) {
      skipped++;
      continue;
    }

    const actorId = asMessageText(notificationData.actorId);
    if (actorId !== request.auth.uid) {
      console.log(
        `ℹ️ ข้าม push ${notificationId}: actorId ไม่ตรงกับผู้เรียก function`
      );
      skipped++;
      continue;
    }

    const title = asMessageText(notificationData.title, "มีแจ้งเตือนใหม่");
    const body = asMessageText(
      notificationData.body,
      "เปิดแอปเพื่อดูรายละเอียดล่าสุด"
    );
    const notificationKey = asMessageText(
      notificationData.notificationKey,
      `${notificationId}-${userId}`
    );
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) {
      console.log(`ℹ️ ไม่พบผู้ใช้ ${userId} สำหรับ notification ${notificationId}`);
      skipped++;
      continue;
    }

    const userData = userDoc.data() || {};
    const fcmToken = asMessageText(userData.fcmToken);
    if (!fcmToken) {
      console.log(`ℹ️ User ${userId} ไม่มี fcmToken ข้าม push notification`);
      await snapshot.ref.set({
        pushStatus: "missing-token",
        pushCheckedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      skipped++;
      continue;
    }

    const payload = notificationDataPayload(
      notificationData,
      userId,
      notificationId
    );
    const channelId = androidChannelIdForNotificationType(notificationType);
    const vibrationTimings = notificationType === "Comment"
      ? [0, 350, 150, 350, 150, 550]
      : [0, 700, 250, 700];

    const message = {
      notification: {
        title: title,
        body: body,
      },
      data: payload,
      android: {
        priority: "high",
        ttl: 24 * 60 * 60 * 1000,
        notification: {
          channelId: channelId,
          sound: "notification",
          icon: "ic_stat_noti_photoroom",
          priority: "max",
          defaultVibrateTimings: false,
          vibrateTimingsMillis: vibrationTimings,
          visibility: "public",
          tag: notificationKey,
          clickAction: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
      token: fcmToken,
    };

    try {
      await messaging.send(message);
      await snapshot.ref.set({
        pushStatus: "sent",
        pushSentAt: admin.firestore.FieldValue.serverTimestamp(),
        pushNotificationType: notificationType,
      }, { merge: true });
      console.log(`🟩 ส่ง push จาก in-app notification สำเร็จ -> User: ${userId}`);
      sent++;
    } catch (err) {
      const updateData = {
        pushStatus: "failed",
        pushError: asMessageText(err && err.message, "unknown-error"),
        pushFailedAt: admin.firestore.FieldValue.serverTimestamp(),
      };

      if (isInvalidFcmTokenError(err)) {
        updateData.pushStatus = "invalid-token";
        updateData.invalidTokenClearedAt =
          admin.firestore.FieldValue.serverTimestamp();
        await userDoc.ref.set({
          fcmToken: admin.firestore.FieldValue.delete(),
          lastInvalidFcmTokenAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }

      await snapshot.ref.set({
        ...updateData,
      }, { merge: true });
      console.error(`🟥 ส่ง push จาก in-app notification ล้มเหลว -> User: ${userId}:`, err);
      failed++;
    }
  }

  return {sent, skipped, failed};
});

// -----------------------------------------------------------------
// 🔁 ตัวช่วยคำนวณรอบถัดไปของงานทำซ้ำ (Recurring Tasks)
// -----------------------------------------------------------------
const THAI_WEEKDAYS_MAP = {
  "อา.": 0,
  "จ.": 1,
  "อ.": 2,
  "พ.": 3,
  "พฤ.": 4,
  "ศ.": 5,
  "ส.": 6,
};

const BANGKOK_OFFSET_MS = 7 * 60 * 60 * 1000;

function toBangkokDate(date) {
  return new Date(date.getTime() + BANGKOK_OFFSET_MS);
}

function fromBangkokDateParts(year, month, date, hours = 0, minutes = 0) {
  return new Date(
    Date.UTC(year, month, date, hours, minutes, 0, 0) - BANGKOK_OFFSET_MS
  );
}

function calculateNextRecurringDate(taskData, fromDate) {
  if (!taskData || !taskData.isRecurring) return null;

  const base =
    fromDate instanceof Date
      ? new Date(fromDate.getTime())
      : new Date(
          taskData.dateTime && taskData.dateTime.toDate
            ? taskData.dateTime.toDate()
            : taskData.dueDate && taskData.dueDate.toDate
              ? taskData.dueDate.toDate()
              : Date.now()
        );

  const bkkBase = toBangkokDate(base);
  let bkkYear = bkkBase.getUTCFullYear();
  let bkkMonth = bkkBase.getUTCMonth();
  let bkkDate = bkkBase.getUTCDate();
  let bkkHours = bkkBase.getUTCHours();
  let bkkMinutes = bkkBase.getUTCMinutes();

  const type = taskData.recurringType || "daily";

  if (type === "daily") {
    bkkDate += 1;
  } else if (type === "weekly") {
    bkkDate += 7;
  } else if (type === "monthly") {
    bkkMonth += 1;
  } else if (type === "yearly") {
    bkkYear += 1;
  } else if (type === "weekdays") {
    bkkDate += 1;
    let tempBkk = toBangkokDate(
      fromBangkokDateParts(bkkYear, bkkMonth, bkkDate, bkkHours, bkkMinutes)
    );
    while (tempBkk.getUTCDay() === 0 || tempBkk.getUTCDay() === 6) {
      bkkDate += 1;
      tempBkk = toBangkokDate(
        fromBangkokDateParts(bkkYear, bkkMonth, bkkDate, bkkHours, bkkMinutes)
      );
    }
  } else if (type === "custom") {
    const num = Number(taskData.customRecurringNum) || 1;
    const unit = taskData.customRecurringUnit || "วัน";
    const days = Array.isArray(taskData.customRecurringDays)
      ? taskData.customRecurringDays
      : [];
    const mode = taskData.customRecurringMode || "byDueDate";

    let customBase = new Date(base.getTime());
    let customFixedFound = false;

    if (mode === "byFixedDate") {
      const fixedDates = Array.isArray(taskData.customRecurringFixedDates)
        ? taskData.customRecurringFixedDates
        : [];
      if (fixedDates.length > 0) {
        const upcomingFixed = fixedDates
          .map((d) => (d.toDate ? d.toDate() : new Date(d)))
          .filter((d) => d.getTime() > base.getTime())
          .sort((a, b) => a.getTime() - b.getTime());
        if (upcomingFixed.length > 0) {
          const nextFixed = upcomingFixed[0];
          const bkkFixed = toBangkokDate(nextFixed);
          bkkYear = bkkFixed.getUTCFullYear();
          bkkMonth = bkkFixed.getUTCMonth();
          bkkDate = bkkFixed.getUTCDate();
          customFixedFound = true;
        }
      } else if (taskData.recurringDate) {
        customBase = taskData.recurringDate.toDate
          ? taskData.recurringDate.toDate()
          : new Date(taskData.recurringDate);
      }
    }

    if (!customFixedFound) {
      const bkkCustom = toBangkokDate(customBase);
      bkkYear = bkkCustom.getUTCFullYear();
      bkkMonth = bkkCustom.getUTCMonth();
      bkkDate = bkkCustom.getUTCDate();

      if (unit === "วัน") {
        bkkDate += num;
      } else if (unit === "สัปดาห์") {
        if (days.length > 0) {
          const targetDays = days
            .map((d) => THAI_WEEKDAYS_MAP[d])
            .filter((d) => typeof d === "number")
            .sort((a, b) => a - b);

          if (targetDays.length === 0) {
            bkkDate += num * 7;
          } else {
            const currentDay = bkkCustom.getUTCDay();
            const remainingThisWeek = targetDays.filter((d) => d > currentDay);
            if (remainingThisWeek.length > 0) {
              const nextDay = remainingThisWeek[0];
              bkkDate += (nextDay - currentDay);
            } else {
              const firstDay = targetDays[0];
              const daysToEndOfWeek = 7 - currentDay;
              const additionalDays = (num - 1) * 7 + firstDay;
              bkkDate += (daysToEndOfWeek + additionalDays);
            }
          }
        } else {
          bkkDate += num * 7;
        }
      } else if (unit === "เดือน") {
        bkkMonth += num;
      } else if (unit === "ปี") {
        bkkYear += num;
      } else {
        bkkDate += num;
      }
    }
  }

  if (
    typeof taskData.recurringTime === "string" &&
    taskData.recurringTime.includes(":")
  ) {
    const parts = taskData.recurringTime.split(":");
    const h = parseInt(parts[0], 10);
    const m = parseInt(parts[1], 10);
    if (!isNaN(h) && !isNaN(m) && h >= 0 && h <= 23 && m >= 0 && m <= 59) {
      bkkHours = h;
      bkkMinutes = m;
    }
  }

  return fromBangkokDateParts(
    bkkYear,
    bkkMonth,
    bkkDate,
    bkkHours,
    bkkMinutes
  );
}

function getUpcomingRecurringDate(taskData, nowMs) {
  let nextDate = calculateNextRecurringDate(taskData, null);
  if (!nextDate) return null;

  let iterations = 0;
  while (nextDate.getTime() < nowMs && iterations < 50) {
    const candidate = calculateNextRecurringDate(taskData, nextDate);
    if (!candidate || candidate.getTime() <= nextDate.getTime()) break;
    nextDate = candidate;
    iterations++;
  }

  return nextDate;
}

async function ensureNextRecurringTaskInstance(db, taskData, taskId, nowMs) {
  if (taskData.isDeleted === true || taskData.deletedAt != null) return;
  const nextDate = getUpcomingRecurringDate(taskData, nowMs);
  if (!nextDate) return;

  const nextTimestamp = admin.firestore.Timestamp.fromDate(nextDate);

  const cleanTitle = (taskData.title || "").trim().toLowerCase();
  const existingCloneSnap = await db
    .collection("tasks")
    .where("creatorId", "==", taskData.creatorId)
    .where("dateTime", "==", nextTimestamp)
    .limit(10)
    .get();

  const hasActiveClone = existingCloneSnap.docs.some((doc) => {
    const d = doc.data();
    const isMatchingTitle = (d.title || "").trim().toLowerCase() === cleanTitle;
    return isMatchingTitle && d.isDeleted !== true && d.deletedAt == null;
  });

  if (hasActiveClone) {
    return;
  }

  const cloneId = `task_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;

  const initialCustomReminders = {};
  if (taskData.customReminders && typeof taskData.customReminders === "object") {
    Object.keys(taskData.customReminders).forEach((minutesStr) => {
      const minutes = parseInt(minutesStr, 10) || 0;
      const reminderTimeMs = nextDate.getTime() - minutes * 60 * 1000;
      initialCustomReminders[minutesStr] = reminderTimeMs < nowMs;
    });
  }

  const isPastDue = nextDate.getTime() < nowMs;
  const isPastFollowUp = nextDate.getTime() + 30 * 60 * 1000 < nowMs;

  const subtasks = Array.isArray(taskData.subtasks)
    ? taskData.subtasks.map((st) => ({
        ...st,
        isDone: false,
      }))
    : [];

  const cloneData = {
    ...taskData,
    id: cloneId,
    dateTime: nextTimestamp,
    dueDate: nextTimestamp,
    status: "inProgress",
    isCompleted: false,
    completedAt: null,
    clearCompletedAt: true,
    isDeleted: false,
    deletedAt: null,
    expireAt: null,
    deletedForUserIds: [],
    hiddenForUserIds: [],
    notified1Week: nextDate.getTime() - 7 * 24 * 60 * 60 * 1000 < nowMs,
    notified1Day: nextDate.getTime() - 24 * 60 * 60 * 1000 < nowMs,
    notified1Hour: nextDate.getTime() - 60 * 60 * 1000 < nowMs,
    notifiedExact: isPastDue,
    notifiedFollowUp: isPastFollowUp,
    submissionText: null,
    submittedBy: null,
    submittedAt: null,
    awardedXP: 0,
    subtasks: subtasks,
    comments: [],
    customReminders: initialCustomReminders,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    clonedFromTaskId: taskId,
  };

  await db.collection("tasks").doc(cloneId).set(cloneData);
  console.log(
    `🔁 [Auto-Spawn] สร้างภารกิจรอบใหม่สำหรับ "${taskData.title}" สำเร็จ -> วันที่: ${nextDate.toISOString()} (ID: ${cloneId})`
  );
}

// ฟังก์ชันนี้เหมือนนาฬิกาปลุกที่ตั้งเวลาให้ทำงานอัตโนมัติทุกๆ 1 นาที
// หน้าที่หลักคือคอยเช็กว่ามีงานไหนใกล้ถึงกำหนดส่ง หรือเลยเวลาส่งไปแล้วบ้าง
// เพื่อจะได้ส่งข้อความแจ้งเตือนเตือนความจำให้กับสมาชิกหรือหัวหน้างาน
exports.checkDeadlinesAndPushNotify = onSchedule({
  schedule: "* * * * *", // ตั้งเวลาให้ทำงานทุก 1 นาที
  region: FUNCTION_REGION,
  timeZone: "Asia/Bangkok", // ใช้เวลาตามประเทศไทย
}, async (event) => {
  const db = admin.firestore();
  const messaging = admin.messaging();
  const now = admin.firestore.Timestamp.now();
  const nowMs = now.toMillis();

  const ONE_HOUR_MS = 60 * 60 * 1000;
  const ONE_DAY_MS = 24 * 60 * 60 * 1000;
  const ONE_WEEK_MS = 7 * 24 * 60 * 60 * 1000;

  try {
    const tasksSnapshot = await db
      .collection("tasks")
      .where("status", "in", ["todo", "inProgress", "pending"])
      .get();
    console.log(`🔍 รันรอบ 1 นาที! พบภารกิจที่กำลังดำเนินการ: ${tasksSnapshot.size} ชิ้น`);

    const notifiedInThisRun = new Set();

    for (const doc of tasksSnapshot.docs) {
      const taskData = doc.data();
      const taskId = doc.id;

      if (taskData.isDeleted === true || taskData.deletedAt != null) {
        continue;
      }

      const isTaskFinished =
        taskData.status === "completed" || taskData.isCompleted === true;
      if (isTaskFinished) {
        console.log(`⏭️ ภารกิจ ${taskId} เสร็จแล้ว ข้ามการแจ้งเตือน`);
        continue;
      }
      
      const targetDate = taskData.dateTime || taskData.dueDate;
      if (!targetDate) continue;

      const dueDateMs = targetDate.toMillis();
      const timeRemaining = dueDateMs - nowMs;

      // 🛡️ Safeguard: หากงานถูกสร้างขึ้นหลังจากเลยกำหนดเวลาไปแล้ว (เช่น งานทำซ้ำที่รันย้อนหลังเมื่อกดเสร็จงานเก่า)
      // ให้ข้ามการแจ้งเตือนและอัปเดต flag ทันที เพื่อป้องกันแจ้งเตือนซ้ำสำหรับงานอดีต
      const createdAtMs = taskData.createdAt
        ? (taskData.createdAt.toMillis ? taskData.createdAt.toMillis() : new Date(taskData.createdAt).getTime())
        : 0;
      if (createdAtMs > 0 && (createdAtMs - dueDateMs > 60 * 1000) && timeRemaining <= 0) {
        if (!taskData.notifiedExact || !taskData.notifiedFollowUp) {
          await doc.ref.update({
            notifiedExact: true,
            notifiedFollowUp: true,
          });
        }
        continue;
      }
      
      let shouldNotify = false;
      let notificationTitle = "";
      let notificationBody = "";
      let updatePayload = {};
      let notifType = "Reminder";
      let flagToUpdateTag = "";

      // 🔥 ดึงตัวแปรแยกว่าเป็นภารกิจส่วนตัวหรือภารกิจกลุ่ม
      // ภารกิจกลุ่มต้องชนะ category เสมอ เพราะ category อาจยังเป็น "Personal"
      const isGroup = isGroupTask(taskData);
      const isPersonalTask = !isGroup;
      const taskTitle = sanitizeForDisplay(taskData.title || 'ไม่มีชื่อ');

      // -----------------------------------------------------------------
      // 🔥 เงื่อนไขใหม่: วนลูปเช็กแจ้งเตือนแบบ Custom Reminders
      // -----------------------------------------------------------------
      const customReminders = taskData.customReminders || {};
      const reminderEntries = Object.entries(customReminders)
        .map(([minutesStr, isNotified]) => ({
          minutesStr,
          isNotified,
          minutesBefore: parseInt(minutesStr, 10),
        }))
        .filter((entry) => Number.isFinite(entry.minutesBefore) && entry.minutesBefore > 0)
        .sort((a, b) => a.minutesBefore - b.minutesBefore);

      for (const entry of reminderEntries) {
        if (entry.isNotified) continue;

        const reminderTargetMs = entry.minutesBefore * 60 * 1000;
        if (timeRemaining <= reminderTargetMs && timeRemaining > 0) {
          const timeLabel = customReminderLabel(entry.minutesBefore);
          shouldNotify = true;
          updatePayload[`customReminders.${entry.minutesStr}`] = true;
          flagToUpdateTag = `custom_${entry.minutesStr}`;
          notifType = "Reminder";

          if (isPersonalTask) {
            notificationTitle = `⏳ ล่วงหน้า ${timeLabel}!`;
            notificationBody = `อย่าลืมเตรียมตัวสำหรับภารกิจ "${taskTitle}" นะ ใกล้ถึงกำหนดแล้ว`;
          } else {
            notificationTitle = `⏳ อีก ${timeLabel} ส่งงานกลุ่ม!`;
            notificationBody = `ภารกิจ "${taskTitle}" ใกล้ถึงกำหนดแล้ว ทุกคนพร้อมไหม?`;
          }
          break;
        }
      }
      // -----------------------------------------------------------------
      // 🔥 เงื่อนไข: ถึงเวลาเป๊ะ!
      // -----------------------------------------------------------------
      if (!shouldNotify && !taskData.notifiedExact && timeRemaining <= 0) {
        shouldNotify = true;
        updatePayload["notifiedExact"] = true;
        flagToUpdateTag = "notifiedExact";
        notifType = "Deadline";
        if (isGroup) {
          notificationTitle = `⏰ หมดเวลาส่งงานกลุ่มแล้ว!`;
          notificationBody = `ภารกิจ "${taskTitle}" ถึงกำหนดเวลาส่งอย่างเป็นทางการแล้ว`;
        } else {
          notificationTitle = `🎯 ถึงเวลาภารกิจของคุณแล้ว!`;
          notificationBody = `ได้เวลาลุยภารกิจ "${taskTitle}" ที่สร้างไว้แล้ว ขอให้ลื่นไหลและสำเร็จนะ!`;
        }
      }
      // -----------------------------------------------------------------
      // 🔥 เงื่อนไข: ระบบตามภารกิจ (เลยเวลามา 30 นาที และยังไม่เสร็จ)
      // -----------------------------------------------------------------
      else if (!shouldNotify && !taskData.notifiedFollowUp && timeRemaining <= -(30 * 60 * 1000)) {
        shouldNotify = true;
        updatePayload["notifiedFollowUp"] = true;
        flagToUpdateTag = "notifiedFollowUp";
        notifType = "Follow-up";
        if (isGroup) {
          notificationTitle = `❓ ภารกิจกลุ่มเสร็จหรือยังครับ?`;
          notificationBody = `ภารกิจ "${taskTitle}" เลยเวลาส่งมา 30 นาทีแล้ว อย่าลืมเข้าไปอัปเดตสถานะด้วยนะครับ`;
        } else {
          notificationTitle = `❓ อัปเดตความคืบหน้ากันหน่อย`;
          notificationBody = `ภารกิจ "${taskTitle}" สำเร็จลุล่วงหรือยัง? ถ้าเสร็จแล้วอย่าลืมกดทำเครื่องหมายนะ`;
        }
      }

      // --- ส่วนของการยิงข้อความ (เพิ่ม Tag กัน Android บล็อกสแปม) ---
      if (shouldNotify && Object.keys(updatePayload).length > 0) {
        let projectData = null;
        if (
          isGroup &&
          typeof taskData.projectId === "string" &&
          taskData.projectId.trim().length > 0
        ) {
          const projectDoc = await db
            .collection("projects")
            .doc(taskData.projectId.trim())
            .get();
          if (projectDoc.exists) {
            projectData = projectDoc.data();
          }
        }

        const recipients = notificationRecipients(
          taskData,
          isPersonalTask,
          projectData
        );
        console.log(`🎯 ภารกิจ ${taskId} เข้าเงื่อนไขเตือน [${flagToUpdateTag}]`);
        console.log(
          `🧭 ประเภทภารกิจ ${taskId}: ${isGroup ? "group" : "personal"} ` +
          `(type=${taskData.type || "-"}, category=${taskData.category || "-"})`
        );
        console.log(`👥 ผู้รับแจ้งเตือนภารกิจ ${taskId}: ${recipients.length} คน`);

        if (recipients.length === 0) {
          console.log(`⚠️ ภารกิจ ${taskId} เข้าเงื่อนไขเตือน [${flagToUpdateTag}] แต่ไม่พบผู้รับแจ้งเตือน (ข้ามการอัปเดต flag)`);
          continue;
        }

        for (const recipient of recipients) {
          const userId = recipient.userId;
          const userDoc = await db.collection("users").doc(userId).get();
          if (!userDoc.exists) continue;

          const userData = userDoc.data();

          // -----------------------------------------------------------------
          // 🔥 จุดที่อัปเดต: เช็กสวิตช์ Master Switch ของผู้ใช้
          // (ถ้าไม่มีฟิลด์นี้ ให้ถือว่าเปิดแจ้งเตือนเป็นค่าเริ่มต้น)
          // -----------------------------------------------------------------
          const isNotificationEnabled = userData.isNotificationEnabled !== false;

          if (!isNotificationEnabled) {
            console.log(`🔕 ผู้ใช้ ${userId} ปิดการแจ้งเตือนไว้ (ข้ามการส่ง)...`);
            continue; // 🛑 สั่งให้ข้ามการทำภารกิจของลูปนี้ไปเลย ไม่เซฟ ไม่ยิง FCM
          }

          const dedupeKey = `${userId}:${(taskData.title || "").trim().toLowerCase()}:${flagToUpdateTag}`;
          if (notifiedInThisRun.has(dedupeKey)) {
            console.log(
              `⚠️ ข้ามการส่งแจ้งเตือนซ้ำในรอบเดียวกัน -> User: ${userId}, ภารกิจ: "${taskTitle}" [${flagToUpdateTag}]`
            );
            continue;
          }
          notifiedInThisRun.add(dedupeKey);

          const copy = isGroup
            ? groupNotificationCopy(flagToUpdateTag, recipient.role, taskTitle)
            : {title: notificationTitle, body: notificationBody};
          const notificationKey =
            `${taskId}-${flagToUpdateTag}-${recipient.userId}-${recipient.role}`;
          const notificationType = notifType;

          try {
            const expireDate = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
            await db
              .collection("users")
              .doc(userId)
              .collection("notifications")
              .doc(notificationKey)
              .set({
                title: sanitizeForDisplay(copy.title),
                body: sanitizeForDisplay(copy.body),
                type: notificationType,
                isRead: false,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                expireAt: admin.firestore.Timestamp.fromDate(expireDate),
                taskId: taskId,
                taskType: isGroup ? "group" : "personal",
                recipientRole: recipient.role,
                notificationStage: flagToUpdateTag,
                notificationKey: notificationKey,
                suppressPush: true,
              }, { merge: true });
            console.log(
              `💾 บันทึก In-App Notification สำเร็จ! [${flagToUpdateTag}] ` +
              `-> User: ${recipient.userId} (${recipient.role})`
            );
          } catch (err) {
            console.error(
              `🟥 บันทึก In-App Notification ล้มเหลว -> User: ${recipient.userId}:`,
              err
            );
          }

          const fcmToken = asMessageText(userData.fcmToken);
          if (!fcmToken) {
            console.log(`ℹ️ User ${recipient.userId} ไม่มี fcmToken ข้าม FCM`);
            continue;
          }

          const message = {
            notification: {
              title: sanitizeForDisplay(copy.title),
              body: sanitizeForDisplay(copy.body),
            },
            data: {
              title: copy.title,
              body: copy.body,
              taskId: taskId,
              taskType: isGroup ? "group" : "personal",
              recipientRole: recipient.role,
              notificationStage: flagToUpdateTag,
              notificationType: notificationType,
              notificationKey: notificationKey,
              click_action: "FLUTTER_NOTIFICATION_CLICK",
            },
            // ส่ง Hybrid Payload (notification + data) เพื่อให้ Android System Tray
            // แสดงผลแจ้งเตือนทะลุโหมดหลับลึก (Doze Mode) ได้อย่างแม่นยำ 100%
            android: {
              priority: "high",
              ttl: 24 * 60 * 60 * 1000,
              notification: {
                channelId: TASK_REMINDER_CHANNEL_ID,
                sound: "notification",
                icon: "ic_stat_noti_photoroom",
                priority: "max",
                defaultVibrateTimings: false,
                vibrateTimingsMillis: [0, 700, 250, 700],
                visibility: "public",
                tag: notificationKey,
                clickAction: "FLUTTER_NOTIFICATION_CLICK",
              },
            },
            token: fcmToken,
          };

          try {
            await messaging.send(message);
            console.log(
              `🟩 ส่งข้อความสำเร็จ! [${flagToUpdateTag}] ` +
              `-> User: ${recipient.userId} (${recipient.role})`
            );
          } catch (err) {
            if (isInvalidFcmTokenError(err)) {
              await userDoc.ref.set({
                fcmToken: admin.firestore.FieldValue.delete(),
                lastInvalidFcmTokenAt:
                  admin.firestore.FieldValue.serverTimestamp(),
              }, { merge: true });
            }
            console.error(`🟥 ส่งข้อความล้มเหลว -> User: ${recipient.userId}:`, err);
          }
        }

        // อัปเดตแฟลกที่แจ้งเตือนไปแล้วให้เป็น true
        await db.collection("tasks").doc(taskId).update(updatePayload);
      }

      // 🔁 Auto-spawn recurring task instance for the next cycle
      if (
        taskData.isRecurring === true &&
        taskData.isDeleted !== true &&
        taskData.deletedAt == null &&
        (taskData.notifiedFollowUp === true ||
          updatePayload["notifiedFollowUp"] === true ||
          timeRemaining <= -(30 * 60 * 1000))
      ) {
        try {
          await ensureNextRecurringTaskInstance(db, taskData, taskId, nowMs);
        } catch (recurringErr) {
          console.error(
            `🟥 Auto-spawn recurring task failed for ${taskId}:`,
            recurringErr
          );
        }
      }
    }
  } catch (error) {
    console.error("เกิดข้อผิดพลาดในการรันระบบจับเวลา:", error);
  }
  return null;
});
